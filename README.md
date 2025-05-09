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

ssh-keygen -t rsa -b 4096 -C "bic7885@gmail.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa


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

# neovim installed needed 0.12.X version
wsl --install
wsl
sudo add-apt-repository ppa:neovim-ppa/unstable -y
sudo apt update
sudo apt install make gcc ripgrep unzip git xclip neovim

# install kickstart nvim
git clone https://github.com/nvim-lua/kickstart.nvim.git "${XDG_CONFIG_HOME:-$HOME/.config}"/nvim

#chage theme find(folke/nightfox.nvim)
'EdenEast/nightfox.nvim',
priority = 1000, -- Make sure to load this before all the other start plugins.
config = function()
  ---@diagnostic disable-next-line: missing-fields
  require('nightfox').setup {
    styles = {
      comments = { italic = false }, -- Disable italics in comments
    },
  }

  -- Load the colorscheme here.
  -- Like many other themes, this one has different styles, and you could load
  -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
  vim.cmd.colorscheme 'dayfox'
end,

#change nerd font
<!-- line75. vim.g.have_nerd_font = true -->

#chage autopairs
  <!-- require 'kickstart.plugins.debug', -->
  <!-- require 'kickstart.plugins.indent_line', -->
  <!-- require 'kickstart.plugins.lint', -->
  <!-- require 'kickstart.plugins.autopairs', -->
  <!-- require 'kickstart.plugins.neo-tree', -->
  <!-- require 'kickstart.plugins.gitsigns', -- adds gitsigns recommend keymaps -->

#add the lazy require toggle terminal. 

  {
    'akinsho/toggleterm.nvim',
    version = '*',
    config = function()
      require('toggleterm').setup {
        open_mapping = [[<C-\>]],
        direction = 'horizontal', -- 'vertical', 'float', 'tab' 중 선택 가능
        start_in_insert = true,
        insert_mappings = true,
        terminal_mappings = true,
        persist_size = true,
        close_on_exit = true,
        shell = vim.o.shell,
      }
    end,
  }, 

#install copilot
https://github.com/CopilotC-Nvim/CopilotChat.nvim

