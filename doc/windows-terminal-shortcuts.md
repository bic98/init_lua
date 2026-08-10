# init_lua Windows Terminal 전체 환경

`init_lua`는 단축키만 배포하지 않습니다. PowerShell 7, Oh My Posh,
SauceCodePro Nerd Font, PowerShell 프로필, Windows Terminal 외형과 조작법,
Neovim을 하나의 재현 가능한 강의 환경으로 설치합니다.

## 수강생 자동 설치

권장 방식은 [수강생용 자동 설치 프롬프트](student-auto-install-prompt.md)를
PowerShell을 실행할 수 있는 AI 코딩 도구에 한 번 붙여넣는 것입니다. AI가 공식
설치기 실행부터 검증까지 진행하며, 수강생은 Windows 사용자 계정 컨트롤(UAC)이
나타날 때 `예`를 누릅니다.

AI 도구를 사용할 수 없으면 일반 권한 Windows PowerShell에서 아래 명령을 직접
실행합니다. bootstrap이 필요한 시점에 표준 UAC 관리자 승인을 요청합니다.

```powershell
$bootstrap = Join-Path $env:TEMP 'init_lua-bootstrap.ps1'
Invoke-WebRequest 'https://raw.githubusercontent.com/bic98/init_lua/main/bootstrap.ps1' -OutFile $bootstrap
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bootstrap
```

설치가 끝나면 Windows Terminal 창을 모두 닫고 다시 실행합니다. 기본으로
열리는 `PowerShell 7 (init_lua)` 프로필이 강의 기준 환경입니다.

## 동일하게 맞춰지는 범위

| 영역 | 기준 상태 |
|---|---|
| 셸 | 안정 버전 PowerShell 7 |
| 프롬프트 | Oh My Posh + `illusi0n-dayfox.omp.json` |
| 글꼴 | SauceCodePro Nerd Font, 10pt, Medium |
| 터미널 본문 | dayfox 색상, 패딩 8, filled-box 커서 |
| 터미널 탭 | Kanagawa Dark 테마 |
| 화면 효과 | 불투명도 100%, Acrylic 끔, 스크롤바 숨김 |
| 복사 동작 | 선택 즉시 복사, 서식 제외 |
| 조작 | 36개 액션과 45개 키 바인딩 |
| 편집기 | 이 저장소의 Neovim 설정과 플러그인 |

기계마다 달라야 하는 항목은 그대로 복사하지 않습니다. Anaconda·WSL·Visual
Studio 같은 동적 프로필, 사용자 이름이 들어간 절대 경로, 앱별 GUID와 로그인
정보는 수강생 PC의 상태를 보존합니다. 대신 `PowerShell 7 (init_lua)`라는
휴대 가능한 프로필을 추가하고 이를 기본 프로필로 지정합니다.

## 단축키

### 패널

