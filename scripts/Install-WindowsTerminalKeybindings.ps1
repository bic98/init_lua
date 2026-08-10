[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [string[]]$SettingsPath,

    [Parameter()]
    [string]$KeybindingsPath = (Join-Path (Split-Path $PSScriptRoot -Parent) "windows-terminal\keybindings.json"),

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

function Get-KeyList {
    param(
        [Parameter(Mandatory)]
        [object]$Binding
    )

    $keys = Get-PropertyValue -InputObject $Binding -Name "keys"
    if ($null -eq $keys) {
        return @()
    }

    return @($keys | ForEach-Object { ([string]$_).ToLowerInvariant() })
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

    if ($null -eq $InputObject.PSObject.Properties[$Name]) {
        $InputObject | Add-Member -MemberType NoteProperty -Name $Name -Value @($Value)
        return
    }

    $InputObject.$Name = @($Value)
}

function Get-DefaultSettingsPath {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json"),
        (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"),
        (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalCanary_8wekyb3d8bbwe\LocalState\settings.json")
    )

    return $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw "PowerShell 7 or later is required. Open Windows Terminal > PowerShell and run this script again."
}

if (-not (Test-Path -LiteralPath $KeybindingsPath)) {
    throw "Keybinding source not found: $KeybindingsPath"
}

$source = Get-Content -Raw -LiteralPath $KeybindingsPath | ConvertFrom-Json -Depth 100
$sourceActions = @($source.actions)
$sourceKeybindings = @($source.keybindings)

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
        $detected = Get-DefaultSettingsPath
        if ($detected) { $detected }
    }
)

if ($targets.Count -eq 0) {
    Write-Warning "Windows Terminal settings.json was not found. Open Windows Terminal once, then rerun this script."
    return
}

foreach ($target in $targets) {
    $resolvedTarget = [System.IO.Path]::GetFullPath($target)
    if (-not (Test-Path -LiteralPath $resolvedTarget)) {
        throw "Windows Terminal settings file not found: $resolvedTarget"
    }

    $settings = Get-Content -Raw -LiteralPath $resolvedTarget | ConvertFrom-Json -Depth 100
    $existingActions = if ($null -ne $settings.PSObject.Properties["actions"]) { @($settings.actions) } else { @() }
    $existingKeybindings = if ($null -ne $settings.PSObject.Properties["keybindings"]) { @($settings.keybindings) } else { @() }

    $mergedActions = [System.Collections.Generic.List[object]]::new()
    foreach ($action in $existingActions) {
        $id = [string](Get-PropertyValue -InputObject $action -Name "id")
        if (-not [string]::IsNullOrWhiteSpace($id) -and $sourceActionIds.Contains($id)) {
            continue
        }
        $mergedActions.Add($action)
    }
    foreach ($action in $sourceActions) {
        $mergedActions.Add($action)
    }

    $mergedKeybindings = [System.Collections.Generic.List[object]]::new()
    foreach ($binding in $existingKeybindings) {
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
        $mergedKeybindings.Add($binding)
    }

    Set-ArrayProperty -InputObject $settings -Name "actions" -Value @($mergedActions)
    Set-ArrayProperty -InputObject $settings -Name "keybindings" -Value @($mergedKeybindings)

    $serialized = $settings | ConvertTo-Json -Depth 100
    $null = $serialized | ConvertFrom-Json -Depth 100

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
    $backupPath = "$resolvedTarget.init_lua_backup_$timestamp"

    if ($PSCmdlet.ShouldProcess($resolvedTarget, "Back up and merge init_lua Windows Terminal keybindings")) {
        Copy-Item -LiteralPath $resolvedTarget -Destination $backupPath -Force

        $tempPath = Join-Path (Split-Path $resolvedTarget -Parent) ".settings.init_lua.$([guid]::NewGuid().ToString('N')).tmp"
        try {
            [System.IO.File]::WriteAllText(
                $tempPath,
                $serialized + [Environment]::NewLine,
                [System.Text.UTF8Encoding]::new($false)
            )
            $null = Get-Content -Raw -LiteralPath $tempPath | ConvertFrom-Json -Depth 100
            [System.IO.File]::Move($tempPath, $resolvedTarget, $true)
        } finally {
            if (Test-Path -LiteralPath $tempPath) {
                Remove-Item -LiteralPath $tempPath -Force
            }
        }

        Write-Host "  Windows Terminal keybindings merged: $resolvedTarget" -ForegroundColor Green
        Write-Host "  Previous settings backup: $backupPath" -ForegroundColor Gray
    }

    if ($PassThru) {
        [pscustomobject]@{
            SettingsPath    = $resolvedTarget
            BackupPath      = $backupPath
            ActionsAdded    = $sourceActions.Count
            KeybindingsAdded = $sourceKeybindings.Count
        }
    }
}
