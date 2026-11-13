<#
.SYNOPSIS
  Installs what the native KoSIT check of EInvoice-for-Pascal needs: the
  validator configurations and the rule files. No Java.

.DESCRIPTION
  Reads kosit.json next to this script; every file is pinned by URL and
  SHA-256 and verified after the download (downloads are kept in
  download/ as a cache). Modules:

    xrechnung  KoSIT configuration XRechnung 3.0.2 (2026-08-31) and the
               LandrixXML rule files en16931-ubl/-cii.xml and
               xrechnung-ubl/-cii.xml
    bis        KoSIT configuration Peppol BIS Billing 3.0.21, the rule file
               en16931-ubl.xml and PEPPOL-EN16931-UBL.sch (OpenPEPPOL,
               May 2026 release 3.0.21)
    zugferd    ZUGFeRD 2.5.2 / Factur-X 1.09.2 configuration (2026-10-15);
               it ships its own Schematron sources

  Without -Modules all three are installed. The target folder then holds
  validator-configuration-xrechnung/, validator-configuration-bis/,
  validator-configuration-zugferd/ and rules/; ship that folder with an
  application that runs the check (see docs/validation.md). The LandrixXML
  rule files are copied from the submodule external/landrix-xml when it is
  checked out, else downloaded from the LandrixXML release. Downloads are
  kept in download/ next to this script, not in the target folder.

  A module is skipped when it is installed with the same archive (marker
  .installed in its folder); -Force reinstalls, also after files were
  deleted by hand. Runs with Windows PowerShell 5.1 and PowerShell 7
  (Windows, Linux, macOS); Windows PowerShell 5.1 cannot unpack below a
  long -Target path (260 characters with the deepest file).

.EXAMPLE
  ./addons/kosit/install-kosit.ps1
  ./addons/kosit/install-kosit.ps1 -Modules xrechnung,zugferd
  ./addons/kosit/install-kosit.ps1 -Target C:\MyApp\kosit
#>
param(
  [string[]]$Modules = @('xrechnung', 'bis', 'zugferd'),
  # folder to install into (default: this script's folder)
  [string]$Target = $PSScriptRoot,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

Add-Type -AssemblyName System.IO.Compression.FileSystem
$Here = $PSScriptRoot
$Repo = Split-Path -Parent (Split-Path -Parent $Here)
$Manifest = Get-Content -Raw -LiteralPath (Join-Path $Here 'kosit.json') | ConvertFrom-Json
$Modules = @(($Modules -join ',').Split(',') | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ -ne '' })
if ($Modules.Count -eq 0) { throw 'No module given (xrechnung, bis, zugferd)' }
foreach ($m in $Modules) {
  if (@('xrechnung', 'bis', 'zugferd') -notcontains $m) { throw "Unknown module '$m' (xrechnung, bis, zugferd)" }
}
New-Item -ItemType Directory -Force -Path $Target | Out-Null
$Target = (Resolve-Path -LiteralPath $Target).Path
$Cache = Join-Path $Here 'download'
New-Item -ItemType Directory -Force -Path $Cache | Out-Null

function Get-Sha256([string]$Path) {
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLower()
}

# Downloads $Url to $File unless it is there with $Sha256; fails on a mismatch.
function Get-Verified([string]$Url, [string]$File, [string]$Sha256) {
  if ((Test-Path -LiteralPath $File) -and ((Get-Sha256 $File) -eq $Sha256)) { return }
  Write-Host "  downloading $Url"
  Invoke-WebRequest -Uri $Url -OutFile $File -UseBasicParsing
  $hash = Get-Sha256 $File
  if ($hash -ne $Sha256) {
    Remove-Item -Force -LiteralPath $File
    throw "SHA-256 mismatch for $Url`n  expected $Sha256`n  got      $hash"
  }
}

function Install-Configuration($Entry) {
  $dir = Join-Path $Target $Entry.dir
  $marker = Join-Path $dir '.installed'
  if (-not $Force -and (Test-Path -LiteralPath $marker) -and ("$(Get-Content -Raw -LiteralPath $marker)".Trim() -eq $Entry.sha256)) {
    Write-Host "  $($Entry.dir): up to date"
    return
  }
  $zip = Join-Path $Cache $Entry.file
  Get-Verified $Entry.url $zip $Entry.sha256
  if (Test-Path -LiteralPath $dir) { Remove-Item -Recurse -Force -LiteralPath $dir }
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  # .NET instead of Expand-Archive, which takes -DestinationPath as a wildcard in 5.1
  [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $dir)
  if (-not (Test-Path -LiteralPath (Join-Path $dir 'scenarios.xml'))) { throw "$($Entry.file): no scenarios.xml at the top level" }
  Set-Content -NoNewline -LiteralPath $marker -Value $Entry.sha256
  Write-Host "  $($Entry.dir): installed"
}

function Install-Rule($Entry) {
  $rules = Join-Path $Target 'rules'
  New-Item -ItemType Directory -Force -Path $rules | Out-Null
  $dest = Join-Path $rules $Entry.file
  if (-not $Force -and (Test-Path -LiteralPath $dest) -and ((Get-Sha256 $dest) -eq $Entry.sha256)) {
    Write-Host "  rules/$($Entry.file): up to date"
    return
  }
  if ($Entry.PSObject.Properties.Name -contains 'landrixxml') {
    $local = Join-Path (Join-Path $Repo $Manifest.landrixxml.submodule) $Entry.landrixxml
    if ((Test-Path -LiteralPath $local) -and ((Get-Sha256 $local) -eq $Entry.sha256)) {
      Copy-Item -LiteralPath $local $dest -Force
    } else {
      Get-Verified ($Manifest.landrixxml.url + $Entry.landrixxml) $dest $Entry.sha256
    }
  } else {
    Get-Verified $Entry.url $dest $Entry.sha256
  }
  Write-Host "  rules/$($Entry.file): installed"
}

Write-Host "Installing into $Target"
foreach ($entry in $Manifest.configurations) {
  if ($Modules -contains $entry.module) { Install-Configuration $entry }
}
foreach ($entry in $Manifest.rules) {
  $needed = $false
  foreach ($m in $entry.modules) { if ($Modules -contains $m) { $needed = $true } }
  if ($needed) { Install-Rule $entry }
}
Write-Host 'Done.'
