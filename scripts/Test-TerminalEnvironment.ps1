[CmdletBinding()]
param(
    [Parameter()]
    [string]$SettingsPath,

    [Parameter()]
    [string]$AppearancePath = (Join-Path (Split-Path $PSScriptRoot -Parent) "windows-terminal\appearance.json"),

    [Parameter()]
    [string]$KeybindingsPath = (Join-Path (Split-Path $PSScriptRoot -Parent) "windows-terminal\keybindings.json"),

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

function Normalize-KeyChord {
    param(
        [Parameter(Mandatory)]
        [string]$Chord
    )

    return $Chord.ToLowerInvariant().Replace("minus", "-").Replace("comma", ",")
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

function Test-SauceCodeProNerdFont {
    $fontKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
        "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    )
    foreach ($fontKey in $fontKeys) {
        if (-not (Test-Path -LiteralPath $fontKey)) {
            continue
        }
        if (
            (Get-ItemProperty -LiteralPath $fontKey).PSObject.Properties |
                Where-Object { $_.Name -match "^SauceCodePro NF" } |
                Select-Object -First 1
        ) {
            return $true
        }
    }
    return $false
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

$repoRoot = Split-Path $PSScriptRoot -Parent
$profileSource = Join-Path $repoRoot "powershell\Microsoft.PowerShell_profile.ps1"
$profileDestination = $PROFILE
$themeSource = Join-Path $repoRoot "powershell\illusi0n-dayfox.omp.json"
$themeDestination = Join-Path (Split-Path $PROFILE -Parent) "illusi0n-dayfox.omp.json"

Add-Check -Name "PowerShell 7" `
    -Passed ($PSVersionTable.PSVersion.Major -ge 7) `
    -Detail $PSVersionTable.PSVersion.ToString()

$ohMyPosh = Get-Command oh-my-posh -ErrorAction SilentlyContinue | Select-Object -First 1
Add-Check -Name "Oh My Posh" `
    -Passed ($null -ne $ohMyPosh) `
    -Detail $(if ($ohMyPosh) { $ohMyPosh.Source } else { "command not found" })

Add-Check -Name "SauceCodePro Nerd Font" `
    -Passed (Test-SauceCodeProNerdFont) `
    -Detail "Windows font registry"

Add-Check -Name "PowerShell profile" `
    -Passed (Test-FileMatches -Source $profileSource -Destination $profileDestination) `
    -Detail $profileDestination

Add-Check -Name "Oh My Posh theme" `
    -Passed (Test-FileMatches -Source $themeSource -Destination $themeDestination) `
    -Detail $themeDestination

foreach ($commandName in @("nvim", "git", "rg", "fd", "node")) {
    $command = Get-Command $commandName -ErrorAction SilentlyContinue | Select-Object -First 1
    Add-Check -Name $commandName `
        -Passed ($null -ne $command) `
        -Detail $(if ($command) { $command.Source } else { "command not found" })
}

if (-not (Test-Path -LiteralPath $AppearancePath) -or -not (Test-Path -LiteralPath $KeybindingsPath)) {
    throw "Portable Windows Terminal source files are missing."
}

$appearance = Get-Content -Raw -LiteralPath $AppearancePath | ConvertFrom-Json -Depth 100
$keySource = Get-Content -Raw -LiteralPath $KeybindingsPath | ConvertFrom-Json -Depth 100
$resolvedSettingsPath = if ($SettingsPath) { $SettingsPath } else { Get-DetectedSettingsPath }
$settingsExist = -not [string]::IsNullOrWhiteSpace($resolvedSettingsPath) -and (Test-Path -LiteralPath $resolvedSettingsPath)
$settings = $null
$settingsDetail = if ($resolvedSettingsPath) { $resolvedSettingsPath } else { "settings.json not found" }
if ($settingsExist) {
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
    $settingsDefaults = Get-NestedValue -InputObject $settings -Path @("profiles", "defaults")
    $appearanceDefaults = Get-NestedValue -InputObject $appearance -Path @("profiles", "defaults")
    $appearanceMatches =
        (Get-NestedValue -InputObject $settings -Path @("copyFormatting")) -eq $appearance.copyFormatting -and
        (Get-NestedValue -InputObject $settings -Path @("copyOnSelect")) -eq $appearance.copyOnSelect -and
        (Get-NestedValue -InputObject $settings -Path @("theme")) -eq $appearance.theme -and
        (Get-NestedValue -InputObject $settings -Path @("defaultProfile")) -eq $appearance.defaultProfile -and
        (Get-NestedValue -InputObject $settingsDefaults -Path @("colorScheme")) -eq $appearanceDefaults.colorScheme -and
        (Get-NestedValue -InputObject $settingsDefaults -Path @("font", "face")) -eq $appearanceDefaults.font.face -and
        (Get-NestedValue -InputObject $settingsDefaults -Path @("font", "size")) -eq $appearanceDefaults.font.size -and
        (Get-NestedValue -InputObject $settingsDefaults -Path @("cursorShape")) -eq $appearanceDefaults.cursorShape -and
        (Get-NestedValue -InputObject $settingsDefaults -Path @("opacity")) -eq $appearanceDefaults.opacity -and
        (Get-NestedValue -InputObject $settingsDefaults -Path @("padding")) -eq $appearanceDefaults.padding
    Add-Check -Name "Terminal appearance" `
        -Passed $appearanceMatches `
        -Detail "dayfox + Kanagawa tabs + SauceCodePro Nerd Font 10"

    $settingsProfiles = @(Get-NestedValue -InputObject $settings -Path @("profiles", "list"))
    $managedProfile = @($settingsProfiles | Where-Object {
        (Get-NestedValue -InputObject $_ -Path @("guid")) -eq $appearance.defaultProfile -and
        (Get-NestedValue -InputObject $_ -Path @("name")) -eq "PowerShell 7 (init_lua)"
    })
    Add-Check -Name "Default PowerShell profile" `
        -Passed ($managedProfile.Count -eq 1) `
        -Detail "PowerShell 7 (init_lua)"

    $settingsSchemes = @(Get-NestedValue -InputObject $settings -Path @("schemes"))
    $settingsThemes = @(Get-NestedValue -InputObject $settings -Path @("themes"))
    $allSchemesPresent = @($appearance.schemes | Where-Object {
        $sourceName = $_.name
        @($settingsSchemes | Where-Object {
            (Get-NestedValue -InputObject $_ -Path @("name")) -eq $sourceName
        }).Count -ne 1
    }).Count -eq 0
    $allThemesPresent = @($appearance.themes | Where-Object {
        $sourceName = $_.name
        @($settingsThemes | Where-Object {
            (Get-NestedValue -InputObject $_ -Path @("name")) -eq $sourceName
        }).Count -ne 1
    }).Count -eq 0
    Add-Check -Name "Terminal palettes and tab theme" `
        -Passed ($allSchemesPresent -and $allThemesPresent) `
        -Detail "$(@($appearance.schemes).Count) schemes, $(@($appearance.themes).Count) theme"

    $missingBindings = [System.Collections.Generic.List[string]]::new()
    $settingsKeybindings = @(Get-NestedValue -InputObject $settings -Path @("keybindings"))
    foreach ($sourceBinding in @($keySource.keybindings)) {
        $sourceKey = Normalize-KeyChord -Chord ([string]$sourceBinding.keys)
        $matching = @($settingsKeybindings | Where-Object {
            $candidateKeys = Get-NestedValue -InputObject $_ -Path @("keys")
            $candidateId = Get-NestedValue -InputObject $_ -Path @("id")
            $null -ne $candidateKeys -and
            (Normalize-KeyChord -Chord ([string]$candidateKeys)) -eq $sourceKey -and
            $candidateId -eq $sourceBinding.id
        })
        if ($matching.Count -ne 1) {
            $missingBindings.Add($sourceKey)
        }
    }
    Add-Check -Name "Terminal keybindings" `
        -Passed ($missingBindings.Count -eq 0) `
        -Detail $(if ($missingBindings.Count -eq 0) { "$(@($keySource.keybindings).Count) bindings" } else { "missing: $($missingBindings -join ', ')" })
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
