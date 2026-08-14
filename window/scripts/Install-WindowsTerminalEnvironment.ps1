[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [string[]]$SettingsPath,

    [Parameter()]
    [string]$AppearancePath = (Join-Path (Split-Path $PSScriptRoot -Parent) "settings\windows-terminal\appearance.json"),

    [Parameter()]
    [string]$KeybindingsPath = (Join-Path (Split-Path $PSScriptRoot -Parent) "settings\windows-terminal\keybindings.json"),

    [Parameter()]
    [switch]$KeybindingsOnly,

    [Parameter()]
    [switch]$CreateIfMissing,

    [Parameter()]
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-PropertyValue {
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Copy-JsonValue {
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return $null
    }

    return $Value | ConvertTo-Json -Depth 100 -Compress | ConvertFrom-Json -Depth 100
}

function Set-PropertyValue {
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $InputObject.PSObject.Properties[$Name]) {
        $InputObject | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
        return
    }

    $InputObject.$Name = $Value
}

function Merge-ObjectProperties {
    param(
        [Parameter(Mandatory)]
        [object]$Target,

        [Parameter(Mandatory)]
        [object]$Source
    )

    foreach ($property in $Source.PSObject.Properties) {
        $sourceValue = $property.Value
        $targetProperty = $Target.PSObject.Properties[$property.Name]

        if (
            $null -ne $targetProperty -and
            $sourceValue -is [pscustomobject] -and
            $targetProperty.Value -is [pscustomobject]
        ) {
            Merge-ObjectProperties -Target $targetProperty.Value -Source $sourceValue
            continue
        }

        Set-PropertyValue -InputObject $Target -Name $property.Name -Value (Copy-JsonValue -Value $sourceValue)
    }
}

function Normalize-KeyChord {
    param(
        [Parameter(Mandatory)]
        [string]$Chord
    )

    $tokens = $Chord.ToLowerInvariant().Split("+")
    $normalized = foreach ($token in $tokens) {
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

    $keys = Get-PropertyValue -InputObject $Binding -Name "keys"
    if ($null -eq $keys) {
        return @()
    }

    return @($keys | ForEach-Object { Normalize-KeyChord -Chord ([string]$_) })
}

function Set-ArrayProperty {
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [object[]]$Value
    )

    Set-PropertyValue -InputObject $InputObject -Name $Name -Value @($Value)
}

function Merge-NamedItems {
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Existing,

        [Parameter(Mandatory)]
        [object[]]$Source,

        [Parameter(Mandatory)]
        [string]$IdentityProperty
    )

    $sourceNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $Source) {
        $identity = [string](Get-PropertyValue -InputObject $item -Name $IdentityProperty)
        if ([string]::IsNullOrWhiteSpace($identity)) {
            throw "Every managed item must have '$IdentityProperty'."
        }
        $null = $sourceNames.Add($identity)
    }

    $merged = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $Existing) {
        if ($null -eq $item) {
            continue
        }
        $identity = [string](Get-PropertyValue -InputObject $item -Name $IdentityProperty)
        if (-not [string]::IsNullOrWhiteSpace($identity) -and $sourceNames.Contains($identity)) {
            continue
        }
        $merged.Add($item)
    }
    foreach ($item in $Source) {
        $merged.Add((Copy-JsonValue -Value $item))
    }

    return @($merged)
}

