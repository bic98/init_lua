# Windows 10/11 bootstrap for the complete init_lua terminal environment.
# Run from Windows PowerShell or PowerShell 7. The script requests standard
# UAC elevation when administrator privileges are required.

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"
Set-ExecutionPolicy Bypass -Scope Process -Force

if ($Branch -notmatch "^[A-Za-z0-9._/-]+$") {
    throw "Invalid Git branch name: $Branch"
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Refresh-ProcessPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

if (-not (Test-Administrator)) {
    if ([string]::IsNullOrWhiteSpace($PSCommandPath)) {
        throw "Administrator privileges are required, but the bootstrap script path could not be detected."
    }

    $powerShellExecutable = if ($PSVersionTable.PSEdition -eq "Core") {
        Join-Path $PSHOME "pwsh.exe"
    } else {
        Join-Path $PSHOME "powershell.exe"
    }
    $elevationArguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Branch "{1}"' -f `
        $PSCommandPath, $Branch

    Write-Host "Administrator privileges are needed to install Windows packages." -ForegroundColor Yellow
    Write-Host "Approve the Windows UAC prompt to continue. No privilege bypass is attempted." -ForegroundColor Yellow

    try {
        $elevatedProcess = Start-Process `
            -FilePath $powerShellExecutable `
            -Verb RunAs `
            -ArgumentList $elevationArguments `
            -Wait `
            -PassThru
    } catch {
        throw "UAC elevation was declined or could not start. No installation was performed. $($_.Exception.Message)"
    }

    if ($elevatedProcess.ExitCode -ne 0) {
        throw "The elevated bootstrap failed with exit code $($elevatedProcess.ExitCode)."
    }
    exit 0
}

$repositoryUrl = "https://github.com/bic98/init_lua.git"
$targetPath = Join-Path $env:LOCALAPPDATA "nvim"

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey..." -ForegroundColor Cyan
    [System.Net.ServicePointManager]::SecurityProtocol =
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString(
        "https://community.chocolatey.org/install.ps1"
    ))
    Refresh-ProcessPath
}

$git = Get-Command git -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $git) {
    Write-Host "Installing Git..." -ForegroundColor Cyan
    choco install git -y --no-progress
    if ($LASTEXITCODE -ne 0) {
        throw "Git installation failed with exit code $LASTEXITCODE."
    }
    Refresh-ProcessPath
    $git = Get-Command git -ErrorAction SilentlyContinue | Select-Object -First 1
}
if (-not $git) {
    throw "Git was installed but is not available on PATH. Restart PowerShell and rerun the bootstrap."
}

if (Test-Path -LiteralPath $targetPath) {
    $gitDirectory = Join-Path $targetPath ".git"
    if (Test-Path -LiteralPath $gitDirectory) {
        $remote = (& $git.Source -C $targetPath remote get-url origin 2>$null).Trim()
        if ($LASTEXITCODE -ne 0 -or $remote -notmatch "(^|[:/])bic98/init_lua(\.git)?$") {
            throw "Existing nvim repository has a different origin. Preserved without changes: $targetPath"
        }

        $workingChanges = @(& $git.Source -C $targetPath status --porcelain)
        if ($workingChanges.Count -gt 0) {
            throw "Existing init_lua repository has local changes. Commit or back them up before rerunning: $targetPath"
        }

        $currentBranch = (& $git.Source -C $targetPath branch --show-current).Trim()
        if ($currentBranch -ne $Branch) {
            throw "Existing init_lua repository is on '$currentBranch', not '$Branch'. It was preserved without changes."
        }

        Write-Host "Updating the existing init_lua repository..." -ForegroundColor Cyan
        & $git.Source -C $targetPath pull --ff-only origin $Branch
        if ($LASTEXITCODE -ne 0) {
            throw "git pull failed. Existing files were preserved."
        }
    } else {
        $backupPath = "$targetPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss_fff')"
        Write-Host "Backing up the existing Neovim configuration: $backupPath" -ForegroundColor Yellow
        Move-Item -LiteralPath $targetPath -Destination $backupPath

        Write-Host "Cloning init_lua..." -ForegroundColor Cyan
        & $git.Source clone --branch $Branch --single-branch $repositoryUrl $targetPath
        if ($LASTEXITCODE -ne 0) {
            throw "git clone failed. The previous configuration remains at: $backupPath"
        }
    }
} else {
    Write-Host "Cloning init_lua..." -ForegroundColor Cyan
    & $git.Source clone --branch $Branch --single-branch $repositoryUrl $targetPath
    if ($LASTEXITCODE -ne 0) {
        throw "git clone failed."
    }
}

$installer = Join-Path $targetPath "install.ps1"
if (-not (Test-Path -LiteralPath $installer)) {
    throw "init_lua installer not found after clone: $installer"
}

Write-Host "Installing the complete terminal environment..." -ForegroundColor Cyan
& $installer -Full
if ($LASTEXITCODE -ne 0) {
    throw "init_lua installation failed with exit code $LASTEXITCODE."
}

Write-Host ""
Write-Host "init_lua terminal environment installation complete." -ForegroundColor Green
Write-Host "Close every Windows Terminal window, reopen it, and select PowerShell 7 (init_lua)." -ForegroundColor Cyan
