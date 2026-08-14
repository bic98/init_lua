# init_lua platform setup

한 저장소에서 Windows, WSL, macOS의 터미널·Neovim 개발 환경을 각각 독립적으로 완전 설치하는 원하는 상태 저장소입니다. AI는 운영체제를 판별하고 필요한 도구 설치부터 strict 검증까지 완료합니다.

## 구조

```text
init_lua/
├─ window/  # Windows용 settings, 설치기, 검증
├─ wsl/     # WSL용 settings, 설치기, 검증
└─ mac/     # macOS용 settings, 설치기, 검증
```

각 폴더는 설치 허용 목록과 버전 기준인 `desired-state.json`, 독립 `settings/`, 설치기, strict verifier를 자체 보유합니다. 관리 설정과 Neovim 플러그인 커밋은 정확히 일치해야 하고 도구 버전은 기준 이상이어야 합니다.

여기서 “완전 일치”는 컴퓨터의 모든 앱을 복제한다는 뜻이 아니라 `desired-state.json`에 선언된 터미널·셸·Neovim 개발 환경 전체가 일치한다는 뜻입니다. 설정 파일과 플러그인 커밋은 정확히 같아야 하고, 외부 도구는 기준 버전 이상이어야 하며, Claude Code는 설치와 로그인 상태까지 검사합니다. 비밀번호·토큰은 저장소에 복사하지 않고 새 장치에서 사용자가 직접 로그인합니다.

| 환경 | 저장소 기본 위치 | Neovim 기본 위치 | 안내 |
|---|---|---|---|
| Windows | `%LOCALAPPDATA%\init_lua` | `%LOCALAPPDATA%\nvim` | [window/README.md](window/README.md) |
| WSL | `${XDG_DATA_HOME:-$HOME/.local/share}/init_lua` | `${XDG_CONFIG_HOME:-$HOME/.config}/nvim` | [wsl/README.md](wsl/README.md) |
| macOS | `${XDG_DATA_HOME:-$HOME/.local/share}/init_lua` | `${XDG_CONFIG_HOME:-$HOME/.config}/nvim` | [mac/README.md](mac/README.md) |

## 권장 설치: AI 프롬프트

[AI_INSTALL.md](AI_INSTALL.md)의 코드 블록 전체를 터미널 실행 권한이 있는 AI 에이전트에 전달합니다. AI가 진단·필수 프로그램 설치·설정 적용·오류 복구·재검증을 수행하며, 필수 검사 하나라도 실패하면 성공으로 보고할 수 없습니다.

- [Windows AI 프롬프트](window/AI_INSTALL.md)
- [WSL AI 프롬프트](wsl/AI_INSTALL.md)
- [macOS AI 프롬프트](mac/AI_INSTALL.md)

## 직접 설치

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/bic98/init_lua/main/window/bootstrap.ps1 | iex
```

WSL:

```bash
curl -fsSL https://raw.githubusercontent.com/bic98/init_lua/main/wsl/bootstrap.sh | bash
```

macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/bic98/init_lua/main/mac/bootstrap.sh | bash
```

## 공통 안전 원칙

- 해당 플랫폼 `desired-state.json`에 선언된 패키지만 표준 패키지 관리자로 설치
- 관리자 권한과 sudo는 선언된 시스템 패키지 설치에만 사용
- 다른 Git 원격, 다른 브랜치, 로컬 변경을 덮어쓰지 않음
- 셸과 PowerShell 프로필은 마커 사이의 관리 블록만 갱신
- 기존 Neovim·터미널 설정은 변경 전에 타임스탬프 백업
- 관리 대상 밖의 개인 파일과 속성은 삭제하지 않음
- 같은 설정을 다시 실행하면 불필요한 파일이나 백업을 만들지 않음
- 모든 필수 verifier 검사가 PASS일 때만 설치 성공

예전처럼 저장소 자체가 Neovim 설정 경로에 복제돼 있으면 새 설치기는 그 저장소를 백업 위치로 이동한 뒤 실제 Neovim 설정 디렉터리를 깨끗하게 만듭니다. 설치기의 소스가 그 레거시 저장소 안에 있는 개발 상황에서는 자기 자신을 이동하지 않고 Neovim 동기화만 건너뜁니다.

## 개발 검증

Windows 테스트는 실제 사용자 설정 대신 임시 디렉터리만 사용합니다.

```powershell
pwsh -NoProfile -File .\window\tests\Install-TerminalConfiguration.Tests.ps1
pwsh -NoProfile -File .\window\tests\Install-WindowsTerminalEnvironment.Tests.ps1
```

WSL과 macOS 테스트도 격리된 임시 홈만 사용합니다.

```bash
bash ./wsl/tests/install.Tests.sh
bash ./mac/tests/install.Tests.sh
```
