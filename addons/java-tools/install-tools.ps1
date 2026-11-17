#Requires -Version 7
<#
.SYNOPSIS
  Downloads the Java tools of EInvoice-for-Pascal into addons/java-tools/.

.DESCRIPTION
  Reads tools.json next to this script: every entry is pinned by URL and
  SHA-256. Downloads go to download/ (kept as cache), are verified and then
  copied or unpacked into their folder. The folders are git-ignored.

  Installed by default: the KoSIT validator, its configurations for
  XRechnung, Peppol BIS Billing and ZUGFeRD / Factur-X, the Java runtime
  (Temurin 21) of the current platform under jre/<os>-<arch>, and qpdf for
  the PDF oracle (tools/pdfcheck/pdf-oracle.py; Windows only, elsewhere
  an installed qpdf is used), commonmark.js for the Markdown oracle
  (tools/render/md-oracle.py) and the veraPDF command line for the PDF/A
  oracle (tools/pdfcheck/verapdf-oracle.py; its IzPack installer runs
  unattended with the Java runtime installed before it, JAVA_HOME or the
  PATH, and installs only the packs in "select"). An entry with a platform is installed only
  for that platform. Linux and
  macOS users may use an installed Java runtime instead (-NoJre). On Windows
  the Linux and macOS runtimes are skipped: their archives contain symbolic
  links that the Windows tar cannot create.

  An entry is skipped when its folder already holds the same file
  (marker .installed with the SHA-256, for an installer also the packs it
  installed); -Force reinstalls.

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

function Find-Java {
  $platform = Get-CurrentPlatform
  $exe = if ($IsWindows) { 'java.exe' } else { 'java' }
  foreach ($c in @((Join-Path $Here "jre/$platform/bin/$exe"), (Join-Path $Here "jre/$platform/Contents/Home/bin/$exe"))) {
    if (Test-Path $c) { return $c }
  }
  if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME "bin/$exe"))) { return (Join-Path $env:JAVA_HOME "bin/$exe") }
  $cmd = Get-Command java -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  throw 'No Java runtime for the veraPDF installer: install the JRE entry, set JAVA_HOME or put java on the PATH'
}

# The panels of the veraPDF IzPack installer (resources/panelsOrder of the
# installer jar); an unattended install lists them in this order.
$VeraPdfPanels = [ordered]@{
  'com.izforge.izpack.panels.htmlhello.HTMLHelloPanel' = 'welcome'
  'com.izforge.izpack.panels.target.TargetPanel'       = 'install_dir'
  'com.izforge.izpack.panels.packs.PacksPanel'         = 'sdk_pack_select'
  'com.izforge.izpack.panels.install.InstallPanel'     = 'install'
  'com.izforge.izpack.panels.finish.FinishPanel'       = 'finish'
}

# Unattended install of the veraPDF IzPack installer from the unpacked
# archive in $Source into $Target: only the packs in izpack.select; then
# "java -jar <izpack.check> --version" must print izpack.version.
function Install-VeraPdf($Entry, $Source, $Target) {
  $iz = $Entry.izpack
  $installer = Join-Path $Source $iz.installer
  if (-not (Test-Path $installer)) { throw "$($Entry.file): installer $($iz.installer) missing" }
  $java = Find-Java
  $xml = [System.Text.StringBuilder]::new()
  [void]$xml.AppendLine('<?xml version="1.0" encoding="UTF-8" standalone="no"?>')
  [void]$xml.AppendLine('<AutomatedInstallation langpack="eng">')
  foreach ($panel in $VeraPdfPanels.GetEnumerator()) {
    if ($panel.Value -eq 'install_dir') {
      [void]$xml.AppendLine("  <$($panel.Key) id=`"install_dir`"><installpath>$([System.Security.SecurityElement]::Escape($Target))</installpath></$($panel.Key)>")
    } elseif ($panel.Value -eq 'sdk_pack_select') {
      [void]$xml.AppendLine("  <$($panel.Key) id=`"sdk_pack_select`">")
      for ($i = 0; $i -lt $iz.packs.Count; $i++) {
        $selected = if ($iz.select -contains $iz.packs[$i]) { 'true' } else { 'false' }
        [void]$xml.AppendLine("    <pack index=`"$i`" name=`"$([System.Security.SecurityElement]::Escape($iz.packs[$i]))`" selected=`"$selected`"/>")
      }
      [void]$xml.AppendLine("  </$($panel.Key)>")
    } else {
      [void]$xml.AppendLine("  <$($panel.Key) id=`"$($panel.Value)`"/>")
    }
  }
  [void]$xml.AppendLine('</AutomatedInstallation>')
  $auto = Join-Path $Source 'auto-install.xml'
  Set-Content -Path $auto -Value $xml.ToString() -Encoding utf8NoBOM
  $log = & $java -jar $installer $auto 2>&1
  if ($LASTEXITCODE -ne 0 -or -not ("$log" -match 'Automated installation done')) {
    throw "veraPDF installer failed (exit $LASTEXITCODE): $log"
  }
  $check = Join-Path $Target $iz.check
  $version = & $java -jar $check --version 2>&1
  if ($LASTEXITCODE -ne 0 -or -not ("$version" -match [regex]::Escape($iz.version))) {
    throw "veraPDF check failed: expected '$($iz.version)', got: $version"
  }
}

function Install-Entry($Entry) {
  if ([string]::IsNullOrWhiteSpace($Entry.dir) -or $Entry.dir -match '\.\.') { throw "Invalid dir in tools.json: '$($Entry.dir)'" }
  $target = Join-Path $Here $Entry.dir
  $marker = Join-Path $target '.installed'
  # the marker holds the archive's SHA-256, for an installer also the packs it installed
  $fingerprint = $Entry.sha256
  if ($Entry.PSObject.Properties.Name -contains 'izpack') { $fingerprint += ' ' + ($Entry.izpack.select -join ',') }
  if (-not $Force -and (Test-Path $marker) -and ("$(Get-Content -Raw $marker)".Trim() -eq $fingerprint)) {
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
  if ($Entry.PSObject.Properties.Name -contains 'izpack') {
    $tmp = Join-Path $Cache ('unpack-' + [Guid]::NewGuid().ToString('N'))
    try {
      Expand-Archive -Path $file -DestinationPath $tmp
      Install-VeraPdf $Entry $tmp (Resolve-Path $target).Path
    } catch {
      Remove-Item -Recurse -Force $target
      throw
    } finally {
      if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
    }
  } elseif (-not $Entry.unpack) {
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
  Set-Content -NoNewline -Path $marker -Value $fingerprint
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
  if ($entry.name -eq 'jre' -and $NoJre) { continue }
  if ($entry.PSObject.Properties.Name -contains 'platform') {
    if (-not ($Platform -contains 'all') -and -not ($wanted -contains $entry.platform)) { continue }
  }
  Install-Entry $entry
}
Write-Host 'Done.'
