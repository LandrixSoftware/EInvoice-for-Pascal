<#
.SYNOPSIS
  Builds and runs the EInvoice-for-Pascal test runner with one or more local toolchains.

.DESCRIPTION
  Every toolchain writes to build/<toolchain>/ so compiled units never mix.
  Compiler warnings, hints and notes that point into a source file (own code
  or the LandrixXml submodule) count as failures (target: zero on all
  compilers). Exit code 0 = everything green.

  Requires the submodule: git submodule update --init

  Toolchain names:
    fpc322-linux fpc324-linux fpc331-linux   FPC under WSL (aarch64-linux)
    fpc322-win32 fpc322-win64 fpc331-winarm  FPC on Windows
    d6 d7                                    Delphi 6 / Delphi 7 (Win32)
    d13-win32 d13-win64                      Delphi 13
    d13-osxarm64                             Delphi 13 macOS ARM64 (LLVM back end),
                                             compile only: every unit under source/,
                                             tests/ and external/landrix-xml/source
                                             (and everything they use) is compiled,
                                             nothing is linked or run, because the
                                             macOS SDK is not imported (PAServer)
    mac                                      FPC 3.2.4 on the Mac via SSH
  Append "-checked" to any local toolchain (e.g. fpc322-linux-checked,
  d6-checked) to build with overflow and range checking, as consuming
  projects may do in debug builds.
  Sets: min (fpc322-linux, fpc322-linux-checked, d6, d13-win32),
        all (everything above plus d6-checked and d13-win64-checked).

  Cross test: every test run writes all scenarios to build/<toolchain>/cross/
  (test Cross.Write, needs tests/data/local). After the runs, each local
  toolchain that ran reads the files of the next one in the list
  (-filter=Cross.Read -cross=<folder>, the last reads the first), so Delphi
  reads what FPC wrote and the other way round. Before that, the outputs of
  all these toolchains must be byte-identical (rows "same output"). Needs at
  least two local toolchains; mac and d13-osxarm64 take no part.

  -Validate: afterwards the KoSIT validator checks the cross output of the
  first local toolchain and its reduced Factur-X profiles in
  build/<toolchain>/profiles/ (test CIIProfiles.WriteScenarios) and the
  business cases in build/<toolchain>/cases/ (tests Cases.*)
  (tools/validate.ps1; tools from addons/java-tools/install-tools.ps1),
  and tools/testdata/xr-compare.py compares the sweep sources and outputs
  in the KoSIT XR form (test Sweep.Official, local corpora needed).

.EXAMPLE
  ./tools/build.ps1                 # minimum set
  ./tools/build.ps1 all
  ./tools/build.ps1 d6,d7 -NoRun
