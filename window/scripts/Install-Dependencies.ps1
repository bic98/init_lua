[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [switch]$SkipOhMyPosh,

    [Parameter()]
    [switch]$SkipClaudeCode,

    [Parameter()]
    [switch]$PassThru
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$platformRoot = Split-Path $PSScriptRoot -Parent
$manifestPath = Join-Path $platformRoot "desired-state.json"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Desired-state manifest not found: $manifestPath"
}
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json -Depth 100
$results = [System.Collections.Generic.List[object]]::new()

function Refresh-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = @($machinePath, $userPath) | Where-Object { $_ } | Join-String -Separator ";"
}

function Get-ToolCommand {
    param([Parameter(Mandatory)][string]$Name)

    if ($Name -eq "npm") {
        $npmCommand = Get-Command npm.cmd -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($npmCommand) {
            return $npmCommand
        }
    }
    $commands = @(Get-Command $Name -All -ErrorAction SilentlyContinue)
    $command = $commands |
        Where-Object { $_.CommandType -in @("Application", "ExternalScript") } |
        Select-Object -First 1
    if (-not $command) {
        $command = $commands | Select-Object -First 1
    }
    if ($command) {
        return $command
    }
    return $null
}

function ConvertTo-NormalizedVersion {
    param([Parameter()][AllowNull()][string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }
    $match = [regex]::Match($Text, '\d+(?:\.\d+){1,3}')
    if (-not $match.Success) {
        return $null
    }
    try {
        return [version]$match.Value
    } catch {
        return $null
    }
}

function Get-ToolVersion {
    param([Parameter(Mandatory)][object]$Tool)

    if ($Tool.name -eq "Windows Terminal") {
        $terminalPackage = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($terminalPackage) {
            return [version]$terminalPackage.Version
        }
        return $null
    }

    $command = Get-ToolCommand -Name ([string]$Tool.command)
    if (-not $command) {
        return $null
    }
    $versionOutput = try {
        if ($Tool.name -eq "PowerShell") {
            & $command.Source -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>&1 |
                Select-Object -First 1
        } elseif ($Tool.name -eq "Oh My Posh") {
            & $command.Source version 2>&1 | Select-Object -First 1
        } else {
            & $command.Source --version 2>&1 | Select-Object -First 1
        }
    } catch {
        return $null
    }
    return ConvertTo-NormalizedVersion -Text ([string]$versionOutput)
}

function Test-VersionAtLeast {
    param(
        [Parameter()][AllowNull()][version]$Actual,
        [Parameter(Mandatory)][string]$Minimum
    )

    $required = ConvertTo-NormalizedVersion -Text $Minimum
    return $null -ne $Actual -and $null -ne $required -and $Actual -ge $required
}

function Test-WingetPackageInstalled {
    param([Parameter(Mandatory)][string]$PackageId)

    $output = @(& $winget.Source list `
        --id $PackageId `
        --exact `
        --accept-source-agreements `
        --disable-interactivity 2>&1)
    $exitCode = $LASTEXITCODE
    return $exitCode -eq 0 -and ($output -join "`n") -match [regex]::Escape($PackageId)
}

function Add-Result {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][string]$Detail
    )

    $results.Add([pscustomobject]@{ Name = $Name; Status = $Status; Detail = $Detail })
}

$winget = Get-Command winget -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $winget) {
    throw "Windows App Installer (winget) is required to install the declared Windows tools. Install App Installer, then rerun."
}

