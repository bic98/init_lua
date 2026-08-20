# Windows Terminal 구성과 단축키

`window/settings/windows-terminal/appearance.json`과 `keybindings.json`은 현재 init_lua Windows Terminal 환경의 원본입니다.

## 외형

| 항목 | 값 |
|---|---|
| 기본 프로필 | Windows Terminal 기본 `PowerShell` |
| 프롬프트 | Oh My Posh + `illusi0n-dayfox.omp.json` |
| 글꼴 | `JetBrainsMono Nerd Font` |
| 본문 색상 | `Dayfox` |
| 창 테마 | `legacyDark` |
| Codex 입력창 | 본문 밝기 자동 판별 후 라이트에서만 실행 범위 보호 |
| 복사 설정 | 선택 즉시 복사 끔, 서식 복사 안 함 |

글꼴 크기, 패딩, 시작 디렉터리, 프로필 명령줄처럼 휴대 설정에 없는 값은 기존 설정을 보존합니다.

## Codex 적응형 테마 호환성

일부 Codex TUI 버전은 Windows Terminal 본문이 Dayfox 라이트 테마여도 입력창에 별도의 어두운 true-color 배경을 그려, Dayfox의 어두운 글자와 겹칠 수 있습니다. Codex 공식 설정의 `tui.theme`는 [구문 강조 테마](https://learn.chatgpt.com/docs/config-file/config-reference)이며 입력창 배경 설정이 아닙니다.

관리 PowerShell 프로필의 `Get-InitLuaTerminalAppearance`는 `codex` 실행 직전에 다음 순서로 본문 밝기를 판별합니다.

1. 선택적 `INIT_LUA_TERMINAL_APPEARANCE=light|dark` 오버라이드
2. Windows Terminal의 현재 프로필 `background`, `colorScheme`, 라이트·다크 쌍과 앱·시스템 테마
3. 다른 터미널이 제공하는 `COLORFGBG`
4. Windows Terminal이 아닌 레거시 콘솔의 배경 팔레트

판정 결과가 `Light`이면 해당 Codex 실행 중에만 `NO_COLOR=1`을 설정하고 정상 종료나 오류 뒤 기존 값을 복원합니다. `Dark` 또는 `Unknown`이면 Codex 기본 색상을 그대로 사용합니다. 현재 판정은 새 PowerShell에서 아래처럼 확인할 수 있습니다.

```powershell
Get-InitLuaTerminalAppearance
```

특수 터미널이라 자동 판별이 불가능한 경우에만 개인 프로필에서 `INIT_LUA_TERMINAL_APPEARANCE`를 `light` 또는 `dark`로 지정할 수 있습니다. 이 값은 판별만 보정하며 다른 CLI의 색상은 바꾸지 않습니다.

따라서 다음 우회는 사용하지 않습니다.

- Windows Terminal 본문을 다크 테마로 변경
- `[Console]::BackgroundColor` 변경
- `tui.theme`를 입력창 배경 옵션처럼 변경
- 사용자 또는 시스템 전역 `NO_COLOR` 설정

개인 프로필에 이미 같은 이름의 함수나 별칭이 있으면 init_lua는 그것을 덮어쓰지 않습니다. 그 경우 개인 `codex` 실행 함수도 같은 실행 범위·원복 원칙을 지켜야 합니다.

## 핵심 키 바인딩 22개

| 키 | 동작 |
|---|---|
| `Alt+,` | 탭 이름 바꾸기 |
| `Alt+Z` | 현재 창 확대·복원 |
| `Alt+W` | 현재 창 닫기 |
| `Alt+←/→/↑/↓` | 분할 창 포커스 이동 |
| `Ctrl+C` | 선택 내용 복사 |
| `Ctrl+V` | 붙여넣기 |
| `Alt+Shift+D` | 현재 창 자동 분할 복제 |
| `Alt+-` | 아래 방향으로 분할 |
| `Alt+\` | 오른쪽 방향으로 분할 |
| `Alt+C` | 새 탭 |
| `Alt+1` ~ `Alt+8` | 1~8번 탭으로 이동 |
| `Alt+9` | 9번 탭으로 이동 |

## 적용

저장소 루트에서 실행합니다.

```powershell
pwsh -NoProfile -File .\window\install.ps1
```

Terminal 설정만 다시 병합하려면 다음 명령을 사용합니다.

```powershell
pwsh -NoProfile -File .\window\scripts\Install-WindowsTerminalEnvironment.ps1
```

병합기는 기존 `settings.json`을 읽고 다음 규칙으로 처리합니다.

- 관련 없는 프로필·색상·테마·액션·키는 유지
- 같은 단축키의 충돌만 휴대 설정 기준으로 정리
- 기본 PowerShell 프로필의 개인 속성은 유지하고 관리 속성만 갱신
- 실제 변경이 있을 때만 원본 옆에 타임스탬프 백업 생성
- 임시 파일을 검증한 뒤 원자적으로 교체
- 두 번째 동일 실행은 파일과 백업을 만들지 않음

현재 상태 확인:

```powershell
pwsh -NoProfile -File .\window\scripts\Test-TerminalEnvironment.ps1
```

출력의 `Codex adaptive-theme compatibility`가 `PASS`여야 관리 프로필에 자동 판별과 실행 범위 보호가 들어간 상태입니다.

적용 후에는 모든 Windows Terminal 창을 닫고 다시 엽니다.
