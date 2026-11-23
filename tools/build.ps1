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
    x86                                      runs the tests of every Windows
                                             toolchain of the call (fpc*-win32,
                                             fpc*-win64, d6, d7, d13-win32,
                                             d13-win64, also -checked) on real
                                             x86 hardware (SSH alias ai-rtx5090)
                                             instead of the x86 emulator of this
                                             ARM machine: faster, and the
                                             emulator computes some x87 results
                                             wrongly
  Append "-checked" to any local toolchain (e.g. fpc322-linux-checked,
  d6-checked) to build with overflow and range checking, as consuming
  projects may do in debug builds.
  Sets: min (fpc322-linux, fpc322-linux-checked, d6, d13-win32),
        dev (before every commit: fpc322-win64, fpc322-win32,
        fpc322-linux-checked, d6, d13-win32, d13-win64, x86),
        all (before a release: every toolchain above plus d6-checked,
        d13-win64-checked, d13-osxarm64, mac and x86).
  x86: the Windows toolchains are built here and their examples run here;
  their test runners run on the x86 machine at the same time in a work
  tree kept there (D:\AI-Work\landrix-einvoice-data: every tracked file
  and the git-ignored test data, tests/data/local and the KoSIT folders
  under addons/), brought up to date before each run (only changed files go
  over); the output folders the cross test and -Validate need come back
  (cross, profiles, cases, sweep*, reports under build/<toolchain>/). One x86
  run at a time (lock folder x86.lock). One build.ps1 run per checkout at a
  time: runs from the same checkout share build/ and the WSL mirror. If the
  machine does not answer, the
  tests run here with a warning. x86 takes only the test runner.

  Examples: after the tests, every example of the list $Examples
  (examples/<Name>/<Name>.dpr) is compiled
  into build/<toolchain>/examples/ (reusing the compiled units) and run there
  in a fixed order with fixed arguments; a build error, a diagnostic or an
  exit code other than 0 fails the toolchain. Not for mac, d13-osxarm64 and
  the -checked variants, and only for the default program. The GUI example
  Workbench (VCL) is only compiled, and only by Delphi (the FPC toolchains
  have no LCL; its Lazarus project is built with lazbuild, see the example).

  Cross test: every test run writes all scenarios to build/<toolchain>/cross/
  (test Cross.Write). After the runs, each local
  toolchain that ran reads the files of the next one in the list
  (-filter=Cross.Read -cross=<folder>, the last reads the first), so Delphi
  reads what FPC wrote and the other way round. Before that, the outputs of
  all these toolchains must be byte-identical (rows "same output"). Needs at
  least two local toolchains; mac and d13-osxarm64 take no part.

  WSL mirror: for the test runner, the Linux toolchains do not work on
  /mnt/d (9P, very slow with the thousands of corpus files) but in a copy
  in the WSL file system, ~/landrix-einvoice-mirror-<hash of the checkout
  path> (one per checkout or worktree), brought up to date
  once per call with rsync (only changes; build/, .git and the large tool
  folders under addons/ excluded). They build, test and run the examples
  there; the output folders the cross test and -Validate need come back to
  build/<toolchain>/ (the same list as for x86).

  Parallel runs: the local toolchains build and run at the same time, each
  in a child process of this script (-Worker) with its output in
  build/<toolchain>/worker.log, which is printed when it ends; -Jobs sets
  how many run at once (default: processor count minus 2), -Jobs 1 runs
  them one after the other in this process as before. Every toolchain has
  its own build/<toolchain>/ folder, so the runs share no output. x86
  starts as soon as every Windows toolchain of the call is built and has
  run its examples (also a
  child process, output in build/x86/worker.log), while the others still
  run; the cross test and -Validate run at the end.

  -Validate: afterwards the KoSIT validator checks the cross output of the
  first local toolchain and its reduced Factur-X profiles in
  build/<toolchain>/profiles/ (test CIIProfiles.WriteScenarios), the
  business cases in build/<toolchain>/cases/ (tests Cases.*) and the sweep
  outputs in build/<toolchain>/sweep/ (test Sweep.Official)
  (tools/validate.ps1; tools from addons/java-tools/install-tools.ps1),
  and tools/testdata/xr-compare.py compares the sweep sources and outputs
  in the KoSIT XR form (test Sweep.Official, local corpora needed).

.EXAMPLE
  ./tools/build.ps1                 # minimum set
  ./tools/build.ps1 dev             # before every commit
  ./tools/build.ps1 all             # before a release
  ./tools/build.ps1 d6,d7 -NoRun
  ./tools/build.ps1 dev -Jobs 1     # one toolchain after the other
