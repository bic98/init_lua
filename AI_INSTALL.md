# init_lua 완전 설치 AI 프롬프트

아래 코드 블록 전체를 터미널 실행 권한이 있는 AI 에이전트에 전달합니다. 이 프롬프트가 기본 설치 방법입니다.

```text
이것은 설치 방법을 설명해 달라는 요청이 아니라 실제 설치·복구 실행 요청이다. https://github.com/bic98/init_lua 의 관리 범위 안에서 이 컴퓨터를 저장소의 원하는 상태와 일치시켜라.

관리 범위는 Git, 셸, PowerShell, Windows Terminal, Neovim, 잠금된 Neovim 플러그인, Mason 도구, Oh My Posh, JetBrainsMono Nerd Font, tmux, Node.js, Python, ripgrep, Claude Code CLI와 저장소의 관리 설정이다. PC의 관련 없는 앱과 개인 파일은 범위 밖이다.

1. 읽기 전용으로 네이티브 Windows, WSL, macOS 중 하나를 판별한다. Windows는 `window`, WSL은 `wsl`, macOS는 `mac`만 선택한다. 불명확할 때만 질문한다.
2. 선택한 폴더의 `desired-state.json`, `AI_INSTALL.md`, README, bootstrap, install, scripts를 먼저 읽는다. 원하는 상태 파일이 설치 허용 목록이자 성공 기준이다.
3. 설치 전 필수 명령·버전·대상 경로·기존 Git 상태를 기록한다.
4. 선택한 플랫폼의 표준 패키지 관리자와 관리자 권한 또는 sudo를 원하는 상태에 선언된 항목 설치에만 사용해도 된다. 라이선스 동의도 허용한다. 비밀번호 입력, OS 설치 대화상자, 로그인, 재부팅처럼 사용자가 직접 해야 하는 단계만 요청하고, 완료 후 같은 작업을 계속한다.
5. 저장소가 없으면 선택한 플랫폼의 bootstrap으로 복제와 기본 설치를 한 번에 실행한다. 이미 올바른 저장소 안에서 작업 중이면 bootstrap을 중복 실행하지 말고 해당 플랫폼의 기본 install만 건너뛰기 옵션 없이 실행한다. 기존 Git 원격·로컬 변경·개인 프로필 내용은 보존하며, 관리 파일을 바꾸기 전 백업한다.
6. `lazy-lock.json`에 선언된 모든 Neovim 플러그인을 정확한 커밋으로 복원하고 모든 Mason 도구 설치까지 완료한다. PATH가 바뀌면 현재 프로세스에서 다시 로드하거나 새 셸을 열고 중단한 지점부터 계속한다.
7. 플랫폼의 strict verifier를 실행한다. FAIL이 있으면 원인을 고치고 verifier를 다시 실행한다. 같은 원인이 3회 연속 실패할 때만 실제 차단 사유와 필요한 사용자 동작을 보고한다.

종료 조건: 필수 검사가 전부 PASS여야 `MATCHED`라고 보고할 수 있다. 필수 항목을 건너뛰었거나 FAIL이 하나라도 남으면 완료·성공·일치라고 말하지 말고 `BLOCKED`로 보고한다.

최종 응답에는 RESULT(MATCHED 또는 BLOCKED), 설치된 도구와 버전, 생성된 백업, verifier의 PASS/FAIL, 남은 사용자 동작만 포함한다.
```
