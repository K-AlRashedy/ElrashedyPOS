[CmdletBinding()]
param(
    [string]$Version,
    [switch]$SkipChecks,
    [switch]$SkipTests,
    [switch]$PortableOnly
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
$buildPath = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$distPath = Join-Path $projectRoot 'dist'
$installerScript = Join-Path $PSScriptRoot 'pos.iss'

function Get-ToolPath([string]$name) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    return $null
}

function Stop-WithMessage([string]$message) {
    throw "[Elrashedy POS] $message"
}

if (-not (Test-Path $pubspecPath)) {
    Stop-WithMessage "pubspec.yaml was not found. Run this script from the POS project."
}

$flutter = Get-ToolPath 'flutter'
if (-not $flutter) {
    Stop-WithMessage 'Flutter was not found on PATH. Install the stable Flutter SDK and add its bin directory to PATH.'
}

if (-not $Version) {
    $versionMatch = Select-String -Path $pubspecPath -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)' | Select-Object -First 1
    if (-not $versionMatch) {
        Stop-WithMessage 'Could not read a semantic version from pubspec.yaml. Pass -Version 1.0.0.'
    }
    $Version = $versionMatch.Matches[0].Groups[1].Value
}

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    Stop-WithMessage "Version '$Version' must use the format major.minor.patch, for example 1.0.0."
}

New-Item -ItemType Directory -Path $distPath -Force | Out-Null
Push-Location $projectRoot
try {
    Write-Host "Preparing Al Rashedy POS $Version..." -ForegroundColor Cyan
    & $flutter config --enable-windows-desktop
    if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'Flutter could not enable Windows desktop support.' }

    & $flutter pub get
    if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'Flutter dependency resolution failed.' }

    if (-not $SkipChecks) {
        & $flutter analyze
        if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'flutter analyze failed.' }

        if (-not $SkipTests) {
            & $flutter test
            if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'flutter test failed.' }
        }
    }

    & $flutter build windows --release --build-name=$Version
    if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'Flutter Windows release build failed.' }
    if (-not (Test-Path (Join-Path $buildPath 'elrashedy_pos.exe'))) {
        Stop-WithMessage "The Windows build completed without producing $buildPath\elrashedy_pos.exe."
    }

    $portablePath = Join-Path $distPath "ElrashedyPOS-$Version-windows-portable.zip"
    if (Test-Path $portablePath) { Remove-Item -LiteralPath $portablePath -Force }
    Compress-Archive -Path (Join-Path $buildPath '*') -DestinationPath $portablePath -CompressionLevel Optimal
    Write-Host "Portable package: $portablePath" -ForegroundColor Green

    if (-not $PortableOnly) {
        $isccCandidates = @(
            (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
            (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
        )
        $iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $iscc) {
            Stop-WithMessage 'Inno Setup 6 was not found. Install it or rerun with -PortableOnly.'
        }

        & $iscc "/DMyAppVersion=$Version" $installerScript
        if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'Inno Setup failed.' }
        $installerPath = Join-Path $distPath "ElrashedyPOS-Setup-$Version.exe"
        if (-not (Test-Path $installerPath)) {
            Stop-WithMessage "Inno Setup completed without producing $installerPath."
        }
        Write-Host "Installer: $installerPath" -ForegroundColor Green
    }
}
finally {
    Pop-Location
}
