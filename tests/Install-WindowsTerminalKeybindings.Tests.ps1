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

$repoRoot = Split-Path $PSScriptRoot -Parent
$installer = Join-Path $repoRoot "scripts\Install-WindowsTerminalKeybindings.ps1"
$sourcePath = Join-Path $repoRoot "windows-terminal\keybindings.json"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "init_lua-terminal-$([guid]::NewGuid().ToString('N'))"
$settingsPath = Join-Path $tempRoot "settings.json"

New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    @'
{
  // JSONC comments and trailing commas must remain readable.
  "defaultProfile": "{keep-this-guid}",
  "profiles": {
    "list": [
      { "name": "Keep me", "commandline": "pwsh.exe" },
    ],
  },
  "actions": [
    { "command": "find", "id": "User.keep" },
    { "command": "closeWindow", "id": "User.newTab" },
  ],
  "keybindings": [
    { "id": "User.keep", "keys": ["f1", "alt+c"] },
    { "id": "User.old", "keys": "alt+h" },
  ],
}
'@ | Set-Content -LiteralPath $settingsPath -Encoding utf8NoBOM

    $first = & $installer -SettingsPath $settingsPath -KeybindingsPath $sourcePath -PassThru
    $result = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json -Depth 100
    $source = Get-Content -Raw -LiteralPath $sourcePath | ConvertFrom-Json -Depth 100

    Assert-True (@($source.keybindings).Count -eq 45) "the portable source must define exactly 45 keybindings"
    Assert-True ($result.defaultProfile -eq "{keep-this-guid}") "defaultProfile must be preserved"
    Assert-True (@($result.profiles.list).Count -eq 1) "profiles must be preserved"
    Assert-True (@($result.actions | Where-Object id -eq "User.keep").Count -eq 1) "unrelated actions must be preserved"
    Assert-True (@($result.actions | Where-Object id -eq "User.newTab").Count -eq 1) "source action ids must not duplicate"
    Assert-True ((@($result.actions | Where-Object id -eq "User.newTab")[0].command) -eq "newTab") "source action must replace same-id action"
    $expectedBindings = [ordered]@{
        'alt+\' = "User.splitPane.right"
        'alt+-'  = "User.splitPane.down"
        'alt+1'  = "User.tab.0"
        'alt+2'  = "User.tab.1"
        'alt+3'  = "User.tab.2"
        'alt+4'  = "User.tab.3"
        'alt+c'  = "User.newTab"
        'alt+w'  = "User.closePane"
        'alt+h'  = "User.moveFocus.left"
        'alt+left' = "User.moveFocus.left"
        'alt+down' = "User.moveFocus.down"
        'alt+up' = "User.moveFocus.up"
        'alt+right' = "User.moveFocus.right"
    }
    foreach ($entry in $expectedBindings.GetEnumerator()) {
        $matching = @($result.keybindings | Where-Object {
            $_.keys -eq $entry.Key -and $_.id -eq $entry.Value
        })
        Assert-True ($matching.Count -eq 1) "$($entry.Key) must map to $($entry.Value)"
    }

    $keepBinding = @($result.keybindings | Where-Object id -eq "User.keep")[0]
    Assert-True (@($keepBinding.keys).Count -eq 1) "only the conflicting key must be removed from an unrelated binding"
    Assert-True (@($keepBinding.keys)[0] -eq "f1") "non-conflicting keys must be preserved"
    Assert-True (Test-Path -LiteralPath $first.BackupPath) "a backup must be created"

    $backup = Get-Content -Raw -LiteralPath $first.BackupPath
    Assert-True ($backup.Contains("JSONC comments")) "the backup must contain the original file"

    $null = & $installer -SettingsPath $settingsPath -KeybindingsPath $sourcePath -PassThru
    $secondResult = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json -Depth 100
    Assert-True (@($secondResult.actions).Count -eq @($result.actions).Count) "a second run must not duplicate actions"
    Assert-True (@($secondResult.keybindings).Count -eq @($result.keybindings).Count) "a second run must not duplicate keybindings"
    Assert-True (@($secondResult.actions).Count -ge @($source.actions).Count) "all source actions must be present"

    Write-Host "PASS: Windows Terminal keybinding merge, backup, preservation, conflict handling, and idempotency" -ForegroundColor Green
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
