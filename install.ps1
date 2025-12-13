# Neovim + PowerShell auto-setup script

$ErrorActionPreference = "Stop"

Write-Host "=== Neovim + PowerShell Setup ===" -ForegroundColor Cyan

$NvimConfigPath = $PSScriptRoot
$PowerShellConfigPath = Join-Path $NvimConfigPath "powershell"
$ProfileDir = Split-Path $PROFILE -Parent
$ProfilePath = $PROFILE
$OhMyPoshThemePath = "$env:LOCALAPPDATA\Programs\oh-my-posh\themes"
$OhMyPoshBin = "$env:LOCALAPPDATA\Programs\oh-my-posh\bin"

# Add Oh My Posh to PATH for this session
if (Test-Path $OhMyPoshBin) {
    $env:Path += ";$OhMyPoshBin"
}

Write-Host ""
Write-Host "[1/4] Checking Oh My Posh..." -ForegroundColor Yellow

$ohMyPoshInstalled = Get-Command oh-my-posh -ErrorAction SilentlyContinue
if (-not $ohMyPoshInstalled) {
    Write-Host "  Installing Oh My Posh..." -ForegroundColor Gray
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://ohmyposh.dev/install.ps1'))
    $env:Path += ";$OhMyPoshBin"
    Write-Host "  Oh My Posh installed" -ForegroundColor Green
} else {
    Write-Host "  Oh My Posh already installed" -ForegroundColor Green
}

Write-Host ""
Write-Host "[2/4] Copying Oh My Posh theme..." -ForegroundColor Yellow

if (-not (Test-Path $OhMyPoshThemePath)) {
    New-Item -ItemType Directory -Path $OhMyPoshThemePath -Force | Out-Null
}

$ThemeSource = Join-Path $PowerShellConfigPath "illusi0n.omp.json"
$ThemeDest = Join-Path $OhMyPoshThemePath "illusi0n.omp.json"
if (Test-Path $ThemeSource) {
    Copy-Item -Path $ThemeSource -Destination $ThemeDest -Force
    Write-Host "  Theme copied: $ThemeDest" -ForegroundColor Green
} else {
    Write-Host "  Theme not found: $ThemeSource" -ForegroundColor Red
}

Write-Host ""
Write-Host "[3/4] Setting up PowerShell profile..." -ForegroundColor Yellow

if (-not (Test-Path $ProfileDir)) {
    New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
    Write-Host "  Created profile directory: $ProfileDir" -ForegroundColor Gray
}

$ProfileSource = Join-Path $PowerShellConfigPath "Microsoft.PowerShell_profile.ps1"
if (Test-Path $ProfileSource) {
    if (Test-Path $ProfilePath) {
        $BackupPath = "$ProfilePath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item -Path $ProfilePath -Destination $BackupPath -Force
        Write-Host "  Backed up existing profile: $BackupPath" -ForegroundColor Gray
    }
    Copy-Item -Path $ProfileSource -Destination $ProfilePath -Force
    Write-Host "  Profile set: $ProfilePath" -ForegroundColor Green
} else {
    Write-Host "  Profile source not found: $ProfileSource" -ForegroundColor Red
}

Write-Host ""
Write-Host "[4/4] Neovim plugins..." -ForegroundColor Yellow
Write-Host "  Lazy.nvim will auto-install plugins on first nvim run" -ForegroundColor Gray

Write-Host ""
Write-Host "=== Setup Complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Restart PowerShell"
Write-Host "  2. Run nvim"
Write-Host "  3. :Copilot auth"
Write-Host ""