#>
param(
  [string[]]$Toolchains = @('min'),
  [string]$Program = 'tests/LandrixEInvoiceTests.dpr',
  [switch]$NoRun,
  [switch]$AllowWarnings,
  [switch]$Validate,
  [int]$Jobs = 0,
  # internal: run one toolchain as a child process of a parallel run
  [switch]$Worker,
  [switch]$X86Deferred,
  [switch]$X86Worker,
  [string]$X86Names = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

# Compiler folders: the environment variables LANDRIXEINVOICE_DELPHI6, _DELPHI7
# and _DELPHI13 override the defaults of the maintainer's machine.
function Get-Folder([string]$Variable, [string]$Default) {
  $value = [Environment]::GetEnvironmentVariable($Variable)
  if ([string]::IsNullOrEmpty($value)) { return $Default }
  return $value
}
$Delphi6  = Get-Folder 'LANDRIXEINVOICE_DELPHI6' 'D:\Projekte\Borland\Delphi6'
$Delphi7  = Get-Folder 'LANDRIXEINVOICE_DELPHI7' 'D:\Projekte\Borland\Delphi7'
$Delphi13 = Get-Folder 'LANDRIXEINVOICE_DELPHI13' 'C:\Program Files (x86)\Embarcadero\Studio\37.0'
$LocalBin = Join-Path $env:USERPROFILE '.local\bin'
$MacRunner = Join-Path $env:USERPROFILE '.local\share\remote-toolchains\macos-fpc\Run-PascalProgram.ps1'
$X86Host = 'ai-rtx5090'
$X86Base = 'D:\AI-Work'
$X86Store = 'landrix-einvoice-data'
# git-ignored folders the tests read; kept in the lasting copy on the x86 machine
$X86DataDirs = @('tests/data/local',
  'addons/java-tools/validator-configuration-bis', 'addons/java-tools/validator-configuration-xrechnung',
  'addons/java-tools/validator-configuration-zugferd', 'addons/java-tools/xrechnung-visualization',
  'addons/kosit/validator-configuration-bis', 'addons/kosit/validator-configuration-xrechnung',
  'addons/kosit/validator-configuration-zugferd', 'addons/kosit/xrechnung-visualization', 'addons/kosit/rules')
# outputs of a test run the cross test, -Validate and a failed golden test need;
# the rest stays there (a Delphi 6 runner writes file names tar cannot read)
$X86Outputs = @('cross', 'profiles', 'cases', 'sweep', 'sweep-source', 'sweep-cross', 'reports')
# -n: the parallel ssh processes must not read the console's keyboard input (scp has no -n)
$X86SshN = @('-n')
$X86Ssh = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15', '-o', 'ServerAliveInterval=15', '-o', 'ServerAliveCountMax=8')

# Unit and include search paths, relative to the repository root.
$XmlSource = 'external/landrix-xml/source'
$UnitDirs = @('source', $XmlSource, 'tests', 'examples/BusinessCases')
$IncDirs = @('source', $XmlSource)

if (-not (Test-Path "$XmlSource/LandrixXmlBase.pas")) {
  Write-Host "Submodule missing: run 'git submodule update --init'" -ForegroundColor Red
  exit 1
}

$Sets = @{
  'min' = @('fpc322-linux', 'fpc322-linux-checked', 'd6', 'd13-win32')
  'dev' = @('fpc322-win64', 'fpc322-win32', 'fpc322-linux-checked', 'd6', 'd13-win32', 'd13-win64', 'x86')
  'all' = @('fpc322-linux', 'fpc322-linux-checked', 'fpc324-linux', 'fpc331-linux',
            'fpc322-win32', 'fpc322-win64', 'fpc331-winarm',
            'd6', 'd6-checked', 'd7', 'd13-win32', 'd13-win64', 'd13-win64-checked',
            'd13-osxarm64', 'mac', 'x86')
}

$expanded = @()
foreach ($t in ($Toolchains -join ',').Split(',')) {
  $t = $t.Trim().ToLowerInvariant()
  if ($t -eq '') { continue }
  if ($Sets.ContainsKey($t)) { $expanded += $Sets[$t] } else { $expanded += $t }
}
if ($expanded.Count -eq 0) {
  Write-Host 'no toolchain given' -ForegroundColor Red
  exit 1
}
if ($Validate -and $NoRun) {
  Write-Host '-Validate needs the test run; it cannot be combined with -NoRun' -ForegroundColor Red
  exit 1
}

$IsTestRunner = ($Program -replace '\\', '/') -eq 'tests/LandrixEInvoiceTests.dpr'
$Program = $Program -replace '\\', '/'
$ProgramName = [IO.Path]::GetFileNameWithoutExtension($Program)
$WslRoot = '/mnt/' + $Root.Substring(0, 1).ToLower() + ($Root.Substring(2) -replace '\\', '/')
# work tree of the Linux toolchains inside WSL (expanded by bash)
$RootHash = (Get-FileHash -Algorithm SHA256 -InputStream ([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($Root.ToLowerInvariant())))).Hash.Substring(0, 8).ToLower()
$WslMirror = '$HOME/landrix-einvoice-mirror-' + $RootHash
$WslExcludes = @('/build/', '.git', '/addons/java-tools/jre/', '/addons/java-tools/download/',
  '/addons/java-tools/mustang/', '/addons/java-tools/qpdf/', '/addons/java-tools/verapdf/',
  '/addons/java-tools/validator/', '/addons/java-tools/commonmark/', '/addons/kosit/download/', '__pycache__/')
# the test runner and its examples build in the mirror, other programs (probes) on /mnt/d
$WslWork = if ($IsTestRunner) { "`"$WslMirror`"" } else { "'$WslRoot'" }

$FpcPaths = @($UnitDirs | ForEach-Object { "-Fu$_" }) + @($IncDirs | ForEach-Object { "-Fi$_" })
$DccUnits = ($UnitDirs | ForEach-Object { $_ -replace '/', '\' }) -join ';'
$DccIncs = ($IncDirs | ForEach-Object { $_ -replace '/', '\' }) -join ';'
# the same as absolute paths, for compiling an example in its own folder
$AbsDccUnits = ($UnitDirs | ForEach-Object { (Resolve-Path $_).Path }) -join ';'
$AbsDccIncs = ($IncDirs | ForEach-Object { (Resolve-Path $_).Path }) -join ';'

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

# Examples in run order with their arguments (run in build/<toolchain>/examples/);
# later ones read what WriteXRechnung wrote.
$Examples = @(
  @{ Name = 'WriteXRechnung';  Args = @('.') },
  @{ Name = 'ReadInvoice';     Args = @('xrechnung-ubl.xml') },
  @{ Name = 'CheckInvoice';    Args = @('xrechnung-ubl.xml') },
  @{ Name = 'ConvertCIIToUBL'; Args = @('xrechnung-cii.xml', 'converted-ubl.xml') },
  @{ Name = 'CompatXRechnung'; Args = @('xrechnung-ubl.xml') },
  @{ Name = 'BusinessCases';   Args = @('business-cases', '../../../examples/BusinessCases/attachments') },
  @{ Name = 'Workbench';       Gui = $true }
)

# Compiles and runs the examples with one toolchain; returns the number of
# failures and adds the compiler diagnostics to $Result.Diag.
function Invoke-Examples([string]$Name, [string]$Base, [string[]]$Checks, $Result) {
  $out = "build/$Name"
  $exOut = "$out/examples"
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $exOut
  New-Item -ItemType Directory -Force $exOut | Out-Null
  if ($Base -match '-linux$') {
    # later examples read what WriteXRechnung wrote: clear the folder once
    & wsl.exe -e bash -lc "cd $WslWork && rm -rf $exOut && mkdir -p $exOut" | Out-Host
    if ($LASTEXITCODE -ne 0) {
      Write-Host "FAIL examples: cannot prepare $exOut in the WSL mirror" -ForegroundColor Red
      return 1
    }
  }
  $failed = 0
  foreach ($ex in $Examples) {
    $dpr = "examples/$($ex.Name)/$($ex.Name).dpr"
    if (-not (Test-Path $dpr)) { continue }
    if ($ex.Gui -and $Base -notmatch '^d') { continue }
    $runCmd = $null
    switch -Regex ($Base) {
      '^fpc(\d+)-linux$' {
        $fpc = "~/.local/bin/fpc$($Matches[1])"
        $log = & wsl.exe -e bash -lc "cd $WslWork && $fpc -vewnhi $($Checks -join ' ') $($FpcPaths -join ' ') -FU$out -FE$exOut '$dpr' 2>&1"
        $code = $LASTEXITCODE
        $argText = ($ex.Args | ForEach-Object { "'$_'" }) -join ' '
        $runCmd = { & wsl.exe -e bash -lc "cd $WslWork/$exOut && './$($ex.Name)' $argText" }
      }
      '^fpc\d+-win(32|64|arm)$' {
        $log = & (Join-Path $LocalBin "$Base.cmd") -vewnhi @Checks @FpcPaths "-FU$out" "-FE$exOut" $dpr 2>&1
        $code = $LASTEXITCODE
      }
      '^d(6|7)$' {
        $d = if ($Matches[1] -eq '6') { $Delphi6 } else { $Delphi7 }
        $winOut = (Resolve-Path $out).Path
        # in the example's folder: Delphi 6 resolves "in 'File.pas'" of a
        # program against the current folder (the form unit of Workbench)
        Push-Location "examples/$($ex.Name)"
        try {
          $log = & "$d\Bin\dcc32.exe" -Q -W -H @Checks "-U$d\Lib;$winOut;$AbsDccUnits" "-I$AbsDccIncs" "-N$winOut" "-E$winOut\examples" "$($ex.Name).dpr" 2>&1
          $code = $LASTEXITCODE
        } finally { Pop-Location }
      }
      '^d13-win(32|64)$' {
        $bits = $Matches[1]
        $dcc = if ($bits -eq '32') { 'dcc32.exe' } else { 'dcc64.exe' }
        $winOut = (Resolve-Path $out).Path
        $winExOut = (Resolve-Path $exOut).Path
        Push-Location "examples/$($ex.Name)"
        try {
          $log = & "$Delphi13\bin\$dcc" -Q -W -H @Checks '-NSSystem;System.Win;Winapi;Vcl' "-U$Delphi13\lib\win$bits\release;$winOut;$AbsDccUnits" "-I$AbsDccIncs" "-NU$winOut" "-E$winExOut" "$($ex.Name).dpr" 2>&1
          $code = $LASTEXITCODE
        } finally { Pop-Location }
      }
      default { return 0 }
    }
    $log = @($log | ForEach-Object { "$_" })
    $log | Set-Content -Encoding utf8 "$exOut/$($ex.Name).build.log"
    $diag = Count-OwnDiagnostics $log
    $Result.Diag += $diag.Count
    $diag | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    if ($code -ne 0) {
      $log | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
      Write-Host "FAIL example $($ex.Name): build" -ForegroundColor Red
      $failed++
      continue
    }
    if ($ex.Gui) { continue }
    if ($runCmd) {
      $runLog = & $runCmd 2>&1
    } else {
      Push-Location $exOut
      try { $runLog = & ".\$($ex.Name).exe" @($ex.Args) 2>&1 } finally { Pop-Location }
    }
    $runCode = $LASTEXITCODE
    @($runLog | ForEach-Object { "$_" }) | Set-Content -Encoding utf8 "$exOut/$($ex.Name).run.log"
    if ($runCode -ne 0) {
      $runLog | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
      Write-Host "FAIL example $($ex.Name): exit code $runCode" -ForegroundColor Red
      $failed++
    }
  }
  Write-Host "  examples: $failed failure(s)"
  return $failed
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
      # outputs of an earlier run must not reach the cross test
      $clean = ($X86Outputs | ForEach-Object { "$out/$_" }) -join ' '
      $cmd = "cd $WslWork && mkdir -p $out && rm -rf $clean && $fpc -B -vewnhi $($fpcChecks -join ' ') $($FpcPaths -join ' ') -FU$out -FE$out '$Program' 2>&1"
      $log = & wsl.exe -e bash -lc $cmd
      $code = $LASTEXITCODE
      $runCmd = { & wsl.exe -e bash -lc "cd $WslWork && './build/$Name/$ProgramName' `"`$PWD`"" }
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
    # with x86 in the list, the test runners of the Windows toolchains run
    # there; their examples still run here
    if ($X86Present -and (Test-X86Toolchain $Name)) {
      Write-Host '  tests run on x86'
    } else {
      if ($runCmd) { & $runCmd | Out-Host } else { & $exe $Root | Out-Host }
      $result.Run = $LASTEXITCODE
      if ($IsTestRunner -and $Base -match '-linux$' -and -not (Copy-WslOutputs $Name) -and $result.Run -eq 0) { $result.Run = 1 }
    }
    if ($IsTestRunner -and -not $Checked) {
      $checks = if ($Base -like 'fpc*') { $fpcChecks } else { $dccChecks }
      if ((Invoke-Examples $Name $Base $checks $result) -gt 0 -and ($null -eq $result.Run -or $result.Run -eq 0)) { $result.Run = 1 }
    }
  }
  return $result
}

