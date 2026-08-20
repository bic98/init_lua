[CmdletBinding()]
param(
    [Parameter()]
    [string]$SettingsPath,

    [Parameter()]
    [string]$ProfilePath = $PROFILE,

    [Parameter()]
    [string]$NvimConfigPath,

    [Parameter()]
    [string]$AppearancePath = (Join-Path (Split-Path $PSScriptRoot -Parent) "settings\windows-terminal\appearance.json"),

    [Parameter()]
    [string]$KeybindingsPath = (Join-Path (Split-Path $PSScriptRoot -Parent) "settings\windows-terminal\keybindings.json"),

    [Parameter()]
    [switch]$SkipTerminalChecks,

    [Parameter()]
    [switch]$SkipNvimCheck,

    [Parameter()]
    [switch]$SkipToolChecks,

    [Parameter()]
    [switch]$SkipPluginChecks,

    [Parameter()]
    [string]$ManifestPath = (Join-Path (Split-Path $PSScriptRoot -Parent) "desired-state.json"),

    [Parameter()]
    [switch]$Strict,

    [Parameter()]
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [bool]$Passed,

        [Parameter(Mandatory)]
        [string]$Detail
    )

    $checks.Add([pscustomobject]@{
        Status = if ($Passed) { "PASS" } else { "FAIL" }
        Check = $Name
        Detail = $Detail
    })
}

function Get-NestedValue {
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string[]]$Path
    )

    $current = $InputObject
    foreach ($name in $Path) {
        if ($null -eq $current) {
            return $null
        }
        $property = $current.PSObject.Properties[$name]
        if ($null -eq $property) {
            return $null
        }
        $current = $property.Value
    }
    return $current
}

function Normalize-KeyChord {
    param(
        [Parameter(Mandatory)]
        [string]$Chord
    )

    $normalized = foreach ($token in $Chord.ToLowerInvariant().Split("+")) {
        switch ($token) {
            "minus" { "-" }
            "comma" { "," }
            "backslash" { "\" }
            default { $token }
        }
    }
    return $normalized -join "+"
}

function Get-KeyList {
    param(
        [Parameter(Mandatory)]
        [object]$Binding
    )

    $keys = Get-NestedValue -InputObject $Binding -Path @("keys")
    if ($null -eq $keys) {
        return @()
    }
    return @($keys | ForEach-Object { Normalize-KeyChord -Chord ([string]$_) })
}

function Test-KeyListEqual {
    param(
        [Parameter(Mandatory)]
        [string[]]$Left,

        [Parameter(Mandatory)]
        [string[]]$Right
    )

    if ($Left.Count -ne $Right.Count) {
        return $false
    }
    for ($index = 0; $index -lt $Left.Count; $index++) {
        if ($Left[$index] -ne $Right[$index]) {
            return $false
        }
    }
    return $true
}

function ConvertTo-CanonicalJson {
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    return ConvertTo-Json -InputObject $Value -Depth 100 -Compress
}

function Test-JsonEquivalent {
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Left,

        [Parameter()]
        [AllowNull()]
        [object]$Right
    )

    return (ConvertTo-CanonicalJson -Value $Left) -eq (ConvertTo-CanonicalJson -Value $Right)
}

function Test-ObjectContains {
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Target,

        [Parameter()]
        [AllowNull()]
        [object]$Source
    )

    if ($null -eq $Source) {
        return $null -eq $Target
    }
    if ($Source -is [pscustomobject]) {
        if ($null -eq $Target) {
            return $false
        }
        foreach ($property in $Source.PSObject.Properties) {
            $targetProperty = $Target.PSObject.Properties[$property.Name]
            if ($null -eq $targetProperty -or
                -not (Test-ObjectContains -Target $targetProperty.Value -Source $property.Value)) {
                return $false
            }
        }
        return $true
    }
    if ($Source -is [System.Collections.IEnumerable] -and $Source -isnot [string]) {
        return Test-JsonEquivalent -Left $Target -Right $Source
    }
    return $Target -eq $Source
}