#add the lazy require copilot chat
  {
    'folke/which-key.nvim',
    optional = true,
    opts = {
      spec = {
        { '<leader>a', group = 'ai' },
        { '<leader>gm', group = 'Copilot Chat' },
      },
    },
  },
  {
    'MeanderingProgrammer/render-markdown.nvim',
    optional = true,
    opts = {
      file_types = { 'markdown', 'copilot-chat' },
    },
    ft = { 'markdown', 'copilot-chat' },
  },
  {
    'CopilotC-Nvim/CopilotChat.nvim',
    branch = 'main',
    -- version = "v3.3.0", -- Use a specific version to prevent breaking changes
    dependencies = {
      { 'github/copilot.vim' },
      { 'nvim-lua/plenary.nvim' },
    },
    opts = {
      question_header = '## User ',
      answer_header = '## Copilot ',
      error_header = '## Error ',
      prompts = prompts,
      -- model = "claude-3.7-sonnet",
      mappings = {
        -- Use tab for completion
        complete = {
          detail = 'Use @<Tab> or /<Tab> for options.',
          insert = '<Tab>',
        },
        -- Close the chat
        close = {
          normal = 'q',
          insert = '<C-c>',
        },
        -- Reset the chat buffer
        reset = {
          normal = '<C-x>',
          insert = '<C-x>',
        },
        -- Submit the prompt to Copilot
        submit_prompt = {
          normal = '<CR>',
          insert = '<C-CR>',
        },
        -- Accept the diff
        accept_diff = {
          normal = '<C-y>',
          insert = '<C-y>',
        },
        -- Show help
        show_help = {
          normal = 'g?',
        },
      },
    },
    config = function(_, opts)
      local chat = require 'CopilotChat'
      local user = vim.env.USER or 'User'
      user = user:sub(1, 1):upper() .. user:sub(2)
      opts.question_header = '  ' .. user .. ' '
      opts.answer_header = '  Copilot '

      chat.setup(opts)

      local select = require 'CopilotChat.select'
      vim.api.nvim_create_user_command('CopilotChatVisual', function(args)
        chat.ask(args.args, { selection = select.visual })
      end, { nargs = '*', range = true })

      -- Inline chat with Copilot
      vim.api.nvim_create_user_command('CopilotChatInline', function(args)
        chat.ask(args.args, {
          selection = select.visual,
          window = {
            layout = 'float',
            relative = 'cursor',
            width = 1,
            height = 0.4,
            row = 1,
          },
        })
      end, { nargs = '*', range = true })

      -- Restore CopilotChatBuffer
      vim.api.nvim_create_user_command('CopilotChatBuffer', function(args)
        chat.ask(args.args, { selection = select.buffer })
      end, { nargs = '*', range = true })

      -- Custom buffer for CopilotChat
      vim.api.nvim_create_autocmd('BufEnter', {
        pattern = 'copilot-*',
        callback = function()
          vim.opt_local.relativenumber = true
          vim.opt_local.number = true

          -- Get current filetype and set it to markdown if the current filetype is copilot-chat
          local ft = vim.bo.filetype
          if ft == 'copilot-chat' then
            vim.bo.filetype = 'markdown'
          end
        end,
      })
    end,
    event = 'VeryLazy',
    keys = {
      -- Show prompts actions
      {
        '<leader>ap',
        function()
          require('CopilotChat').select_prompt {
            context = {
              'buffers',
            },
          }
        end,
        desc = 'CopilotChat - Prompt actions',
      },
      {
        '<leader>ap',
        ":lua require('CopilotChat.integrations.telescope').pick(require('CopilotChat.actions').prompt_actions({selection = require('CopilotChat.select').visual}))<CR>",
        mode = 'x',
        desc = 'CopilotChat - Prompt actions',
      },
      -- Code related commands
      { '<leader>ae', '<cmd>CopilotChatExplain<cr>', desc = 'CopilotChat - Explain code' },
      { '<leader>at', '<cmd>CopilotChatTests<cr>', desc = 'CopilotChat - Generate tests' },
      { '<leader>ar', '<cmd>CopilotChatReview<cr>', desc = 'CopilotChat - Review code' },
      { '<leader>aR', '<cmd>CopilotChatRefactor<cr>', desc = 'CopilotChat - Refactor code' },
      { '<leader>an', '<cmd>CopilotChatBetterNamings<cr>', desc = 'CopilotChat - Better Naming' },
      -- Chat with Copilot in visual mode
      {
        '<leader>av',
        ':CopilotChatVisual',
        mode = 'x',
        desc = 'CopilotChat - Open in vertical split',
      },
      {
        '<leader>ax',
        ':CopilotChatInline',
        mode = 'x',
        desc = 'CopilotChat - Inline chat',
      },
      -- Custom input for CopilotChat
      {
        '<leader>ai',
        function()
          local input = vim.fn.input 'Ask Copilot: '
          if input ~= '' then
            vim.cmd('CopilotChat ' .. input)
          end
        end,
        desc = 'CopilotChat - Ask input',
      },
      -- Generate commit message based on the git diff
      {
        '<leader>am',
        '<cmd>CopilotChatCommit<cr>',
        desc = 'CopilotChat - Generate commit message for all changes',
      },
      -- Quick chat with Copilot
      {
        '<leader>aq',
        function()
          local input = vim.fn.input 'Quick Chat: '
          if input ~= '' then
            vim.cmd('CopilotChatBuffer ' .. input)
          end
        end,
        desc = 'CopilotChat - Quick chat',
      },
      -- Fix the issue with diagnostic
      { '<leader>af', '<cmd>CopilotChatFixError<cr>', desc = 'CopilotChat - Fix Diagnostic' },
      -- Clear buffer and chat history
      { '<leader>al', '<cmd>CopilotChatReset<cr>', desc = 'CopilotChat - Clear buffer and chat history' },
      -- Toggle Copilot Chat Vsplit
      { '<leader>av', '<cmd>CopilotChatToggle<cr>', desc = 'CopilotChat - Toggle' },
      -- Copilot Chat Models
      { '<leader>a?', '<cmd>CopilotChatModels<cr>', desc = 'CopilotChat - Select Models' },
      -- Copilot Chat Agents
      { '<leader>aa', '<cmd>CopilotChatAgents<cr>', desc = 'CopilotChat - Select Agents' },
    },
  },


