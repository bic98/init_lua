# >>> init_lua terminal environment >>>
# This Windows block is managed by init_lua. Personal functions and other profile
# content outside the markers are preserved by install.ps1.

$__initLuaOhMyPoshBin = Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\bin'
if ((Test-Path -LiteralPath $__initLuaOhMyPoshBin) -and
    (($env:Path -split ';') -notcontains $__initLuaOhMyPoshBin)) {
    $env:Path += ";$__initLuaOhMyPoshBin"
}

$__initLuaOhMyPosh = Get-Command oh-my-posh -ErrorAction SilentlyContinue | Select-Object -First 1
$__initLuaTheme = Join-Path $PSScriptRoot 'illusi0n-dayfox.omp.json'
if ($__initLuaOhMyPosh -and (Test-Path -LiteralPath $__initLuaTheme)) {
    & $__initLuaOhMyPosh init pwsh --config $__initLuaTheme | Invoke-Expression
}

# Dayfox light-background colors for interactive PowerShell output.
if (Get-Module PSReadLine) {
    $__initLuaEsc = [char]27
    Set-PSReadLineOption -Colors @{
        Command                = '#2848a9'
        Parameter              = '#534c45'
        Operator               = '#3d2b5a'
        Variable               = '#287980'
        String                 = '#396847'
        Number                 = '#ac5402'
        Type                   = '#6e33ce'
        Keyword                = '#6e33ce'
        Member                 = '#9e5f22'
        Comment                = '#6b635c'
        Default                = '#3d2b5a'
        Error                  = '#a5222f'
        Emphasis               = "$__initLuaEsc[1;38;2;172;84;2m"
        InlinePrediction       = '#7d746b'
        ListPrediction         = '#52775d'
        Selection              = "$__initLuaEsc[38;2;61;43;90;48;2;231;210;190m"
        ListPredictionSelected = "$__initLuaEsc[48;2;231;210;190m"
    }
}

$__initLuaEsc = [char]27
$PSStyle.FileInfo.Directory    = "$__initLuaEsc[1;38;2;40;72;169m"
$PSStyle.FileInfo.SymbolicLink = "$__initLuaEsc[38;2;40;121;128m"
$PSStyle.FileInfo.Executable   = "$__initLuaEsc[38;2;57;104;71m"

