# Windows 완전 설치 AI 프롬프트

```text
이것은 설명 요청이 아니라 실제 설치 요청이다. 이 환경이 WSL이 아닌 네이티브 Windows인지 확인하고 https://github.com/bic98/init_lua 의 `window` 원하는 상태로 수렴시켜라.

먼저 `window/desired-state.json`과 `window`의 README·bootstrap·install·scripts를 읽어라. `%LOCALAPPDATA%\init_lua`, `%LOCALAPPDATA%\nvim`, PowerShell 프로필, Windows Terminal settings.json의 기존 상태와 필수 명령 버전을 기록한다.

원하는 상태에 적힌 정확한 winget ID와 Claude Code 공식 네이티브 설치기만 설치·업그레이드에 사용해도 된다. 필요한 UAC와 패키지 동의도 이 범위에서 허용한다. App Installer 부재, 로그인, 재부팅처럼 AI가 완료할 수 없는 동작만 사용자에게 요청하고 완료 후 계속한다. Chocolatey와 Scoop은 사용하지 않는다.

저장소가 없으면 `window/bootstrap.ps1`로 복제와 설치를 한 번에 실행한다. 이미 올바른 저장소 안이면 bootstrap을 다시 실행하지 말고 기본 `window/install.ps1`만 skip 옵션 없이 실행한다. PowerShell 프로필은 관리 블록만, Windows Terminal은 관리 속성과 키만 병합한다. 레거시 `%LOCALAPPDATA%\nvim` Git 저장소의 백업을 보존한다. PATH 변경 뒤에는 명령을 다시 탐색한다. Claude Code 인증이 필요하면 사용자 로그인 후 계속한다. `lazy-lock.json`의 모든 플러그인이 정확한 커밋인지 확인한다.

저장소의 PowerShell 프로필에 포함된 Codex 적응형 테마 래퍼를 반드시 유지한다. 래퍼는 `codex` 실행 직전에 터미널 본문을 `Light`, `Dark`, `Unknown`으로 판별하고, `Light`에서만 `NO_COLOR=1`을 해당 실행 범위에 적용한 뒤 기존 값을 복원해야 한다. `Dark`와 `Unknown`에서는 Codex 기본 색상을 유지한다. 입력창 대비를 고친다는 이유로 사용자의 Terminal 테마를 바꾸거나, `[Console]::BackgroundColor` 또는 Codex의 `tui.theme`를 입력창 배경 설정처럼 사용하거나, `NO_COLOR`를 사용자·시스템 전역에 영구 설정하지 않는다. 프로필과 Terminal 설정을 손으로 재작성하지 않는다.

마지막에 `pwsh -NoProfile -File .\window\scripts\Test-TerminalEnvironment.ps1 -Strict`를 실행하고 `Codex adaptive-theme compatibility`를 포함한 모든 검사를 확인한다. FAIL을 원인별로 수정하고 최대 3회 재검증한다. 모든 필수 검사가 PASS일 때만 RESULT: MATCHED라고 보고한다. 하나라도 남으면 RESULT: BLOCKED이며 성공이라고 말하지 않는다.
```
