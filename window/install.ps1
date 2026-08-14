# Complete Windows configuration for the platform-oriented init_lua repository.
# The default path installs only dependencies declared in desired-state.json,
# then applies and verifies every managed setting.

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$SkipDependencyInstall,

    [Parameter()]
    [switch]$SkipClaudeCodeInstall,

    [Parameter()]
    [switch]$SkipOhMyPoshInstall,

    [Parameter()]
    [switch]$SkipFontInstall,

    [Parameter()]
    [Alias("SkipWindowsTerminalKeybindings")]
    [switch]$SkipWindowsTerminalEnvironment,

    [Parameter()]
    [switch]$SkipVerification,

    [Parameter()]
    [string]$ProfilePath,

    [Parameter()]
    [switch]$SkipNvimConfiguration,

    [Parameter()]
    [switch]$SkipNvimPluginInstall,

    [Parameter()]
    [string]$NvimConfigPath,

    [Parameter()]
    [switch]$PassThru
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$partialRun = [bool](
    $SkipDependencyInstall -or
    $SkipClaudeCodeInstall -or
    $SkipOhMyPoshInstall -or
    $SkipFontInstall -or
    $SkipNvimConfiguration -or
    $SkipNvimPluginInstall -or
    $SkipWindowsTerminalEnvironment -or
    $SkipVerification
)

function Get-PowerShell7Path {
    $command = Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        return $command.Source
    }

    foreach ($candidate in @(
        (Join-Path $env:ProgramFiles "PowerShell\7\pwsh.exe"),
        $(if (${env:ProgramFiles(x86)}) { Join-Path ${env:ProgramFiles(x86)} "PowerShell\7\pwsh.exe" })
    )) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    return $null
}

function Get-OhMyPoshPath {
    $command = Get-Command oh-my-posh -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        return $command.Source
    }

    foreach ($candidate in @(
        (Join-Path $env:LOCALAPPDATA "Programs\oh-my-posh\bin\oh-my-posh.exe"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\oh-my-posh.exe")
    )) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

function Test-JetBrainsMonoNerdFont {
    foreach ($fontKey in @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
        "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    )) {
        if (-not (Test-Path -LiteralPath $fontKey)) {
            continue
        }

        $font = (Get-ItemProperty -LiteralPath $fontKey).PSObject.Properties |
            Where-Object { $_.Name -match "^JetBrainsMono NF" } |
            Select-Object -First 1
        if ($font) {
            return $true
        }
    }

    return $false
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Content
    )

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function New-TimestampBackup {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $backupPath = "$Path.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss_fff')"
    Copy-Item -LiteralPath $Path -Destination $backupPath -Force
    return $backupPath
}

function Sync-ManagedFile {
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter(Mandatory)]
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        throw "$Label source not found: $Source"
    }

    $destinationDirectory = Split-Path $Destination -Parent
    if (-not (Test-Path -LiteralPath $destinationDirectory)) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    }

    if (Test-Path -LiteralPath $Destination) {
        $sameHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash -eq
            (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
        if ($sameHash) {
            Write-Host "  $Label already matches: $Destination" -ForegroundColor Green
            return [pscustomobject]@{ Changed = $false; BackupPath = $null; Path = $Destination }
        }
    }

    $backupPath = if (Test-Path -LiteralPath $Destination) {
        New-TimestampBackup -Path $Destination
    } else {
        $null
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    Write-Host "  $Label synchronized: $Destination" -ForegroundColor Green
    if ($backupPath) {
        Write-Host "  Previous $Label backup: $backupPath" -ForegroundColor Gray
    }

    return [pscustomobject]@{ Changed = $true; BackupPath = $backupPath; Path = $Destination }
}

function Sync-PowerShellProfile {
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        throw "PowerShell profile source not found: $Source"
    }

    $startMarker = "# >>> init_lua terminal environment >>>"
    $endMarker = "# <<< init_lua terminal environment <<<"
    $managedBlock = [System.IO.File]::ReadAllText($Source).Trim()
    if (-not $managedBlock.Contains($startMarker) -or -not $managedBlock.Contains($endMarker)) {
        throw "The managed PowerShell profile block is missing its init_lua markers."
    }

    $destinationDirectory = Split-Path $Destination -Parent
    if (-not (Test-Path -LiteralPath $destinationDirectory)) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    }

    $destinationExists = Test-Path -LiteralPath $Destination
    $existing = if ($destinationExists) {
        [System.IO.File]::ReadAllText($Destination)
    } else {
        ""
    }

    $markerPattern = '(?ms)^[ \t]*' + [regex]::Escape($startMarker) +
        '.*?^[ \t]*' + [regex]::Escape($endMarker) + '[ \t]*(?:\r?\n)?'

    if ([regex]::IsMatch($existing, $markerPattern)) {
        $replacement = { param($match) $managedBlock + [Environment]::NewLine }.GetNewClosure()
        $updated = [regex]::Replace($existing, $markerPattern, $replacement).TrimEnd() + [Environment]::NewLine
    } else {
        $working = $existing
        $legacyProfile =
            $working.Contains('illusi0n-dayfox.omp.json') -and
            $working.Contains('# Dayfox 라이트 배경용 PSReadLine 색상') -and
            $working.Contains('# ls(Get-ChildItem)')

        if ($legacyProfile) {
            $working = [regex]::Replace(
                $working,
                '(?ms)^# Oh My Posh 설정.*?(?=^# Dayfox 라이트 배경용 PSReadLine 색상)',
                ''
            )
            $working = [regex]::Replace(
                $working,
                '(?ms)^# Dayfox 라이트 배경용 PSReadLine 색상.*?(?=^# ls\(Get-ChildItem\))',
                ''
            )
            $working = [regex]::Replace(
                $working,
                '(?ms)^# ls\(Get-ChildItem\).*?(?=^function\s|\z)',
                ''
            )
        }

        $personalContent = $working.Trim()
        $updated = if ([string]::IsNullOrWhiteSpace($personalContent)) {
            $managedBlock + [Environment]::NewLine
        } else {
            $personalContent + [Environment]::NewLine + [Environment]::NewLine +
                $managedBlock + [Environment]::NewLine
        }
    }

    if ($destinationExists -and $existing -eq $updated) {
        Write-Host "  PowerShell profile already contains the current init_lua block." -ForegroundColor Green
        return [pscustomobject]@{ Changed = $false; BackupPath = $null; Path = $Destination }
    }

    $backupPath = if ($destinationExists) {
        New-TimestampBackup -Path $Destination
    } else {
        $null
    }
    Write-Utf8NoBom -Path $Destination -Content $updated
    Write-Host "  PowerShell profile synchronized: $Destination" -ForegroundColor Green
    if ($backupPath) {
        Write-Host "  Previous profile backup: $backupPath" -ForegroundColor Gray
    }

    return [pscustomobject]@{ Changed = $true; BackupPath = $backupPath; Path = $Destination }
}

