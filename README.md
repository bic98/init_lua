# My Neovim Configuration

kickstart.nvim 기반의 개인 Neovim 설정입니다.

## 새 컴퓨터에서 설치하기

### 1. 사전 요구사항

- Neovim (0.9.0+)
- Git
- ripgrep (`rg`)
- fd
- C compiler (gcc/clang)
- [Nerd Font](https://www.nerdfonts.com/) (아이콘 표시용)

### 2. 기존 설정 백업 (있는 경우)

**Linux/Mac:**
```bash
mv ~/.config/nvim ~/.config/nvim.bak
mv ~/.local/share/nvim ~/.local/share/nvim.bak
```

**Windows (PowerShell):**
```powershell
Move-Item $env:LOCALAPPDATA\nvim $env:LOCALAPPDATA\nvim.bak
Move-Item $env:LOCALAPPDATA\nvim-data $env:LOCALAPPDATA\nvim-data.bak
```

### 3. 설정 클론

**Linux/Mac:**
```bash
git clone git@github.com:bic98/init_lua.git ~/.config/nvim
```

**Windows (PowerShell):**
```powershell
git clone git@github.com:bic98/init_lua.git $env:LOCALAPPDATA\nvim
```

**Windows (cmd):**
```cmd
git clone git@github.com:bic98/init_lua.git "%localappdata%\nvim"
```

### 4. Neovim 실행

```bash
nvim
```

첫 실행 시 Lazy.nvim이 자동으로 플러그인을 설치합니다.

## 설정 업데이트하기

로컬에서 변경한 설정을 저장소에 반영:

```bash
cd ~/.config/nvim  # Windows: cd $env:LOCALAPPDATA\nvim
git add -A
git commit -m "Update config"
git push
```

다른 컴퓨터에서 최신 설정 가져오기:

```bash
cd ~/.config/nvim  # Windows: cd $env:LOCALAPPDATA\nvim
git pull
```

## 주요 명령어

- `:Lazy` - 플러그인 관리
- `:Mason` - LSP/포맷터/린터 관리
- `:checkhealth` - 설정 상태 확인

## 파일 구조

```
nvim/
├── init.lua          # 메인 설정 파일
├── lua/
│   └── custom/
│       └── plugins/  # 커스텀 플러그인 설정
└── lazy-lock.json    # 플러그인 버전 잠금
```