#>
param(
  [string[]]$Toolchains = @('min'),
  [string]$Program = 'tests/LandrixEInvoiceTests.dpr',
  [switch]$NoRun,
  [switch]$AllowWarnings,
  [switch]$Validate
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Delphi6  = 'D:\Projekte\Borland\Delphi6'
$Delphi7  = 'D:\Projekte\Borland\Delphi7'
$Delphi13 = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'
$LocalBin = Join-Path $env:USERPROFILE '.local\bin'
$MacRunner = Join-Path $env:USERPROFILE '.local\share\remote-toolchains\macos-fpc\Run-PascalProgram.ps1'

# Unit and include search paths, relative to the repository root.
$XmlSource = 'external/landrix-xml/source'
$UnitDirs = @('source', $XmlSource, 'tests')
$IncDirs = @('source', $XmlSource)

if (-not (Test-Path "$XmlSource/LandrixXmlBase.pas")) {
  Write-Host "Submodule missing: run 'git submodule update --init'" -ForegroundColor Red
  exit 1
}

$Sets = @{
  'min' = @('fpc322-linux', 'fpc322-linux-checked', 'd6', 'd13-win32')
  'all' = @('fpc322-linux', 'fpc322-linux-checked', 'fpc324-linux', 'fpc331-linux',
            'fpc322-win32', 'fpc322-win64', 'fpc331-winarm',
            'd6', 'd6-checked', 'd7', 'd13-win32', 'd13-win64', 'd13-win64-checked',
            'd13-osxarm64', 'mac')
}

$expanded = @()
foreach ($t in ($Toolchains -join ',').Split(',')) {
  $t = $t.Trim()
  if ($t -eq '') { continue }
  if ($Sets.ContainsKey($t)) { $expanded += $Sets[$t] } else { $expanded += $t }
}

$Program = $Program -replace '\\', '/'
$ProgramName = [IO.Path]::GetFileNameWithoutExtension($Program)
$WslRoot = '/mnt/' + $Root.Substring(0, 1).ToLower() + ($Root.Substring(2) -replace '\\', '/')

$FpcPaths = @($UnitDirs | ForEach-Object { "-Fu$_" }) + @($IncDirs | ForEach-Object { "-Fi$_" })
$DccUnits = ($UnitDirs | ForEach-Object { $_ -replace '/', '\' }) -join ';'
$DccIncs = ($IncDirs | ForEach-Object { $_ -replace '/', '\' }) -join ';'

function Count-OwnDiagnostics([string[]]$Lines) {
  # Delphi: file.pas(12) Warning: ...   FPC: file.pas(12,5) Warning: ...
  # Language-independent (the local Delphi 13 prints "Warnung"/"Hinweis"):
  # every compiler line pointing into a source file is a diagnostic. Errors
  # already fail through the exit code.
  $own = $Lines | Where-Object {
    $_ -match '\.(pas|inc|dpr|lpr)\(\d+(,\d+)?\)'
  }
  return @($own)
}

function Invoke-Toolchain([string]$Name) {
  $out = "build/$Name"
  New-Item -ItemType Directory -Force $out | Out-Null
  # the cross test may only see what this run writes
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$out/cross"
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$out/profiles"
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$out/sweep"
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$out/sweep-source"
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$out/sweep-cross"
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$out/cases"
  $exe = $null
  $log = @()
  $runCmd = $null
  $Base = $Name -replace '-checked$', ''
  $Checked = $Base -ne $Name
  $fpcChecks = if ($Checked) { @('-Co', '-Cr') } else { @() }
  $dccChecks = if ($Checked) { @('-$Q+', '-$R+') } else { @() }

  switch -Regex ($Base) {
    '^fpc(\d+)-linux$' {
      $fpc = "~/.local/bin/fpc$($Matches[1])"
      $cmd = "cd '$WslRoot' && $fpc -B -vewnhi $($fpcChecks -join ' ') $($FpcPaths -join ' ') -FU$out -FE$out '$Program' 2>&1"
      $log = & wsl.exe -e bash -lc $cmd
      $code = $LASTEXITCODE
      $runCmd = { & wsl.exe -e bash -lc "cd '$WslRoot' && './build/$Name/$ProgramName' '$WslRoot'" }
    }
    '^fpc\d+-win(32|64|arm)$' {
      $wrapper = Join-Path $LocalBin "$Base.cmd"
      $log = & $wrapper -B -vewnhi @fpcChecks @FpcPaths "-FU$out" "-FE$out" $Program 2>&1
      $code = $LASTEXITCODE
      $exe = "$out/$ProgramName.exe"
    }
    '^d(6|7)$' {
      $d = if ($Matches[1] -eq '6') { $Delphi6 } else { $Delphi7 }
      # dcc32 of Delphi 6/7 ignores a relative -N and writes the DCUs next to
      # the sources, so pass the absolute path.
      $winOut = (Resolve-Path $out).Path
      $log = & "$d\Bin\dcc32.exe" -B -Q -W -H @dccChecks "-U$d\Lib;$DccUnits" "-I$DccIncs" "-N$winOut" "-E$winOut" ($Program -replace '/', '\') 2>&1
      $code = $LASTEXITCODE
      $exe = "$out/$ProgramName.exe"
    }
    '^d13-win(32|64)$' {
      $bits = $Matches[1]
      $dcc = if ($bits -eq '32') { 'dcc32.exe' } else { 'dcc64.exe' }
      $log = & "$Delphi13\bin\$dcc" -B -Q -W -H @dccChecks '-NSSystem;System.Win;Winapi' "-U$Delphi13\lib\win$bits\release;$DccUnits" "-I$DccIncs" "-NU$out" "-E$out" $Program 2>&1
      $code = $LASTEXITCODE
      $exe = "$out/$ProgramName.exe"
    }
    '^d13-osxarm64$' {
      # Compile only: linking needs the macOS SDK (imported through PAServer),
      # which is not set up. Every unit under source/ and tests/ and every
      # LandrixXml unit is compiled, together with everything it uses.
      $code = 0
      $log = @()
      $units = @(Get-ChildItem source -Filter *.pas | Sort-Object Name) +
               @(Get-ChildItem tests -Filter *.pas | Sort-Object Name) +
               @(Get-ChildItem $XmlSource -Filter *.pas | Sort-Object Name)
      foreach ($unit in $units) {
        $log += & "$Delphi13\bin\dccosxarm64.exe" -B -Q -W -H @dccChecks '-NSSystem' "-U$Delphi13\lib\osxarm64\release;$DccUnits" "-I$DccIncs" "-NU$out" $unit.FullName 2>&1
        if ($LASTEXITCODE -ne 0) { $code = $LASTEXITCODE }
      }
      $log = @($log | ForEach-Object { "$_" })
      $log | Set-Content -Encoding utf8 "$out/build.log"
      $diag = Count-OwnDiagnostics $log
      if ($code -ne 0) {
        # later units keep compiling, so show the error lines, not only the tail
        $log | Where-Object { $_ -match 'Fehler|Error|Schwerwiegend|Fatal' } | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
      } else {
        $diag | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
        Write-Host '  compiled only (not linked, tests not run)'
      }
      return @{ Name = $Name; Build = $code; Diag = $diag.Count; Run = $null; Log = $log }
    }
    '^mac$' {
      if (-not (Test-Path $MacRunner)) { throw "Mac runner not found: $MacRunner" }
      $log = & $MacRunner -Repository $Root -Program $Program -UnitPath $UnitDirs -NoRun:$NoRun 2>&1
      $code = $LASTEXITCODE
      $log = @($log | ForEach-Object { "$_" })
      $log | Set-Content -Encoding utf8 "$out/build.log"
      Count-OwnDiagnostics $log | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
      $log | Where-Object { $_ -match 'test\(s\)|^FAIL|^ERROR|Fatal|Error:' } | ForEach-Object { Write-Host $_ }
      return @{ Name = $Name; Build = $code; Diag = (Count-OwnDiagnostics $log).Count; Run = $code; Log = $log }
    }
    default { throw "Unknown toolchain: $Name" }
  }

  $log = @($log | ForEach-Object { "$_" })
  $log | Set-Content -Encoding utf8 "$out/build.log"
  $diag = Count-OwnDiagnostics $log
  $result = @{ Name = $Name; Build = $code; Diag = $diag.Count; Run = $null; Log = $log }
  if ($code -ne 0) {
    $log | Select-Object -Last 30 | ForEach-Object { Write-Host "  $_" }
    return $result
  }
  $diag | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
  if (-not $NoRun) {
    if ($runCmd) { & $runCmd | Out-Host } else { & $exe $Root | Out-Host }
    $result.Run = $LASTEXITCODE
  }
  return $result
}

$results = @()
foreach ($t in $expanded) {
  Write-Host "=== $t ===" -ForegroundColor Cyan
  try {
    $results += Invoke-Toolchain $t
  } catch {
    Write-Host "  $_" -ForegroundColor Red
    $results += @{ Name = $t; Build = -1; Diag = 0; Run = $null }
  }
}

# Cross test: each local toolchain reads what the next one wrote.
$ring = @($results | Where-Object {
  $_.Build -eq 0 -and $_.Run -eq 0 -and $_.Name -notmatch '^(mac|d13-osxarm64)$' -and
  (Test-Path "build/$($_.Name)/cross/*.xml")
})
if (-not $NoRun -and $ring.Count -lt 2) {
  Write-Host "cross test skipped: $($ring.Count) local toolchain(s) with cross output" -ForegroundColor Yellow
}
if (-not $NoRun -and $ring.Count -ge 2) {
  # every toolchain must have written the same files
  $first = $ring[0].Name
  $reference = @{}
  Get-ChildItem "build/$first/cross" -Filter *.xml | ForEach-Object { $reference[$_.Name] = (Get-FileHash $_.FullName).Hash }
  foreach ($member in $ring) {
    $same = $true
    $files = @(Get-ChildItem "build/$($member.Name)/cross" -Filter *.xml)
    if ($files.Count -ne $reference.Count) {
      Write-Host "  $($member.Name): $($files.Count) files, $first has $($reference.Count)" -ForegroundColor Red
      $same = $false
    }
    foreach ($f in $files) {
      if ($reference[$f.Name] -ne (Get-FileHash $f.FullName).Hash) {
        Write-Host "  $($member.Name): $($f.Name) differs from $first" -ForegroundColor Red
        $same = $false
      }
    }
    $results += @{ Name = "same output $($member.Name)"; Build = 0; Diag = 0; Run = $(if ($same) { 0 } else { 1 }) }
  }
  for ($i = 0; $i -lt $ring.Count; $i++) {
    $reader = $ring[$i].Name
    $writer = $ring[($i + 1) % $ring.Count].Name
    Write-Host "=== cross: $reader reads $writer ===" -ForegroundColor Cyan
    if ($reader -match '-linux') {
      & wsl.exe -e bash -lc "cd '$WslRoot' && './build/$reader/$ProgramName' '$WslRoot' -filter=Cross.Read '-cross=$WslRoot/build/$writer/cross'" | Out-Host
    } else {
      & "build/$reader/$ProgramName.exe" $Root '-filter=Cross.Read' "-cross=$Root\build\$writer\cross" | Out-Host
    }
    $results += @{ Name = "cross $reader<-$writer"; Build = 0; Diag = 0; Run = $LASTEXITCODE }
  }
}

if ($Validate -and -not $NoRun) {
  $source = @($results | Where-Object {
    $_.Build -eq 0 -and $_.Run -eq 0 -and $_.Name -notmatch '^(mac|d13-osxarm64)$' -and
    (Test-Path "build/$($_.Name)/cross/*.xml")
  }) | Select-Object -First 1
  if ($null -eq $source) {
    Write-Host 'validation skipped: no toolchain with cross output' -ForegroundColor Yellow
    $results += @{ Name = 'KoSIT validation'; Build = 0; Diag = 0; Run = 1 }
  } else {
    foreach ($folder in @('cross', 'profiles', 'cases')) {
      # profiles/ needs the local attachments like cross/ (test CIIProfiles.WriteScenarios);
      # cases/ comes from the business cases (Cases.*)
      if (-not (Test-Path "build/$($source.Name)/$folder/*.xml")) {
        Write-Host "validation of $folder skipped: no output" -ForegroundColor Yellow
        continue
      }
      Write-Host "=== KoSIT validation of $($source.Name)/$folder ===" -ForegroundColor Cyan
      try {
        & (Join-Path $PSScriptRoot 'validate.ps1') -Folder "build/$($source.Name)/$folder" | Out-Host
        $code = $LASTEXITCODE
      } catch {
        Write-Host "  $_" -ForegroundColor Red
        $code = 1
      }
      $results += @{ Name = "KoSIT validation $($source.Name)/$folder"; Build = 0; Diag = 0; Run = $code }
    }
    # independent oracle: sweep sources and outputs in the KoSIT XR form
    if (Test-Path "build/$($source.Name)/sweep/*.xml") {
      Write-Host "=== XR comparison of $($source.Name)/sweep ===" -ForegroundColor Cyan
      try {
        & python (Join-Path $PSScriptRoot 'testdata/xr-compare.py') --toolchain $source.Name | Out-Host
        $code = $LASTEXITCODE
      } catch {
        Write-Host "  $_" -ForegroundColor Red
        $code = 1
      }
      $results += @{ Name = "XR comparison $($source.Name)/sweep"; Build = 0; Diag = 0; Run = $code }
    }
  }
}

Write-Host ''
Write-Host 'Summary' -ForegroundColor Cyan
$failed = $false
foreach ($r in $results) {
  $state = 'OK'
  if ($r.Build -ne 0) { $state = 'BUILD FAILED'; $failed = $true }
  elseif ($r.Diag -gt 0 -and -not $AllowWarnings) { $state = "WARNINGS ($($r.Diag))"; $failed = $true }
  if ($r.Build -eq 0 -and $null -ne $r.Run -and $r.Run -ne 0) { $state = "TESTS FAILED"; $failed = $true }
  '{0,-46} {1}' -f $r.Name, $state | Write-Host
}
if ($failed) { exit 1 } else { exit 0 }