**********

# prompt table dont input require('lazy')

local prompts = {
  -- Code related prompts
  Explain = "Please explain how the following code works.",
  Review = "Please review the following code and provide suggestions for improvement.",
  Tests = "Please explain how the selected code works, then generate unit tests for it.",
  Refactor = "Please refactor the following code to improve its clarity and readability.",
  FixCode = "Please fix the following code to make it work as intended.",
  FixError = "Please explain the error in the following text and provide a solution.",
  BetterNamings = "Please provide better names for the following variables and functions.",
  Documentation = "Please provide documentation for the following code.",
  SwaggerApiDocs = "Please provide documentation for the following API using Swagger.",
  SwaggerJsDocs = "Please write JSDoc for the following API using Swagger.",
  -- Text related prompts
  Summarize = "Please summarize the following text.",
  Spelling = "Please correct any grammar and spelling errors in the following text.",
  Wording = "Please improve the grammar and wording of the following text.",
  Concise = "Please rewrite the following text to make it more concise.",
}


# copilot enable
git clone https://github.com/github/copilot.vim \
   ~/.config/nvim/pack/github/start/copilot.vim

:Copilot setup
:Copilot enable

# install the plugin claude-code
sudo npm install -g @anthropic-ai/claude-code
# login the claude-code

# Adapt the bashrc file
# cd
# git clone git@github.com:bic98/init_lua.git
# cd init_lua
# cp bashrc_backup ~/.bashrc
# source ~/.bashrc
# dircolors -p > ~/.dircolors
cd
sudo wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64 -O /usr/local/bin/oh-my-posh
sudo chmod +x /usr/local/bin/oh-my-posh

