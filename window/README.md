# Windows

Windows에서는 [desired-state.json](desired-state.json)의 Git, PowerShell 7, Windows Terminal, Neovim, Node.js, Python, ripgrep, Claude Code, Oh My Posh와 글꼴을 설치하고 플랫폼 설정·잠금 플러그인·Mason 도구를 모두 적용합니다.

## 설치

```powershell
irm https://raw.githubusercontent.com/bic98/init_lua/main/window/bootstrap.ps1 | iex
```

이미 저장소가 있으면 루트에서 실행합니다.

```powershell
pwsh -NoProfile -File .\window\install.ps1
```

Windows App Installer(`winget`)만 선행 조건입니다. 설치기는 원하는 상태에 선언된 정확한 winget ID와 Claude Code 공식 네이티브 설치기만 사용하며 Chocolatey와 Scoop은 사용하지 않습니다.

선택 단계:

```powershell
pwsh -NoProfile -File .\window\install.ps1 `
  -SkipNvimConfiguration `
  -SkipNvimPluginInstall `
  -SkipDependencyInstall `
  -SkipOhMyPoshInstall `
  -SkipFontInstall `
  -SkipWindowsTerminalEnvironment `
  -SkipVerification
```

skip 옵션은 부분 설치나 테스트용이며 하나라도 사용하면 완전 일치로 판정하지 않습니다. 기존 프로필과 Terminal 설정은 관리 블록·관리 속성만 갱신하며 실제 변경이 있을 때만 백업합니다. 레거시 `%LOCALAPPDATA%\nvim` 저장소는 전체 백업 후 실제 Neovim 설정으로 전환합니다.

관리 PowerShell 프로필에는 Windows Terminal의 밝은 테마에서 Codex CLI `0.148`~`0.149` 입력창이 어둡게 렌더링되는 [업스트림 회귀](https://github.com/openai/codex/issues/39418)의 임시 우회책이 포함됩니다. `codex` 자식 프로세스에서만 `WT_SESSION`을 제거하고 종료 뒤 원래 값을 복원하므로 전역 터미널 환경과 Codex 색상은 유지합니다. `NO_COLOR`나 Codex `tui.theme`은 변경하지 않습니다.

Claude Code를 새로 설치한 장치는 `claude auth login`의 브라우저 로그인이 필요합니다. AI 설치 프롬프트는 이 사용자 단계가 끝난 뒤 검증을 계속하며, 직접 설치에서는 로그인 후 설치기를 다시 실행하면 됩니다.

권장 설치는 [AI_INSTALL.md](AI_INSTALL.md) 프롬프트입니다. 검증은 `pwsh -NoProfile -File .\window\scripts\Test-TerminalEnvironment.ps1 -Strict`, 단축키는 [docs/terminal.md](docs/terminal.md)를 사용합니다.
