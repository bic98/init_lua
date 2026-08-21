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

Remove-Variable __initLuaEsc, __initLuaOhMyPosh, __initLuaOhMyPoshBin, __initLuaTheme -ErrorAction SilentlyContinue
# <<< init_lua terminal environment <<<
