#Requires -Version 7
<#
.SYNOPSIS
  Downloads the Java tools of EInvoice-for-Pascal into addons/java-tools/.

.DESCRIPTION
  Reads tools.json next to this script: every entry is pinned by URL and
  SHA-256. Downloads go to download/ (kept as cache), are verified and then
  copied or unpacked into their folder. The folders are git-ignored.

  Installed by default: the KoSIT validator, its configurations for
  XRechnung, Peppol BIS Billing and ZUGFeRD / Factur-X, and the Java runtime
  (Temurin 21) of the current platform under jre/<os>-<arch>. Linux and
  macOS users may use an installed Java runtime instead (-NoJre). On Windows
  the Linux and macOS runtimes are skipped: their archives contain symbolic
  links that the Windows tar cannot create.

  An entry is skipped when its folder already holds the same file
  (marker .installed with the SHA-256); -Force reinstalls.

.EXAMPLE
  ./addons/java-tools/install-tools.ps1
  ./addons/java-tools/install-tools.ps1 -Platform all
  ./addons/java-tools/install-tools.ps1 -NoJre
#>
param(
  # Platforms of the Java runtime: auto (this machine), all, or a list such
  # as windows-x64,linux-aarch64.
  [string[]]$Platform = @('auto'),
  [switch]$NoJre,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$Here = $PSScriptRoot
$Manifest = Get-Content -Raw (Join-Path $Here 'tools.json') | ConvertFrom-Json
$Cache = Join-Path $Here 'download'
New-Item -ItemType Directory -Force $Cache | Out-Null

function Get-CurrentPlatform {
  $os = if ($IsWindows) { 'windows' } elseif ($IsMacOS) { 'macos' } elseif ($IsLinux) { 'linux' } else { throw 'Unknown operating system' }
  $arch = switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture) {
    'X64' { 'x64' }
    'Arm64' { 'aarch64' }
    default { throw "Unsupported architecture: $_" }
  }
  return "$os-$arch"
}

$wanted = @()
foreach ($p in ($Platform -join ',').Split(',')) {
  $p = $p.Trim()
  if ($p -eq 'auto') { $wanted += Get-CurrentPlatform }
  elseif ($p -ne '') { $wanted += $p }
}

function Install-Entry($Entry) {
  if ([string]::IsNullOrWhiteSpace($Entry.dir) -or $Entry.dir -match '\.\.') { throw "Invalid dir in tools.json: '$($Entry.dir)'" }
  $target = Join-Path $Here $Entry.dir
  $marker = Join-Path $target '.installed'
  if (-not $Force -and (Test-Path $marker) -and ("$(Get-Content -Raw $marker)".Trim() -eq $Entry.sha256)) {
    Write-Host "  $($Entry.dir): up to date"
    return
  }

  if ($IsWindows -and $Entry.file -like '*.tar.gz') {
    # these archives contain symbolic links that tar.exe cannot create on Windows
    Write-Host "  $($Entry.dir): skipped, install it on its own platform" -ForegroundColor Yellow
    return
  }

  $file = Join-Path $Cache $Entry.file
  $valid = (Test-Path $file) -and ((Get-FileHash -Algorithm SHA256 $file).Hash.ToLower() -eq $Entry.sha256)
  if (-not $valid) {
    Write-Host "  $($Entry.dir): downloading $($Entry.url)"
    Invoke-WebRequest -Uri $Entry.url -OutFile $file -UseBasicParsing
    $hash = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLower()
    if ($hash -ne $Entry.sha256) {
      Remove-Item -Force $file
      throw "SHA-256 mismatch for $($Entry.file): expected $($Entry.sha256), got $hash"
    }
  }

  if (Test-Path $target) { Remove-Item -Recurse -Force $target }
  New-Item -ItemType Directory -Force $target | Out-Null
  if (-not $Entry.unpack) {
    Copy-Item $file (Join-Path $target $Entry.file)
  } else {
    $strip = if ($Entry.PSObject.Properties.Name -contains 'strip') { [int]$Entry.strip } else { 0 }
    if ($Entry.file -like '*.zip') {
      $tmp = Join-Path $Cache ('unpack-' + [Guid]::NewGuid().ToString('N'))
      Expand-Archive -Path $file -DestinationPath $tmp
      $source = $tmp
      for ($i = 0; $i -lt $strip; $i++) {
        $dirs = @(Get-ChildItem $source -Directory)
        if ($dirs.Count -ne 1) { throw "$($Entry.file): cannot strip, $($dirs.Count) top-level folders" }
        $source = $dirs[0].FullName
      }
      Get-ChildItem -Force $source | Move-Item -Destination $target
      Remove-Item -Recurse -Force $tmp
    } else {
      & tar -xzf $file -C $target "--strip-components=$strip"
      if ($LASTEXITCODE -ne 0) { throw "tar failed for $($Entry.file)" }
    }
  }
  Set-Content -NoNewline -Path $marker -Value $Entry.sha256
  Write-Host "  $($Entry.dir): installed"
}

$known = @($Manifest.tools | Where-Object { $_.name -eq 'jre' } | ForEach-Object { $_.platform })
if (-not $NoJre -and -not ($Platform -contains 'all')) {
  foreach ($p in $wanted) {
    if ($known -notcontains $p) {
      Write-Host "  no Java runtime for $p in tools.json (known: $($known -join ', ')); validate.ps1 uses JAVA_HOME or PATH" -ForegroundColor Yellow
    }
  }
}

foreach ($entry in $Manifest.tools) {
  if ($entry.name -eq 'jre') {
    if ($NoJre -or (-not ($Platform -contains 'all') -and -not ($wanted -contains $entry.platform))) { continue }
  }
  Install-Entry $entry
}
Write-Host 'Done.'