# Brings the WSL mirror up to date (rsync: only changes, deletes what is gone here).
function Sync-WslMirror {
  $ex = ($WslExcludes | ForEach-Object { "--exclude='$_'" }) -join ' '
  $sw = [Diagnostics.Stopwatch]::StartNew()
  & wsl.exe -e bash -lc "mkdir -p $WslMirror && rsync -a --delete $ex '$WslRoot/' $WslMirror/" | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "rsync to the WSL mirror failed (exit code $LASTEXITCODE)" }
  Write-Host ("WSL mirror up to date ({0:N1} min)" -f $sw.Elapsed.TotalMinutes)
}

# Copies the output folders of a Linux test run from the mirror to build/<toolchain>/.
function Copy-WslOutputs([string]$Name) {
  $parts = @()
  foreach ($sub in $X86Outputs) {
    $from = "$WslMirror/build/$Name/$sub"
    $to = "$WslRoot/build/$Name/$sub"
    $parts += "if [ -d $from ]; then mkdir -p '$to' && rsync -a --delete $from/ '$to/'; else rm -rf '$to'; fi"
  }
  & wsl.exe -e bash -lc ($parts -join ' && ') | Out-Host
  if ($LASTEXITCODE -ne 0) {
    Write-Host "  copying the outputs of $Name back failed" -ForegroundColor Red
    return $false
  }
  return $true
}