# Resolve the effective terminal body as Light, Dark, or Unknown. Windows
# Terminal's console compatibility API can report Black even for a light custom
# scheme, so inspect the active profile and scheme before using that fallback.
function global:Get-InitLuaTerminalAppearance {
    [CmdletBinding()]
    param()

    function Get-InitLuaPropertyValue {
        param(
            [Parameter()]
            [AllowNull()]
            [object]$InputObject,

            [Parameter(Mandatory)]
            [string]$Name
        )

        if ($null -eq $InputObject) {
            return $null
        }
        $property = $InputObject.PSObject.Properties[$Name]
        if ($null -eq $property) {
            return $null
        }
        return $property.Value
    }

    function Get-InitLuaAppearanceFromColor {
        param(
            [Parameter()]
            [AllowNull()]
            [string]$Color
        )

        if ([string]::IsNullOrWhiteSpace($Color)) {
            return 'Unknown'
        }
        $match = [regex]::Match(
            $Color.Trim(),
            '^#(?<hex>[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$'
        )
        if (-not $match.Success) {
            return 'Unknown'
        }

        $hex = $match.Groups['hex'].Value
        if ($hex.Length -eq 3) {
            $hex = -join @(
                $hex[0], $hex[0],
                $hex[1], $hex[1],
                $hex[2], $hex[2]
            )
        } elseif ($hex.Length -eq 8) {
            $hex = $hex.Substring(0, 6)
        }

        $red = [Convert]::ToInt32($hex.Substring(0, 2), 16)
        $green = [Convert]::ToInt32($hex.Substring(2, 2), 16)
        $blue = [Convert]::ToInt32($hex.Substring(4, 2), 16)
        $perceivedBrightness = (($red * 299) + ($green * 587) + ($blue * 114)) / 1000
        if ($perceivedBrightness -ge 128) {
            return 'Light'
        }
        return 'Dark'
    }

    function Get-InitLuaWindowsApplicationAppearance {
        param(
            [Parameter(Mandatory)]
            [object]$Settings
        )

        $themeName = [string](Get-InitLuaPropertyValue -InputObject $Settings -Name 'theme')
        $applicationTheme = $themeName
        if ([string]::IsNullOrWhiteSpace($applicationTheme)) {
            $applicationTheme = 'dark'
        } elseif ($applicationTheme -notmatch '^(?i:light|dark|system|legacyLight|legacyDark)$') {
            $customTheme = @(
                (Get-InitLuaPropertyValue -InputObject $Settings -Name 'themes') |
                    Where-Object {
                        [string](Get-InitLuaPropertyValue -InputObject $_ -Name 'name') -eq $themeName
                    } |
                    Select-Object -First 1
            )
            if ($customTheme.Count -eq 1) {
                $windowTheme = Get-InitLuaPropertyValue -InputObject $customTheme[0] -Name 'window'
                $applicationTheme = [string](
                    Get-InitLuaPropertyValue -InputObject $windowTheme -Name 'applicationTheme'
                )
            }
        }

        switch -Regex ($applicationTheme) {
            '^(?i:light|legacyLight)$' { return 'Light' }
            '^(?i:dark|legacyDark)$' { return 'Dark' }
            '^(?i:system)$' {
                try {
                    $appsUseLightTheme = Get-ItemPropertyValue `
                        -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' `
                        -Name AppsUseLightTheme `
                        -ErrorAction Stop
                    if ([int]$appsUseLightTheme -eq 0) {
                        return 'Dark'
                    }
                    return 'Light'
                } catch {
                    return 'Unknown'
                }
            }
        }
        return 'Unknown'
    }

    $appearanceOverride = [string]$env:INIT_LUA_TERMINAL_APPEARANCE
    switch -Regex ($appearanceOverride.Trim()) {
        '^(?i:light)$' { return 'Light' }
        '^(?i:dark)$' { return 'Dark' }
    }

    $settingsOverride = [string]$env:INIT_LUA_WINDOWS_TERMINAL_SETTINGS
    $isWindowsTerminal =
        -not [string]::IsNullOrWhiteSpace($env:WT_SESSION) -or
        -not [string]::IsNullOrWhiteSpace($env:WT_PROFILE_ID) -or
        -not [string]::IsNullOrWhiteSpace($settingsOverride)
    if ($isWindowsTerminal) {
        $settingsPaths = [System.Collections.Generic.List[string]]::new()
        if (-not [string]::IsNullOrWhiteSpace($settingsOverride)) {
            $settingsPaths.Add($settingsOverride)
        }
        if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
            foreach ($relativePath in @(
                'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json',
                'Microsoft\Windows Terminal\settings.json',
                'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json',
                'Packages\Microsoft.WindowsTerminalCanary_8wekyb3d8bbwe\LocalState\settings.json'
            )) {
                $settingsPaths.Add((Join-Path $env:LOCALAPPDATA $relativePath))
            }
        }

        foreach ($settingsPath in @($settingsPaths | Select-Object -Unique)) {
            if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
                continue
            }
            try {
                $settings = Get-Content -Raw -LiteralPath $settingsPath |
                    ConvertFrom-Json -Depth 100 -ErrorAction Stop
            } catch {
                continue
            }

            $profiles = Get-InitLuaPropertyValue -InputObject $settings -Name 'profiles'
            $defaults = Get-InitLuaPropertyValue -InputObject $profiles -Name 'defaults'
            $profileList = @(
                (Get-InitLuaPropertyValue -InputObject $profiles -Name 'list') |
                    Where-Object { $null -ne $_ }
            )
            $profileId = [string]$env:WT_PROFILE_ID
            if ([string]::IsNullOrWhiteSpace($profileId)) {
                $profileId = [string](Get-InitLuaPropertyValue -InputObject $settings -Name 'defaultProfile')
            }
            $activeProfile = @(
                $profileList |
                    Where-Object {
                        [string](Get-InitLuaPropertyValue -InputObject $_ -Name 'guid') -eq $profileId
                    } |
                    Select-Object -First 1
            )
            if (-not [string]::IsNullOrWhiteSpace($env:WT_PROFILE_ID) -and
                $activeProfile.Count -eq 0) {
                continue
            }
            $profile = if ($activeProfile.Count -eq 1) { $activeProfile[0] } else { $null }

            $background = [string](Get-InitLuaPropertyValue -InputObject $profile -Name 'background')
            if ([string]::IsNullOrWhiteSpace($background)) {
                $background = [string](Get-InitLuaPropertyValue -InputObject $defaults -Name 'background')
            }
            $backgroundAppearance = Get-InitLuaAppearanceFromColor -Color $background
            if ($backgroundAppearance -ne 'Unknown') {
                return $backgroundAppearance
            }

            $colorScheme = Get-InitLuaPropertyValue -InputObject $profile -Name 'colorScheme'
            if ($null -eq $colorScheme) {
                $colorScheme = Get-InitLuaPropertyValue -InputObject $defaults -Name 'colorScheme'
            }
            if ($null -eq $colorScheme) {
                $colorScheme = 'Campbell'
            }

            $pairedAppearance = 'Unknown'
            $schemeName = ''
            if ($colorScheme -is [string]) {
                $schemeName = [string]$colorScheme
            } else {
                $pairedAppearance = Get-InitLuaWindowsApplicationAppearance -Settings $settings
                if ($pairedAppearance -ne 'Unknown') {
                    $schemeName = [string](
                        Get-InitLuaPropertyValue `
                            -InputObject $colorScheme `
                            -Name $pairedAppearance.ToLowerInvariant()
                    )
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($schemeName)) {
                $scheme = @(
                    (Get-InitLuaPropertyValue -InputObject $settings -Name 'schemes') |
                        Where-Object {
                            [string](Get-InitLuaPropertyValue -InputObject $_ -Name 'name') -eq $schemeName
                        } |
                        Select-Object -First 1
                )
                if ($scheme.Count -eq 1) {
                    $schemeBackground = [string](
                        Get-InitLuaPropertyValue -InputObject $scheme[0] -Name 'background'
                    )
                    $schemeAppearance = Get-InitLuaAppearanceFromColor -Color $schemeBackground
                    if ($schemeAppearance -ne 'Unknown') {
                        return $schemeAppearance
                    }
                }

                if ($schemeName -match '(?i:dark|night|dusk|moon)') {
                    return 'Dark'
                }
                if ($schemeName -match '(?i:light|day|dawn)') {
                    return 'Light'
                }
                if ($schemeName -match '^(?i:Campbell|Campbell Powershell|Vintage)$') {
                    return 'Dark'
                }
            }
            if ($pairedAppearance -ne 'Unknown') {
                return $pairedAppearance
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($env:COLORFGBG)) {
        $colorFgBgParts = @($env:COLORFGBG -split ';')
        $backgroundIndex = $colorFgBgParts[-1]
        if ($backgroundIndex -match '^\d+$') {
            switch ([int]$backgroundIndex) {
                { $_ -in @(0, 8) } { return 'Dark' }
                { $_ -in @(7, 15) } { return 'Light' }
            }
        }
    }

    if ($isWindowsTerminal) {
        return 'Unknown'
    }

    try {
        $consoleBackground = [int][Console]::BackgroundColor
        if ($consoleBackground -in @(0, 1, 2, 3, 4, 5, 6, 8)) {
            return 'Dark'
        }
        if ($consoleBackground -in @(7, 9, 10, 11, 12, 13, 14, 15)) {
            return 'Light'
        }
    } catch {
        return 'Unknown'
    }
    return 'Unknown'
}

# Codex can paint its composer with a dark true-color background on a light
# terminal. Disable Codex colors only after light mode is positively detected.
$__initLuaCodexOverride = Get-Command codex -CommandType Alias, Function -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $__initLuaCodexOverride) {
    function global:codex {
        # init_lua Codex adaptive-theme wrapper
        $__initLuaCodexCommand = Get-Command codex -All -ErrorAction SilentlyContinue |
            Where-Object {
                $_.CommandType -in @(
                    [System.Management.Automation.CommandTypes]::Application,
                    [System.Management.Automation.CommandTypes]::ExternalScript
                )
            } |
            Select-Object -First 1

        if (-not $__initLuaCodexCommand) {
            throw 'Codex executable was not found on PATH.'
        }

        $__initLuaTerminalAppearance = Get-InitLuaTerminalAppearance
        if ($__initLuaTerminalAppearance -ne 'Light') {
            & $__initLuaCodexCommand.Source @args
            return
        }

        $__initLuaPreviousNoColor = $env:NO_COLOR
        try {
            $env:NO_COLOR = '1'
            & $__initLuaCodexCommand.Source @args
        } finally {
            if ($null -eq $__initLuaPreviousNoColor) {
                Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue
            } else {
                $env:NO_COLOR = $__initLuaPreviousNoColor
            }
        }
    }
}

Remove-Variable __initLuaCodexOverride, __initLuaEsc, __initLuaOhMyPosh, __initLuaOhMyPoshBin, __initLuaTheme -ErrorAction SilentlyContinue
# <<< init_lua terminal environment <<<
