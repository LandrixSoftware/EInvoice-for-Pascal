#Requires -Version 7
<#
.SYNOPSIS
  Validates invoice XML files with the KoSIT validator (XRechnung, Peppol BIS
  Billing, ZUGFeRD / Factur-X).

.DESCRIPTION
  The configuration follows the file name, as the scenario outputs name
  their files:
    *-ubl-30x.xml, *-cii-30x.xml                XRechnung 3.0.2
    *-ubl-peppol.xml                            Peppol BIS Billing 3.0
    *-ciiEN16931-25.xml, *-ciiextended-25.xml   ZUGFeRD 2.5.2 / Factur-X 1.09.2
  Other files fail the run. A file passes when the assessment in its report
  accepts it (rep:assessment/rep:accept: the acceptMatch of the XRechnung
  and ZUGFeRD scenarios; the BIS configuration has no acceptMatch, there its
  report stylesheet rejects only error-level messages); warnings are listed.
  The validator's own summary may still call a file REJECT (without
  acceptMatch a Schematron step with only warnings counts as invalid), so
  its exit code is shown, not used.
  Every configuration runs in its own validator
  call: with several configurations in one call, validator 1.6.3 matches no
  scenario for the ZUGFeRD EN16931 files.

  Default folder: build/<toolchain>/cross/ of the first toolchain that has
  one (written by tools/build.ps1, test Cross.Write). Reports and HTML go to
  build/validation/<folder name>/.

  Needs the tools of addons/java-tools/install-tools.ps1. Java: -Java, else
  addons/java-tools/jre/<os>-<arch>, else JAVA_HOME, else PATH.
  Exit code 0 = every file accepted.

.EXAMPLE
  ./tools/validate.ps1
  ./tools/validate.ps1 -Folder tests/data/local/golden
#>
param(
  [string]$Folder,
  [string]$Java
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Tools = Join-Path $Root 'addons/java-tools'

$Configurations = @(
  @{ Name = 'XRechnung 3.0.2'; Dir = 'validator-configuration-xrechnung'; Patterns = @('*-ubl-30x.xml', '*-cii-30x.xml') },
  @{ Name = 'Peppol BIS Billing 3.0'; Dir = 'validator-configuration-bis'; Patterns = @('*-ubl-peppol.xml') },
  @{ Name = 'ZUGFeRD 2.5.2'; Dir = 'validator-configuration-zugferd'; Patterns = @('*-ciiEN16931-25.xml', '*-ciiextended-25.xml') }
)

function Find-Java {
  if ($Java) { return $Java }
  $os = if ($IsWindows) { 'windows' } elseif ($IsMacOS) { 'macos' } else { 'linux' }
  $arch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64') { 'aarch64' } else { 'x64' }
  $exe = if ($IsWindows) { 'java.exe' } else { 'java' }
  $jre = Join-Path $Tools "jre/$os-$arch"
  foreach ($candidate in @((Join-Path $jre "bin/$exe"), (Join-Path $jre "Contents/Home/bin/$exe"))) {
    if (Test-Path $candidate) { return $candidate }
  }
  if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME "bin/$exe"))) { return Join-Path $env:JAVA_HOME "bin/$exe" }
  $cmd = Get-Command java -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  throw 'No Java runtime: run addons/java-tools/install-tools.ps1 or pass -Java'
}

if (-not $Folder) {
  $candidates = @(Get-ChildItem (Join-Path $Root 'build') -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path (Join-Path $_.FullName 'cross/*.xml') } | Sort-Object Name)
  if ($candidates.Count -eq 0) { throw 'No build/<toolchain>/cross folder: run tools/build.ps1 first or pass -Folder' }
  $Folder = Join-Path $candidates[0].FullName 'cross'
}
$Folder = (Resolve-Path $Folder).Path
$Validator = Get-ChildItem (Join-Path $Tools 'validator') -Filter 'validator-*-standalone.jar' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $Validator) { throw 'KoSIT validator missing: run addons/java-tools/install-tools.ps1' }
$JavaExe = Find-Java

