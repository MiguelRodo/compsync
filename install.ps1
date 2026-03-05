#!/usr/bin/env pwsh
# install.ps1 — Install compsync for Windows (manual installation)
# Adds the bin/ directory to the user's PATH

param(
    [switch]$Uninstall
)

$ScriptRoot = Split-Path -Parent $PSCommandPath
$BinDir = Join-Path $ScriptRoot "bin"

if (-not (Test-Path $BinDir)) {
    Write-Error "Error: bin directory not found at $BinDir"
    exit 1
}

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")

if ($Uninstall) {
    if ($UserPath -like "*$BinDir*") {
        $NewPath = ($UserPath -split ';' | Where-Object { $_ -ne $BinDir }) -join ';'
        [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
        Write-Host "Successfully removed $BinDir from PATH" -ForegroundColor Green
        Write-Host "Please restart your PowerShell session for changes to take effect." -ForegroundColor Yellow
    } else {
        Write-Host "compsync bin directory was not found in PATH." -ForegroundColor Yellow
    }
} else {
    if ($UserPath -like "*$BinDir*") {
        Write-Host "compsync bin directory is already in PATH." -ForegroundColor Yellow
    } else {
        $NewPath = "$UserPath;$BinDir"
        [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
        Write-Host "Successfully added $BinDir to PATH" -ForegroundColor Green
        Write-Host "Please restart your PowerShell session for changes to take effect." -ForegroundColor Yellow
    }
}

if (-not $Uninstall) {
    Write-Host ""
    Write-Host "Installation complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "After restarting PowerShell, you can run:" -ForegroundColor Cyan
    Write-Host "  compsync --help" -ForegroundColor White
    Write-Host ""
    Write-Host "Dependencies required:" -ForegroundColor Cyan
    Write-Host "  - Git for Windows (includes bash and git)" -ForegroundColor White
    Write-Host "  - Python 3 (download from https://python.org)" -ForegroundColor White
    Write-Host ""
}
