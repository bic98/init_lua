# Windows Terminal pane and tab shortcuts

`init_lua` installs the shortcuts below without replacing the user's full
Windows Terminal configuration. The installer backs up `settings.json`, keeps
profiles, colors, fonts, and the default profile, and merges only `actions` and
`keybindings`.

## Shortcut map

### Panes

| Shortcut | Action |
|---|---|
| `Alt+\` | Split the focused pane to the right |
| `Alt+-` | Split the focused pane downward |
| `Alt+Shift+D` | Duplicate the focused pane automatically |
| `Alt+H/J/K/L` | Move focus left/down/up/right |
| `Alt+Shift+H/J/K/L` | Swap the focused pane left/down/up/right |
| `Ctrl+Alt+H/J/K/L` | Resize the focused pane left/down/up/right |
| `Alt+[` / `Alt+]` | Focus the previous/next pane in creation order |
| `Alt+Z` | Zoom or restore the focused pane |
| `Alt+W` | Close the focused pane |

### Tabs

| Shortcut | Action |
|---|---|
| `Alt+C` | Open a new tab |
| `Alt+Shift+W` | Close the current tab |
| `Alt+N` / `Alt+P` | Select the next/previous tab |
| `Alt+1` ... `Alt+9` | Select tabs 1 through 9 |
| `Alt+,` | Rename the current tab |

## Install

The normal Windows setup includes the shortcut merge:

```powershell
pwsh -File .\install.ps1
```

Run only the Windows Terminal step:

```powershell
pwsh -File .\scripts\Install-WindowsTerminalKeybindings.ps1
```

Use a specific settings file when testing Preview, Canary, or a portable
installation:

```powershell
pwsh -File .\scripts\Install-WindowsTerminalKeybindings.ps1 `
  -SettingsPath "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
```

Skip the shortcut merge during a full setup:

```powershell
pwsh -File .\install.ps1 -SkipWindowsTerminalKeybindings
```

## Safety and conflict behavior

- The installer requires PowerShell 7 or later.
- It selects the first existing settings file in this order: Stable,
  unpackaged, Preview, Canary.
- Before writing, it creates
  `settings.json.init_lua_backup_yyyyMMdd_HHmmss_fff` beside the settings file.
- If a shortcut already uses an `init_lua` key chord, that chord is reassigned
  to the `init_lua` action. Other keys on the same existing binding remain.
- Actions with the same `User.*` id are replaced. Unrelated actions and
  keybindings remain.
- `wt-settings.json` is a personal full-settings snapshot and is not copied to
  other computers.

To restore a backup, close Windows Terminal and copy the backup over the active
`settings.json`:

```powershell
Copy-Item '<backup path>' '<settings.json path>' -Force
```

## Source and validation

- Portable shortcut source: `windows-terminal/keybindings.json`
- Merge installer: `scripts/Install-WindowsTerminalKeybindings.ps1`
- Regression test: `tests/Install-WindowsTerminalKeybindings.Tests.ps1`
- Official action schema: <https://learn.microsoft.com/windows/terminal/customize-settings/actions>
- Official settings locations: <https://learn.microsoft.com/windows/terminal/faq>

Run the test with:

```powershell
pwsh -NoProfile -File .\tests\Install-WindowsTerminalKeybindings.Tests.ps1
```
