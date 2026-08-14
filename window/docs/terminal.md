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

## 핵심 키 바인딩 18개

| 키 | 동작 |
|---|---|
| `Alt+,` | 탭 이름 바꾸기 |
| `Alt+Z` | 현재 창 확대·복원 |
| `Alt+W` | 현재 창 닫기 |
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