$parentName = Split-Path -Leaf (Split-Path -Parent $Folder)
$leafName = Split-Path -Leaf $Folder
$Out = Join-Path $Root ('build/validation/' + (($parentName + '-' + $leafName) -replace '[^A-Za-z0-9._-]', '_'))
if (Test-Path $Out) { Remove-Item -Recurse -Force $Out }
New-Item -ItemType Directory -Force $Out | Out-Null
# Standard input of the validator on Windows: it fails on the null device
# (available() throws), so it gets an empty file.
$EmptyInput = Join-Path $Out 'empty-input.txt'
Set-Content -NoNewline -Path $EmptyInput -Value ''

Write-Host "Validating $Folder"
Write-Host "  Java: $JavaExe"
$all = @(Get-ChildItem $Folder -Filter *.xml)
$assigned = @{}
$failed = 0

foreach ($cfg in $Configurations) {
  $cfgDir = Join-Path $Tools $cfg.Dir
  $files = @($all | Where-Object { $name = $_.Name; @($cfg.Patterns | Where-Object { $name -like $_ }).Count -gt 0 })
  if ($files.Count -eq 0) { continue }
  if (-not (Test-Path (Join-Path $cfgDir 'scenarios.xml'))) { throw "$($cfg.Dir) missing: run addons/java-tools/install-tools.ps1" }
  foreach ($f in $files) { $assigned[$f.Name] = $true }

  $log = Join-Path $Out ($cfg.Dir + '.log')
  $arguments = @('-jar', $Validator.FullName, '-r', $cfgDir, '-s', (Join-Path $cfgDir 'scenarios.xml'), '-o', $Out, '-h') +
    @($files | ForEach-Object FullName)
  if ($IsWindows) {
    # Start-Process joins the arguments with spaces and does not quote them
    $quoted = @($arguments | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } })
    $process = Start-Process -FilePath $JavaExe -ArgumentList $quoted -NoNewWindow -Wait -PassThru `
      -RedirectStandardInput $EmptyInput -RedirectStandardOutput $log -RedirectStandardError ($log + '.err')
    $exitCode = $process.ExitCode
  } else {
    # inherits the terminal or /dev/null as standard input; a redirected
    # input would reach Java as a pipe, which counts as a piped document
    & $JavaExe @arguments > $log 2> ($log + '.err')
    $exitCode = $LASTEXITCODE
  }

  $accepted = 0
  foreach ($f in $files) {
    $report = Join-Path $Out ([IO.Path]::GetFileNameWithoutExtension($f.Name) + '-report.xml')
    if (-not (Test-Path $report)) {
      Write-Host "  no report: $($f.Name)" -ForegroundColor Red
      $failed++
      continue
    }
    $text = Get-Content -Raw $report
    $codes = @([regex]::Matches($text, '<rep:message [^>]*level="(warning|error)"[^>]*code="([^"]+)"') |
      ForEach-Object { "$($_.Groups[2].Value) ($($_.Groups[1].Value))" } | Sort-Object -Unique)
    if ($text -match '<rep:assessment>\s*<rep:accept') {
      $accepted++
      if ($codes.Count -gt 0) { Write-Host "  accepted with messages: $($f.Name): $($codes -join ', ')" -ForegroundColor Yellow }
    } else {
      $reason = $codes -join ', '
      if ($reason -eq '' -and $text -match '<rep:processingError>([\s\S]*?)</rep:processingError>') { $reason = $Matches[1].Trim() }
      if ($reason -eq '' -and $text -match '<rep:noScenarioMatched') { $reason = 'no scenario matched' }
      Write-Host "  rejected: $($f.Name): $reason" -ForegroundColor Red
      $failed++
    }
  }
  $color = if ($accepted -eq $files.Count) { 'Green' } else { 'Red' }
  Write-Host ('  {0,-24} {1,3} of {2,3} accepted (validator exit code {3})' -f $cfg.Name, $accepted, $files.Count, $exitCode) -ForegroundColor $color
}

foreach ($f in $all) {
  if (-not $assigned.ContainsKey($f.Name)) {
    Write-Host "  no configuration for $($f.Name)" -ForegroundColor Red
    $failed++
  }
}
Write-Host "Reports: $Out"
if ($all.Count -eq 0) { Write-Host '  no XML files' -ForegroundColor Red; exit 1 }
if ($failed -gt 0) { Write-Host "$failed file(s) failed" -ForegroundColor Red; exit 1 }
Write-Host "All $($all.Count) files accepted" -ForegroundColor Green
exit 0