# Windows toolchains whose test runner can run on the x86 machine.
function Test-X86Toolchain([string]$Name) {
  return $IsTestRunner -and ($Name -match '^(fpc\d+-win(32|64)|d6|d7|d13-win(32|64))(-checked)?$')
}

function Invoke-X86Ssh([string]$Command) {
  & ssh.exe @X86SshN @X86Ssh $X86Host $Command 2>&1 | ForEach-Object { Write-Host "    $_" }
  return $LASTEXITCODE
}

function Send-X86File([string[]]$Local, [string]$RemoteDir) {
  & scp.exe -q @X86Ssh @Local "${X86Host}:$($RemoteDir -replace '\\', '/')/" 2>&1 | ForEach-Object { Write-Host "    $_" }
  if ($LASTEXITCODE -ne 0) { throw "x86: scp to $RemoteDir failed" }
}

# Brings the work tree on the x86 machine up to date: every tracked file
# (with the submodule) and the git-ignored test data. A manifest (path,
# size, time) on both sides; only new or changed files go over, files gone
# here are deleted there. The manifest is written last, so an interrupted
# run repeats the transfer.
function Sync-X86Tree([string]$Tmp) {
  $store = "$X86Base\$X86Store"
  $entries = @{}
  $tracked = @(git -c core.quotepath=off ls-files --recurse-submodules)
  if ($LASTEXITCODE -ne 0) { throw 'git ls-files failed' }
  foreach ($f in $tracked) {
    $item = Get-Item -LiteralPath $f -ErrorAction SilentlyContinue
    if ($null -eq $item -or $item.PSIsContainer) { continue }
    $entries[$f] = "$f`t$($item.Length)`t$($item.LastWriteTimeUtc.Ticks)"
  }
  foreach ($d in $X86DataDirs) {
    if (-not (Test-Path $d)) { continue }
    Get-ChildItem -LiteralPath $d -Recurse -File | ForEach-Object {
      $rel = $_.FullName.Substring($Root.Length + 1) -replace '\\', '/'
      $entries[$rel] = "$rel`t$($_.Length)`t$($_.LastWriteTimeUtc.Ticks)"
    }
  }
  $remote = @{}
  $manifest = "$Tmp/manifest-remote.txt"
  & scp.exe -q @X86Ssh "${X86Host}:$($store -replace '\\', '/')/manifest.txt" $manifest 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) {
    Get-Content $manifest | ForEach-Object { $remote[$_.Split("`t")[0]] = $_ }
  }
  if ($remote.Count -eq 0) {
    # unknown state (first run, or a sync that stopped before its manifest):
    # empty the tree there, so no file deleted here can survive, then send everything
    $wipe = @('@echo off', "cd /d $store || exit /b 1",
      'for /d %%d in (*) do if /i not "%%d"=="x86.lock" rmdir /s /q "%%d"',
      'for %%f in (*) do if /i not "%%f"=="wipe.cmd" del /f /q "%%f"', 'exit /b 0')
    [IO.File]::WriteAllLines("$Tmp/wipe.cmd", [string[]]$wipe)
    Send-X86File @("$Tmp/wipe.cmd") $store
    if ((Invoke-X86Ssh "$store\wipe.cmd") -ne 0) { throw 'x86: emptying the work tree failed' }
    Write-Host '  work tree: no manifest there, emptied'
  }
  $changed = @($entries.Keys | Where-Object { $remote[$_] -ne $entries[$_] } | Sort-Object)
  $removed = @($remote.Keys | Where-Object { -not $entries.ContainsKey($_) } | Sort-Object)
  Write-Host "  work tree: $($entries.Count) files, $($changed.Count) to send, $($removed.Count) to delete"
  if ($changed.Count -eq 0 -and $removed.Count -eq 0) { return }
  # tar.exe reads the file list in the ANSI code page, not UTF-8
  $odd = @(@($changed) + @($removed) | Where-Object { $_ -match '[^\x20-\x7E]' })
  if ($odd.Count -gt 0) { throw "x86: file names outside ASCII cannot go through the tar list: $($odd[0])" }
  # cmd expands %NAME% even inside quotes
  $odd = @(@($removed) | Where-Object { $_ -match '%' })
  if ($odd.Count -gt 0) { throw "x86: a file name with % cannot be deleted through cmd: $($odd[0])" }
  # an interrupted sync must not leave a manifest that no longer fits the tree:
  # without one, the next run sends everything again
  $cmd = @('@echo off', "cd /d $store || exit /b 1", 'if exist manifest.txt del manifest.txt',
    'if exist manifest.txt exit /b 1')
  $send = @()
  if ($changed.Count -gt 0) {
    [IO.File]::WriteAllLines("$Tmp/sync.txt", [string[]]$changed)
    & tar.exe --no-recursion -cf "$Tmp/sync.tar" -T "$Tmp/sync.txt" | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'x86: tar of the work tree failed' }
    $send += "$Tmp/sync.tar"
    $cmd += 'tar -xf sync.tar || exit /b 1'
    $cmd += 'del sync.tar'
  }
  foreach ($r in $removed) {
    $w = $r -replace '/', '\'
    $cmd += "if exist `"$w`" del /f /q `"$w`""
    $cmd += "if exist `"$w`" exit /b 1"
  }
  $cmd += 'exit /b 0'
  [IO.File]::WriteAllLines("$Tmp/sync.cmd", [string[]]$cmd)
  Send-X86File (@($send) + @("$Tmp/sync.cmd")) $store
  if ((Invoke-X86Ssh "$store\sync.cmd") -ne 0) { throw 'x86: unpacking the work tree failed' }
  [IO.File]::WriteAllLines("$Tmp/manifest.txt", [string[]]@($entries.Keys | Sort-Object | ForEach-Object { $entries[$_] }))
  Send-X86File @("$Tmp/manifest.txt") $store
}

# Runs the test runners of the given toolchains on the x86 machine at the
# same time, in the work tree there (D:\AI-Work\landrix-einvoice-data, kept
# between runs), and fetches their outputs (the folders $X86Outputs under
# build/<toolchain>/) back. Writes the exit code of each run into $Codes; throws on transport
# errors. One x86 run at a time: the lock folder x86.lock guards the tree.
function Invoke-X86([string[]]$Names, [hashtable]$Codes) {
  $store = "$X86Base\$X86Store"
  $id = "$(Get-Date -Format 'yyyyMMdd-HHmmss')-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
  $tmp = Join-Path $Root "build/x86/$id"
  New-Item -ItemType Directory -Force $tmp | Out-Null
  $locked = $false
  $procs = @()
  $empty = "build/x86-empty-$id"
  try {
    if ((Invoke-X86Ssh "if not exist $store mkdir $store") -ne 0) { throw 'x86: cannot create the work tree' }
    if ((Invoke-X86Ssh "mkdir $store\x86.lock") -ne 0) {
      throw "x86: $store\x86.lock exists: another x86 run is active, or remove the folder after a crash"
    }
    $locked = $true
    Sync-X86Tree $tmp
    $files = @($Names | ForEach-Object { "build/$_/$ProgramName.exe" })
    [IO.File]::WriteAllLines("$tmp/runners.txt", [string[]]$files)
    & tar.exe --no-recursion -cf "$tmp/runners.tar" -T "$tmp/runners.txt" | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'tar of the runners failed' }
    Send-X86File @("$tmp/runners.tar") $store
    if ((Invoke-X86Ssh "cd /d $store && (if exist build rmdir /s /q build) && tar -xf runners.tar && del runners.tar") -ne 0) {
      throw 'unpacking the runners failed'
    }
    foreach ($n in $Names) {
      $argList = @($X86SshN) + @($X86Ssh) + @($X86Host, "cd /d $store && build\$n\$ProgramName.exe .")
      $p = Start-Process -FilePath 'ssh.exe' -ArgumentList $argList -NoNewWindow -PassThru `
        -RedirectStandardOutput "$tmp/$n.log" -RedirectStandardError "$tmp/$n.err"
      $null = $p.Handle   # keeps the exit code available after the end
      $procs += @{ Name = $n; Proc = $p }
      Write-Host "  started $n"
    }
    foreach ($e in $procs) {
      $e.Proc.WaitForExit()
      $n = $e.Name
      $Codes[$n] = $e.Proc.ExitCode
      $log = @(Get-Content "$tmp/$n.log") + @(Get-Content "$tmp/$n.err" | Where-Object { $_ -notmatch '^\*\*' })
      $log | Set-Content -Encoding utf8 "build/$n/x86-test.log"
      Write-Host ("  {0}: exit code {1}" -f $n, $Codes[$n]) -ForegroundColor Cyan
      $log | Where-Object { $_ -match 'test\(s\)|^FAIL|^ERROR' } | ForEach-Object { Write-Host "    $_" }
      if ($Codes[$n] -ne 0) { $log | Select-Object -Last 15 | ForEach-Object { Write-Host "    $_" } }
    }
    # outputs back (cross test, -Validate, reports of failed golden tests)
    $fetch = @('@echo off', "cd /d $store || exit /b 1", 'if exist out.txt del out.txt',
      "mkdir $($empty -replace '/', '\')", "echo $empty>out.txt",
      "for %%t in ($($Names -join ' ')) do for %%s in ($($X86Outputs -join ' ')) do if exist build\%%t\%%s echo build/%%t/%%s>>out.txt",
      'tar -cf out.tar -T out.txt || exit /b 1', 'exit /b 0')
    [IO.File]::WriteAllLines("$tmp/fetch.cmd", [string[]]$fetch)
    Send-X86File @("$tmp/fetch.cmd") $store
    if ((Invoke-X86Ssh "$store\fetch.cmd") -ne 0) { throw 'tar of the outputs failed' }
    & scp.exe -q @X86Ssh "${X86Host}:$($store -replace '\\', '/')/out.tar" "$tmp/out.tar" 2>&1 | ForEach-Object { Write-Host "    $_" }
    if ($LASTEXITCODE -ne 0) { throw 'scp of the outputs failed' }
    & tar.exe -xf "$tmp/out.tar" -C $Root | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'unpacking the outputs failed' }
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $empty
  } finally {
    try {
      # runners still going must end before their tree goes and the lock is released
      foreach ($e in $procs) { if (-not $e.Proc.HasExited) { $e.Proc.WaitForExit() } }
      if ($locked) {
        if ((Invoke-X86Ssh "cd /d $store && ((if exist out.tar del out.tar) & (if exist out.txt del out.txt) & (if exist fetch.cmd del fetch.cmd) & (if exist build rmdir /s /q $store\build) & (if not exist $store\build rmdir $store\x86.lock))") -ne 0) {
          Write-Host "  could not clean up $store on $X86Host (a runner may still use build\; remove x86.lock by hand once it is done)" -ForegroundColor Red
          $Codes['(cleanup)'] = 1
        }
      }
    } finally {
      Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $tmp
    }
  }
}

