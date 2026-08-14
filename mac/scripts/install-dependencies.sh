#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
platform_root="$(cd "$script_dir/.." && pwd -P)"
manifest="$platform_root/desired-state.json"
[ -f "$manifest" ] || { echo "ERROR: Desired-state manifest not found: $manifest" >&2; exit 1; }

skip_claude=0
check_only=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-claude-code) skip_claude=1; shift ;;
    --check) check_only=1; shift ;;
    *) echo "ERROR: Unknown dependency-installer option: $1" >&2; exit 2 ;;
  esac
done

version_at_least() {
  awk -v actual="$1" -v minimum="$2" 'BEGIN {
    split(actual, a, "."); split(minimum, m, ".");
    for (i = 1; i <= 4; i++) {
      av = (a[i] == "" ? 0 : a[i]) + 0; mv = (m[i] == "" ? 0 : m[i]) + 0;
      if (av > mv) exit 0; if (av < mv) exit 1;
    }
    exit 0
  }'
}

extract_version() {
  printf '%s\n' "$1" | sed -E 's/^[^0-9]*([0-9]+(\.[0-9]+){1,3}).*/\1/'
}

homebrew_installer="$(sed -nE '/"packageManager"/ s/.*"installer": "([^"]+)".*/\1/p' "$manifest")"
[ "$homebrew_installer" = "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" ] || { echo "ERROR: Unexpected Homebrew installer: $homebrew_installer" >&2; exit 1; }
formulae=()
while IFS= read -r formula; do
  [ -n "$formula" ] && formulae+=("$formula")
done < <(sed -nE '/"manager": "brew"/ s/.*"formula": "([^"]+)".*/\1/p' "$manifest")
[ "${#formulae[@]}" -gt 0 ] || { echo "ERROR: Empty Homebrew formula allowlist." >&2; exit 1; }
claude_required="$(sed -nE '/"name": "Claude Code"/ s/.*"minimumVersion": "([^"]+)".*/\1/p' "$manifest")"
claude_installer="$(sed -nE '/"name": "Claude Code"/ s/.*"installer": "([^"]+)".*/\1/p' "$manifest")"
[ "$claude_installer" = "https://claude.ai/install.sh" ] || { echo "ERROR: Unexpected Claude installer: $claude_installer" >&2; exit 1; }

if [ "$check_only" -eq 1 ]; then
  echo "Homebrew formulae: ${formulae[*]}"
  echo "PASS: macOS dependency manifest is valid"
  exit 0
fi

if ! command -v brew >/dev/null 2>&1; then
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools are required. Starting the Apple installer..."
  xcode-select --install
  echo "Complete the Apple dialog, then rerun this installer."
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew from its official installer..."
  /bin/bash -c "$(curl -fsSL "$homebrew_installer")"
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi
command -v brew >/dev/null 2>&1 || {
  echo "ERROR: Homebrew installation completed but brew is unavailable." >&2
  exit 1
}

for formula in "${formulae[@]}"; do
  if brew list --formula "$formula" >/dev/null 2>&1; then
    if [ -n "$(brew outdated --quiet --formula "$formula" 2>/dev/null || true)" ]; then
      brew upgrade "$formula"
    else
      echo "$formula already installed and current."
    fi
  else
    brew install "$formula"
  fi
done

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"
if [ "$skip_claude" -eq 0 ]; then
  claude_current=0
  if command -v claude >/dev/null 2>&1; then
    claude_version="$(extract_version "$(claude --version 2>&1 | head -n 1)")"
    version_at_least "$claude_version" "$claude_required" && claude_current=1
  fi
  if [ "$claude_current" -eq 0 ]; then
    curl -fsSL "$claude_installer" | bash
    export PATH="$HOME/.local/bin:$PATH"
    command -v claude >/dev/null 2>&1 || {
      echo "ERROR: Native Claude Code installation finished but claude is unavailable." >&2
      exit 1
    }
    claude_version="$(extract_version "$(claude --version 2>&1 | head -n 1)")"
    version_at_least "$claude_version" "$claude_required" || {
      echo "ERROR: Claude Code $claude_version is below required version $claude_required." >&2
      exit 1
    }
  fi
fi

echo "macOS dependencies installed."