mkdir -p ~/.poshthemes
wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip -O ~/.poshthemes/themes.zip
unzip ~/.poshthemes/themes.zip -d ~/.poshthemes
chmod u+rw ~/.poshthemes/*.omp.json

cd
eval "$(oh-my-posh init bash --config ~/.poshthemes/clean-detailed.omp.json)"
source ~/.bashrc


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


## My Powershell Settings

```sh
# 관리자 권한 powershell
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Client*'
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

# 관리자 권한 PowerShell
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = 'Tls12'
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# 홈 디렉터리로 이동
Set-Location ~

# Git 사용자 정보 설정
git config --global user.name "inchanBaek"
git config --global user.email "bic7885@gmail.com"

# SSH 키 생성 (ed25519)
ssh-keygen -t ed25519 -C "bic7885@gmail.com" -f $HOME\.ssh\id_ed25519

# 공개키를 클립보드로 복사
Get-Content $HOME\.ssh\id_ed25519.pub | clip

# (GitHub Settings > SSH Keys 에 붙여넣기)

# ssh-agent 실행 및 키 추가
Start-Service ssh-agent
ssh-add $HOME\.ssh\id_ed25519

# 연결 테스트
ssh -T git@github.com

#패키지설치
winget install --id=Git.Git -e
winget install --id=LLVM.LLVM -e
winget install --id=Neovim.Neovim -e
winget install --id=Anaconda.Anaconda3 -e
winget install --id OpenJS.NodeJS -e


# NeoVim 설정 디렉터리로 클론
git clone https://github.com/nvim-lua/kickstart.nvim.git $env:LOCALAPPDATA\nvim

nvim
:edit $MYVIMRC

#chage theme find(folke/nightfox.nvim)
'EdenEast/nightfox.nvim',
priority = 1000, -- Make sure to load this before all the other start plugins.
config = function()
  ---@diagnostic disable-next-line: missing-fields
  require('nightfox').setup {
    styles = {
      comments = { italic = false }, -- Disable italics in comments
    },
  }

  -- Load the colorscheme here.
  -- Like many other themes, this one has different styles, and you could load
  -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
  vim.cmd.colorscheme 'dayfox'
end,

#change nerd font
<!-- line75. vim.g.have_nerd_font = true -->

#chage autopairs
  <!-- require 'kickstart.plugins.debug', -->
  <!-- require 'kickstart.plugins.indent_line', -->
  <!-- require 'kickstart.plugins.lint', -->
  <!-- require 'kickstart.plugins.autopairs', -->
  <!-- require 'kickstart.plugins.neo-tree', -->
  <!-- require 'kickstart.plugins.gitsigns', -- adds gitsigns recommend keymaps -->

#add the lazy require toggle terminal. 

  {
    'akinsho/toggleterm.nvim',
    version = '*',
    config = function()
      require('toggleterm').setup {
        open_mapping = [[<C-\>]],
        direction = 'horizontal', -- 'vertical', 'float', 'tab' 중 선택 가능
        start_in_insert = true,
        insert_mappings = true,
        terminal_mappings = true,
        persist_size = true,
        close_on_exit = true,
        shell = vim.o.shell,
      }
    end,
  }, 

# lsp server설치
      local servers = {
        clangd = {
          cmd = {
            'clangd',
            '--query-driver=C:/MinGW/bin/*',
          },
        },
        -- gopls = {},
        pyright = {
          root_dir = function(fname)
            return vim.fn.getcwd() -- 현재 디렉토리를 루트로 강제
          end,
          settings = {
            python = {
              pythonPath = 'C:/Users/BaekInchan/AppData/Local/Programs/Python/Python312/python.exe',
            },
            analysis = {
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
              extraPaths = {

              },
            },
          },
        },


#install copilot
https://github.com/CopilotC-Nvim/CopilotChat.nvim

#add the lazy require copilot chat
  {
    'folke/which-key.nvim',
    optional = true,
    opts = {
      spec = {
        { '<leader>a', group = 'ai' },
        { '<leader>gm', group = 'Copilot Chat' },
      },
    },
  },
  {
    'MeanderingProgrammer/render-markdown.nvim',
    optional = true,
    opts = {
      file_types = { 'markdown', 'copilot-chat' },
    },
    ft = { 'markdown', 'copilot-chat' },
  },
  {
    'CopilotC-Nvim/CopilotChat.nvim',
    branch = 'main',
    -- version = "v3.3.0", -- Use a specific version to prevent breaking changes
    dependencies = {
      { 'github/copilot.vim' },
      { 'nvim-lua/plenary.nvim' },
    },
    opts = {
      question_header = '## User ',
      answer_header = '## Copilot ',
      error_header = '## Error ',
      prompts = prompts,
      -- model = "claude-3.7-sonnet",
      mappings = {
        -- Use tab for completion
        complete = {
          detail = 'Use @<Tab> or /<Tab> for options.',
          insert = '<Tab>',
        },
        -- Close the chat
        close = {
          normal = 'q',
          insert = '<C-c>',
        },
        -- Reset the chat buffer
        reset = {
          normal = '<C-x>',
          insert = '<C-x>',
        },
        -- Submit the prompt to Copilot
        submit_prompt = {
          normal = '<CR>',
          insert = '<C-CR>',
        },
        -- Accept the diff
        accept_diff = {
          normal = '<C-y>',
          insert = '<C-y>',
        },
        -- Show help
        show_help = {
          normal = 'g?',
        },
      },
    },
    config = function(_, opts)
      local chat = require 'CopilotChat'
      local user = vim.env.USER or 'User'
      user = user:sub(1, 1):upper() .. user:sub(2)
      opts.question_header = '  ' .. user .. ' '
      opts.answer_header = '  Copilot '

      chat.setup(opts)

      local select = require 'CopilotChat.select'
      vim.api.nvim_create_user_command('CopilotChatVisual', function(args)
        chat.ask(args.args, { selection = select.visual })
      end, { nargs = '*', range = true })

      -- Inline chat with Copilot
      vim.api.nvim_create_user_command('CopilotChatInline', function(args)
        chat.ask(args.args, {
          selection = select.visual,
          window = {
            layout = 'float',
            relative = 'cursor',
            width = 1,
            height = 0.4,
            row = 1,
          },
        })
      end, { nargs = '*', range = true })

      -- Restore CopilotChatBuffer
      vim.api.nvim_create_user_command('CopilotChatBuffer', function(args)
        chat.ask(args.args, { selection = select.buffer })
      end, { nargs = '*', range = true })

      -- Custom buffer for CopilotChat
      vim.api.nvim_create_autocmd('BufEnter', {
        pattern = 'copilot-*',
        callback = function()
          vim.opt_local.relativenumber = true
          vim.opt_local.number = true

          -- Get current filetype and set it to markdown if the current filetype is copilot-chat
          local ft = vim.bo.filetype
          if ft == 'copilot-chat' then
            vim.bo.filetype = 'markdown'
          end
        end,
      })
    end,
    event = 'VeryLazy',
    keys = {
      -- Show prompts actions
      {
        '<leader>ap',
        function()
          require('CopilotChat').select_prompt {
            context = {
              'buffers',
            },
          }
        end,
        desc = 'CopilotChat - Prompt actions',
      },
      {
        '<leader>ap',
        ":lua require('CopilotChat.integrations.telescope').pick(require('CopilotChat.actions').prompt_actions({selection = require('CopilotChat.select').visual}))<CR>",
        mode = 'x',
        desc = 'CopilotChat - Prompt actions',
      },
      -- Code related commands
      { '<leader>ae', '<cmd>CopilotChatExplain<cr>', desc = 'CopilotChat - Explain code' },
      { '<leader>at', '<cmd>CopilotChatTests<cr>', desc = 'CopilotChat - Generate tests' },
      { '<leader>ar', '<cmd>CopilotChatReview<cr>', desc = 'CopilotChat - Review code' },
      { '<leader>aR', '<cmd>CopilotChatRefactor<cr>', desc = 'CopilotChat - Refactor code' },
      { '<leader>an', '<cmd>CopilotChatBetterNamings<cr>', desc = 'CopilotChat - Better Naming' },
      -- Chat with Copilot in visual mode
      {
        '<leader>av',
        ':CopilotChatVisual',
        mode = 'x',
        desc = 'CopilotChat - Open in vertical split',
      },
      {
        '<leader>ax',
        ':CopilotChatInline',
        mode = 'x',
        desc = 'CopilotChat - Inline chat',
      },
      -- Custom input for CopilotChat
      {
        '<leader>ai',
        function()
          local input = vim.fn.input 'Ask Copilot: '
          if input ~= '' then
            vim.cmd('CopilotChat ' .. input)
          end
        end,
        desc = 'CopilotChat - Ask input',
      },
      -- Generate commit message based on the git diff
      {
        '<leader>am',
        '<cmd>CopilotChatCommit<cr>',
        desc = 'CopilotChat - Generate commit message for all changes',
      },
      -- Quick chat with Copilot
      {
        '<leader>aq',
        function()
          local input = vim.fn.input 'Quick Chat: '
          if input ~= '' then
            vim.cmd('CopilotChatBuffer ' .. input)
          end
        end,
        desc = 'CopilotChat - Quick chat',
      },
      -- Fix the issue with diagnostic
      { '<leader>af', '<cmd>CopilotChatFixError<cr>', desc = 'CopilotChat - Fix Diagnostic' },
      -- Clear buffer and chat history
      { '<leader>al', '<cmd>CopilotChatReset<cr>', desc = 'CopilotChat - Clear buffer and chat history' },
      -- Toggle Copilot Chat Vsplit
      { '<leader>av', '<cmd>CopilotChatToggle<cr>', desc = 'CopilotChat - Toggle' },
      -- Copilot Chat Models
      { '<leader>a?', '<cmd>CopilotChatModels<cr>', desc = 'CopilotChat - Select Models' },
      -- Copilot Chat Agents
      { '<leader>aa', '<cmd>CopilotChatAgents<cr>', desc = 'CopilotChat - Select Agents' },
    },
  },


**********

# prompt table dont input require('lazy')

local prompts = {
  -- Code related prompts
  Explain = "Please explain how the following code works.",
  Review = "Please review the following code and provide suggestions for improvement.",
  Tests = "Please explain how the selected code works, then generate unit tests for it.",
  Refactor = "Please refactor the following code to improve its clarity and readability.",
  FixCode = "Please fix the following code to make it work as intended.",
  FixError = "Please explain the error in the following text and provide a solution.",
  BetterNamings = "Please provide better names for the following variables and functions.",
  Documentation = "Please provide documentation for the following code.",
  SwaggerApiDocs = "Please provide documentation for the following API using Swagger.",
  SwaggerJsDocs = "Please write JSDoc for the following API using Swagger.",
  -- Text related prompts
  Summarize = "Please summarize the following text.",
  Spelling = "Please correct any grammar and spelling errors in the following text.",
  Wording = "Please improve the grammar and wording of the following text.",
  Concise = "Please rewrite the following text to make it more concise.",
}


git clone https://github.com/github/copilot.vim $env:LOCALAPPDATA\nvim\pack\github\start\copilot.vim
# nvim 내부에서 :Copilot setup, :Copilot enable

#프로필 설정
cd
if (-not (Test-Path $PROFILE)) {
  New-Item -ItemType Directory -Path (Split-Path $PROFILE) -Force
  New-Item -ItemType File -Path $PROFILE -Force
}

winget install JanDeDobbeleer.OhMyPosh -s winget
$env:Path += ";C:\Users\user\AppData\Local\Programs\oh-my-posh\bin"

# powershell 관리자 권한으로 실행
[System.Environment]::SetEnvironmentVariable(
  "Path",
  [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";C:\Users\BaekInchan\AppData\Local\Programs\oh-my-posh\bin",
  "Machine"
)

#yy copy
winget install --id equalsraf.win32yank --accept-package-agreements --accept-source-agreements

nvim $PROFILE

oh-my-posh init pwsh --config "C:\Users\BaekInchan\AppData\Local\Programs\oh-my-posh\themes\illusi0n.omp.json" | Invoke-Expression

function root {
    Set-Location C:\
}

function rhino {
    Start-Process "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Rhino 8\Rhino 8.lnk"
}

function revit {
    Start-Process "C:\Program Files\Autodesk\Revit 2024\Revit.exe"
}

function acad {
    Start-Process "C:\Program Files\Autodesk\AutoCAD 2023\acad.exe"
}

function boj {
    Set-Location "C:\Users\BaekInchan\boj"
    nvim
}

function env_path {
    param(
        [string]$NewPath
    )

    if (-not (Test-Path $NewPath)) {
        Write-Host "❌ 경로가 존재하지 않습니다: $NewPath"
        return
    }

    $currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)

    if ($currentPath -like "*$NewPath*") {
        Write-Host "✅ 이미 시스템 PATH에 존재합니다: $NewPath"
    }
    else {
        [Environment]::SetEnvironmentVariable(
            "Path",
            $currentPath + ";$NewPath",
            [EnvironmentVariableTarget]::Machine
        )
        Write-Host "✅ 시스템 PATH에 추가 완료: $NewPath"
    }
}

function gh_venv {
    if ($env:VIRTUAL_ENV) {
        # 이미 가상환경이 활성화되어 있으면 비활성화
        deactivate
    }
    else {
        # 가상환경이 비활성화되어 있으면 활성화
        & "C:\Users\BaekInchan\grasshopper\Scripts\Activate.ps1"
    }
}