| 단축키 | 동작 |
|---|---|
| `Alt+\` | 현재 패널을 오른쪽으로 분할 |
| `Alt+-` | 현재 패널을 아래로 분할 |
| `Alt+Shift+D` | 현재 패널 복제 분할 |
| `Alt+H/J/K/L` 또는 `Alt+←/↓/↑/→` | 포커스를 왼쪽/아래/위/오른쪽으로 이동 |
| `Alt+Shift+H/J/K/L` | 패널 위치를 왼쪽/아래/위/오른쪽으로 교환 |
| `Ctrl+Alt+H/J/K/L` | 패널 크기를 왼쪽/아래/위/오른쪽으로 조절 |
| `Alt+[` / `Alt+]` | 이전/다음 패널로 이동 |
| `Alt+Z` | 현재 패널 확대/복원 |
| `Alt+W` | 현재 패널 닫기 |

### 탭과 공통 동작

| 단축키 | 동작 |
|---|---|
| `Alt+C` | 새 탭 열기 |
| `Alt+Shift+W` | 현재 탭 닫기 |
| `Alt+N` / `Alt+P` | 다음/이전 탭으로 이동 |
| `Alt+1` ... `Alt+9` | 1번부터 9번 탭으로 바로 이동 |
| `Alt+,` | 현재 탭 이름 바꾸기 |
| `Ctrl+C` / `Ctrl+V` | 복사/붙여넣기 |
| `Ctrl+Shift+F` | 터미널 내용 검색 |

기존 Windows Terminal 기본키와 충돌하지 않도록 `Ctrl+W`,
`Ctrl+Shift+W/D/-`, `Ctrl+Numpad0`의 기본 할당은 해제합니다. `Alt+방향키`는
`Alt+H/J/K/L`과 동일하게 분할 패널 포커스를 이동합니다.

## 기존 저장소에서 업데이트

```powershell
Set-Location $env:LOCALAPPDATA\nvim
git pull --ff-only
pwsh -NoProfile -File .\install.ps1
```

Windows Terminal 환경만 다시 적용하려면:

```powershell
pwsh -NoProfile -File .\scripts\Install-WindowsTerminalEnvironment.ps1 -CreateIfMissing
```

단축키만 적용하고 현재 외형은 유지하려면 기존 호환 명령을 사용합니다.

```powershell
pwsh -NoProfile -File .\scripts\Install-WindowsTerminalKeybindings.ps1
```

전체 설치에서 Windows Terminal 단계만 제외하려면:

```powershell
pwsh -NoProfile -File .\install.ps1 -SkipWindowsTerminalEnvironment
```

## 자동 검증

```powershell
pwsh -NoProfile -File .\scripts\Test-TerminalEnvironment.ps1 -Strict
```

다음을 `PASS` 또는 `FAIL`로 출력합니다.

- PowerShell 7, Oh My Posh, Nerd Font
- PowerShell 프로필과 dayfox 프롬프트 테마
- Neovim, Git, ripgrep, fd, Node.js
- Windows Terminal 외형, 기본 PowerShell 프로필, 색상과 탭 테마
- 관리 대상 키 바인딩 45개

## 백업과 충돌 처리

- 기존 `settings.json`은 같은 폴더의
  `settings.json.init_lua_backup_yyyyMMdd_HHmmss_fff`로 먼저 복사됩니다.
- 기존 PowerShell 프로필도 `.backup_yyyyMMdd_HHmmss_fff`로 보존됩니다.
- 외형은 `init_lua`가 관리하는 항목만 갱신합니다. 정의하지 않은 설정은
  유지됩니다.
- `dayfox`, `Kanagawa Wave`, `Solarized Light (복사)`, `Kanagawa Dark`는
  이름 기준으로 갱신하며 다른 색상과 테마는 보존합니다.
- `PowerShell 7 (init_lua)` 프로필만 갱신하며 기존 프로필은 보존합니다.
- 관리 키와 충돌하는 기존 할당에서는 해당 키만 제거합니다. 한 액션에 다른
  키도 있었다면 다른 키는 유지합니다.
- `wt-settings.json`은 개인 PC 전체 스냅샷일 뿐 설치에 사용하지 않습니다.

백업으로 복구하려면 Windows Terminal을 모두 닫고 실행합니다.

```powershell
Copy-Item '<backup path>' '<settings.json path>' -Force
```

## 소스와 테스트

- 외형 기준: `windows-terminal/appearance.json`
- 조작 기준: `windows-terminal/keybindings.json`
- 전체 병합기: `scripts/Install-WindowsTerminalEnvironment.ps1`
- 단축키 전용 호환기: `scripts/Install-WindowsTerminalKeybindings.ps1`
- 검증기: `scripts/Test-TerminalEnvironment.ps1`
- 회귀 테스트: `tests/Install-WindowsTerminalEnvironment.Tests.ps1`

```powershell
pwsh -NoProfile -File .\tests\Install-WindowsTerminalEnvironment.Tests.ps1
pwsh -NoProfile -File .\tests\Install-WindowsTerminalKeybindings.Tests.ps1
```

공식 참고 문서:

- <https://learn.microsoft.com/windows/terminal/customize-settings/actions>
- <https://learn.microsoft.com/windows/terminal/faq>
- <https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-windows>
- <https://ohmyposh.dev/docs/installation/fonts>
