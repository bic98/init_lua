# macOS 완전 설치 AI 프롬프트

```text
이것은 설명 요청이 아니라 실제 설치 요청이다. `uname -s`로 이 환경이 macOS인지 확인하고 https://github.com/bic98/init_lua 의 `mac` 원하는 상태로 수렴시켜라.

먼저 `mac/desired-state.json`과 `mac`의 README·bootstrap·install·scripts를 읽어라. macOS·CPU, Xcode Command Line Tools, Homebrew, 셸, 필수 명령 버전, `${XDG_CONFIG_HOME:-$HOME/.config}`와 기존 Git 상태를 기록한다.

원하는 상태에 선언된 Homebrew formula와 Claude Code 공식 네이티브 설치기만 설치·업그레이드해도 된다. Xcode 설치 대화상자, 관리자 비밀번호, Claude 로그인처럼 사용자가 해야 하는 단계만 요청하고 완료 후 계속한다. Terminal 또는 iTerm2 전체 설정과 관련 없는 앱은 수정하지 않는다.

저장소가 없으면 `mac/bootstrap.sh`로 복제와 설치를 한 번에 실행한다. 이미 올바른 저장소 안이면 bootstrap을 다시 실행하지 말고 기본 `mac/install.sh`만 skip 옵션 없이 실행한다. `lazy-lock.json`의 모든 Neovim 플러그인을 정확한 커밋으로 복원하고 Mason 도구, JetBrainsMono Nerd Font, 셸과 tmux 설정까지 설치한다. 기존 개인 내용과 백업을 보존한다.

마지막에 `bash ./mac/scripts/verify.sh`를 실행한다. FAIL을 원인별로 수정하고 최대 3회 재검증한다. 모든 필수 검사가 PASS일 때만 RESULT: MATCHED라고 보고한다. 하나라도 남으면 RESULT: BLOCKED이며 성공이라고 말하지 않는다.
```
