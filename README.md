# My Neovim + PowerShell Configuration

kickstart.nvim 기반의 개인 Neovim 설정 + Oh My Posh PowerShell 환경입니다.

## 빠른 설치 (Windows)

### 옵션 A: Chocolatey로 한 번에 설치 (권장)

**관리자 권한 PowerShell에서:**
```powershell
# 1. 저장소 클론
git clone git@github.com:bic98/init_lua.git $env:LOCALAPPDATA\nvim

# 2. 전체 설치 (Chocolatey + 모든 의존성 + 설정)
cd $env:LOCALAPPDATA\nvim
.\install.ps1 -Full

# 3. Claude Code 설치 및 로그인
npm install -g @anthropic-ai/claude-code
claude login
```

설치되는 도구: neovim, git, ripgrep, fd, gcc, nodejs, python, uv, pandoc, miktex

### 옵션 B: 수동 설치

### 사전 설치 (필수)

```powershell
# 1. Scoop으로 기본 도구 설치 (Scoop 없으면: iwr get.scoop.sh | iex)
scoop install neovim git ripgrep fd gcc

# 2. Node.js 설치 (nvm-windows 권장)
# https://github.com/coreybutler/nvm-windows

# 3. Claude Code CLI 설치
npm install -g @anthropic-ai/claude-code

# 4. Claude 로그인
claude login
```

### 설정 클론 및 설치

```powershell
# 1. 저장소 클론
git clone git@github.com:bic98/init_lua.git $env:LOCALAPPDATA\nvim

# 2. 자동 설치 스크립트 실행
cd $env:LOCALAPPDATA\nvim
.\install.ps1

# 3. PowerShell 재시작 후 nvim 실행
nvim
```

자동 설치 스크립트가 다음을 수행합니다:
- Oh My Posh 설치 (없는 경우)
- Oh My Posh 테마 복사
- PowerShell 프로필 설정

첫 실행 시 Lazy.nvim이 자동으로 플러그인을 설치합니다.

## 빠른 설치 (Linux/WSL)

### 사전 설치 (필수)

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install neovim git ripgrep fd-find gcc curl

# Node.js 설치 (nvm 권장)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install --lts

# Claude Code CLI 설치
npm install -g @anthropic-ai/claude-code

# Claude 로그인
claude login
```

### 설정 클론 및 설치

```bash
# 1. 저장소 클론
git clone https://github.com/bic98/init_lua.git ~/.config/nvim

# 2. 자동 설치 스크립트 실행
cd ~/.config/nvim
./install.sh

