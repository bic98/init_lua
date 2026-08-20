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

$platformRoot = Split-Path $PSScriptRoot -Parent
$repoRoot = Split-Path $platformRoot -Parent
$installer = Join-Path $platformRoot "install.ps1"
$bootstrap = Join-Path $platformRoot "bootstrap.ps1"
$verifier = Join-Path $platformRoot "scripts\Test-TerminalEnvironment.ps1"
$dependencyInstaller = Join-Path $platformRoot "scripts\Install-Dependencies.ps1"

foreach ($scriptPath in @($bootstrap, $installer, $verifier, $dependencyInstaller, (Join-Path $platformRoot "scripts\Install-WindowsTerminalEnvironment.ps1"))) {
    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        $scriptPath,
        [ref]$tokens,
        [ref]$parseErrors
    )
    Assert-True ($parseErrors.Count -eq 0) "$scriptPath must parse without PowerShell errors"
}

$bootstrapSource = Get-Content -Raw -LiteralPath $bootstrap
$installerSource = Get-Content -Raw -LiteralPath $installer
$dependencySource = Get-Content -Raw -LiteralPath $dependencyInstaller
$verifierSource = Get-Content -Raw -LiteralPath $verifier
$managedProfilePath = Join-Path $platformRoot "settings\powershell\Microsoft.PowerShell_profile.ps1"
$managedProfileSource = Get-Content -Raw -LiteralPath $managedProfilePath
foreach ($source in @($bootstrapSource, $installerSource)) {
    Assert-True ($source -notmatch '(?im)^\s*(?:&\s*)?(?:choco|scoop)(?:\.exe)?\b') "the default installer must not invoke an undeclared package manager"
    Assert-True ($source -notmatch '(?i)-Verb\s+RunAs') "the default installer must not force elevation"
}
Assert-True ($installerSource -notmatch '(?i)\[switch\]\s*\$Full\b') "the removed full-package mode must not return"
Assert-True ($installerSource.Contains('+Lazy! restore')) "the installer must restore the committed Neovim lockfile"
Assert-True (-not $installerSource.Contains('+Lazy! sync')) "the installer must not update the committed Neovim lockfile"
Assert-True ($dependencySource.Contains('Test-WingetPackageInstalled')) "tool detection must verify the declared winget package, not just a coincidental command"
Assert-True ($verifierSource.Contains('rev-parse HEAD')) "the verifier must compare every plugin checkout with its locked Git commit"
Assert-True ($verifierSource.Contains('Codex adaptive-theme compatibility')) "the verifier must report the adaptive Codex theme guard separately"
Assert-True ($managedProfileSource.Contains('function global:Get-InitLuaTerminalAppearance')) "the managed profile must detect the terminal appearance"
Assert-True ($managedProfileSource.Contains('# init_lua Codex adaptive-theme wrapper')) "the managed profile must carry the adaptive Codex theme wrapper"
Assert-True (Test-Path -LiteralPath (Join-Path $platformRoot "desired-state.json")) "the Windows desired-state manifest must exist"

$desiredState = Get-Content -Raw -LiteralPath (Join-Path $platformRoot "desired-state.json") | ConvertFrom-Json -Depth 100
$codexCompatibility = $desiredState.terminalCompatibility.codexTheme
Assert-True ($codexCompatibility.mode -eq "adaptive-scoped-no-color") "Codex compatibility must detect the terminal before using scoped NO_COLOR"
Assert-True ([bool]$codexCompatibility.detectBeforeLaunch) "Codex compatibility must detect appearance before launch"
Assert-True ($codexCompatibility.lightAction -eq "scoped-no-color") "light terminals must use scoped NO_COLOR"
Assert-True ($codexCompatibility.darkAction -eq "preserve-native-colors") "dark terminals must preserve Codex colors"
Assert-True ($codexCompatibility.unknownAction -eq "preserve-native-colors") "unknown terminals must preserve Codex colors"
Assert-True ($codexCompatibility.overrideVariable -eq "INIT_LUA_TERMINAL_APPEARANCE") "the appearance override must be explicit and documented"
Assert-True ([bool]$codexCompatibility.preserveConfiguredTheme) "Codex compatibility must preserve the configured terminal theme"
Assert-True ([bool]$codexCompatibility.restorePreviousEnvironment) "the Codex wrapper must restore the previous NO_COLOR value"
Assert-True ([bool]$codexCompatibility.globalNoColorForbidden) "the desired state must forbid global NO_COLOR changes"
$declaredWingetIds = @($desiredState.requiredTools | Where-Object manager -eq "winget" | Select-Object -ExpandProperty packageId | Sort-Object)
$expectedWingetIds = @(
    "BurntSushi.ripgrep.MSVC",
    "Git.Git",
    "JanDeDobbeleer.OhMyPosh",
    "Microsoft.PowerShell",
    "Microsoft.WindowsTerminal",
    "Neovim.Neovim",
    "OpenJS.NodeJS.LTS",
    "Python.Python.3.14"
) | Sort-Object
Assert-True (($declaredWingetIds -join ",") -eq ($expectedWingetIds -join ",")) "the Windows package allowlist must remain explicit and complete"