function Merge-ProfileItems {
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Existing,

        [Parameter(Mandatory)]
        [object[]]$Source
    )

    $sourceByGuid = [System.Collections.Generic.Dictionary[string, object]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $sourceByName = [System.Collections.Generic.Dictionary[string, object]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    foreach ($profile in $Source) {
        $guid = [string](Get-PropertyValue -InputObject $profile -Name "guid")
        $name = [string](Get-PropertyValue -InputObject $profile -Name "name")
        if ([string]::IsNullOrWhiteSpace($guid) -or [string]::IsNullOrWhiteSpace($name)) {
            throw "Every managed profile must have a guid and name."
        }
        if ($sourceByGuid.ContainsKey($guid) -or $sourceByName.ContainsKey($name)) {
            throw "Managed profile identities must be unique: $name ($guid)"
        }
        $sourceByGuid.Add($guid, $profile)
        $sourceByName.Add($name, $profile)
    }

    $existingGuids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($profile in $Existing) {
        if ($null -eq $profile) {
            continue
        }
        $guid = [string](Get-PropertyValue -InputObject $profile -Name "guid")
        if (-not [string]::IsNullOrWhiteSpace($guid)) {
            $null = $existingGuids.Add($guid)
        }
    }

    $handledGuids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $merged = [System.Collections.Generic.List[object]]::new()
    foreach ($profile in $Existing) {
        if ($null -eq $profile) {
            continue
        }
        $guid = [string](Get-PropertyValue -InputObject $profile -Name "guid")
        $name = [string](Get-PropertyValue -InputObject $profile -Name "name")
        $sourceProfile = $null
        if (-not [string]::IsNullOrWhiteSpace($guid) -and $sourceByGuid.ContainsKey($guid)) {
            $sourceProfile = $sourceByGuid[$guid]
        } elseif (-not [string]::IsNullOrWhiteSpace($name) -and $sourceByName.ContainsKey($name)) {
            $candidate = $sourceByName[$name]
            $candidateGuid = [string](Get-PropertyValue -InputObject $candidate -Name "guid")
            if (-not $existingGuids.Contains($candidateGuid)) {
                $sourceProfile = $candidate
            }
        }

        if ($sourceProfile) {
            $sourceGuid = [string](Get-PropertyValue -InputObject $sourceProfile -Name "guid")
            if ($handledGuids.Contains($sourceGuid)) {
                $merged.Add($profile)
                continue
            }
            $profileCopy = Copy-JsonValue -Value $profile
            Merge-ObjectProperties -Target $profileCopy -Source $sourceProfile
            $merged.Add($profileCopy)
            $null = $handledGuids.Add($sourceGuid)
            continue
        }
        $merged.Add($profile)
    }
    foreach ($profile in $Source) {
        $guid = [string](Get-PropertyValue -InputObject $profile -Name "guid")
        if (-not $handledGuids.Contains($guid)) {
            $merged.Add((Copy-JsonValue -Value $profile))
        }
    }

    return @($merged)
}

function Get-TerminalCandidates {
    return @(
        [pscustomobject]@{
            Path = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
            PackageName = "Microsoft.WindowsTerminal"
        },
        [pscustomobject]@{
            Path = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json"
            PackageName = $null
        },
        [pscustomobject]@{
            Path = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
            PackageName = "Microsoft.WindowsTerminalPreview"
        },
        [pscustomobject]@{
            Path = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalCanary_8wekyb3d8bbwe\LocalState\settings.json"
            PackageName = "Microsoft.WindowsTerminalCanary"
        }
    )
}

function Get-DefaultSettingsPath {
    param(
        [Parameter()]
        [switch]$AllowMissing
    )

    $candidates = @(Get-TerminalCandidates)
    $existing = $candidates | Where-Object { Test-Path -LiteralPath $_.Path } | Select-Object -First 1
    if ($existing) {
        return $existing.Path
    }

    if (-not $AllowMissing) {
        return $null
    }

    foreach ($candidate in $candidates) {
        if ($null -eq $candidate.PackageName) {
            if (Test-Path -LiteralPath (Split-Path $candidate.Path -Parent)) {
                return $candidate.Path
            }
            continue
        }

        if (Get-AppxPackage -Name $candidate.PackageName -ErrorAction SilentlyContinue) {
            return $candidate.Path
        }
    }

    return $null
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw "PowerShell 7 or later is required. Run the repository install.ps1 bootstrap first."
}

foreach ($requiredPath in @($KeybindingsPath, $(if (-not $KeybindingsOnly) { $AppearancePath }))) {
    if (-not [string]::IsNullOrWhiteSpace($requiredPath) -and -not (Test-Path -LiteralPath $requiredPath)) {
        throw "Portable Windows Terminal source not found: $requiredPath"
    }
}

$keySource = Get-Content -Raw -LiteralPath $KeybindingsPath | ConvertFrom-Json -Depth 100
$sourceActions = @($keySource.actions)
$sourceKeybindings = @($keySource.keybindings)
$appearanceSource = if ($KeybindingsOnly) {
    $null
} else {
    Get-Content -Raw -LiteralPath $AppearancePath | ConvertFrom-Json -Depth 100
}

$sourceActionIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($action in $sourceActions) {
    $id = [string](Get-PropertyValue -InputObject $action -Name "id")
    if ([string]::IsNullOrWhiteSpace($id)) {
        throw "Every source action must have an id."
    }
    $null = $sourceActionIds.Add($id)
}

$sourceKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($binding in $sourceKeybindings) {
    foreach ($key in (Get-KeyList -Binding $binding)) {
        if (-not $sourceKeys.Add($key)) {
            throw "Duplicate keybinding in source: $key"
        }
    }
}

$targets = @(
    if ($SettingsPath) {
        $SettingsPath
    } else {
        $detected = Get-DefaultSettingsPath -AllowMissing:$CreateIfMissing
        if ($detected) { $detected }
    }
)

if ($targets.Count -eq 0) {
    Write-Warning "Windows Terminal was not found. Install it or open it once, then rerun this script."
    return
}

foreach ($target in $targets) {
    $resolvedTarget = [System.IO.Path]::GetFullPath($target)
    $targetExists = Test-Path -LiteralPath $resolvedTarget
    if (-not $targetExists -and -not $CreateIfMissing) {
        throw "Windows Terminal settings file not found: $resolvedTarget"
    }

    $originalCanonical = $null
    $settings = if ($targetExists) {
        $parsedSettings = Get-Content -Raw -LiteralPath $resolvedTarget | ConvertFrom-Json -Depth 100
        $originalCanonical = $parsedSettings | ConvertTo-Json -Depth 100 -Compress
        $parsedSettings
    } else {
        '{"$schema":"https://aka.ms/terminal-profiles-schema","profiles":{"defaults":{},"list":[]}}' |
            ConvertFrom-Json -Depth 100
    }

    if (-not $KeybindingsOnly) {
        $reservedProperties = @("`$schema", "profiles", "schemes", "themes", "actions", "keybindings")
        foreach ($property in $appearanceSource.PSObject.Properties) {
            if ($reservedProperties -contains $property.Name) {
                continue
            }
            Set-PropertyValue -InputObject $settings -Name $property.Name -Value (Copy-JsonValue -Value $property.Value)
        }

        $sourceProfiles = Get-PropertyValue -InputObject $appearanceSource -Name "profiles"
        if ($null -ne $sourceProfiles) {
            $targetProfiles = Get-PropertyValue -InputObject $settings -Name "profiles"
            if ($null -eq $targetProfiles) {
                $targetProfiles = [pscustomobject]@{}
                Set-PropertyValue -InputObject $settings -Name "profiles" -Value $targetProfiles
            }

            $sourceDefaults = Get-PropertyValue -InputObject $sourceProfiles -Name "defaults"
            if ($null -ne $sourceDefaults) {
                $targetDefaults = Get-PropertyValue -InputObject $targetProfiles -Name "defaults"
                if ($null -eq $targetDefaults) {
                    $targetDefaults = [pscustomobject]@{}
                    Set-PropertyValue -InputObject $targetProfiles -Name "defaults" -Value $targetDefaults
                }
                Merge-ObjectProperties -Target $targetDefaults -Source $sourceDefaults
            }

            $sourceProfileList = @(Get-PropertyValue -InputObject $sourceProfiles -Name "list")
            if ($sourceProfileList.Count -gt 0) {
                $existingProfileList = @(Get-PropertyValue -InputObject $targetProfiles -Name "list")
                Set-ArrayProperty -InputObject $targetProfiles -Name "list" -Value @(
                    Merge-ProfileItems -Existing $existingProfileList -Source $sourceProfileList
                )
            }
        }

        foreach ($arrayName in @("schemes", "themes")) {
            $sourceItems = @(Get-PropertyValue -InputObject $appearanceSource -Name $arrayName)
            if ($sourceItems.Count -eq 0) {
                continue
            }
            $existingItems = @(Get-PropertyValue -InputObject $settings -Name $arrayName)
            Set-ArrayProperty -InputObject $settings -Name $arrayName -Value @(
                Merge-NamedItems -Existing $existingItems -Source $sourceItems -IdentityProperty "name"
            )
        }
    }

    $existingActions = @(Get-PropertyValue -InputObject $settings -Name "actions")
    $existingKeybindings = @(Get-PropertyValue -InputObject $settings -Name "keybindings")

    $mergedActions = [System.Collections.Generic.List[object]]::new()
    foreach ($action in $existingActions) {
        if ($null -eq $action) {
            continue
        }
        $id = [string](Get-PropertyValue -InputObject $action -Name "id")
        if (-not [string]::IsNullOrWhiteSpace($id) -and $sourceActionIds.Contains($id)) {
            continue
        }
        $mergedActions.Add($action)
    }
    foreach ($action in $sourceActions) {
        $mergedActions.Add((Copy-JsonValue -Value $action))
    }

    $mergedKeybindings = [System.Collections.Generic.List[object]]::new()
    foreach ($binding in $existingKeybindings) {
        if ($null -eq $binding) {
            continue
        }
        $id = [string](Get-PropertyValue -InputObject $binding -Name "id")
        if (-not [string]::IsNullOrWhiteSpace($id) -and $sourceActionIds.Contains($id)) {
            continue
        }

        $originalKeys = @(Get-KeyList -Binding $binding)
        if ($originalKeys.Count -eq 0) {
            $mergedKeybindings.Add($binding)
            continue
        }

        $remainingKeys = @($originalKeys | Where-Object { -not $sourceKeys.Contains($_) })
        if ($remainingKeys.Count -eq 0) {
            continue
        }

        if ($remainingKeys.Count -ne $originalKeys.Count) {
            $binding.keys = if ($remainingKeys.Count -eq 1) { $remainingKeys[0] } else { @($remainingKeys) }
        }
        $mergedKeybindings.Add($binding)
    }
    foreach ($binding in $sourceKeybindings) {
        $mergedKeybindings.Add((Copy-JsonValue -Value $binding))
    }

    Set-ArrayProperty -InputObject $settings -Name "actions" -Value @($mergedActions)
    Set-ArrayProperty -InputObject $settings -Name "keybindings" -Value @($mergedKeybindings)

    $serialized = $settings | ConvertTo-Json -Depth 100
    $null = $serialized | ConvertFrom-Json -Depth 100
    $updatedCanonical = $settings | ConvertTo-Json -Depth 100 -Compress
    $changed = -not $targetExists -or $originalCanonical -ne $updatedCanonical

    $backupPath = $null
    $applied = $false
    $operation = if ($KeybindingsOnly) {
        "Merge init_lua Windows Terminal keybindings"
    } else {
        "Merge the portable init_lua Windows Terminal environment"
    }

    if (-not $changed) {
        Write-Host "  Windows Terminal settings already match the portable init_lua environment." -ForegroundColor Green
    } elseif ($PSCmdlet.ShouldProcess($resolvedTarget, $operation)) {
        $targetDirectory = Split-Path $resolvedTarget -Parent
        if (-not (Test-Path -LiteralPath $targetDirectory)) {
            New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
        }
        if ($targetExists) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
            $backupPath = "$resolvedTarget.init_lua_backup_$timestamp"
            Copy-Item -LiteralPath $resolvedTarget -Destination $backupPath -Force
        }

        $tempPath = Join-Path $targetDirectory ".settings.init_lua.$([guid]::NewGuid().ToString('N')).tmp"
        try {
            [System.IO.File]::WriteAllText(
                $tempPath,
                $serialized + [Environment]::NewLine,
                [System.Text.UTF8Encoding]::new($false)
            )
            $null = Get-Content -Raw -LiteralPath $tempPath | ConvertFrom-Json -Depth 100
            [System.IO.File]::Move($tempPath, $resolvedTarget, $true)
            $applied = $true
        } finally {
            if (Test-Path -LiteralPath $tempPath) {
                Remove-Item -LiteralPath $tempPath -Force
            }
        }

        if ($KeybindingsOnly) {
            Write-Host "  Windows Terminal keybindings merged: $resolvedTarget" -ForegroundColor Green
        } else {
            Write-Host "  Windows Terminal environment synchronized: $resolvedTarget" -ForegroundColor Green
        }
        if ($backupPath) {
            Write-Host "  Previous settings backup: $backupPath" -ForegroundColor Gray
        } else {
            Write-Host "  Created a new settings file; no previous file required a backup." -ForegroundColor Gray
        }
    }

    if ($PassThru) {
        [pscustomobject]@{
            SettingsPath       = $resolvedTarget
            BackupPath         = $backupPath
            Created            = (-not $targetExists -and $applied)
            Changed            = $changed
            Applied            = $applied
            KeybindingsOnly    = [bool]$KeybindingsOnly
            ActionsManaged     = $sourceActions.Count
            KeybindingsManaged = $sourceKeybindings.Count
            ProfilesManaged    = if ($KeybindingsOnly) { 0 } else { @($appearanceSource.profiles.list).Count }
            SchemesManaged     = if ($KeybindingsOnly) { 0 } else { @($appearanceSource.schemes).Count }
            ThemesManaged      = if ($KeybindingsOnly) { 0 } else { @($appearanceSource.themes).Count }
        }
    }
}
