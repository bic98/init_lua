# kickstart.nvim
```sh
# Microsoft Windows installed Windows Subsystem for Linux in store. https://apps.microsoft.com/detail/9p9tqf7mrm4r?hl=ko-KR&gl=KR
# Microsoft Windows intalled Ubuntu in store. 

cd

git config --global user.name "inchanBaek"
git config --global user.email "bic7885@gmail.com"

ssh-keygen -t ed25519 -C "bic7885@gmail.com"

cat ~/.ssh/id_ed25519.pub
# Copy the output and add it to your GitHub account
https://github.com/settings/keys
# add the SSH key to your GitHub account and copy the output
# Test the SSH connection
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

ssh -T git@github.com

# neovim installed needed 0.11.X version
wsl --install
wsl
sudo add-apt-repository ppa:neovim-ppa/unstable -y
sudo apt update
sudo apt install make gcc ripgrep unzip git xclip neovim

# C compiler installed
sudo apt update
sudo apt install build-essential -y

# Install clangd for lsp
sudo apt install clangd-20
sudo update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-20 100

# install nodejs and npm
# 1. NodeSource 리포지토리 추가 (Node.js 20.x용)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# check the version
nvim --version

git clone https://github.com/nvim-lua/kickstart.nvim.git "${XDG_CONFIG_HOME:-$HOME/.config}"/nvim
cd ~/.config/nvim
git clone git@github.com:bic98/init_lua.git
cp -rT ~/.config/nvim/init_lua/ ~/.config/nvim/
rm -rf ~/.config/nvim/init_lua
mv CopilotChat.nvim/ ~/

# id = vim.lsp.start change ok?
cd .local/share/nvim/lazy/copilot.vim/lua
nvim _copilot.lua


# lsp clangd change in init.lua
        <!--  clangd = { -->
        <!--   cmd = { "/usr/bin/clangd" } -- 시스템에 이미 설치된 clangd 사용 -->
        <!-- }, -->


# copilot chat in init.lua removed dir = '' path. 

# install the plugin claude-code
sudo npm install -g @anthropic-ai/claude-code
# login the claude-code

# Adapt the bashrc file
cp bashrc_backup ~/.bashrc
source ~/.bashrc
dircolors -p > ~/.dircolors


# Adapt (base) venv
wget https://repo.anaconda.com/archive/Anaconda3-2024.02-1-Linux-x86_64.sh
bash Anaconda3-2024.02-1-Linux-x86_64.sh
# 가상환경 설정

set -e

# 1. conda 명령이 없으면 profile.d 스크립트 먼저 로드
if ! command -v conda &> /dev/null; then
  if [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/anaconda3/etc/profile.d/conda.sh"
  else
    echo "Error: conda.sh not found at ~/anaconda3/etc/profile.d/conda.sh"
    exit 1
  fi
fi

# 2. conda init 으로 ~/.bashrc에 초기화 블록 추가
conda init bash

# 3. base 환경을 Python 3.11로 업그레이드
conda activate base
conda install python=3.11 -y

# 4. base 환경 자동 활성화 설정
conda config --set auto_activate_base true

# 5. 변경된 ~/.bashrc 즉시 적용
source "$HOME/.bashrc"

echo "✅ Conda auto-activation setup complete!"
echo "(base) 환경이 자동으로 활성화됩니다."

# 만약에 에러가 나면
nano ~/.bashrc
# → 해당 줄(# conda activate mybase) 제거 또는 앞에 # 붙이기


```

