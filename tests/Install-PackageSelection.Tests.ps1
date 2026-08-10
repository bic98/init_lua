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
$installerPath = Join-Path $repoRoot "install.ps1"
$installerSource = Get-Content -Raw -LiteralPath $installerPath
$packageBlock = [regex]::Match(
    $installerSource,
    '(?s)\$packages\s*=\s*@\((?<body>.*?)\)'
)

Assert-True $packageBlock.Success "install.ps1 must define the Chocolatey package list"

$packages = @(
    [regex]::Matches($packageBlock.Groups["body"].Value, '"(?<name>[^"]+)"') |
        ForEach-Object { $_.Groups["name"].Value }
)

foreach ($requiredPackage in @(
    "powershell-core",
    "microsoft-windows-terminal",
    "nerd-fonts-SourceCodePro",
    "neovim",
    "git",
    "ripgrep",
    "fd",
    "mingw",
    "nodejs-lts",
    "python"
)) {
    Assert-True ($packages -contains $requiredPackage) "$requiredPackage must remain in the default installation"
}

foreach ($excludedPackage in @("uv", "pandoc", "miktex")) {
    Assert-True ($packages -notcontains $excludedPackage) "$excludedPackage must not be installed automatically"
}

Write-Host "PASS: default package selection excludes uv, Pandoc, and MiKTeX" -ForegroundColor Green
