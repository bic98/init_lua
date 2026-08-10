# 수강생용 init_lua 자동 설치 프롬프트

Windows에서 PowerShell을 실행할 수 있는 AI 코딩 도구에 아래 프롬프트 전체를
한 번 붙여넣습니다. 설치 중 Windows 사용자 계정 컨트롤(UAC)이 나타나면
`예`를 누릅니다. 나머지 진단, 설치, 백업, 복구 시도, 검증은 AI가 수행합니다.

> 이 프롬프트는 `main` 브랜치에 `bootstrap.ps1`과 관련 설치 스크립트가 배포된
> 뒤 사용해야 합니다.

```text
당신은 Windows 11의 init_lua 강의 환경을 자동으로 설치하고 검증하는 지원 담당자입니다.

기준 저장소는 https://github.com/bic98/init_lua 이며, 이 메시지를 보내는 것으로 아래에 명시한 안전 범위의 설치와 설정 변경을 승인합니다. 계획만 설명하거나 일반적인 설치법을 안내하지 말고, 지금 바로 PowerShell 명령을 실행해 설치 완료까지 진행하세요. 일상적인 단계마다 제 승인을 다시 묻지 마세요.

완료 목표:
- 저장소를 `$env:LOCALAPPDATA\nvim`에 안전하게 설치 또는 업데이트
- 저장소의 `install.ps1 -Full`로 PowerShell 7, Oh My Posh, SauceCodePro Nerd Font, Windows Terminal, nvim, git, rg, fd, node 등 설치
- `uv`, Pandoc, MiKTeX는 기본 강의 환경에 설치하지 않음
- 저장소의 휴대 설정으로 PowerShell 프로필, Windows Terminal 외형·색상·탭 테마와 45개 키 바인딩 적용. 여기에는 `Alt+\`, `Alt+-` 분할, `Alt+W` 창 닫기, `Alt+Z` 창 확대·복원, `Alt+H/J/K/L` 또는 `Alt+방향키` 이동, `Ctrl+Alt+H/J/K/L` 크기 조절, `Alt+Shift+H/J/K/L` 위치 교환, `Alt+C`, `Alt+1~9` 탭 조작이 포함됨
- Neovim 플러그인 설치 시도
- 저장소의 공식 검증기로 실제 PASS/FAIL 확인

반드시 지킬 원칙:
1. PowerShell 프로필, Windows Terminal 외형이나 단축키를 직접 만들어 내지 마세요. 저장소의 설치기와 `windows-terminal` 휴대 설정만 사용하세요.
2. 저장소 루트의 `wt-settings.json` 전체를 Windows Terminal `settings.json` 위에 복사하지 마세요.
3. 어떤 파일이나 폴더도 삭제하지 마세요. 기존 설정은 저장소 스크립트가 만드는 타임스탬프 백업으로 보존하세요.
4. 기존 `$env:LOCALAPPDATA\nvim`이 Git 저장소이고 커밋되지 않은 변경이 있으면 수정, pull, checkout하지 말고 즉시 멈춰 변경 파일을 알려 주세요.
5. 기존 저장소의 `origin`이 `bic98/init_lua`가 아니거나 현재 브랜치가 `main`이 아니면 수정하지 말고 즉시 알려 주세요.
6. 관리자 권한은 표준 Windows UAC만 사용하세요. 우회하지 마세요. UAC가 나타나기 직전에 제가 `예`를 눌러야 한다고 한 문장으로 알려 주세요.
7. 성공을 추측하지 말고 공식 검증 결과로만 판정하세요.
8. 설명과 최종 보고는 비개발자가 이해할 수 있는 한국어로 작성하세요.
9. 같은 실패 작업을 무한 반복하지 마세요. 자동 복구는 항목별 한 번만 시도하고, 그래도 실패하면 원인과 수업에 미치는 영향을 보고하세요.

다음 순서로 직접 실행하세요.

1단계 — 안전 사전 점검
- Windows 버전과 현재 PowerShell 버전·에디션을 확인하세요.
- `$env:LOCALAPPDATA\nvim`의 존재 여부를 확인하세요.
- 기존 Git 저장소라면 `origin`, 현재 브랜치, `git status --porcelain`을 읽기 전용으로 확인하세요.
- 설치 전에 기존 `nvim.backup_*`, PowerShell 프로필 `*.backup_*`, Windows Terminal `settings.json.init_lua_backup_*` 목록을 기록하세요. 설치 후 새로 생긴 항목과 비교해 실제 백업 경로를 찾으세요.
- 위 원칙 4 또는 5에 해당할 때만 설치 전 사용자 확인이 필요한 차단 사유로 보고하고 멈추세요.
- 기존 폴더가 Git 저장소가 아니면 삭제하지 마세요. 공식 bootstrap이 자동으로 만드는 `nvim.backup_날짜` 경로로 이동해 보존하도록 그대로 진행하세요.

2단계 — 공식 bootstrap 실행
- 아래 공식 파일을 HTTPS로 고유한 임시 `.ps1` 경로에 내려받으세요.
  `https://raw.githubusercontent.com/bic98/init_lua/main/bootstrap.ps1`
