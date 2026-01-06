#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Neovim + Oh My Posh 설치 스크립트 (Linux/WSL)${NC}"
echo -e "${CYAN}========================================${NC}"
echo

# 스크립트 위치 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_CONFIG_DIR="$HOME/.config/nvim"

# 1단계: Oh My Posh 설치 확인
echo -e "${YELLOW}[1/3] Oh My Posh 확인 중...${NC}"
if ! command -v oh-my-posh &> /dev/null; then
    echo -e "${YELLOW}Oh My Posh가 설치되어 있지 않습니다. 설치를 시작합니다...${NC}"
    curl -s https://ohmyposh.dev/install.sh | bash -s

    # PATH에 추가
    export PATH="$HOME/.local/bin:$PATH"

    if command -v oh-my-posh &> /dev/null; then
        echo -e "${GREEN}✓ Oh My Posh 설치 완료${NC}"
    else
        echo -e "${RED}✗ Oh My Posh 설치 실패${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Oh My Posh가 이미 설치되어 있습니다${NC}"
fi
echo

# 2단계: 테마 파일 복사
echo -e "${YELLOW}[2/3] Oh My Posh 테마 설정 중...${NC}"
THEME_DIR="$HOME/.poshthemes"
mkdir -p "$THEME_DIR"

if [ -f "$SCRIPT_DIR/powershell/illusi0n.omp.json" ]; then
    cp "$SCRIPT_DIR/powershell/illusi0n.omp.json" "$THEME_DIR/"
    echo -e "${GREEN}✓ 테마 파일 복사 완료${NC}"
else
    echo -e "${YELLOW}⚠ 테마 파일을 찾을 수 없습니다 (powershell/illusi0n.omp.json)${NC}"
fi
echo

# 3단계: 쉘 프로필 설정
echo -e "${YELLOW}[3/3] 쉘 프로필 설정 중...${NC}"

# 사용 중인 쉘 확인
CURRENT_SHELL=$(basename "$SHELL")
PROFILE_FILE=""

case "$CURRENT_SHELL" in
    "zsh")
        PROFILE_FILE="$HOME/.zshrc"
        ;;
    "bash")
        PROFILE_FILE="$HOME/.bashrc"
        ;;
    *)
        PROFILE_FILE="$HOME/.bashrc"
        ;;
esac

# Oh My Posh 초기화 라인
OMP_INIT='eval "$(oh-my-posh init '"$CURRENT_SHELL"' --config ~/.poshthemes/illusi0n.omp.json)"'

# 이미 추가되어 있는지 확인
if grep -q "oh-my-posh init" "$PROFILE_FILE" 2>/dev/null; then
    echo -e "${GREEN}✓ Oh My Posh가 이미 프로필에 설정되어 있습니다${NC}"
else
    # 백업 생성
    if [ -f "$PROFILE_FILE" ]; then
        BACKUP_FILE="${PROFILE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$PROFILE_FILE" "$BACKUP_FILE"
        echo -e "${CYAN}기존 프로필 백업: $BACKUP_FILE${NC}"
    fi

    # Oh My Posh 초기화 추가
    echo "" >> "$PROFILE_FILE"
    echo "# Oh My Posh" >> "$PROFILE_FILE"
    echo "$OMP_INIT" >> "$PROFILE_FILE"
    echo -e "${GREEN}✓ $PROFILE_FILE에 Oh My Posh 설정 추가 완료${NC}"
fi

# PATH 설정 추가 (oh-my-posh 경로)
if ! grep -q 'PATH="$HOME/.local/bin:$PATH"' "$PROFILE_FILE" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$PROFILE_FILE"
fi

echo
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}✓ 설치가 완료되었습니다!${NC}"
echo -e "${CYAN}========================================${NC}"
echo
echo -e "${YELLOW}다음 단계:${NC}"
echo -e "  1. 터미널을 재시작하거나 다음 명령어 실행:"
echo -e "     ${CYAN}source $PROFILE_FILE${NC}"
echo -e "  2. Neovim 실행:"
echo -e "     ${CYAN}nvim${NC}"
echo -e "  3. 첫 실행 시 Lazy.nvim이 자동으로 플러그인을 설치합니다"
echo
