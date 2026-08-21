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
foreach ($source in @($bootstrapSource, $installerSource)) {
    Assert-True ($source -notmatch '(?im)^\s*(?:&\s*)?(?:choco|scoop)(?:\.exe)?\b') "the default installer must not invoke an undeclared package manager"
    Assert-True ($source -notmatch '(?i)-Verb\s+RunAs') "the default installer must not force elevation"
}
Assert-True ($installerSource -notmatch '(?i)\[switch\]\s*\$Full\b') "the removed full-package mode must not return"
Assert-True ($installerSource.Contains('+Lazy! restore')) "the installer must restore the committed Neovim lockfile"
Assert-True (-not $installerSource.Contains('+Lazy! sync')) "the installer must not update the committed Neovim lockfile"
Assert-True ($dependencySource.Contains('Test-WingetPackageInstalled')) "tool detection must verify the declared winget package, not just a coincidental command"
Assert-True ($verifierSource.Contains('rev-parse HEAD')) "the verifier must compare every plugin checkout with its locked Git commit"
Assert-True (Test-Path -LiteralPath (Join-Path $platformRoot "desired-state.json")) "the Windows desired-state manifest must exist"

$desiredState = Get-Content -Raw -LiteralPath (Join-Path $platformRoot "desired-state.json") | ConvertFrom-Json -Depth 100
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

    $codexBin = Join-Path $tempRoot "codex-bin"
    $codexCapturePath = Join-Path $tempRoot "codex-capture.json"
    $codexHarnessPath = Join-Path $tempRoot "Test-CodexWtSessionWorkaround.ps1"
    New-Item -ItemType Directory -Path $codexBin -Force | Out-Null

    @'
[pscustomobject]@{
    WtSessionPresent = (Test-Path Env:WT_SESSION)
    WtSession = $env:WT_SESSION
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
    [Parameter(Mandatory)] [string]$CapturePath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$env:Path = $CodexBin
$env:INIT_LUA_CODEX_CAPTURE = $CapturePath
$env:WT_SESSION = "init-lua-test-session"
$env:NO_COLOR = "preserve-me"

function Read-CodexCapture {
    return Get-Content -Raw -LiteralPath $CapturePath | ConvertFrom-Json
}

. $ProfilePath
if ($env:WT_SESSION -ne "init-lua-test-session") {
    throw "loading the profile must not change WT_SESSION globally"
}

codex alpha "two words"
$capture = Read-CodexCapture
if ($capture.WtSessionPresent -or $null -ne $capture.WtSession) {
    throw "the Codex child process must not receive WT_SESSION"
}
if ($capture.NoColor -ne "preserve-me" -or $env:NO_COLOR -ne "preserve-me") {
    throw "the wrapper must preserve NO_COLOR instead of managing Codex colors"
}
if (@($capture.Arguments).Count -ne 2 -or
    $capture.Arguments[0] -ne "alpha" -or
    $capture.Arguments[1] -ne "two words") {
    throw "the wrapper must forward every Codex argument unchanged"
}
if ($env:WT_SESSION -ne "init-lua-test-session") {
    throw "the wrapper must restore WT_SESSION after Codex exits"
}

$env:WT_SESSION = "restore-after-error"
$failureObserved = $false
try {
    codex fail
} catch {
    $failureObserved = $true
}
if (-not $failureObserved -or $env:WT_SESSION -ne "restore-after-error") {
    throw "the wrapper must restore WT_SESSION when Codex fails"
}

Remove-Item Env:WT_SESSION -ErrorAction SilentlyContinue
codex without-session
$capture = Read-CodexCapture
if ($capture.WtSessionPresent -or (Test-Path Env:WT_SESSION)) {
    throw "the wrapper must not create WT_SESSION when it was initially absent"
}
'@ | Set-Content -LiteralPath $codexHarnessPath -Encoding utf8NoBOM

    $pwsh = Get-Command pwsh -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $codexHarnessOutput = @(& $pwsh.Source -NoProfile -File $codexHarnessPath `
        -ProfilePath $profilePath `
        -CodexBin $codexBin `
        -CapturePath $codexCapturePath 2>&1)
    Assert-True ($LASTEXITCODE -eq 0) "the Codex WT_SESSION workaround behavior test must pass: $($codexHarnessOutput -join ' | ')"

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
    foreach ($checkName in @("Neovim configuration", "PowerShell profile block", "Codex WT_SESSION compatibility", "Oh My Posh theme")) {
        $check = @($verification | Where-Object Check -eq $checkName)
        Assert-True ($check.Count -eq 1 -and $check[0].Status -eq "PASS") "$checkName verification must pass"
    }

    $profileWithoutCodexWorkaround = $installedProfile.Replace(
        "# init_lua Codex WT_SESSION theme workaround",
        "# Codex WT_SESSION workaround removed for verifier test"
    )
    [System.IO.File]::WriteAllText(
        $profilePath,
        $profileWithoutCodexWorkaround,
        [System.Text.UTF8Encoding]::new($false)
    )
    $compatibilityVerification = @(& $verifier -ProfilePath $profilePath -NvimConfigPath $nvimConfigPath -SkipTerminalChecks -SkipToolChecks -SkipPluginChecks -PassThru)
    $compatibilityCheck = @($compatibilityVerification | Where-Object Check -eq "Codex WT_SESSION compatibility")
    Assert-True ($compatibilityCheck.Count -eq 1 -and $compatibilityCheck[0].Status -eq "FAIL") "the verifier must reject a missing Codex WT_SESSION workaround"
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

    Write-Host "PASS: complete installer, Codex WT_SESSION compatibility, strict mismatch rejection, repository pruning, and idempotency" -ForegroundColor Green
} finally {
    $resolvedTemp = [System.IO.Path]::GetFullPath($tempRoot)
    $systemTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if ($resolvedTemp.StartsWith($systemTemp, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $resolvedTemp)) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
