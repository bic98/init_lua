# ─── 환경 변수 ───
export PATH="$HOME/.local/bin:$PATH"
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export EDITOR=nvim
export USERPROFILE="/mnt/c/Users/junglim"

# ─── NVM 레이지 로딩 ───
export NVM_DIR="$HOME/.nvm"
_nvm_lazy() {
  unset -f nvm node npm npx yarn pnpm bun bunx 2>/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}
nvm()  { _nvm_lazy; nvm  "$@"; }
node() { _nvm_lazy; node "$@"; }
npm()  { _nvm_lazy; npm  "$@"; }
npx()  { _nvm_lazy; npx  "$@"; }
yarn() { _nvm_lazy; yarn "$@"; }
pnpm() { _nvm_lazy; pnpm "$@"; }
bun()  { _nvm_lazy; bun  "$@"; }
bunx() { _nvm_lazy; bunx "$@"; }

# ─── 플러그인 (존재할 때만 로드) ───
[[ -f ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ─── 히스토리 (대용량 + 중복 제거) ───
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY
setopt EXTENDED_HISTORY

# ─── 자동완성 (하루 1회만 재빌드) ───
autoload -Uz compinit
if [[ -f ~/.zcompdump(#qN.mh+24) ]]; then
  compinit -d ~/.zcompdump
else
  compinit -C -d ~/.zcompdump
fi
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# ─── 유용한 옵션 ───
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt CORRECT
setopt NO_BEEP
setopt GLOB_DOTS

# ─── 단축키 ───
bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^R' history-incremental-search-backward

# ─── ls / grep 컬러 ───
if [[ -x /usr/bin/dircolors ]]; then
  eval "$(dircolors -b)"
fi
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# ─── alias ───
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias gs='git status'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --all'
alias gd='git diff'
alias ga='git add'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias cc='claude --dangerously-skip-permissions'
alias cx='codex --dangerously-bypass-approvals-and-sandbox'
alias claude='claude --dangerously-skip-permissions'
alias codex='codex --dangerously-bypass-approvals-and-sandbox'
alias v='nvim'
alias vi='nvim'

# ─── lesspipe ───
[[ -x /usr/bin/lesspipe ]] && eval "$(SHELL=/bin/sh lesspipe)"

# ─── Oh My Posh 프롬프트 ───
eval "$(oh-my-posh init zsh --config ~/.poshthemes/illusi0n.omp.json)"