foreach ($tool in @($manifest.requiredTools | Where-Object manager -eq "winget")) {
    if ($SkipOhMyPosh -and $tool.name -eq "Oh My Posh") {
        Add-Result -Name $tool.name -Status "SKIPPED" -Detail "SkipOhMyPosh"
        continue
    }
    $existing = Get-ToolCommand -Name ([string]$tool.command)
    $installedVersion = Get-ToolVersion -Tool $tool
    $packageInstalled = Test-WingetPackageInstalled -PackageId ([string]$tool.packageId)
    $versionCurrent = Test-VersionAtLeast -Actual $installedVersion -Minimum ([string]$tool.minimumVersion)
    $commandAvailable = $null -ne $existing -or $tool.name -eq "Windows Terminal"
    if ($packageInstalled -and $commandAvailable -and $versionCurrent) {
        Add-Result -Name $tool.name -Status "PRESENT" -Detail "$installedVersion via $($tool.packageId)"
        continue
    }

    $wingetAction = if ($packageInstalled) { "upgrade" } else { "install" }
    $operation = if ($packageInstalled) { "Upgrade required init_lua dependency" } else { "Install required init_lua dependency" }
    if ($PSCmdlet.ShouldProcess($tool.packageId, $operation)) {
        $actionLabel = if ($wingetAction -eq "upgrade") { "Upgrading" } else { "Installing" }
        Write-Host "$actionLabel $($tool.name) ($($tool.packageId))..." -ForegroundColor Cyan
        & $winget.Source $wingetAction `
            --id $tool.packageId `
            --exact `
            --source winget `
            --accept-package-agreements `
            --accept-source-agreements `
            --disable-interactivity
        if ($LASTEXITCODE -ne 0) {
            throw "winget failed to $wingetAction $($tool.name) with exit code $LASTEXITCODE."
        }
        Refresh-ProcessPath
        $installed = Get-ToolCommand -Name ([string]$tool.command)
        $installedVersion = Get-ToolVersion -Tool $tool
        $packageInstalled = Test-WingetPackageInstalled -PackageId ([string]$tool.packageId)
        $commandAvailable = $null -ne $installed -or $tool.name -eq "Windows Terminal"
        if (-not $packageInstalled) {
            throw "$($tool.name) completed through winget but package '$($tool.packageId)' is not registered as installed."
        }
        if (-not $commandAvailable) {
            throw "$($tool.name) was installed but '$($tool.command)' is not available after refreshing PATH."
        }
        if (-not (Test-VersionAtLeast -Actual $installedVersion -Minimum ([string]$tool.minimumVersion))) {
            throw "$($tool.name) version '$installedVersion' is below required version $($tool.minimumVersion) after $wingetAction."
        }
        $resultStatus = if ($wingetAction -eq "upgrade") { "UPGRADED" } else { "INSTALLED" }
        Add-Result -Name $tool.name -Status $resultStatus -Detail "$installedVersion via $($tool.packageId)"
    } else {
        Add-Result -Name $tool.name -Status "SKIPPED" -Detail "ShouldProcess declined"
    }
}

foreach ($tool in @($manifest.requiredTools | Where-Object manager -eq "bundled")) {
    $bundledCommand = Get-ToolCommand -Name ([string]$tool.command)
    $bundledVersion = Get-ToolVersion -Tool $tool
    if (-not $bundledCommand -or
        -not (Test-VersionAtLeast -Actual $bundledVersion -Minimum ([string]$tool.minimumVersion))) {
        throw "$($tool.name) was not provided at the required version by $($tool.providedBy)."
    }
    Add-Result -Name $tool.name -Status "PRESENT" -Detail "$bundledVersion via $($tool.providedBy)"
}

if (-not $SkipClaudeCode) {
    $claude = Get-ToolCommand -Name "claude"
    $claudeTool = @($manifest.requiredTools | Where-Object name -eq "Claude Code" | Select-Object -First 1)
    if ($claudeTool.Count -ne 1) {
        throw "Claude Code is missing from the desired-state manifest."
    }
    $claudeVersion = if ($claude) {
        ConvertTo-NormalizedVersion -Text ([string](& $claude.Source --version 2>&1 | Select-Object -First 1))
    } else {
        $null
    }
    if ($claude -and (Test-VersionAtLeast -Actual $claudeVersion -Minimum ([string]$claudeTool[0].minimumVersion))) {
        Add-Result -Name "Claude Code" -Status "PRESENT" -Detail "$claudeVersion @ $($claude.Source)"
    } else {
        $claudeInstaller = [string]$claudeTool[0].installer
        if ($claudeInstaller -ne "https://claude.ai/install.ps1") {
            throw "Unexpected Claude Code installer in desired-state: $claudeInstaller"
        }
        if ($PSCmdlet.ShouldProcess($claudeInstaller, "Install or update the native Claude Code CLI")) {
            Write-Host "Installing the native Claude Code CLI..." -ForegroundColor Cyan
            $installerSource = Invoke-RestMethod -Uri $claudeInstaller
            $installerBlock = [scriptblock]::Create([string]$installerSource)
            & $installerBlock
            Refresh-ProcessPath
            $claude = Get-ToolCommand -Name "claude"
            if (-not $claude) {
                throw "Claude Code was installed but the 'claude' command is unavailable after refreshing PATH."
            }
            $claudeVersion = ConvertTo-NormalizedVersion -Text ([string](& $claude.Source --version 2>&1 | Select-Object -First 1))
            if (-not (Test-VersionAtLeast -Actual $claudeVersion -Minimum ([string]$claudeTool[0].minimumVersion))) {
                throw "Claude Code version '$claudeVersion' is below required version $($claudeTool[0].minimumVersion) after native installation."
            }
            Add-Result -Name "Claude Code" -Status "INSTALLED" -Detail "$claudeVersion @ $($claude.Source)"
        } else {
            Add-Result -Name "Claude Code" -Status "SKIPPED" -Detail "ShouldProcess declined"
        }
    }
} else {
    Add-Result -Name "Claude Code" -Status "SKIPPED" -Detail "SkipClaudeCode"
}

if ($PassThru) {
    $results
} else {
    $results | Format-Table -AutoSize
}
