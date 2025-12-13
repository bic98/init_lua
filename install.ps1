# Neovim + PowerShell 환경 자동 설치 스크립트
# 사용법: git clone 후 PowerShell에서 .\install.ps1 실행

$ErrorActionPreference = "Stop"

Write-Host "=== Neovim + PowerShell 환경 설치 ===" -ForegroundColor Cyan

# 현재 스크립트 위치 (nvim 설정 폴더)
$NvimConfigPath = $PSScriptRoot
$PowerShellConfigPath = Join-Path $NvimConfigPath "powershell"

# PowerShell 프로필 경로
$ProfileDir = Split-Path $PROFILE -Parent
$ProfilePath = $PROFILE

# Oh My Posh 테마 경로
$OhMyPoshThemePath = "$env:LOCALAPPDATA\Programs\oh-my-posh\themes"

Write-Host ""
Write-Host "[1/4] Oh My Posh 설치 확인..." -ForegroundColor Yellow

# Oh My Posh 설치 확인
$ohMyPoshInstalled = Get-Command oh-my-posh -ErrorAction SilentlyContinue
if (-not $ohMyPoshInstalled) {
    Write-Host "  Oh My Posh 설치 중..." -ForegroundColor Gray
    winget install JanDeDobbeleer.OhMyPosh -s winget
    $env:Path += ";$env:LOCALAPPDATA\Programs\oh-my-posh\bin"
}
else {
    Write-Host "  Oh My Posh 이미 설치됨" -ForegroundColor Green
}

Write-Host ""
Write-Host "[2/4] Oh My Posh 테마 복사..." -ForegroundColor Yellow

# 테마 폴더 생성
if (-not (Test-Path $OhMyPoshThemePath)) {
    New-Item -ItemType Directory -Path $OhMyPoshThemePath -Force | Out-Null
}

# 테마 파일 복사
$ThemeSource = Join-Path $PowerShellConfigPath "illusi0n.omp.json"
$ThemeDest = Join-Path $OhMyPoshThemePath "illusi0n.omp.json"
if (Test-Path $ThemeSource) {
    Copy-Item -Path $ThemeSource -Destination $ThemeDest -Force
    Write-Host "  테마 복사 완료: $ThemeDest" -ForegroundColor Green
}
else {
    Write-Host "  테마 파일을 찾을 수 없음: $ThemeSource" -ForegroundColor Red
}

Write-Host ""
Write-Host "[3/4] PowerShell 프로필 설정..." -ForegroundColor Yellow

# 프로필 디렉토리 생성
if (-not (Test-Path $ProfileDir)) {
    New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
    Write-Host "  프로필 디렉토리 생성: $ProfileDir" -ForegroundColor Gray
}

# 프로필 복사
$ProfileSource = Join-Path $PowerShellConfigPath "Microsoft.PowerShell_profile.ps1"
if (Test-Path $ProfileSource) {
    if (Test-Path $ProfilePath) {
        $BackupPath = "$ProfilePath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item -Path $ProfilePath -Destination $BackupPath -Force
        Write-Host "  기존 프로필 백업: $BackupPath" -ForegroundColor Gray
    }
    Copy-Item -Path $ProfileSource -Destination $ProfilePath -Force
    Write-Host "  프로필 설정 완료: $ProfilePath" -ForegroundColor Green
}
else {
    Write-Host "  프로필 소스를 찾을 수 없음: $ProfileSource" -ForegroundColor Red
}

Write-Host ""
Write-Host "[4/4] Neovim 플러그인 설치..." -ForegroundColor Yellow
Write-Host "  Neovim 첫 실행 시 Lazy.nvim이 자동으로 플러그인을 설치합니다" -ForegroundColor Gray

Write-Host ""
Write-Host "=== 설치 완료! ===" -ForegroundColor Green
Write-Host ""
Write-Host "다음 단계:" -ForegroundColor Cyan
Write-Host "  1. PowerShell 재시작 (Oh My Posh 적용)"
Write-Host "  2. nvim 실행 (플러그인 자동 설치)"
Write-Host "  3. :Copilot auth (GitHub Copilot 인증)"
Write-Host ""