# Runs one toolchain in this process; never throws.
function Invoke-ToolchainSafe([string]$Name) {
  try {
    return Invoke-Toolchain $Name
  } catch {
    Write-Host "  $_" -ForegroundColor Red
    return @{ Name = $Name; Build = -1; Diag = 0; Run = $null }
  }
}

# Runs the x86 step in this process and returns @{ Codes; Failed }; never throws.
function Invoke-X86Safe([string[]]$Names) {
  $codes = @{}
  $failed = $false
  $sw = [Diagnostics.Stopwatch]::StartNew()
  try {
    Invoke-X86 $Names $codes
    $failed = $codes.ContainsKey('(cleanup)')
  } catch {
    Write-Host "  $_" -ForegroundColor Red
    $failed = $true
  }
  Write-Host ("  x86: {0:N1} min" -f $sw.Elapsed.TotalMinutes)
  return @{ Codes = $codes; Failed = $failed }
}

if ($X86Worker) {
  # child process of a parallel run: the x86 step, result as JSON
  $r = Invoke-X86Safe @($X86Names.Split(',') | Where-Object { $_ -ne '' })
  New-Item -ItemType Directory -Force (Join-Path $Root 'build/x86') | Out-Null
  $json = @{ Codes = $r.Codes; Failed = $r.Failed } | ConvertTo-Json -Compress
  [IO.File]::WriteAllText((Join-Path $Root 'build/x86/worker-result.json'), $json)
  exit 0
}

