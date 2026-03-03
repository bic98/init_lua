# ─── 환경 변수 ───
export PATH="$HOME/.local/bin:$PATH"
export LANG=en_US.UTF-8
export EDITOR=nvim
export USERPROFILE="/mnt/c/Users/junglim"

# ─── NVM 레이지 로딩 (핵심 속도 개선) ───
export NVM_DIR="$HOME/.nvm"
nvm() {
  unset -f nvm node npm npx yarn pnpm
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  nvm "$@"
}
node() { nvm; node "$@"; }
npm()  { nvm; npm  "$@"; }
npx()  { nvm; npx  "$@"; }
yarn() { nvm; yarn "$@"; }
pnpm() { nvm; pnpm "$@"; }

# ─── 플러그인 ───
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ─── 히스토리 ───
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY
setopt HIST_IGNORE_SPACE

# ─── 자동완성 (하루 1회만 재빌드) ───
autoload -Uz compinit
if [[ -f ~/.zcompdump && $(date +'%j') == $(stat -c '%Y' ~/.zcompdump 2>/dev/null | xargs -I{} date -d @{} +'%j' 2>/dev/null) ]]; then
  compinit -C -d ~/.zcompdump
else
  compinit -d ~/.zcompdump
fi
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# ─── 단축키 ───
bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# ─── 유용한 alias ───
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias gs='git status'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --all'
alias ..='cd ..'
alias ...='cd ../..'
alias cc='claude --dangerously-skip-permissions'
alias cx='codex --dangerously-bypass-approvals-and-sandbox'

# ─── Oh My Posh 프롬프트 ───
eval "$(oh-my-posh init zsh --config ~/.poshthemes/illusi0n.omp.json)"
