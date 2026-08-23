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
| 복사 설정 | 선택 즉시 복사 끔, 서식 복사 안 함 |

글꼴 크기, 패딩, 시작 디렉터리, 프로필 명령줄처럼 휴대 설정에 없는 값은 기존 설정을 보존합니다.

## Codex 밝은 테마 호환성

Codex CLI `0.148`~`0.149`는 Windows에서 화면에 보이는 Windows Terminal 테마 대신 ConPTY 호환 팔레트를 입력창 배경 계산에 사용할 수 있습니다. Dayfox처럼 밝은 테마에서는 그 결과가 어두운 입력창 위의 어두운 글자로 나타납니다([openai/codex#39418](https://github.com/openai/codex/issues/39418)).

관리 PowerShell 프로필의 `codex` 래퍼는 실행되는 Codex 자식 프로세스에서만 `WT_SESSION`을 잠시 제거하고 `finally`에서 원래 값을 복원합니다. 다른 프로세스의 환경, 전역 `NO_COLOR`, Codex `tui.theme`은 변경하지 않습니다. 사용자가 먼저 정의한 `codex` 함수나 별칭이 있으면 해당 사용자 정의를 우선합니다. 업스트림 수정 버전이 배포되면 이 임시 래퍼와 테스트를 제거합니다.

## 핵심 키 바인딩 34개

| 키 | 동작 |
|---|---|
| `Alt+,` | 탭 이름 바꾸기 |
| `Alt+Z` | 현재 창 확대·복원 |
| `Alt+W` | 현재 창 닫기 |
| `Alt+H/J/K/L` 또는 `Alt+←/↓/↑/→` | 분할 창 포커스를 왼쪽/아래/위/오른쪽으로 이동 |
| `Ctrl+Alt+H/J/K/L` | 분할 창 크기를 왼쪽/아래/위/오른쪽으로 조절 |
| `Alt+Shift+H/J/K/L` | 분할 창 위치를 왼쪽/아래/위/오른쪽으로 교환 |
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

적용 후에는 모든 Windows Terminal 창을 닫고 다시 엽니다.
