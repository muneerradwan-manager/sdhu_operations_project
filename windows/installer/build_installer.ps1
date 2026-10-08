<#
.SYNOPSIS
    Builds the Windows release and packages it into a single setup .exe.

.DESCRIPTION
    Runs `flutter build windows --release`, reads the version from pubspec.yaml,
    then compiles windows\installer\hajjoperations.iss with Inno Setup.

    Requires Inno Setup 6.3 or newer: https://jrsoftware.org/isdl.php

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File windows\installer\build_installer.ps1

.EXAMPLE
    # Package what is already in build\windows, without rebuilding
    powershell -ExecutionPolicy Bypass -File windows\installer\build_installer.ps1 -SkipFlutterBuild
#>
[CmdletBinding()]
param(
    [switch]$SkipFlutterBuild
)

$ErrorActionPreference = 'Stop'

$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir '..\..')).Path
$issFile     = Join-Path $scriptDir 'hajjoperations.iss'
$releaseDir  = Join-Path $projectRoot 'build\windows\x64\runner\Release'

# --- version, straight from pubspec.yaml (0.1.0+1 -> 0.1.0) -----------------
$pubspec = Join-Path $projectRoot 'pubspec.yaml'
$versionLine = Select-String -Path $pubspec -Pattern '^version:\s*(.+)$' | Select-Object -First 1
if (-not $versionLine) { throw "No 'version:' line found in $pubspec" }
$version = $versionLine.Matches[0].Groups[1].Value.Trim().Split('+')[0]
Write-Host "Version: $version" -ForegroundColor Cyan

# --- flutter build ----------------------------------------------------------
if (-not $SkipFlutterBuild) {
    Write-Host 'Building Flutter Windows release...' -ForegroundColor Cyan
    Push-Location $projectRoot
    try {
        & flutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw "flutter build failed (exit $LASTEXITCODE)" }
    } finally {
        Pop-Location
    }
}

if (-not (Test-Path (Join-Path $releaseDir 'hajjoperations.exe'))) {
    throw "Release build not found at $releaseDir. Run without -SkipFlutterBuild."
}

# --- locate the Inno Setup compiler ----------------------------------------
$isccCandidates = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
)
$iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
    $onPath = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($onPath) { $iscc = $onPath.Source }
}
if (-not $iscc) {
    throw 'ISCC.exe not found. Install Inno Setup 6.3+ from https://jrsoftware.org/isdl.php'
}
Write-Host "Compiler: $iscc" -ForegroundColor Cyan

# --- compile the installer --------------------------------------------------
& $iscc "/DMyAppVersion=$version" $issFile
if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed (exit $LASTEXITCODE)" }

$output = Join-Path $projectRoot "build\windows\installer\HajjOperations-$version-x64-setup.exe"
$sizeMb = [math]::Round((Get-Item $output).Length / 1MB, 1)
Write-Host ''
Write-Host "Installer ready: $output ($sizeMb MB)" -ForegroundColor Green
