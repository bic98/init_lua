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

$installer = Join-Path $PSScriptRoot "Install-WindowsTerminalEnvironment.ps1"
if (-not (Test-Path -LiteralPath $installer)) {
    throw "Windows Terminal environment installer not found: $installer"
}

$arguments = @{
    KeybindingsOnly = $true
    KeybindingsPath = $KeybindingsPath
    PassThru = $PassThru
}
if ($SettingsPath) {
    $arguments.SettingsPath = $SettingsPath
}
if ($WhatIfPreference) {
    $arguments.WhatIf = $true
}

& $installer @arguments