if ($Worker) {
  # child process of a parallel run: one toolchain, result as JSON
  $X86Present = [bool]$X86Deferred
  $name = $expanded[0]
  $r = Invoke-ToolchainSafe $name
  $json = @{ Name = $r.Name; Build = $r.Build; Diag = $r.Diag; Run = $r.Run } | ConvertTo-Json -Compress
  [IO.File]::WriteAllText((Join-Path $Root "build/$name/worker-result.json"), $json)
  exit 0
}

# x86 runs the runners built in this call, so it comes after the builds
$X86Present = $expanded -contains 'x86'
$X86Note = $null
if ($X86Present -and ($NoRun -or -not $IsTestRunner)) {
  $X86Present = $false
  $X86Note = 'x86 skipped: it runs only the test runner'
} elseif ($X86Present) {
  & ssh.exe -n -o BatchMode=yes -o ConnectTimeout=8 $X86Host 'exit' 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    $X86Present = $false
    $X86Note = "x86 machine $X86Host not reachable: the Windows tests ran here"
    Write-Host "  $X86Note" -ForegroundColor Yellow
  }
}
$local = @($expanded | Where-Object { $_ -ne 'x86' } | Select-Object -Unique)
if ($Jobs -le 0) { $Jobs = [Math]::Max(1, [Environment]::ProcessorCount - 2) }
if ($IsTestRunner -and @($local | Where-Object { $_ -match '-linux(-checked)?$' }).Count -gt 0) {
  try {
    Sync-WslMirror
  } catch {
    Write-Host "  $_" -ForegroundColor Red
    exit 1
  }
}
$results = @()
$x86Run = @()
$x86Result = $null
if ($Jobs -eq 1 -or $local.Count -le 1) {
  foreach ($t in $local) {
    Write-Host "=== $t ===" -ForegroundColor Cyan
    $results += Invoke-ToolchainSafe $t
  }
  if ($X86Present) {
    $x86Run = @($results | Where-Object { $_.Build -eq 0 -and (Test-X86Toolchain $_.Name) } | ForEach-Object { $_.Name })
    if ($x86Run.Count -gt 0) {
      Write-Host "=== x86: $($x86Run -join ', ') ===" -ForegroundColor Cyan
      $x86Result = Invoke-X86Safe $x86Run
    }
  }
} else {
  $pwsh = (Get-Process -Id $PID).Path
  $byName = @{}
  $pending = [Collections.ArrayList]@($local)
  $running = @()
  $x86Wanted = @($local | Where-Object { Test-X86Toolchain $_ })
  $x86Started = -not $X86Present -or $x86Wanted.Count -eq 0
  Write-Host "running $($local.Count) toolchains, up to $Jobs at once" -ForegroundColor Cyan
  while ($pending.Count -gt 0 -or $running.Count -gt 0) {
    while ($pending.Count -gt 0 -and $running.Count -lt $Jobs) {
      $t = $pending[0]
      $pending.RemoveAt(0)
      $dir = Join-Path $Root "build/$t"
      New-Item -ItemType Directory -Force $dir | Out-Null
      Remove-Item -Force -ErrorAction SilentlyContinue "$dir/worker-result.json", "$dir/worker.log", "$dir/worker.err"
      $argList = @('-NoProfile', '-File', "`"$PSCommandPath`"", '-Toolchains', $t, '-Program', "`"$Program`"", '-Worker')
      if ($NoRun) { $argList += '-NoRun' }
      if ($X86Present) { $argList += '-X86Deferred' }
      $proc = Start-Process -FilePath $pwsh -ArgumentList $argList -NoNewWindow -PassThru `
        -RedirectStandardOutput "$dir/worker.log" -RedirectStandardError "$dir/worker.err"
      $running += @{ Name = $t; Proc = $proc; Start = Get-Date }
      Write-Host "  started $t"
    }
    $done = @($running | Where-Object { $_.Proc.HasExited })
    if ($done.Count -eq 0) { Start-Sleep -Milliseconds 500; continue }
    $running = @($running | Where-Object { $done -notcontains $_ })
    foreach ($job in $done) {
      $t = $job.Name
      $dir = "build/$t"
      $minutes = ((Get-Date) - $job.Start).TotalMinutes
      if ($job.X86) {
        Write-Host ("=== x86: {0} ({1:N1} min) ===" -f ($x86Run -join ', '), $minutes) -ForegroundColor Cyan
        if (Test-Path "$dir/worker.log") { Get-Content "$dir/worker.log" | ForEach-Object { Write-Host $_ } }
        if ((Test-Path "$dir/worker.err") -and (Get-Item "$dir/worker.err").Length -gt 0) {
          Get-Content "$dir/worker.err" | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        }
        $x86Result = @{ Codes = @{}; Failed = $true }
        if (Test-Path "$dir/worker-result.json") {
          $j = Get-Content -Raw "$dir/worker-result.json" | ConvertFrom-Json
          $x86Result.Failed = [bool]$j.Failed
          foreach ($prop in $j.Codes.PSObject.Properties) { $x86Result.Codes[$prop.Name] = [int]$prop.Value }
        } else {
          Write-Host "  x86 worker ended without a result (exit code $($job.Proc.ExitCode))" -ForegroundColor Red
        }
        continue
      }
      Write-Host ("=== {0} ({1:N1} min) ===" -f $t, $minutes) -ForegroundColor Cyan
      if (Test-Path "$dir/worker.log") { Get-Content "$dir/worker.log" | ForEach-Object { Write-Host $_ } }
      if ((Test-Path "$dir/worker.err") -and (Get-Item "$dir/worker.err").Length -gt 0) {
        Get-Content "$dir/worker.err" | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
      }
      if (Test-Path "$dir/worker-result.json") {
        $j = Get-Content -Raw "$dir/worker-result.json" | ConvertFrom-Json
        $byName[$t] = @{ Name = $t; Build = [int]$j.Build; Diag = [int]$j.Diag; Run = $(if ($null -eq $j.Run) { $null } else { [int]$j.Run }) }
      } else {
        Write-Host "  worker ended without a result (exit code $($job.Proc.ExitCode))" -ForegroundColor Red
        $byName[$t] = @{ Name = $t; Build = -1; Diag = 0; Run = $null }
      }
    }
    # x86 starts once every Windows toolchain of the call is built
    if (-not $x86Started -and @($x86Wanted | Where-Object { -not $byName.ContainsKey($_) }).Count -eq 0) {
      $x86Started = $true
      $x86Run = @($x86Wanted | Where-Object { $byName[$_].Build -eq 0 })
      if ($x86Run.Count -gt 0) {
        $dir = Join-Path $Root 'build/x86'
        New-Item -ItemType Directory -Force $dir | Out-Null
        Remove-Item -Force -ErrorAction SilentlyContinue "$dir/worker-result.json", "$dir/worker.log", "$dir/worker.err"
        $argList = @('-NoProfile', '-File', "`"$PSCommandPath`"", '-Toolchains', 'x86', '-Program', "`"$Program`"",
          '-X86Worker', '-X86Names', ($x86Run -join ','))
        $proc = Start-Process -FilePath $pwsh -ArgumentList $argList -NoNewWindow -PassThru `
          -RedirectStandardOutput "$dir/worker.log" -RedirectStandardError "$dir/worker.err"
        $running += @{ Name = 'x86'; Proc = $proc; Start = Get-Date; X86 = $true }
        Write-Host "  started x86: $($x86Run -join ', ')"
      }
    }
  }
  # keep the order of the list: the cross ring and the validation depend on it
  foreach ($t in $local) { $results += $byName[$t] }
}
if ($X86Present) {
  $deferred = @($results | Where-Object { $_.Build -eq 0 -and (Test-X86Toolchain $_.Name) } | ForEach-Object { $_.Name })
  if ($deferred.Count -eq 0) {
    Write-Host 'x86: no Windows toolchain built in this call' -ForegroundColor Yellow
  } else {
    if ($null -eq $x86Result) {
      Write-Host 'x86: the step did not run' -ForegroundColor Red
      $x86Result = @{ Codes = @{}; Failed = $true }
    }
    foreach ($r in $results) {
      if ($deferred -notcontains $r.Name) { continue }
      $c = $x86Result.Codes[$r.Name]
      if ($null -eq $c) { $c = 1 }
      # examples that failed here keep the toolchain red
      if ($null -eq $r.Run -or $r.Run -eq 0) { $r.Run = $c }
    }
    $results += @{ Name = 'x86 machine'; Build = 0; Diag = 0; Run = $(if ($x86Result.Failed) { 1 } else { 0 }) }
  }
}

# Cross test: each local toolchain reads what the next one wrote.
$ring = @($results | Where-Object {
  $_.Build -eq 0 -and $_.Run -eq 0 -and $_.Name -notmatch '^(mac|d13-osxarm64|x86)$' -and
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
      & wsl.exe -e bash -lc "cd $WslWork && './build/$reader/$ProgramName' `"`$PWD`" -filter=Cross.Read '-cross=$WslRoot/build/$writer/cross'" | Out-Host
    } else {
      & "build/$reader/$ProgramName.exe" $Root '-filter=Cross.Read' "-cross=$Root\build\$writer\cross" | Out-Host
    }
    $results += @{ Name = "cross $reader<-$writer"; Build = 0; Diag = 0; Run = $LASTEXITCODE }
  }
}