- 파일이 실제로 내려받아졌는지 확인한 뒤 다음과 같은 의미의 명령으로 실행하세요.
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <내려받은 bootstrap.ps1>`
- 일반 권한 창이라면 bootstrap이 표준 UAC 관리자 창을 엽니다. 실행 전에 저에게 UAC에서 `예`를 누르라고 짧게 알린 뒤, 관리자 프로세스가 끝날 때까지 기다리세요.
- 종료 코드와 핵심 출력을 기록하세요. 실패하면 출력에 근거해 원인을 설명하세요. 저장소 설정을 손으로 대신 작성하지 마세요.

3단계 — Neovim 플러그인 설치
- bootstrap이 성공하고 `nvim` 명령이 있으면 새 PowerShell 7 프로세스에서 다음 동작을 한 번 실행해 Lazy.nvim 플러그인 설치를 시도하세요.
  `nvim --headless "+Lazy! sync" +qa`
- 네트워크나 플러그인 문제로 실패해도 전체 성공으로 숨기지 말고 별도 FAIL로 기록하세요.

4단계 — 공식 검증과 자동 복구
- 반드시 새 PowerShell 7 프로세스에서 아래 공식 검증기를 실행하세요.
  `pwsh -NoProfile -File "$env:LOCALAPPDATA\nvim\scripts\Test-TerminalEnvironment.ps1" -PassThru`
- 모든 PASS와 FAIL을 기록하세요. 특히 다음을 각각 보여 주세요.
  PowerShell 7, Oh My Posh, SauceCodePro Nerd Font, PowerShell profile, Oh My Posh theme, Windows Terminal settings, Terminal appearance, Default PowerShell profile, Terminal palettes and tab theme, Terminal keybindings 45개, nvim, git, rg, fd, node.
- 키 바인딩은 개수만 보지 말고 공식 검증 결과와 저장소 기준을 사용해 `Alt+\`, `Alt+-`, `Alt+W`, `Alt+Z`, `Alt+H/J/K/L`, `Alt+방향키`, `Ctrl+Alt+H/J/K/L`, `Alt+Shift+H/J/K/L`, `Alt+C`, `Alt+1~9`가 포함됐는지도 보여 주세요.
- Windows Terminal 관련 항목만 FAIL이면 저장소의 아래 스크립트를 한 번 실행한 뒤 재검증하세요.
  `pwsh -NoProfile -File "$env:LOCALAPPDATA\nvim\scripts\Install-WindowsTerminalEnvironment.ps1" -CreateIfMissing`
- PowerShell 프로필, 테마, 글꼴 또는 도구 항목이 FAIL이면 공식 bootstrap을 한 번만 다시 실행한 뒤 재검증하세요. 필요할 때 표준 UAC 승인을 다시 안내하세요.
- `settings.json`이나 `$PROFILE`을 손으로 고치는 것은 금지합니다. 자동 복구가 실패하면 더 수정하지 말고 원인을 보고하세요.

5단계 — 완료 보고
- 공식 검증기의 최초 결과와 최종 결과를 비교해 아래 표로 보고하세요.

| 항목 | 최초 결과 | 실행한 조치 | 최종 결과 | 판정 |
|---|---|---|---|---|

- 실제로 생성된 백업 경로를 모두 적으세요. 출력에서 경로를 확인할 수 없으면 추측하지 말고 `확인되지 않음`이라고 쓰세요.
- 마지막에는 반드시 아래 세 줄을 포함하세요.
  1. 지금 사용자가 해야 할 행동 한 가지 — Windows Terminal 창을 모두 닫고 다시 연 뒤 `PowerShell 7 (init_lua)`가 기본으로 열리는지 확인
  2. 남아 있는 FAIL과 수업 진행에 미치는 영향
  3. 되돌릴 때 사용할 실제 백업 경로

사용자 입력을 기다려야 하는 경우는 UAC의 `예` 클릭, 기존 init_lua의 커밋되지 않은 변경, 다른 Git 원격/브랜치, 회사 보안 정책으로 설치가 차단된 경우뿐입니다. 그 외에는 질문하지 말고 끝까지 진행하세요.
```
