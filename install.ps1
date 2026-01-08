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
Write-Host "[4/5] Neovim plugins..." -ForegroundColor Yellow
Write-Host "  Lazy.nvim will auto-install plugins on first nvim run" -ForegroundColor Gray

Write-Host ""
Write-Host "[5/5] Claude Code agents setup..." -ForegroundColor Yellow

$ClaudeConfigSource = Join-Path $NvimConfigPath "claude-config"
$ClaudeHome = Join-Path $env:USERPROFILE ".claude"

if (Test-Path $ClaudeConfigSource) {
    # Create .claude directory if not exists
    if (-not (Test-Path $ClaudeHome)) {
        New-Item -ItemType Directory -Path $ClaudeHome -Force | Out-Null
        Write-Host "  Created: $ClaudeHome" -ForegroundColor Gray
    }

    # Copy agents
    $AgentsSource = Join-Path $ClaudeConfigSource "agents"
    $AgentsDest = Join-Path $ClaudeHome "agents"
    if (Test-Path $AgentsSource) {
        if (-not (Test-Path $AgentsDest)) {
            New-Item -ItemType Directory -Path $AgentsDest -Force | Out-Null
        }
        Copy-Item -Path "$AgentsSource\*" -Destination $AgentsDest -Force -Recurse
        Write-Host "  Agents installed: $AgentsDest" -ForegroundColor Green
    }

    # Copy skills if exists
    $SkillsSource = Join-Path $ClaudeConfigSource "skills"
    $SkillsDest = Join-Path $ClaudeHome "skills"
    if (Test-Path $SkillsSource) {
        if (-not (Test-Path $SkillsDest)) {
            New-Item -ItemType Directory -Path $SkillsDest -Force | Out-Null
        }
        Copy-Item -Path "$SkillsSource\*" -Destination $SkillsDest -Force -Recurse
        Write-Host "  Skills installed: $SkillsDest" -ForegroundColor Green
    }

    # Copy CLAUDE.md (only if not exists, to preserve user customizations)
    $ClaudeMdSource = Join-Path $ClaudeConfigSource "CLAUDE.md"
    $ClaudeMdDest = Join-Path $ClaudeHome "CLAUDE.md"
    if ((Test-Path $ClaudeMdSource) -and (-not (Test-Path $ClaudeMdDest))) {
        Copy-Item -Path $ClaudeMdSource -Destination $ClaudeMdDest -Force
        Write-Host "  CLAUDE.md created: $ClaudeMdDest" -ForegroundColor Green
    } elseif (Test-Path $ClaudeMdDest) {
        Write-Host "  CLAUDE.md already exists (skipped)" -ForegroundColor Gray
    }

    Write-Host "  Claude Code agents ready!" -ForegroundColor Green
} else {
    Write-Host "  claude-config not found (skipped)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Setup Complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Restart PowerShell"
Write-Host "  2. Run nvim"
Write-Host "  3. Claude Code: npm install -g @anthropic-ai/claude-code && claude login"
Write-Host ""
Write-Host "Installed Claude agents:" -ForegroundColor Cyan
Write-Host "  - document-organizer: Document formatting/conversion"
Write-Host "  - report-generator:   Auto-generate reports"
Write-Host "  - data-extractor:     Extract data from documents"
Write-Host "  - supervisor:         Multi-agent orchestrator"
Write-Host "  - reviewer:           Review and feedback"
Write-Host "  - writer:             Content writing"
Write-Host ""
