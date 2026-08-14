# WSL

WSL에서는 [desired-state.json](desired-state.json)의 시스템 패키지, Neovim, Node.js와 npm, Python, ripgrep, 네이티브 Claude Code, Oh My Posh, 잠금 플러그인, Mason 도구, 셸과 tmux 설정을 설치합니다. Windows Terminal과 Windows 글꼴은 호스트 영역이라 건드리지 않습니다.

## 설치

```bash
curl -fsSL https://raw.githubusercontent.com/bic98/init_lua/main/wsl/bootstrap.sh | bash
```

이미 저장소가 있으면 다음처럼 실행합니다.

```bash
bash ./wsl/install.sh
```

설치기는 배포판을 감지해 원하는 상태에 선언된 패키지만 apt·dnf·pacman·zypper와 sudo로 설치합니다. 기존 `~/.bashrc`, `~/.zshrc`, `~/.tmux.conf`, Neovim 설정은 변경 전에 타임스탬프 백업으로 보존하며 관리 대상 밖의 내용은 삭제하지 않습니다.

Claude Code를 새로 설치한 장치는 `claude auth login`이 필요합니다. 자격 증명은 저장소에 복사하지 않으며 로그인 완료 후 verifier가 상태만 확인합니다.

권장 설치는 [AI_INSTALL.md](AI_INSTALL.md) 프롬프트입니다. 옵션은 `bash ./wsl/install.sh --help`, strict 검증은 `bash ./wsl/scripts/verify.sh`로 실행합니다. skip 옵션을 사용한 설치는 완전 일치가 아닙니다.
