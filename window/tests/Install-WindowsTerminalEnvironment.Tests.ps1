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

$platformRoot = Split-Path $PSScriptRoot -Parent
$repoRoot = Split-Path $platformRoot -Parent
$installer = Join-Path $platformRoot "scripts\Install-WindowsTerminalEnvironment.ps1"
$verifier = Join-Path $platformRoot "scripts\Test-TerminalEnvironment.ps1"
$appearancePath = Join-Path $platformRoot "settings\windows-terminal\appearance.json"
$keybindingsPath = Join-Path $platformRoot "settings\windows-terminal\keybindings.json"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "init_lua-terminal-environment-$([guid]::NewGuid().ToString('N'))"
$settingsPath = Join-Path $tempRoot "settings.json"
$newSettingsPath = Join-Path $tempRoot "new-install\settings.json"
$whatIfSettingsPath = Join-Path $tempRoot "what-if\settings.json"
$incompleteSettingsPath = Join-Path $tempRoot "incomplete-settings.json"

New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    @'
{
  // JSONC comments and trailing commas must remain readable.
  "copyOnSelect": true,
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
      {
        "name": "PowerShell",
        "guid": "{obsolete-powershell-guid}",
        "commandline": "pwsh.exe -NoLogo",
        "startingDirectory": "C:\\work"
      },
    ],
  },
  "schemes": [
    { "name": "Keep scheme", "background": "#000000" },
    { "name": "Dayfox", "background": "#000000" },
  ],
  "themes": [
    { "name": "Keep theme", "window": { "applicationTheme": "light" } },
  ],
  "actions": [
    { "command": "find", "id": "User.keep" },
    { "command": "closeWindow", "id": "User.switchToTab.ED268D78" },
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

    Assert-True $first.Changed "the first merge must report a logical change"
    Assert-True $first.Applied "the first merge must report an applied write"
    Assert-True (Test-Path -LiteralPath $first.BackupPath) "an existing settings file must be backed up"
    Assert-True ((Get-Content -Raw -LiteralPath $first.BackupPath).Contains("JSONC comments")) "the backup must contain the original JSONC"

    Assert-True ($result.copyOnSelect -eq $false) "copyOnSelect must match the portable environment"
    Assert-True ($result.copyFormatting -eq "none") "copy formatting must match the portable environment"
    Assert-True ($result.theme -eq "legacyDark") "the window theme must match the current portable environment"
    Assert-True ($result.defaultProfile -eq $appearance.defaultProfile) "PowerShell must become the default profile"
    Assert-True ($result.profiles.defaults.colorScheme -eq "Dayfox") "the Dayfox color scheme must be active"
    Assert-True ($result.profiles.defaults.font.face -eq "JetBrainsMono Nerd Font") "the Nerd Font face must match"
    Assert-True ($result.profiles.defaults.font.cellHeight -eq 1.2) "unmanaged nested font properties must be preserved"
    Assert-True ($result.profiles.defaults.antialiasingMode -eq "grayscale") "unmanaged profile defaults must be preserved"

    Assert-True (@($result.profiles.list | Where-Object name -eq "Keep me").Count -eq 1) "unrelated profiles must be preserved"
    $managedProfiles = @($result.profiles.list | Where-Object guid -eq $appearance.defaultProfile)
    Assert-True ($managedProfiles.Count -eq 1) "the managed PowerShell profile must not duplicate"
    Assert-True ($managedProfiles[0].name -eq "PowerShell") "the built-in PowerShell profile name must match"
    Assert-True ($managedProfiles[0].commandline -eq "pwsh.exe -NoLogo") "unmanaged profile commandline must be preserved"
    Assert-True ($managedProfiles[0].startingDirectory -eq "C:\work") "unmanaged profile startingDirectory must be preserved"

    Assert-True (@($result.schemes | Where-Object name -eq "Keep scheme").Count -eq 1) "unrelated color schemes must be preserved"
    Assert-True ((@($result.schemes | Where-Object name -eq "Dayfox")[0].background) -eq "#F6F2EE") "the Dayfox scheme must be replaced"
    Assert-True (@($result.themes | Where-Object name -eq "Keep theme").Count -eq 1) "unmanaged Terminal themes must be preserved"
    Assert-True (@($result.actions | Where-Object id -eq "User.keep").Count -eq 1) "unrelated actions must be preserved"
    $managedAction = @($result.actions | Where-Object id -eq "User.switchToTab.ED268D78")
    Assert-True ($managedAction.Count -eq 1 -and $managedAction[0].command.action -eq "switchToTab") "the managed action must replace the same id"

    Assert-True (@($keySource.keybindings).Count -eq 18) "the portable source must define the focused 18-key set"
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

    $backupCountBeforeSecondRun = @(Get-ChildItem -LiteralPath $tempRoot -Filter "settings.json.init_lua_backup_*" -File).Count
    $second = & $installer `
        -SettingsPath $settingsPath `
        -AppearancePath $appearancePath `
        -KeybindingsPath $keybindingsPath `
        -PassThru
    $backupCountAfterSecondRun = @(Get-ChildItem -LiteralPath $tempRoot -Filter "settings.json.init_lua_backup_*" -File).Count
    Assert-True (-not $second.Changed -and -not $second.Applied) "a second run must be a no-op"
    Assert-True ($null -eq $second.BackupPath) "a no-op must not report a backup"
    Assert-True ($backupCountAfterSecondRun -eq $backupCountBeforeSecondRun) "a no-op must not create another backup"

    $created = & $installer `
        -SettingsPath $newSettingsPath `
        -AppearancePath $appearancePath `
        -KeybindingsPath $keybindingsPath `
        -CreateIfMissing `
        -PassThru
    Assert-True ($created.Created -and $created.Applied) "CreateIfMissing must create and apply settings"
    Assert-True ($null -eq $created.BackupPath) "a new settings file must not report a backup"
    $newSettings = Get-Content -Raw -LiteralPath $newSettingsPath | ConvertFrom-Json -Depth 100
    Assert-True ($newSettings.profiles.defaults.colorScheme -eq "Dayfox") "fresh settings must receive the complete appearance"

    $preview = & $installer `
        -SettingsPath $whatIfSettingsPath `
        -AppearancePath $appearancePath `
        -KeybindingsPath $keybindingsPath `
        -CreateIfMissing `
        -WhatIf `
        -PassThru
    Assert-True ($preview.Changed -and -not $preview.Applied -and -not $preview.Created) "WhatIf must report a pending change without applying it"
    Assert-True (-not (Test-Path -LiteralPath $whatIfSettingsPath)) "WhatIf must not create settings.json"

    $verification = @(& $verifier `
        -SettingsPath $newSettingsPath `
        -AppearancePath $appearancePath `
        -KeybindingsPath $keybindingsPath `
        -SkipNvimCheck `
        -SkipToolChecks `
        -SkipPluginChecks `
        -PassThru)
    foreach ($checkName in @(
        "Windows Terminal settings",
        "Terminal appearance",
        "Default PowerShell profile",
        "Terminal color scheme",
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
        -SkipNvimCheck `
        -SkipToolChecks `
        -SkipPluginChecks `
        -PassThru)
    $incompleteAppearance = @($incompleteVerification | Where-Object Check -eq "Terminal appearance")
    Assert-True ($incompleteAppearance.Count -eq 1 -and $incompleteAppearance[0].Status -eq "FAIL") "incomplete settings must be reported instead of crashing"

    Write-Host "PASS: Windows Terminal merge, preservation, change-only backup, verification, and idempotency" -ForegroundColor Green
} finally {
    $resolvedTemp = [System.IO.Path]::GetFullPath($tempRoot)
    $systemTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if ($resolvedTemp.StartsWith($systemTemp, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $resolvedTemp)) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