function Get-ManagedProfileBlock {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    $content = [System.IO.File]::ReadAllText($Path)
    $match = [regex]::Match(
        $content,
        '(?ms)^[ \t]*# >>> init_lua terminal environment >>>.*?^[ \t]*# <<< init_lua terminal environment <<<[ \t]*'
    )
    if (-not $match.Success) {
        return $null
    }
    return (($match.Value -replace "`r`n?", "`n").Trim())
}

function Test-CodexAdaptiveThemeGuard {
    param(
        [Parameter()]
        [AllowNull()]
        [string]$ProfileBlock,

        [Parameter()]
        [AllowNull()]
        [object]$Manifest
    )

    if ([string]::IsNullOrWhiteSpace($ProfileBlock)) {
        return $false
    }

    $compatibilityPath = @("terminalCompatibility", "codexTheme")
    $mode = Get-NestedValue -InputObject $Manifest -Path ($compatibilityPath + "mode")
    $detectBeforeLaunch = Get-NestedValue -InputObject $Manifest -Path ($compatibilityPath + "detectBeforeLaunch")
    $lightAction = Get-NestedValue -InputObject $Manifest -Path ($compatibilityPath + "lightAction")
    $darkAction = Get-NestedValue -InputObject $Manifest -Path ($compatibilityPath + "darkAction")
    $unknownAction = Get-NestedValue -InputObject $Manifest -Path ($compatibilityPath + "unknownAction")
    $overrideVariable = Get-NestedValue -InputObject $Manifest -Path ($compatibilityPath + "overrideVariable")
    $preserveConfiguredTheme = Get-NestedValue -InputObject $Manifest -Path ($compatibilityPath + "preserveConfiguredTheme")
    $restoreEnvironment = Get-NestedValue -InputObject $Manifest -Path ($compatibilityPath + "restorePreviousEnvironment")
    $forbidGlobalNoColor = Get-NestedValue -InputObject $Manifest -Path ($compatibilityPath + "globalNoColorForbidden")
    if ($mode -ne "adaptive-scoped-no-color" -or
        -not [bool]$detectBeforeLaunch -or
        $lightAction -ne "scoped-no-color" -or
        $darkAction -ne "preserve-native-colors" -or
        $unknownAction -ne "preserve-native-colors" -or
        $overrideVariable -ne "INIT_LUA_TERMINAL_APPEARANCE" -or
        -not [bool]$preserveConfiguredTheme -or
        -not [bool]$restoreEnvironment -or
        -not [bool]$forbidGlobalNoColor) {
        return $false
    }

    foreach ($requiredFragment in @(
        "function global:Get-InitLuaTerminalAppearance",
        "function global:codex",
        "# init_lua Codex adaptive-theme wrapper",
        "Get-Command codex -All",
        "Get-InitLuaTerminalAppearance",
        "if (`$__initLuaTerminalAppearance -ne 'Light')",
        "`$env:NO_COLOR = '1'",
        "Remove-Item Env:NO_COLOR",
        "`$env:NO_COLOR = `$__initLuaPreviousNoColor"
    )) {
        if (-not $ProfileBlock.Contains($requiredFragment)) {
            return $false
        }
    }

    return $true
}

function Test-FileMatches {
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source) -or -not (Test-Path -LiteralPath $Destination)) {
        return $false
    }
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Source).Hash -eq
        (Get-FileHash -Algorithm SHA256 -LiteralPath $Destination).Hash
}