# 3. 터미널 재시작 후 nvim 실행
nvim
```

자동 설치 스크립트가 다음을 수행합니다:
- Oh My Posh 설치 (없는 경우)
- Oh My Posh 테마 복사 (`~/.poshthemes/`)
- 쉘 프로필 설정 (`.bashrc` 또는 `.zshrc`)

첫 실행 시 Lazy.nvim이 자동으로 플러그인을 설치합니다.

---

## 수동 설치

### 1. 사전 요구사항

- Neovim (0.9.0+)
- Git
- Node.js & yarn (markdown-preview용)
- ripgrep (`rg`)
- fd
- C compiler (gcc/clang)
- [Nerd Font](https://www.nerdfonts.com/) (아이콘 표시용)
- win32yank (Windows clipboard용)

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

### 5. Markdown Preview 설치 (Windows)

Windows에서 markdown-preview가 자동 빌드되지 않으면 PowerShell에서 수동 설치:

```powershell
cd $env:LOCALAPPDATA\nvim-data\lazy\markdown-preview.nvim\app
npx --yes yarn install
Invoke-WebRequest -Uri "https://github.com/iamcco/markdown-preview.nvim/releases/download/v0.0.10/markdown-preview-win.zip" -OutFile "markdown-preview-win.zip"
mkdir bin -Force
Expand-Archive markdown-preview-win.zip -DestinationPath bin -Force
Remove-Item markdown-preview-win.zip
```

## 주요 기능

### Claude Code (AI Coding Assistant)

[claudecode.nvim](https://github.com/coder/claudecode.nvim) 플러그인으로 Claude Code CLI와 Neovim 연동

> GitHub Copilot을 대체하여 Claude Code를 메인 AI 도구로 사용합니다.

**요구사항:**
- Claude Code CLI (`npm install -g @anthropic-ai/claude-code`)
- folke/snacks.nvim (자동 설치됨)

**설정 파일:** `lua/custom/plugins/claudecode.lua`

#### 기본 컨트롤

| 키맵 | 설명 |
|------|------|
| `<leader>ac` | Claude 터미널 토글 |
| `<leader>af` | Claude 포커스 |
| `<leader>ar` | 이전 세션 재개 (--resume) |
| `<leader>aC` | 계속하기 (--continue) |
| `<leader>am` | 모델 선택 |
| `<leader>al` | Claude 리셋 |

#### 컨텍스트 관리

| 키맵 | 설명 |
|------|------|
| `<leader>ab` | 현재 버퍼 추가 |
| `<leader>as` | 선택 영역 전송 (visual) |

#### 코드 작업 (Visual Mode)

| 키맵 | 설명 |
|------|------|
| `<leader>ae` | 코드 설명 |
| `<leader>at` | 테스트 생성 |
| `<leader>aR` | 코드 리뷰 |
| `<leader>aF` | 리팩토링 |
| `<leader>an` | 더 나은 이름 제안 |
| `<leader>ax` | 에러 수정 |

#### Diff 관리

| 키맵 | 설명 |
|------|------|
| `<leader>aA` | Diff 수용 |
| `<leader>aD` | Diff 거부 |

#### 기타

| 키맵 | 설명 |
|------|------|
| `<leader>ai` | Claude에게 질문 |

**주요 명령어:**
- `:ClaudeCode` - 터미널 토글
- `:ClaudeCodeFocus` - 스마트 포커스
- `:ClaudeCodeSend` - 선택 영역 전송
- `:ClaudeCodeAdd <file>` - 파일을 컨텍스트에 추가
- `:ClaudeCodeSelectModel` - 모델 선택

### Claude Code 에이전트 (Global)

이 레포를 설치하면 `~/.claude/agents/`에 6개의 전문 에이전트가 자동 설치됩니다.
**모든 프로젝트에서 사용 가능**합니다.

| 에이전트 | 설명 | 트리거 예시 |
|---------|------|------------|
| `document-organizer` | 문서 정리/변환 (PDF, Word, Excel) | "문서 정리해줘", "PDF를 Word로" |
| `report-generator` | 데이터 기반 보고서 자동 생성 | "보고서 만들어줘", "분석해줘" |
| `data-extractor` | 문서에서 데이터 추출 → Excel/JSON | "표 추출해줘", "데이터 뽑아줘" |
| `supervisor` | 멀티에이전트 오케스트레이터 | "팀으로 작업해줘" |
| `reviewer` | 결과물 검토 및 피드백 | "검토해줘", "피드백 줘" |
| `writer` | 콘텐츠 작성 (피드백 반영) | "글 써줘", "정리해줘" |

**멀티에이전트 협업 예시:**
```
사용자: "이 PDF 분석해서 경영진 보고서 만들어줘"

supervisor → data-extractor (데이터 추출)
         → report-generator (분석)
         → writer (초안)
         → reviewer (피드백)
         → writer (최종본)
```

**MCP 서버 설치 (선택):**

문서 작업 강화를 위해 MCP 서버를 추가로 설치할 수 있습니다:

```powershell
# PDF 읽기
claude mcp add pdf-reader -- npx -y @sylphx/pdf-reader-mcp

# Word 문서
claude mcp add word -- uvx --from office-word-mcp-server word_mcp_server

# Excel 파일
claude mcp add excel -- cmd /c npx -y @negokaz/excel-mcp-server

# PowerPoint
claude mcp add powerpoint -- uvx --from office-powerpoint-mcp-server ppt_mcp_server