foreach ($directory in @("window", "wsl", "mac")) {
    Assert-True (Test-Path -LiteralPath (Join-Path $repoRoot $directory) -PathType Container) "platform structure must contain $directory"

    $platformPath = Join-Path $repoRoot $directory
    $platformManifest = Get-Content -Raw -LiteralPath (Join-Path $platformPath "desired-state.json") |
        ConvertFrom-Json -Depth 100
    $claudeState = @($platformManifest.requiredTools | Where-Object name -eq "Claude Code")
    Assert-True ($claudeState.Count -eq 1 -and $claudeState[0].manager -eq "native") "$directory must use the official native Claude Code installation"
    Assert-True ([bool]$claudeState[0].authenticationRequired) "$directory must require Claude Code authentication before MATCHED"
    $npmState = @($platformManifest.requiredTools | Where-Object name -eq "npm")
    Assert-True ($npmState.Count -eq 1) "$directory must declare npm because the Neovim environment uses it"

    $lockPath = Join-Path $platformPath "settings\nvim\lazy-lock.json"
    $lockedPlugins = Get-Content -Raw -LiteralPath $lockPath | ConvertFrom-Json -AsHashtable
    Assert-True ($lockedPlugins.Count -eq 43) "$directory must carry the complete 43-plugin reference lockfile"
    foreach ($entry in $lockedPlugins.GetEnumerator()) {
        Assert-True ([string]$entry.Value.commit -match '^[0-9a-f]{40}$') "$directory plugin $($entry.Key) must have an exact Git commit"
    }
}

$platformLockHashes = @(@("window", "wsl", "mac") | ForEach-Object {
    (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repoRoot "$_\settings\nvim\lazy-lock.json")).Hash
} | Select-Object -Unique)
Assert-True ($platformLockHashes.Count -eq 1) "all three platforms must start from the same reference plugin lock"

$platformDirectories = @(Get-ChildItem -LiteralPath $repoRoot -Directory | Select-Object -ExpandProperty Name | Sort-Object)
Assert-True (($platformDirectories -join ",") -eq "mac,window,wsl") "repository must expose exactly the three platform directories"

foreach ($relativePath in @(
    ".github",
    ".claude",
    "claude-config",
    "skills",
    ".bashrc",
    ".zshrc",
    ".tmux.conf",
    ".wslconfig",
    "install.sh",
    "tmux.conf",
    "wt-settings.json",
    "powershell\dayfox.omp.json",
    "powershell\illusi0n.omp.json",
    "scripts\Install-WindowsTerminalKeybindings.ps1"
)) {
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $repoRoot $relativePath))) "obsolete repository asset must stay removed: $relativePath"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "init_lua-profile-$([guid]::NewGuid().ToString('N'))"
$profilePath = Join-Path $tempRoot "PowerShell\Microsoft.PowerShell_profile.ps1"
$nvimConfigPath = Join-Path $tempRoot "nvim"
New-Item -ItemType Directory -Path (Split-Path $profilePath -Parent) -Force | Out-Null
New-Item -ItemType Directory -Path $nvimConfigPath -Force | Out-Null