function Test-ManagedTreeMatches {
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Container) -or
        -not (Test-Path -LiteralPath $Destination -PathType Container)) {
        return $false
    }
    foreach ($sourceFile in Get-ChildItem -LiteralPath $Source -File -Recurse) {
        $relativePath = [System.IO.Path]::GetRelativePath($Source, $sourceFile.FullName)
        $targetFile = Join-Path $Destination $relativePath
        if (-not (Test-Path -LiteralPath $targetFile -PathType Leaf) -or
            (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash -ne
                (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256).Hash) {
            return $false
        }
    }
    return $true
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

function Get-DeclaredToolState {
    param([Parameter(Mandatory)][object]$Tool)

    if ($Tool.name -eq "PowerShell") {
        return [pscustomobject]@{ Found = $true; Version = $PSVersionTable.PSVersion; Detail = $PSVersionTable.PSVersion.ToString() }
    }
    if ($Tool.name -eq "Windows Terminal") {
        $package = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue | Select-Object -First 1
        return [pscustomobject]@{
            Found = $null -ne $package
            Version = if ($package) { [version]$package.Version } else { $null }
            Detail = if ($package) { $package.Version.ToString() } else { "Appx package not found" }
        }
    }

    $commands = if ($Tool.name -eq "npm") {
        @(Get-Command npm.cmd -CommandType Application -ErrorAction SilentlyContinue)
    } else {
        @(Get-Command ([string]$Tool.command) -All -ErrorAction SilentlyContinue)
    }
    $command = $commands |
        Where-Object { $_.CommandType -in @("Application", "ExternalScript") } |
        Select-Object -First 1
    if (-not $command) {
        $command = $commands | Select-Object -First 1
    }
    if (-not $command) {
        return [pscustomobject]@{ Found = $false; Version = $null; Detail = "command not found" }
    }
    $versionOutput = try {
        if ($Tool.name -eq "Oh My Posh") {
            (& $command.Source version 2>&1 | Select-Object -First 1).ToString()
        } else {
            (& $command.Source --version 2>&1 | Select-Object -First 1).ToString()
        }
    } catch {
        $_.Exception.Message
    }
    return [pscustomobject]@{
        Found = $true
        Version = ConvertTo-NormalizedVersion -Text $versionOutput
        Detail = "$versionOutput @ $($command.Source)"
    }
}

function Get-DetectedSettingsPath {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json"),
        (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"),
        (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalCanary_8wekyb3d8bbwe\LocalState\settings.json")
    )
    return $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

$platformRoot = Split-Path $PSScriptRoot -Parent
$ProfilePath = [System.IO.Path]::GetFullPath($ProfilePath)
if ([string]::IsNullOrWhiteSpace($NvimConfigPath)) {
    $NvimConfigPath = Join-Path $env:LOCALAPPDATA "nvim"
}
$NvimConfigPath = [System.IO.Path]::GetFullPath($NvimConfigPath)
$nvimSource = Join-Path $platformRoot "settings\nvim"
$profileSource = Join-Path $platformRoot "settings\powershell\Microsoft.PowerShell_profile.ps1"
$themeSource = Join-Path $platformRoot "settings\oh-my-posh\illusi0n-dayfox.omp.json"
$themeDestination = Join-Path (Split-Path $ProfilePath -Parent) "illusi0n-dayfox.omp.json"
$manifest = if (Test-Path -LiteralPath $ManifestPath -PathType Leaf) {
    Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json -Depth 100
} else {
    $null
}

Add-Check -Name "Desired-state manifest" `
    -Passed ($null -ne $manifest) `
    -Detail $ManifestPath

if (-not $SkipNvimCheck) {
    Add-Check -Name "Neovim configuration" `
        -Passed (Test-ManagedTreeMatches -Source $nvimSource -Destination $NvimConfigPath) `
        -Detail $NvimConfigPath
}

if (-not $SkipToolChecks -and $null -ne $manifest) {
    $wingetListingSucceeded = $false
    $wingetListingText = ""
    $declaredWingetTools = @($manifest.requiredTools | Where-Object manager -eq "winget")
    if ($declaredWingetTools.Count -gt 0) {
        $wingetCommand = Get-Command winget -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($wingetCommand) {
            $wingetListing = @(& $wingetCommand.Source list `
                --accept-source-agreements `
                --disable-interactivity 2>&1)
            $wingetListingSucceeded = $LASTEXITCODE -eq 0
            $wingetListingText = $wingetListing -join "`n"
        }
    }

    foreach ($tool in @($manifest.requiredTools)) {
        $state = Get-DeclaredToolState -Tool $tool
        $minimum = ConvertTo-NormalizedVersion -Text ([string]$tool.minimumVersion)
        $versionMatches = $state.Found -and $null -ne $state.Version -and
            ($null -eq $minimum -or $state.Version -ge $minimum)
        $installMethodMatches = $true
        $installMethodDetail = ""
        if ($tool.manager -eq "winget") {
            $packagePattern = "(?im)(?:^|\s)$([regex]::Escape([string]$tool.packageId))(?:\s|$)"
            $installMethodMatches = $wingetListingSucceeded -and $wingetListingText -match $packagePattern
            $installMethodDetail = "; winget $($tool.packageId): $(if ($installMethodMatches) { 'installed' } else { 'missing' })"
        } elseif ($tool.manager -eq "native" -and $tool.name -eq "Claude Code") {
            $nativeCommand = Get-Command claude.exe -CommandType Application -ErrorAction SilentlyContinue |
                Select-Object -First 1
            $expectedClaudePath = Join-Path $env:USERPROFILE ".local\bin\claude.exe"
            $installMethodMatches = $null -ne $nativeCommand -and
                [System.IO.Path]::GetFullPath($nativeCommand.Source) -eq [System.IO.Path]::GetFullPath($expectedClaudePath)
            $installMethodDetail = "; native path: $expectedClaudePath"
        }
        Add-Check -Name $tool.name `
            -Passed ($versionMatches -and $installMethodMatches) `
            -Detail "$($state.Detail); required >= $($tool.minimumVersion)$installMethodDetail"
    }

    $nativeClaude = Get-Command claude.exe -CommandType Application -ErrorAction SilentlyContinue |
        Where-Object Source -eq (Join-Path $env:USERPROFILE ".local\bin\claude.exe") |
        Select-Object -First 1
    $claudeAuthenticated = $false
    if ($nativeClaude) {
        & $nativeClaude.Source auth status *> $null
        $claudeAuthenticated = $LASTEXITCODE -eq 0
    }
    Add-Check -Name "Claude Code authentication" `
        -Passed $claudeAuthenticated `
        -Detail $(if ($claudeAuthenticated) { "logged in" } else { "run: claude auth login" })

    Add-Check -Name "JetBrainsMono Nerd Font" `
        -Passed (Test-JetBrainsMonoNerdFont) `
        -Detail "Windows font registry"
}

$sourceProfileBlock = Get-ManagedProfileBlock -Path $profileSource
$installedProfileBlock = Get-ManagedProfileBlock -Path $ProfilePath
Add-Check -Name "PowerShell profile block" `
    -Passed ($null -ne $sourceProfileBlock -and $sourceProfileBlock -eq $installedProfileBlock) `
    -Detail $ProfilePath

Add-Check -Name "Codex adaptive-theme compatibility" `
    -Passed (Test-CodexAdaptiveThemeGuard -ProfileBlock $installedProfileBlock -Manifest $manifest) `
    -Detail "detect Light/Dark/Unknown; NO_COLOR only for detected Light"

Add-Check -Name "Oh My Posh theme" `
    -Passed (Test-FileMatches -Source $themeSource -Destination $themeDestination) `
    -Detail $themeDestination

if (-not $SkipPluginChecks) {
    $sourceLock = Join-Path $nvimSource "lazy-lock.json"
    $installedLock = Join-Path $NvimConfigPath "lazy-lock.json"
    $lockMatches = Test-FileMatches -Source $sourceLock -Destination $installedLock
    Add-Check -Name "Neovim plugin lock" `
        -Passed $lockMatches `
        -Detail $installedLock

    if ($lockMatches) {
        $lockedPlugins = Get-Content -Raw -LiteralPath $sourceLock | ConvertFrom-Json -AsHashtable
        $appName = Split-Path $NvimConfigPath -Leaf
        $dataRoot = Join-Path $env:LOCALAPPDATA "$appName-data"
        $lazyRoot = Join-Path $dataRoot "lazy"
        $gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
        $pluginMismatches = [System.Collections.Generic.List[string]]::new()
        foreach ($entry in @($lockedPlugins.GetEnumerator() | Sort-Object Key)) {
            $pluginPath = Join-Path $lazyRoot ([string]$entry.Key)
            if (-not (Test-Path -LiteralPath $pluginPath -PathType Container)) {
                $pluginMismatches.Add("$($entry.Key) (missing)")
                continue
            }
            if (-not $gitCommand) {
                $pluginMismatches.Add("$($entry.Key) (Git unavailable)")
                continue
            }
            $actualCommit = [string](& $gitCommand.Source -C $pluginPath rev-parse HEAD 2>$null)
            if ($LASTEXITCODE -ne 0 -or
                $actualCommit.Trim() -ne [string]$entry.Value.commit) {
                $pluginMismatches.Add("$($entry.Key) (commit mismatch)")
                continue
            }
            $worktreeChanges = @(@(& $gitCommand.Source -C $pluginPath status --porcelain 2>$null) |
                Where-Object { $_ -notmatch '^\?\? doc/tags$' })
            if ($LASTEXITCODE -ne 0 -or $worktreeChanges.Count -gt 0) {
                $pluginMismatches.Add("$($entry.Key) (dirty worktree)")
            }
        }
        Add-Check -Name "Neovim locked plugins" `
            -Passed ($pluginMismatches.Count -eq 0) `
            -Detail $(if ($pluginMismatches.Count -eq 0) {
                "$($lockedPlugins.Count) plugins at locked commits"
            } else {
                $pluginMismatches -join ", "
            })
    } else {
        Add-Check -Name "Neovim locked plugins" -Passed $false -Detail "lockfile mismatch"
    }

    $masonRoot = Join-Path $env:LOCALAPPDATA "$(Split-Path $NvimConfigPath -Leaf)-data\mason\packages"
    $requiredMasonPackages = if ($null -ne $manifest) { @($manifest.neovim.masonPackages) } else { @() }
    $missingMasonPackages = @($requiredMasonPackages | Where-Object {
        $packageRoot = Join-Path $masonRoot $_
        -not (Test-Path -LiteralPath $packageRoot -PathType Container) -or
            -not (Test-Path -LiteralPath (Join-Path $packageRoot "mason-receipt.json") -PathType Leaf)
    })
    Add-Check -Name "Mason tools" `
        -Passed ($missingMasonPackages.Count -eq 0) `
        -Detail $(if ($missingMasonPackages.Count -eq 0) { "$($requiredMasonPackages.Count) packages" } else { "missing: $($missingMasonPackages -join ', ')" })
}

if (-not $SkipTerminalChecks) {
    if (-not (Test-Path -LiteralPath $AppearancePath) -or -not (Test-Path -LiteralPath $KeybindingsPath)) {
        throw "Portable Windows Terminal source files are missing."
    }

    $appearance = Get-Content -Raw -LiteralPath $AppearancePath | ConvertFrom-Json -Depth 100
    $keySource = Get-Content -Raw -LiteralPath $KeybindingsPath | ConvertFrom-Json -Depth 100
    $resolvedSettingsPath = if ($SettingsPath) { $SettingsPath } else { Get-DetectedSettingsPath }
    $settings = $null
    $settingsDetail = if ($resolvedSettingsPath) { $resolvedSettingsPath } else { "settings.json not found" }
    if ($resolvedSettingsPath -and (Test-Path -LiteralPath $resolvedSettingsPath)) {
        try {
            $settings = Get-Content -Raw -LiteralPath $resolvedSettingsPath | ConvertFrom-Json -Depth 100
        } catch {
            $settingsDetail = "invalid settings.json: $($_.Exception.Message)"
        }
    }

    Add-Check -Name "Windows Terminal settings" `
        -Passed ($null -ne $settings) `
        -Detail $settingsDetail

    if ($null -ne $settings) {
        $reservedProperties = @("`$schema", "profiles", "schemes", "themes", "actions", "keybindings")
        $appearanceMatches = $true
        foreach ($property in $appearance.PSObject.Properties) {
            if ($reservedProperties -contains $property.Name) {
                continue
            }
            $targetValue = Get-NestedValue -InputObject $settings -Path @($property.Name)
            if (-not (Test-ObjectContains -Target $targetValue -Source $property.Value)) {
                $appearanceMatches = $false
                break
            }
        }

        $settingsDefaults = Get-NestedValue -InputObject $settings -Path @("profiles", "defaults")
        $appearanceDefaults = Get-NestedValue -InputObject $appearance -Path @("profiles", "defaults")
        $appearanceMatches = $appearanceMatches -and
            (Test-ObjectContains -Target $settingsDefaults -Source $appearanceDefaults)

        Add-Check -Name "Terminal appearance" `
            -Passed $appearanceMatches `
            -Detail "$($appearanceDefaults.colorScheme) + $($appearanceDefaults.font.face) + $($appearance.theme)"

        $settingsProfiles = @(
            (Get-NestedValue -InputObject $settings -Path @("profiles", "list")) |
                Where-Object { $null -ne $_ }
        )
        $sourceProfiles = @(Get-NestedValue -InputObject $appearance -Path @("profiles", "list"))
        $profilesMatch = $true
        foreach ($sourceProfile in $sourceProfiles) {
            $matches = @($settingsProfiles | Where-Object {
                (Get-NestedValue -InputObject $_ -Path @("guid")) -eq $sourceProfile.guid
            })
            if ($matches.Count -ne 1 -or
                -not (Test-ObjectContains -Target $matches[0] -Source $sourceProfile)) {
                $profilesMatch = $false
                break
            }
        }
        $defaultSourceProfile = @($sourceProfiles | Where-Object guid -eq $appearance.defaultProfile | Select-Object -First 1)
        $defaultProfileMatches =
            (Get-NestedValue -InputObject $settings -Path @("defaultProfile")) -eq $appearance.defaultProfile -and
            $defaultSourceProfile.Count -eq 1 -and
            $profilesMatch
        Add-Check -Name "Default PowerShell profile" `
            -Passed $defaultProfileMatches `
            -Detail $(if ($defaultSourceProfile.Count -eq 1) { $defaultSourceProfile[0].name } else { $appearance.defaultProfile })

        $settingsSchemes = @(
            (Get-NestedValue -InputObject $settings -Path @("schemes")) |
                Where-Object { $null -ne $_ }
        )
        $allSchemesPresent = @($appearance.schemes | Where-Object {
            $sourceScheme = $_
            $matches = @($settingsSchemes | Where-Object name -eq $sourceScheme.name)
            $matches.Count -ne 1 -or -not (Test-ObjectContains -Target $matches[0] -Source $sourceScheme)
        }).Count -eq 0
        Add-Check -Name "Terminal color scheme" `
            -Passed $allSchemesPresent `
            -Detail "$(@($appearance.schemes).Count) managed scheme"

        $settingsActions = @(
            (Get-NestedValue -InputObject $settings -Path @("actions")) |
                Where-Object { $null -ne $_ }
        )
        $actionsMatch = @($keySource.actions | Where-Object {
            $sourceAction = $_
            $matches = @($settingsActions | Where-Object id -eq $sourceAction.id)
            $matches.Count -ne 1 -or -not (Test-ObjectContains -Target $matches[0] -Source $sourceAction)
        }).Count -eq 0

        $settingsKeybindings = @(
            (Get-NestedValue -InputObject $settings -Path @("keybindings")) |
                Where-Object { $null -ne $_ }
        )
        $missingBindings = [System.Collections.Generic.List[string]]::new()
        foreach ($sourceBinding in @($keySource.keybindings)) {
            $sourceKeys = @(Get-KeyList -Binding $sourceBinding)
            $matching = @($settingsKeybindings | Where-Object {
                (Get-NestedValue -InputObject $_ -Path @("id")) -eq $sourceBinding.id -and
                (Test-KeyListEqual -Left @(Get-KeyList -Binding $_) -Right $sourceKeys)
            })
            if ($matching.Count -ne 1) {
                $missingBindings.Add($sourceKeys -join ",")
            }
        }
        Add-Check -Name "Terminal keybindings" `
            -Passed ($actionsMatch -and $missingBindings.Count -eq 0) `
            -Detail $(if ($missingBindings.Count -eq 0) {
                "$(@($keySource.keybindings).Count) bindings"
            } else {
                "missing: $($missingBindings -join ', ')"
            })
    }
}

if ($PassThru) {
    $checks
} else {
    $checks | Format-Table -AutoSize
}

$failures = @($checks | Where-Object Status -eq "FAIL")
if ($Strict -and $failures.Count -gt 0) {
    throw "Terminal environment verification failed: $($failures.Check -join ', ')"
}