# 문서 변환 (MD↔PDF, DOCX, HTML, EPUB 등)
claude mcp add mcp-pandoc -- uvx mcp-pandoc
# 요구사항: pandoc 설치 필요 (choco install pandoc)
# PDF 출력: TeX Live 필요 (choco install miktex)
```

### Markdown Preview

```
:MarkdownPreview      # 브라우저에서 프리뷰 열기
:MarkdownPreviewStop  # 프리뷰 종료
```

## 주요 명령어

- `:Lazy` - 플러그인 관리
- `:Mason` - LSP/포맷터/린터 관리
- `:checkhealth` - 설정 상태 확인
- `:ClaudeCode` - Claude Code 토글

## 파일 구조

```
nvim/
├── init.lua              # 메인 설정 파일
├── install.ps1           # 자동 설치 스크립트 (Windows)
├── install.sh            # 자동 설치 스크립트 (Linux/WSL)
├── lua/
│   ├── kickstart/
│   │   └── plugins/      # kickstart 기본 플러그인
│   └── custom/
│       └── plugins/      # 커스텀 플러그인
│           ├── init.lua         # markdown-preview
│           └── claudecode.lua   # Claude Code 연동
├── powershell/
│   ├── Microsoft.PowerShell_profile.ps1  # PowerShell 프로필
│   └── illusi0n.omp.json                 # Oh My Posh 테마
├── claude-config/        # Claude Code 글로벌 설정 (→ ~/.claude/)
│   ├── agents/           # 전문 에이전트들
│   │   ├── document-organizer.md
│   │   ├── report-generator.md
│   │   ├── data-extractor.md
│   │   ├── supervisor.md
│   │   ├── reviewer.md
│   │   └── writer.md
│   └── CLAUDE.md         # 글로벌 지침 템플릿
└── lazy-lock.json        # 플러그인 버전 잠금
```

## 설정 동기화

설정 변경 후 다른 컴퓨터에 반영하기:

```powershell
# 현재 컴퓨터에서 변경사항 푸시
cd $env:LOCALAPPDATA\nvim
git add -A
git commit -m "Update config"
git push

# 다른 컴퓨터에서 최신 설정 가져오기
cd $env:LOCALAPPDATA\nvim
git pull
.\install.ps1
```

---

## PowerShell 명령어 가이드

### 커스텀 단축 명령어

프로필에 정의된 빠른 이동 및 실행 명령어:

| 명령어 | 설명 |
|--------|------|
| `e` | E:\ 드라이브로 이동 |
| `root` | C:\ 루트로 이동 |
| `ppe` | pyRevit Extensions 폴더로 이동 |
| `boj` | BOJ 폴더로 이동 후 nvim 실행 |
| `rhino` | Rhino 8 실행 |
| `revit` | Revit 2024 실행 |
| `acad` | AutoCAD 2023 실행 |
| `gh_venv` | Grasshopper 가상환경 토글 |
| `env_path <경로>` | 시스템 PATH에 경로 추가 |

### 디렉토리 탐색

```powershell
# 기본 이동
cd ~                      # 홈 디렉토리
cd ..                     # 상위 디렉토리
cd -                      # 이전 디렉토리 (PSReadLine)

# 경로 확인
pwd                       # 현재 경로
Get-Location              # 현재 경로 (전체)

# 디렉토리 내용
ls                        # 목록 보기
ls -Force                 # 숨김 파일 포함
ls -Recurse               # 하위 폴더 포함
tree                      # 트리 구조로 보기
```

### 파일 작업

```powershell
# 파일 생성/편집
ni file.txt               # 새 파일 생성 (New-Item)
nvim file.txt             # Neovim으로 편집
code file.txt             # VS Code로 편집

# 파일 내용 보기
cat file.txt              # 전체 내용
head -n 10 file.txt       # 처음 10줄 (함수 필요)
tail -n 10 file.txt       # 마지막 10줄 (함수 필요)
Get-Content file.txt -First 10   # 처음 10줄
Get-Content file.txt -Last 10    # 마지막 10줄

# 복사/이동/삭제
cp source dest            # 복사
mv source dest            # 이동/이름변경
rm file.txt               # 삭제
rm -r folder              # 폴더 삭제 (재귀)
rm -r -Force folder       # 강제 삭제
```

### 검색

```powershell
# 파일 찾기
Get-ChildItem -Recurse -Filter "*.py"           # 확장자로 찾기
Get-ChildItem -Recurse | Where-Object { $_.Name -like "*test*" }  # 이름으로 찾기
fd "pattern"              # fd 사용 (빠름)

