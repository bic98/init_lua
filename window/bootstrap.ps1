# Windows bootstrap for the platform-oriented init_lua repository.
#
# This entry point converges a native Windows machine to the repository's
# declared terminal environment. It uses only the allow-listed winget packages.

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

$repositoryUrl = "https://github.com/bic98/init_lua.git"
$targetPath = Join-Path $env:LOCALAPPDATA "init_lua"
$git = Get-Command git -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $git) {
    $winget = Get-Command winget -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $winget) {
        throw "Git is missing and Windows App Installer (winget) is unavailable. Install App Installer, then rerun."
    }
    Write-Host "Installing Git from the declared winget package..." -ForegroundColor Cyan
    & $winget.Source install --id Git.Git --exact --source winget `
        --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        throw "winget failed to install Git with exit code $LASTEXITCODE."
    }
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
        [Environment]::GetEnvironmentVariable("Path", "User")
    $git = Get-Command git -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $git) {
        throw "Git was installed but is unavailable after refreshing PATH."
    }
}

if (Test-Path -LiteralPath $targetPath) {
    $gitDirectory = Join-Path $targetPath ".git"
    if (Test-Path -LiteralPath $gitDirectory) {
        $remote = (& $git.Source -C $targetPath remote get-url origin 2>$null).Trim()
        if ($LASTEXITCODE -ne 0 -or $remote -notmatch "(^|[:/])bic98/init_lua(\.git)?$") {
            throw "Existing init_lua directory has a different Git origin. Preserved without changes: $targetPath"
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
        Write-Host "Backing up the existing init_lua directory: $backupPath" -ForegroundColor Yellow
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

$installer = Join-Path $targetPath "window\install.ps1"
if (-not (Test-Path -LiteralPath $installer)) {
    throw "init_lua installer not found after clone: $installer"
}

$manifestPath = Join-Path $targetPath "window\desired-state.json"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Windows desired-state manifest not found after clone: $manifestPath"
}
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$powerShellState = @($manifest.requiredTools | Where-Object name -eq "PowerShell" | Select-Object -First 1)
if ($powerShellState.Count -ne 1) {
    throw "PowerShell is missing from the Windows desired-state manifest."
}
$requiredPowerShellVersion = [version]$powerShellState[0].minimumVersion
$powerShellPackageId = [string]$powerShellState[0].packageId
$powerShell7 = Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1
$powerShellVersion = if ($powerShell7) {
    try {
        [version]((& $powerShell7.Source -NoProfile -Command '$PSVersionTable.PSVersion.ToString()').Trim())
    } catch {
        $null
    }
} else {
    $null
}
if (-not $powerShell7 -or $null -eq $powerShellVersion -or $powerShellVersion -lt $requiredPowerShellVersion) {
    $winget = Get-Command winget -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $winget) {
        throw "PowerShell 7 is missing and Windows App Installer (winget) is unavailable."
    }
    $wingetListing = @(& $winget.Source list --id $powerShellPackageId --exact `
        --accept-source-agreements --disable-interactivity 2>&1)
    $powerShellPackageInstalled = $LASTEXITCODE -eq 0 -and
        ($wingetListing -join "`n") -match [regex]::Escape($powerShellPackageId)
    $wingetAction = if ($powerShellPackageInstalled) { "upgrade" } else { "install" }
    $wingetActionLabel = if ($wingetAction -eq "upgrade") { "Upgrading" } else { "Installing" }
    Write-Host "$wingetActionLabel PowerShell 7 from the declared winget package..." -ForegroundColor Cyan
    & $winget.Source $wingetAction --id $powerShellPackageId --exact --source winget `
        --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        throw "winget failed to $wingetAction PowerShell 7 with exit code $LASTEXITCODE."
    }
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
        [Environment]::GetEnvironmentVariable("Path", "User")
    $powerShell7 = Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $powerShell7) {
        $powerShellCandidate = Join-Path $env:ProgramFiles "PowerShell\7\pwsh.exe"
        if (Test-Path -LiteralPath $powerShellCandidate) {
            $powerShell7 = Get-Item -LiteralPath $powerShellCandidate
        }
    }
    if (-not $powerShell7) {
        throw "PowerShell 7 was installed but pwsh is unavailable after refreshing PATH."
    }
}

$powerShellExecutable = if ($powerShell7.PSObject.Properties["Source"] -and $powerShell7.Source) {
    $powerShell7.Source
} elseif ($powerShell7.PSObject.Properties["FullName"] -and $powerShell7.FullName) {
    $powerShell7.FullName
} else {
    [string]$powerShell7
}
$resolvedPowerShellVersion = [version]((& $powerShellExecutable -NoProfile -Command '$PSVersionTable.PSVersion.ToString()').Trim())
if ($resolvedPowerShellVersion -lt $requiredPowerShellVersion) {
    throw "PowerShell $resolvedPowerShellVersion is below required version $requiredPowerShellVersion after winget convergence."
}

Write-Host "Applying the init_lua Windows configuration..." -ForegroundColor Cyan
& $powerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $installer
if ($LASTEXITCODE -ne 0) {
    throw "init_lua configuration failed with exit code $LASTEXITCODE."
}

Write-Host ""
Write-Host "init_lua Windows configuration complete." -ForegroundColor Green
Write-Host "Close every Windows Terminal window and reopen it to load the updated profile." -ForegroundColor Cyan