try {
    $codexBin = Join-Path $tempRoot "codex-bin"
    $codexCapturePath = Join-Path $tempRoot "codex-capture.json"
    $codexHarnessPath = Join-Path $tempRoot "Test-CodexAdaptiveThemeGuard.ps1"
    $codexLocalAppData = Join-Path $tempRoot "local-app-data"
    New-Item -ItemType Directory -Path $codexBin, $codexLocalAppData -Force | Out-Null

    @'
[pscustomobject]@{
    NoColor = $env:NO_COLOR
    Arguments = @($args)
} | ConvertTo-Json -Depth 4 -Compress |
    Set-Content -LiteralPath $env:INIT_LUA_CODEX_CAPTURE -Encoding utf8NoBOM
if ($args.Count -gt 0 -and $args[0] -eq "fail") {
    throw "simulated Codex failure"
}
'@ | Set-Content -LiteralPath (Join-Path $codexBin "codex.ps1") -Encoding utf8NoBOM

    @'
param(
    [Parameter(Mandatory)] [string]$ProfilePath,
    [Parameter(Mandatory)] [string]$CodexBin,
    [Parameter(Mandatory)] [string]$CapturePath,
    [Parameter(Mandatory)] [string]$LocalAppDataPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$env:LOCALAPPDATA = $LocalAppDataPath
$env:Path = $CodexBin
$env:INIT_LUA_CODEX_CAPTURE = $CapturePath
$env:WT_SESSION = "init-lua-test-session"
$env:WT_PROFILE_ID = "{11111111-1111-1111-1111-111111111111}"
$settingsPath = Join-Path $LocalAppDataPath "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
New-Item -ItemType Directory -Path (Split-Path $settingsPath -Parent) -Force | Out-Null
Remove-Item Env:NO_COLOR, Env:COLORFGBG, Env:INIT_LUA_TERMINAL_APPEARANCE -ErrorAction SilentlyContinue

function Assert-Equal {
    param(
        [Parameter()] [AllowNull()] [object]$Actual,
        [Parameter()] [AllowNull()] [object]$Expected,
        [Parameter(Mandatory)] [string]$Message
    )

    if ($Actual -ne $Expected) {
        throw "$Message (expected: $Expected; actual: $Actual)"
    }
}

function Write-TestTerminalSettings {
    param(
        [Parameter(Mandatory)] [string]$Theme,
        [Parameter(Mandatory)] [string]$Background,
        [Parameter()] [switch]$Paired,
        [Parameter()] [string]$ProfileBackground
    )

    $profile = [ordered]@{ guid = $env:WT_PROFILE_ID; name = "Test PowerShell" }
    if (-not [string]::IsNullOrWhiteSpace($ProfileBackground)) {
        $profile["background"] = $ProfileBackground
    }

    if ($Paired) {
        $colorScheme = [ordered]@{ light = "Test Light"; dark = "Test Dark" }
        $schemes = @(
            [ordered]@{ name = "Test Light"; background = "#F6F2EE" },
            [ordered]@{ name = "Test Dark"; background = "#101010" }
        )
    } else {
        $colorScheme = "Test Scheme"
        $schemes = @([ordered]@{ name = "Test Scheme"; background = $Background })
    }

    [ordered]@{
        theme = $Theme
        defaultProfile = $env:WT_PROFILE_ID
        profiles = [ordered]@{
            defaults = [ordered]@{ colorScheme = $colorScheme }
            list = @($profile)
        }
        schemes = $schemes
    } | ConvertTo-Json -Depth 10 |
        Set-Content -LiteralPath $settingsPath -Encoding utf8NoBOM
}

function Read-CodexCapture {
    return Get-Content -Raw -LiteralPath $CapturePath | ConvertFrom-Json
}

. $ProfilePath
if (Test-Path Env:NO_COLOR) {
    throw "loading the profile must not set NO_COLOR globally"
}

Write-TestTerminalSettings -Theme "legacyLight" -Background "#F6F2EE"
Assert-Equal (Get-InitLuaTerminalAppearance) "Light" "a light Windows Terminal scheme must be detected"
$env:NO_COLOR = "preserve-me"
codex alpha "two words"
$capture = Read-CodexCapture
Assert-Equal $capture.NoColor "1" "a light terminal must give the child Codex process NO_COLOR=1"
if (@($capture.Arguments).Count -ne 2 -or
    $capture.Arguments[0] -ne "alpha" -or
    $capture.Arguments[1] -ne "two words") {
    throw "the wrapper must forward every Codex argument unchanged"
}
if ($env:NO_COLOR -ne "preserve-me") {
    throw "the wrapper must restore a pre-existing NO_COLOR value"
}

$env:NO_COLOR = "restore-after-error"
$failureObserved = $false
try {
    codex fail
} catch {
    $failureObserved = $true
}
if (-not $failureObserved -or $env:NO_COLOR -ne "restore-after-error") {
    throw "the wrapper must restore NO_COLOR when Codex fails"
}

Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue
Write-TestTerminalSettings -Theme "legacyDark" -Background "#101010"
Assert-Equal (Get-InitLuaTerminalAppearance) "Dark" "a dark Windows Terminal scheme must be detected"
codex dark
$capture = Read-CodexCapture
if ($null -ne $capture.NoColor) {
    throw "a dark terminal must preserve native Codex colors"
}
if (Test-Path Env:NO_COLOR) {
    throw "a dark terminal must not create NO_COLOR"
}

Write-TestTerminalSettings -Theme "legacyLight" -Background "#000000" -Paired
Assert-Equal (Get-InitLuaTerminalAppearance) "Light" "a paired scheme must follow a light application theme"
Write-TestTerminalSettings -Theme "legacyDark" -Background "#FFFFFF" -Paired
Assert-Equal (Get-InitLuaTerminalAppearance) "Dark" "a paired scheme must follow a dark application theme"
Write-TestTerminalSettings -Theme "legacyLight" -Background "#F6F2EE" -ProfileBackground "#101010"
Assert-Equal (Get-InitLuaTerminalAppearance) "Dark" "an explicit profile background must override its scheme"

Remove-Item -LiteralPath $settingsPath -Force
Assert-Equal (Get-InitLuaTerminalAppearance) "Unknown" "an unreadable Windows Terminal appearance must remain unknown"
codex unknown
$capture = Read-CodexCapture
if ($null -ne $capture.NoColor -or (Test-Path Env:NO_COLOR)) {
    throw "an unknown terminal must preserve native Codex colors"
}

$env:INIT_LUA_TERMINAL_APPEARANCE = "light"
Assert-Equal (Get-InitLuaTerminalAppearance) "Light" "the explicit light override must win"
codex override-light
$capture = Read-CodexCapture
Assert-Equal $capture.NoColor "1" "the explicit light override must enable the scoped guard"
if (Test-Path Env:NO_COLOR) {
    throw "the explicit light override must not leak NO_COLOR"
}

Write-TestTerminalSettings -Theme "legacyLight" -Background "#F6F2EE"
$env:INIT_LUA_TERMINAL_APPEARANCE = "dark"
Assert-Equal (Get-InitLuaTerminalAppearance) "Dark" "the explicit dark override must win"
codex override-dark
$capture = Read-CodexCapture
if ($null -ne $capture.NoColor) {
    throw "the explicit dark override must preserve native Codex colors"
}

Remove-Item Env:INIT_LUA_TERMINAL_APPEARANCE, Env:WT_SESSION, Env:WT_PROFILE_ID -ErrorAction SilentlyContinue
$env:COLORFGBG = "0;15"
Assert-Equal (Get-InitLuaTerminalAppearance) "Light" "COLORFGBG must detect a standard light background"
$env:COLORFGBG = "15;0"
Assert-Equal (Get-InitLuaTerminalAppearance) "Dark" "COLORFGBG must detect a standard dark background"
'@ | Set-Content -LiteralPath $codexHarnessPath -Encoding utf8NoBOM

    $pwsh = Get-Command pwsh -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $codexHarnessOutput = @(& $pwsh.Source -NoProfile -File $codexHarnessPath `
        -ProfilePath $managedProfilePath `
        -CodexBin $codexBin `
        -CapturePath $codexCapturePath `
        -LocalAppDataPath $codexLocalAppData 2>&1)
    Assert-True ($LASTEXITCODE -eq 0) "the Codex wrapper behavior test must pass: $($codexHarnessOutput -join ' | ')"

    @'
# Personal content must survive init_lua updates.
function Get-PersonalGreeting {
    "hello"
}
'@ | Set-Content -LiteralPath $profilePath -Encoding utf8NoBOM
    "return { personal = true }" | Set-Content -LiteralPath (Join-Path $nvimConfigPath "personal.lua") -Encoding utf8NoBOM

    $first = & $installer `
        -SkipDependencyInstall `
        -SkipClaudeCodeInstall `
        -SkipOhMyPoshInstall `
        -SkipFontInstall `
        -SkipNvimPluginInstall `
        -SkipWindowsTerminalEnvironment `
        -SkipVerification `
        -ProfilePath $profilePath `
        -NvimConfigPath $nvimConfigPath `
        -PassThru

    $installedProfile = Get-Content -Raw -LiteralPath $profilePath
    $themePath = Join-Path (Split-Path $profilePath -Parent) "illusi0n-dayfox.omp.json"
    $themeSource = Join-Path $platformRoot "settings\oh-my-posh\illusi0n-dayfox.omp.json"

    Assert-True ($installedProfile.Contains("Get-PersonalGreeting")) "personal profile content must be preserved"
    Assert-True ([regex]::Matches($installedProfile, '# >>> init_lua terminal environment >>>').Count -eq 1) "the managed profile block must be inserted once"
    Assert-True ($installedProfile.Contains("Join-Path `$PSScriptRoot 'illusi0n-dayfox.omp.json'")) "the managed profile must resolve its theme beside itself"
    Assert-True (Test-Path -LiteralPath $first.ProfileBackup) "the original profile must be backed up"
    Assert-True (Test-Path -LiteralPath $themePath) "the managed theme must be copied beside the profile"
    Assert-True ((Get-FileHash -LiteralPath $themeSource -Algorithm SHA256).Hash -eq
        (Get-FileHash -LiteralPath $themePath -Algorithm SHA256).Hash) "the installed Oh My Posh theme must match the repository"
    Assert-True (Test-Path -LiteralPath (Join-Path $nvimConfigPath "init.lua")) "the platform Neovim entry point must be synchronized"
    Assert-True (Test-Path -LiteralPath (Join-Path $nvimConfigPath "personal.lua")) "unmanaged Neovim files must be preserved"
    Assert-True (Test-Path -LiteralPath $first.NvimBackup -PathType Container) "an existing Neovim directory must be backed up before managed files change"

    $backupCountBeforeSecondRun = @(Get-ChildItem -LiteralPath (Split-Path $profilePath -Parent) -Filter "*.backup_*" -File).Count
    $second = & $installer `
        -SkipDependencyInstall `
        -SkipClaudeCodeInstall `
        -SkipOhMyPoshInstall `
        -SkipFontInstall `
        -SkipNvimPluginInstall `
        -SkipWindowsTerminalEnvironment `
        -SkipVerification `
        -ProfilePath $profilePath `
        -NvimConfigPath $nvimConfigPath `
        -PassThru
    $backupCountAfterSecondRun = @(Get-ChildItem -LiteralPath (Split-Path $profilePath -Parent) -Filter "*.backup_*" -File).Count

    Assert-True ($null -eq $second.NvimBackup -and $null -eq $second.ProfileBackup -and $null -eq $second.ThemeBackup) "an idempotent second run must not report backups"
    Assert-True ($backupCountAfterSecondRun -eq $backupCountBeforeSecondRun) "an idempotent second run must not create backups"

    $verification = @(& $verifier -ProfilePath $profilePath -NvimConfigPath $nvimConfigPath -SkipTerminalChecks -SkipToolChecks -SkipPluginChecks -PassThru)
    foreach ($checkName in @("Neovim configuration", "PowerShell profile block", "Codex adaptive-theme compatibility", "Oh My Posh theme")) {
        $check = @($verification | Where-Object Check -eq $checkName)
        Assert-True ($check.Count -eq 1 -and $check[0].Status -eq "PASS") "$checkName verification must pass"
    }

    $profileWithoutCodexGuard = $installedProfile.Replace(
        "# init_lua Codex adaptive-theme wrapper",
        "# Codex adaptive-theme wrapper removed for verifier test"
    )
    [System.IO.File]::WriteAllText(
        $profilePath,
        $profileWithoutCodexGuard,
        [System.Text.UTF8Encoding]::new($false)
    )
    $guardVerification = @(& $verifier -ProfilePath $profilePath -NvimConfigPath $nvimConfigPath -SkipTerminalChecks -SkipToolChecks -SkipPluginChecks -PassThru)
    $guardCheck = @($guardVerification | Where-Object Check -eq "Codex adaptive-theme compatibility")
    Assert-True ($guardCheck.Count -eq 1 -and $guardCheck[0].Status -eq "FAIL") "the verifier must reject a missing adaptive Codex theme guard"
    [System.IO.File]::WriteAllText(
        $profilePath,
        $installedProfile,
        [System.Text.UTF8Encoding]::new($false)
    )

    Remove-Item -LiteralPath $themePath -Force
    $strictRejectedMismatch = $false
    try {
        & $verifier `
            -ProfilePath $profilePath `
            -NvimConfigPath $nvimConfigPath `
            -SkipTerminalChecks `
            -SkipToolChecks `
            -SkipPluginChecks `
            -Strict | Out-Null
    } catch {
        $strictRejectedMismatch = $true
    }
    Assert-True $strictRejectedMismatch "strict verification must reject a missing managed theme instead of reporting success"

    Write-Host "PASS: complete installer, adaptive Codex theme guard, explicit package policy, strict mismatch rejection, repository pruning, and idempotency" -ForegroundColor Green
} finally {
    $resolvedTemp = [System.IO.Path]::GetFullPath($tempRoot)
    $systemTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if ($resolvedTemp.StartsWith($systemTemp, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $resolvedTemp)) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