# 내용 검색
Select-String -Path "*.txt" -Pattern "검색어"   # 파일 내용 검색
rg "pattern"              # ripgrep 사용 (빠름)
rg "pattern" -t py        # Python 파일만 검색
rg "pattern" -i           # 대소문자 무시
```

### Git 명령어

```powershell
# 기본
git status                # 상태 확인
git add .                 # 모든 변경사항 스테이징
git commit -m "메시지"     # 커밋
git push                  # 푸시
git pull                  # 풀

# 브랜치
git branch                # 브랜치 목록
git checkout -b new       # 새 브랜치 생성 및 이동
git switch main           # main 브랜치로 이동
git merge feature         # feature 브랜치 병합

# 로그
git log --oneline -10     # 최근 10개 커밋
git log --graph --oneline # 그래프로 보기
git diff                  # 변경사항 확인
```

### Python 가상환경 (uv)

```powershell
# 가상환경 생성
uv venv                   # .venv 폴더에 생성
uv venv myenv             # 지정 이름으로 생성

# 활성화/비활성화
.venv\Scripts\activate    # 활성화
deactivate                # 비활성화

# 패키지 관리
uv pip install package    # 패키지 설치
uv pip install -r requirements.txt  # requirements 설치
uv pip list               # 설치된 패키지 목록
uv pip freeze > requirements.txt    # requirements 생성
```

### 프로세스 관리

```powershell
# 프로세스 확인
Get-Process               # 모든 프로세스
Get-Process nvim          # 특정 프로세스
ps | Where-Object { $_.CPU -gt 10 }  # CPU 사용량 높은 프로세스

# 프로세스 종료
Stop-Process -Name "nvim" # 이름으로 종료
Stop-Process -Id 1234     # PID로 종료
taskkill /F /IM "app.exe" # 강제 종료
```

### 네트워크

```powershell
# 연결 확인
ping google.com           # 핑 테스트
Test-Connection google.com -Count 4   # PowerShell 방식

# 포트 확인
netstat -an | Select-String "LISTENING"   # 열린 포트
Get-NetTCPConnection -State Listen        # PowerShell 방식

# 다운로드
Invoke-WebRequest -Uri "URL" -OutFile "file.zip"  # 파일 다운로드
curl -o file.zip "URL"    # curl 사용
```

### 시스템 정보

```powershell
# 시스템
$env:USERNAME             # 현재 사용자
$env:COMPUTERNAME         # 컴퓨터 이름
systeminfo                # 시스템 정보
Get-ComputerInfo          # 상세 시스템 정보

# 환경 변수
$env:PATH                 # PATH 확인
$env:PATH -split ";"      # PATH를 줄별로 보기
[Environment]::GetEnvironmentVariable("PATH", "Machine")  # 시스템 PATH
```

### 유용한 팁

```powershell
# 히스토리
history                   # 명령어 기록
h                         # 축약형
Ctrl + R                  # 히스토리 검색 (PSReadLine)

# 클립보드
Get-Clipboard             # 클립보드 내용 가져오기
Set-Clipboard "text"      # 클립보드에 복사
ls | clip                 # 출력을 클립보드에 복사

# 별칭 확인
Get-Alias                 # 모든 별칭
Get-Alias ls              # 특정 별칭 확인

# 도움말
Get-Help command          # 명령어 도움말
Get-Help command -Examples    # 예제 보기
command -?                # 간단한 도움말

# 프로필 편집
nvim $PROFILE             # 프로필 편집
. $PROFILE                # 프로필 다시 로드
```

### Oh My Posh 테마

```powershell
# 테마 미리보기
Get-PoshThemes            # 모든 테마 미리보기

# 테마 변경 (프로필에서)
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\theme-name.omp.json" | Invoke-Expression
```

### 자주 쓰는 조합

```powershell
# 특정 확장자 파일 개수
(Get-ChildItem -Recurse -Filter "*.py").Count

# 폴더 크기 확인
(Get-ChildItem -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB

# 최근 수정된 파일 10개
Get-ChildItem -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 10

# 빈 폴더 찾기
Get-ChildItem -Directory -Recurse | Where-Object { (Get-ChildItem $_.FullName).Count -eq 0 }

# 중복 파일 찾기 (해시 기반)
Get-ChildItem -Recurse -File | Get-FileHash | Group-Object Hash | Where-Object { $_.Count -gt 1 }
```