function Sync-ManagedTree {
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter(Mandatory)]
        [string]$Label
    )

    $resolvedSource = [System.IO.Path]::GetFullPath($Source).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $resolvedDestination = [System.IO.Path]::GetFullPath($Destination).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )

    if (-not (Test-Path -LiteralPath $resolvedSource -PathType Container)) {
        throw "$Label source directory not found: $resolvedSource"
    }
    if ($resolvedSource.Equals($resolvedDestination, [System.StringComparison]::OrdinalIgnoreCase) -or
        $resolvedSource.StartsWith(
            $resolvedDestination + [System.IO.Path]::DirectorySeparatorChar,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
        Write-Host "  $Label sync skipped because this is a legacy checkout inside the destination." -ForegroundColor Yellow
        return [pscustomobject]@{
            Changed = $false
            BackupPath = $null
            Path = $resolvedDestination
            Skipped = $true
            MigratedLegacy = $false
        }
    }
    if ((Test-Path -LiteralPath $resolvedDestination) -and
        -not (Test-Path -LiteralPath $resolvedDestination -PathType Container)) {
        throw "$Label destination exists but is not a directory: $resolvedDestination"
    }

    $legacyCheckout = $false
    $destinationGit = Join-Path $resolvedDestination ".git"
    $git = Get-Command git -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($git -and (Test-Path -LiteralPath $destinationGit)) {
        $remote = (& $git.Source -C $resolvedDestination remote get-url origin 2>$null | Out-String).Trim()
        $legacyCheckout = $LASTEXITCODE -eq 0 -and
            $remote -match "(^|[:/])bic98/init_lua(\.git)?$"
    }

    $sourceFiles = @(Get-ChildItem -LiteralPath $resolvedSource -File -Recurse)
    $changed = $legacyCheckout -or -not (Test-Path -LiteralPath $resolvedDestination -PathType Container)
    if (-not $changed) {
        foreach ($sourceFile in $sourceFiles) {
            $relativePath = [System.IO.Path]::GetRelativePath($resolvedSource, $sourceFile.FullName)
            $targetFile = Join-Path $resolvedDestination $relativePath
            if (-not (Test-Path -LiteralPath $targetFile -PathType Leaf) -or
                (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash -ne
                    (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256).Hash) {
                $changed = $true
                break
            }
        }
    }

    if (-not $changed) {
        Write-Host "  $Label already matches: $resolvedDestination" -ForegroundColor Green
        return [pscustomobject]@{
            Changed = $false
            BackupPath = $null
            Path = $resolvedDestination
            Skipped = $false
            MigratedLegacy = $false
        }
    }

    $backupPath = $null
    if (Test-Path -LiteralPath $resolvedDestination -PathType Container) {
        $backupPath = "$resolvedDestination.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss_fff')"
        if ($legacyCheckout) {
            Move-Item -LiteralPath $resolvedDestination -Destination $backupPath
            New-Item -ItemType Directory -Path $resolvedDestination -Force | Out-Null
        } else {
            Copy-Item -LiteralPath $resolvedDestination -Destination $backupPath -Recurse -Force
        }
    } else {
        New-Item -ItemType Directory -Path $resolvedDestination -Force | Out-Null
    }

    foreach ($sourceFile in $sourceFiles) {
        $relativePath = [System.IO.Path]::GetRelativePath($resolvedSource, $sourceFile.FullName)
        $targetFile = Join-Path $resolvedDestination $relativePath
        $targetDirectory = Split-Path $targetFile -Parent
        if (-not (Test-Path -LiteralPath $targetDirectory)) {
            New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
        }
        Copy-Item -LiteralPath $sourceFile.FullName -Destination $targetFile -Force
    }

    Write-Host "  $Label synchronized: $resolvedDestination" -ForegroundColor Green
    if ($backupPath) {
        Write-Host "  Previous $Label backup: $backupPath" -ForegroundColor Gray
    }
    return [pscustomobject]@{
        Changed = $true
        BackupPath = $backupPath
        Path = $resolvedDestination
        Skipped = $false
        MigratedLegacy = $legacyCheckout
    }
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    $powerShell7 = Get-PowerShell7Path
    if (-not $powerShell7 -and -not $SkipDependencyInstall) {
        $winget = Get-Command winget -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($winget) {
            Write-Host "Installing PowerShell 7 from the declared winget package..." -ForegroundColor Cyan
            & $winget.Source install --id Microsoft.PowerShell --exact --source winget `
                --accept-package-agreements --accept-source-agreements --disable-interactivity
            if ($LASTEXITCODE -eq 0) {
                $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                    [Environment]::GetEnvironmentVariable("Path", "User")
                $powerShell7 = Get-PowerShell7Path
            }
        }
    }
    if (-not $powerShell7) {
        Write-Host "ERROR: PowerShell 7 is required for the init_lua terminal profile." -ForegroundColor Red
        Write-Host "Windows App Installer (winget) could not provide PowerShell 7. Install it, then rerun." -ForegroundColor Yellow
        exit 1
    }

    $relaunchArguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath)
    foreach ($switchName in @(
        "SkipDependencyInstall",
        "SkipClaudeCodeInstall",
        "SkipOhMyPoshInstall",
        "SkipFontInstall",
        "SkipWindowsTerminalEnvironment",
        "SkipNvimConfiguration",
        "SkipNvimPluginInstall",
        "SkipVerification",
        "PassThru"
    )) {
        if ($PSBoundParameters.ContainsKey($switchName) -and $PSBoundParameters[$switchName]) {
            $relaunchArguments += "-$switchName"
        }
    }
    if ($PSBoundParameters.ContainsKey("ProfilePath")) {
        $relaunchArguments += @("-ProfilePath", $ProfilePath)
    }
    if ($PSBoundParameters.ContainsKey("NvimConfigPath")) {
        $relaunchArguments += @("-NvimConfigPath", $NvimConfigPath)
    }

    & $powerShell7 @relaunchArguments
    exit $LASTEXITCODE
}

if ([string]::IsNullOrWhiteSpace($ProfilePath)) {
    $ProfilePath = $PROFILE
}
$ProfilePath = [System.IO.Path]::GetFullPath($ProfilePath)
if ([string]::IsNullOrWhiteSpace($NvimConfigPath)) {
    $NvimConfigPath = Join-Path $env:LOCALAPPDATA "nvim"
}
$NvimConfigPath = [System.IO.Path]::GetFullPath($NvimConfigPath)

$platformRoot = $PSScriptRoot
$nvimSource = Join-Path $platformRoot "settings\nvim"
$powerShellSource = Join-Path $platformRoot "settings\powershell"
$profileSource = Join-Path $powerShellSource "Microsoft.PowerShell_profile.ps1"
$themeSource = Join-Path $platformRoot "settings\oh-my-posh\illusi0n-dayfox.omp.json"
$profileDirectory = Split-Path $ProfilePath -Parent
$themeDestination = Join-Path $profileDirectory "illusi0n-dayfox.omp.json"

Write-Host ""
Write-Host "=== init_lua Windows configuration ===" -ForegroundColor Cyan
Write-Host "The declared desired state will be installed and verified." -ForegroundColor Gray

Write-Host ""
Write-Host "[1/8] Required tools" -ForegroundColor Yellow
$dependencyResults = @()
if ($SkipDependencyInstall) {
    Write-Host "  Dependency installation skipped by explicit request." -ForegroundColor Gray
} else {
    $dependencyInstaller = Join-Path $platformRoot "scripts\Install-Dependencies.ps1"
    if (-not (Test-Path -LiteralPath $dependencyInstaller)) {
        throw "Dependency installer not found: $dependencyInstaller"
    }
    $dependencyArguments = @{ PassThru = $true }
    if ($SkipClaudeCodeInstall) {
        $dependencyArguments.SkipClaudeCode = $true
    }
    if ($SkipOhMyPoshInstall) {
        $dependencyArguments.SkipOhMyPosh = $true
    }
    $dependencyResults = @(& $dependencyInstaller @dependencyArguments)
    $dependencyResults | Format-Table -AutoSize
}

Write-Host ""
Write-Host "[2/8] Neovim configuration" -ForegroundColor Yellow
$nvimResult = $null
if ($SkipNvimConfiguration) {
    Write-Host "  Neovim configuration synchronization skipped." -ForegroundColor Gray
} else {
    $nvimResult = Sync-ManagedTree -Source $nvimSource -Destination $NvimConfigPath -Label "Neovim configuration"
}

Write-Host ""
Write-Host "[3/8] Neovim plugins and Mason tools" -ForegroundColor Yellow
if ($SkipNvimConfiguration -or $SkipNvimPluginInstall) {
    Write-Host "  Neovim plugin installation skipped by explicit request." -ForegroundColor Gray
} else {
    $nvim = Get-Command nvim -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $nvim) {
        throw "Neovim is required to install the locked plugins but nvim is unavailable."
    }
    $oldXdgConfigHome = $env:XDG_CONFIG_HOME
    $oldNvimAppName = $env:NVIM_APPNAME
    try {
        $env:XDG_CONFIG_HOME = Split-Path $NvimConfigPath -Parent
        $env:NVIM_APPNAME = Split-Path $NvimConfigPath -Leaf
        & $nvim.Source --headless -i NONE -n "+Lazy! restore" "+Lazy! clean" "+qa"
        if ($LASTEXITCODE -ne 0) {
            throw "Neovim plugin synchronization failed with exit code $LASTEXITCODE."
        }
        & $nvim.Source --headless -i NONE -n "+MasonToolsInstallSync" "+qa"
        if ($LASTEXITCODE -ne 0) {
            throw "Mason tool synchronization failed with exit code $LASTEXITCODE."
        }
    } finally {
        $env:XDG_CONFIG_HOME = $oldXdgConfigHome
        $env:NVIM_APPNAME = $oldNvimAppName
    }
    Write-Host "  Locked Neovim plugins and Mason tools synchronized." -ForegroundColor Green
}

Write-Host ""
Write-Host "[4/8] Oh My Posh" -ForegroundColor Yellow
$ohMyPoshPath = Get-OhMyPoshPath
if ($ohMyPoshPath) {
    Write-Host "  Oh My Posh ready: $ohMyPoshPath" -ForegroundColor Green
} elseif ($SkipOhMyPoshInstall -or $SkipDependencyInstall) {
    Write-Host "  Oh My Posh installation skipped; verification will report its current state." -ForegroundColor Yellow
} else {
    throw "Oh My Posh is unavailable after the declared winget dependency installation."
}

Write-Host ""
Write-Host "[5/8] JetBrainsMono Nerd Font" -ForegroundColor Yellow
if (Test-JetBrainsMonoNerdFont) {
    Write-Host "  JetBrainsMono Nerd Font already installed." -ForegroundColor Green
} elseif ($SkipFontInstall) {
    Write-Host "  Font installation skipped; verification will report its current state." -ForegroundColor Yellow
} elseif ($ohMyPoshPath) {
    Write-Host "  Installing JetBrainsMono Nerd Font for the current user..." -ForegroundColor Gray
    & $ohMyPoshPath font install JetBrainsMono
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Font installer exited with code $LASTEXITCODE." -ForegroundColor Yellow
    } elseif (Test-JetBrainsMonoNerdFont) {
        Write-Host "  JetBrainsMono Nerd Font installed." -ForegroundColor Green
    } else {
        Write-Host "  Font installation finished; Windows may require sign-out before registry detection." -ForegroundColor Yellow
    }
} else {
    Write-Host "  JetBrainsMono Nerd Font was not installed because Oh My Posh is unavailable." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[6/8] PowerShell profile and Oh My Posh theme" -ForegroundColor Yellow
$profileResult = Sync-PowerShellProfile -Source $profileSource -Destination $ProfilePath
$themeResult = Sync-ManagedFile -Source $themeSource -Destination $themeDestination -Label "Oh My Posh theme"

Write-Host ""
Write-Host "[7/8] Windows Terminal portable settings" -ForegroundColor Yellow
$terminalResult = @()
$terminalError = $null
if ($SkipWindowsTerminalEnvironment) {
    Write-Host "  Windows Terminal synchronization skipped." -ForegroundColor Gray
} else {
    $terminalInstaller = Join-Path $platformRoot "scripts\Install-WindowsTerminalEnvironment.ps1"
    if (-not (Test-Path -LiteralPath $terminalInstaller)) {
        throw "Windows Terminal installer not found: $terminalInstaller"
    }
    try {
        $terminalResult = @(& $terminalInstaller -CreateIfMissing -PassThru)
    } catch {
        $terminalError = $_.Exception.Message
        Write-Host "  Windows Terminal was not changed: $terminalError" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "[8/8] Verification" -ForegroundColor Yellow
$verification = @()
if ($SkipVerification) {
    Write-Host "  Verification skipped." -ForegroundColor Gray
} else {
    $verifier = Join-Path $platformRoot "scripts\Test-TerminalEnvironment.ps1"
    if (-not (Test-Path -LiteralPath $verifier)) {
        throw "Terminal environment verifier not found: $verifier"
    }
    $verificationArguments = @{
        ProfilePath = $ProfilePath
        NvimConfigPath = $NvimConfigPath
        PassThru = $true
    }
    if ($SkipNvimConfiguration) {
        $verificationArguments.SkipNvimCheck = $true
    }
    if ($SkipDependencyInstall) {
        $verificationArguments.SkipToolChecks = $true
    }
    if ($SkipNvimPluginInstall) {
        $verificationArguments.SkipPluginChecks = $true
    }
    if ($SkipWindowsTerminalEnvironment) {
        $verificationArguments.SkipTerminalChecks = $true
    }
    $verification = @(& $verifier @verificationArguments)
    $verification | Format-Table -AutoSize
}

$verificationFailures = @($verification | Where-Object Status -eq "FAIL")
if ($verificationFailures.Count -gt 0) {
    throw "Required environment verification failed: $($verificationFailures.Check -join ', ')"
}

Write-Host ""
if ($partialRun) {
    Write-Host "=== init_lua Windows partial run finished; RESULT is not MATCHED ===" -ForegroundColor Yellow
} else {
    Write-Host "=== init_lua Windows configuration finished ===" -ForegroundColor Green
}
Write-Host "Close all Windows Terminal windows and reopen one to load the updated profile." -ForegroundColor Cyan

if ($PassThru) {
    [pscustomobject]@{
        DependencyResults  = @($dependencyResults)
        NvimConfigPath    = $NvimConfigPath
        NvimBackup        = if ($null -ne $nvimResult) { $nvimResult.BackupPath } else { $null }
        ProfilePath       = $ProfilePath
        ProfileBackup     = $profileResult.BackupPath
        ThemePath         = $themeDestination
        ThemeBackup       = $themeResult.BackupPath
        TerminalResults   = @($terminalResult)
        TerminalError     = $terminalError
        Verification      = @($verification)
        VerificationPassed = if ($SkipVerification) { $null } elseif ($partialRun) { $false } else { $verificationFailures.Count -eq 0 }
    }
}
