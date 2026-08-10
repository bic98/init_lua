$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Assert-True {
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not $Condition) {
        throw "ASSERTION FAILED: $Message"
    }
}

function Normalize-KeyChord {
    param(
        [Parameter(Mandatory)]
        [string]$Chord
    )

    return $Chord.ToLowerInvariant().Replace("minus", "-").Replace("comma", ",")
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$installer = Join-Path $repoRoot "scripts\Install-WindowsTerminalEnvironment.ps1"
$verifier = Join-Path $repoRoot "scripts\Test-TerminalEnvironment.ps1"
$appearancePath = Join-Path $repoRoot "windows-terminal\appearance.json"
$keybindingsPath = Join-Path $repoRoot "windows-terminal\keybindings.json"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "init_lua-terminal-environment-$([guid]::NewGuid().ToString('N'))"
$settingsPath = Join-Path $tempRoot "settings.json"
$newSettingsPath = Join-Path $tempRoot "new-install\settings.json"
$incompleteSettingsPath = Join-Path $tempRoot "incomplete-settings.json"

New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    @'
{
  // JSONC comments and trailing commas must remain readable.
  "copyOnSelect": false,
  "defaultProfile": "{keep-this-guid}",
  "profiles": {
    "defaults": {
      "antialiasingMode": "grayscale",
      "font": {
        "face": "Cascadia Code",
        "cellHeight": 1.2,
      },
    },
    "list": [
      { "name": "Keep me", "guid": "{keep-profile-guid}", "commandline": "cmd.exe" },
      { "name": "PowerShell 7 (init_lua)", "guid": "{obsolete-guid}", "commandline": "old.exe" },
    ],
  },
  "schemes": [
    { "name": "Keep scheme", "background": "#000000" },
    { "name": "dayfox", "background": "#000000" },
  ],
  "themes": [
    { "name": "Keep theme", "window": { "applicationTheme": "light" } },
    { "name": "Kanagawa Dark", "window": { "applicationTheme": "light" } },
  ],
  "actions": [
    { "command": "find", "id": "User.keep" },
    { "command": "closeWindow", "id": "User.newTab" },
  ],
  "keybindings": [
    { "id": "User.keep", "keys": ["f1", "alt+c"] },
    { "id": "User.old", "keys": "alt+minus" },
  ],
}
'@ | Set-Content -LiteralPath $settingsPath -Encoding utf8NoBOM

    $first = & $installer `
        -SettingsPath $settingsPath `
        -AppearancePath $appearancePath `
        -KeybindingsPath $keybindingsPath `
        -PassThru

    $result = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json -Depth 100
    $appearance = Get-Content -Raw -LiteralPath $appearancePath | ConvertFrom-Json -Depth 100
    $keySource = Get-Content -Raw -LiteralPath $keybindingsPath | ConvertFrom-Json -Depth 100

    Assert-True ($result.copyOnSelect -eq $true) "managed global settings must be synchronized"
    Assert-True ($result.copyFormatting -eq "none") "copy formatting must match the portable environment"
    Assert-True ($result.language -eq "ko") "the Terminal UI language must match"
    Assert-True ($result.launchMode -eq "default") "the launch mode must match"
    Assert-True (@($result.newTabMenu).Count -eq 1) "the new-tab menu must match"
    Assert-True ($result.defaultProfile -eq $appearance.defaultProfile) "the managed PowerShell 7 profile must become default"
    Assert-True ($result.profiles.defaults.colorScheme -eq "dayfox") "the dayfox color scheme must be active"
    Assert-True ($result.profiles.defaults.font.face -eq "SauceCodePro Nerd Font") "the Nerd Font face must match"
    Assert-True ($result.profiles.defaults.font.size -eq 10) "the font size must match"
    Assert-True ($result.profiles.defaults.opacity -eq 100) "the opacity must match"
    Assert-True ($result.profiles.defaults.padding -eq "8") "the padding must match"
    Assert-True ($result.profiles.defaults.cursorShape -eq "filledBox") "the cursor shape must match"
    Assert-True ($result.profiles.defaults.scrollbarState -eq "hidden") "the scrollbar state must match"
    Assert-True ($result.profiles.defaults.useAcrylic -eq $false) "the acrylic setting must match"
    Assert-True ($result.profiles.defaults.font.cellHeight -eq 1.2) "unmanaged nested profile defaults must be preserved"
    Assert-True ($result.profiles.defaults.antialiasingMode -eq "grayscale") "unmanaged profile defaults must be preserved"
    Assert-True (@($result.profiles.list | Where-Object name -eq "Keep me").Count -eq 1) "unrelated profiles must be preserved"
    Assert-True (@($result.profiles.list | Where-Object name -eq "PowerShell 7 (init_lua)").Count -eq 1) "the managed profile must not duplicate"
    Assert-True (@($result.profiles.list | Where-Object guid -eq $appearance.defaultProfile).Count -eq 1) "the managed profile GUID must match defaultProfile"
    Assert-True (@($result.schemes | Where-Object name -eq "Keep scheme").Count -eq 1) "unrelated color schemes must be preserved"
    Assert-True ((@($result.schemes | Where-Object name -eq "dayfox")[0].background) -eq "#F6F2EE") "the dayfox scheme must be replaced"
    Assert-True (@($result.themes | Where-Object name -eq "Keep theme").Count -eq 1) "unrelated themes must be preserved"
    Assert-True ((@($result.themes | Where-Object name -eq "Kanagawa Dark")[0].window.applicationTheme) -eq "dark") "the managed tab theme must be replaced"
    Assert-True (@($result.actions | Where-Object id -eq "User.keep").Count -eq 1) "unrelated actions must be preserved"
    Assert-True ((@($result.actions | Where-Object id -eq "User.newTab")[0].command) -eq "newTab") "managed actions must replace same-id actions"

    foreach ($sourceBinding in @($keySource.keybindings)) {
        $sourceKey = Normalize-KeyChord -Chord ([string]$sourceBinding.keys)
        $matching = @($result.keybindings | Where-Object {
            (Normalize-KeyChord -Chord ([string]$_.keys)) -eq $sourceKey -and $_.id -eq $sourceBinding.id
        })
        Assert-True ($matching.Count -eq 1) "$sourceKey must match the portable binding"
    }

    $keepBinding = @($result.keybindings | Where-Object id -eq "User.keep")[0]
    Assert-True (@($keepBinding.keys).Count -eq 1) "only a conflicting key must be removed from an unrelated binding"
    Assert-True (@($keepBinding.keys)[0] -eq "f1") "a non-conflicting key must remain"
    Assert-True (@($result.keybindings | Where-Object { $_.id -eq $null -and $_.keys -eq "ctrl+w" }).Count -eq 1) "managed disabled defaults must be present"
    Assert-True (Test-Path -LiteralPath $first.BackupPath) "an existing settings file must be backed up"
    Assert-True ((Get-Content -Raw -LiteralPath $first.BackupPath).Contains("JSONC comments")) "the backup must contain the original JSONC"

    $null = & $installer `
        -SettingsPath $settingsPath `
        -AppearancePath $appearancePath `
        -KeybindingsPath $keybindingsPath `
        -PassThru
    $secondResult = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json -Depth 100
    Assert-True (@($secondResult.profiles.list).Count -eq @($result.profiles.list).Count) "a second run must not duplicate profiles"
    Assert-True (@($secondResult.schemes).Count -eq @($result.schemes).Count) "a second run must not duplicate schemes"
    Assert-True (@($secondResult.themes).Count -eq @($result.themes).Count) "a second run must not duplicate themes"
    Assert-True (@($secondResult.actions).Count -eq @($result.actions).Count) "a second run must not duplicate actions"
    Assert-True (@($secondResult.keybindings).Count -eq @($result.keybindings).Count) "a second run must not duplicate keybindings"

    $created = & $installer `
        -SettingsPath $newSettingsPath `
        -AppearancePath $appearancePath `
        -KeybindingsPath $keybindingsPath `
        -CreateIfMissing `
        -PassThru
    Assert-True ($created.Created -eq $true) "CreateIfMissing must report a new settings file"
    Assert-True ($null -eq $created.BackupPath) "a new settings file must not report a backup"
    Assert-True (Test-Path -LiteralPath $newSettingsPath) "CreateIfMissing must create settings.json"
    $newSettings = Get-Content -Raw -LiteralPath $newSettingsPath | ConvertFrom-Json -Depth 100
    Assert-True ($newSettings.profiles.defaults.colorScheme -eq "dayfox") "a fresh settings file must receive the complete appearance"
    Assert-True (@($newSettings.actions).Count -eq @($keySource.actions).Count) "a fresh settings file must receive every managed action"

    $verification = @(& $verifier `
        -SettingsPath $newSettingsPath `
        -AppearancePath $appearancePath `
        -KeybindingsPath $keybindingsPath `
        -PassThru)
    foreach ($checkName in @(
        "Windows Terminal settings",
        "Terminal appearance",
        "Default PowerShell profile",
        "Terminal palettes and tab theme",
        "Terminal keybindings"
    )) {
        $check = @($verification | Where-Object Check -eq $checkName)
        Assert-True ($check.Count -eq 1 -and $check[0].Status -eq "PASS") "$checkName verification must pass"
    }

    '{}' | Set-Content -LiteralPath $incompleteSettingsPath -Encoding utf8NoBOM
    $incompleteVerification = @(& $verifier `
        -SettingsPath $incompleteSettingsPath `
        -AppearancePath $appearancePath `
        -KeybindingsPath $keybindingsPath `
        -PassThru)
    $incompleteAppearance = @($incompleteVerification | Where-Object Check -eq "Terminal appearance")
    Assert-True ($incompleteAppearance.Count -eq 1 -and $incompleteAppearance[0].Status -eq "FAIL") "an incomplete settings file must be reported instead of crashing the verifier"

    Write-Host "PASS: complete Windows Terminal environment merge, preservation, backup, creation, conflicts, verification, and idempotency" -ForegroundColor Green
} finally {
    $resolvedTemp = [System.IO.Path]::GetFullPath($tempRoot)
    $systemTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if ($resolvedTemp.StartsWith($systemTemp, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTemp)) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
