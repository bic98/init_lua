# WSL 완전 설치 AI 프롬프트

```text
이것은 설명 요청이 아니라 실제 설치 요청이다. `/proc/sys/kernel/osrelease`로 이 환경이 WSL인지 확인하고 https://github.com/bic98/init_lua 의 `wsl` 원하는 상태로 수렴시켜라.

먼저 `wsl/desired-state.json`과 `wsl`의 README·bootstrap·install·scripts를 읽어라. 배포판, 패키지 관리자, 셸, 필수 명령 버전, `${XDG_CONFIG_HOME:-$HOME/.config}`와 기존 Git 상태를 기록한다.

원하는 상태의 `systemPackages`에 선언된 패키지만 배포판의 apt·dnf·pacman·zypper와 sudo로 설치해도 된다. Claude Code는 원하는 상태에 선언된 공식 네이티브 설치기만 사용한다. sudo 비밀번호나 Claude 로그인이 필요하면 사용자에게 요청하고 완료 후 계속한다. Windows Terminal과 Windows 호스트 글꼴은 수정하지 않는다.

저장소가 없으면 `wsl/bootstrap.sh`로 복제와 설치를 한 번에 실행한다. 이미 올바른 저장소 안이면 bootstrap을 다시 실행하지 말고 기본 `wsl/install.sh`만 skip 옵션 없이 실행한다. `lazy-lock.json`의 모든 Neovim 플러그인을 정확한 커밋으로 복원하고 선언된 Mason 도구까지 설치한다. 기존 셸·tmux·Neovim 개인 내용과 백업을 보존한다.

마지막에 `bash ./wsl/scripts/verify.sh`를 실행한다. FAIL을 원인별로 수정하고 최대 3회 재검증한다. 모든 필수 검사가 PASS일 때만 RESULT: MATCHED라고 보고한다. 하나라도 남으면 RESULT: BLOCKED이며 성공이라고 말하지 않는다.
```