if ($Validate -and -not $NoRun) {
  $source = @($results | Where-Object {
    $_.Build -eq 0 -and $_.Run -eq 0 -and $_.Name -notmatch '^(mac|d13-osxarm64|x86)$' -and
    (Test-Path "build/$($_.Name)/cross/*.xml")
  }) | Select-Object -First 1
  if ($null -eq $source) {
    Write-Host 'validation skipped: no toolchain with cross output' -ForegroundColor Yellow
    $results += @{ Name = 'KoSIT validation'; Build = 0; Diag = 0; Run = 1 }
  } else {
    foreach ($folder in @('cross', 'profiles', 'cases', 'sweep')) {
      # profiles/ comes from the example scenarios like cross/ (test CIIProfiles.WriteScenarios);
      # cases/ comes from the business cases (Cases.*), sweep/ from Sweep.Official (local
      # corpora); sweep-cross/ is not validated: a source with third-party payments (BG-DEX-09)
      # has no valid form in XRechnung CII and is reported as an error
      if (-not (Test-Path "build/$($source.Name)/$folder/*.xml")) {
        # only sweep/ may be missing (no local corpora); it shows in the summary
        Write-Host "validation of $folder skipped: no output" -ForegroundColor Yellow
        if ($folder -eq 'sweep' -and -not (Test-Path 'tests/data/local/sweep')) {
          $results += @{ Name = "KoSIT validation $($source.Name)/sweep: no corpora"; Build = 0; Diag = 0; Run = 0 }
        } else {
          $results += @{ Name = "KoSIT validation $($source.Name)/$folder"; Build = 0; Diag = 0; Run = 1 }
        }
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
if ($X86Note) { Write-Host $X86Note -ForegroundColor Yellow }
$failed = $false
foreach ($r in $results) {
  $state = 'OK'
  if ($r.Build -ne 0) { $state = 'BUILD FAILED'; $failed = $true }
  elseif ($r.Diag -gt 0 -and -not $AllowWarnings) { $state = "WARNINGS ($($r.Diag))"; $failed = $true }
  if ($r.Build -eq 0 -and $null -ne $r.Run -and $r.Run -ne 0) { $state = "TESTS FAILED"; $failed = $true }
  '{0,-46} {1}' -f $r.Name, $state | Write-Host
}
if ($failed) { exit 1 } else { exit 0 }
