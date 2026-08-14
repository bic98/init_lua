#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

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

if [ "$check_only" -eq 1 ]; then
  for manager_name in apt dnf pacman zypper; do
    package_text="$(sed -nE "s/^[[:space:]]*\"$manager_name\": \[([^]]+)\].*/\1/p" "$manifest" | tr -d '",')"
    [ -n "$package_text" ] || { echo "ERROR: Empty $manager_name package allowlist." >&2; exit 1; }
    echo "$manager_name packages: $package_text"
  done
  nvim_required="$(sed -nE '/"name": "Neovim"/ s/.*"minimumVersion": "([^"]+)".*/\1/p' "$manifest")"
  claude_installer="$(sed -nE '/"name": "Claude Code"/ s/.*"installer": "([^"]+)".*/\1/p' "$manifest")"
  [[ "$nvim_required" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "ERROR: Invalid desired Neovim version: $nvim_required" >&2; exit 1; }
  [ "$claude_installer" = "https://claude.ai/install.sh" ] || { echo "ERROR: Unexpected Claude installer: $claude_installer" >&2; exit 1; }
  echo "PASS: WSL dependency manifest is valid"
  exit 0
fi

install_system_packages() {
  local sudo_command=()
  local package_text
  local declared_packages=()
  if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null 2>&1 || {
      echo "ERROR: sudo is required to install declared WSL system packages." >&2
      exit 1
    }
    sudo_command=(sudo)
  fi

  if command -v apt-get >/dev/null 2>&1; then
    package_text="$(sed -nE 's/^[[:space:]]*"apt": \[([^]]+)\].*/\1/p' "$manifest" | tr -d '",')"
    read -r -a declared_packages <<< "$package_text"
    [ "${#declared_packages[@]}" -gt 0 ] || { echo "ERROR: Empty apt package allowlist." >&2; exit 1; }
    "${sudo_command[@]}" apt-get update
    "${sudo_command[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y "${declared_packages[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    package_text="$(sed -nE 's/^[[:space:]]*"dnf": \[([^]]+)\].*/\1/p' "$manifest" | tr -d '",')"
    read -r -a declared_packages <<< "$package_text"
    [ "${#declared_packages[@]}" -gt 0 ] || { echo "ERROR: Empty dnf package allowlist." >&2; exit 1; }
    "${sudo_command[@]}" dnf install -y "${declared_packages[@]}"
  elif command -v pacman >/dev/null 2>&1; then
    package_text="$(sed -nE 's/^[[:space:]]*"pacman": \[([^]]+)\].*/\1/p' "$manifest" | tr -d '",')"
    read -r -a declared_packages <<< "$package_text"
    [ "${#declared_packages[@]}" -gt 0 ] || { echo "ERROR: Empty pacman package allowlist." >&2; exit 1; }
    "${sudo_command[@]}" pacman -Sy --needed --noconfirm "${declared_packages[@]}"
  elif command -v zypper >/dev/null 2>&1; then
    package_text="$(sed -nE 's/^[[:space:]]*"zypper": \[([^]]+)\].*/\1/p' "$manifest" | tr -d '",')"
    read -r -a declared_packages <<< "$package_text"
    [ "${#declared_packages[@]}" -gt 0 ] || { echo "ERROR: Empty zypper package allowlist." >&2; exit 1; }
    "${sudo_command[@]}" zypper --non-interactive install "${declared_packages[@]}"
  else
    echo "ERROR: Supported WSL package manager not found (apt, dnf, pacman, zypper)." >&2
    exit 1
  fi
}

version_at_least() {
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n 1)" = "$2" ]
}

extract_version() {
  printf '%s\n' "$1" | sed -E 's/^[^0-9]*([0-9]+(\.[0-9]+){1,3}).*/\1/'
}

needs_packages=0
for command_name in unzip make gcc; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    needs_packages=1
    break
  fi
  case "$(command -v "$command_name")" in
    /mnt/*) needs_packages=1; break ;;
  esac
done
if [ "$needs_packages" -eq 0 ]; then
  while IFS='|' read -r command_name minimum; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      needs_packages=1
      break
    fi
    case "$(command -v "$command_name")" in
      /mnt/*) needs_packages=1; break ;;
    esac
    case "$command_name" in
      tmux) raw_version="$(tmux -V </dev/null 2>&1)" ;;
      *) raw_version="$($command_name --version </dev/null 2>&1 | head -n 1)" ;;
    esac
    actual_version="$(extract_version "$raw_version")"
    if ! version_at_least "$actual_version" "$minimum"; then
      needs_packages=1
      break
    fi
  done < <(sed -nE '/"packages":/ s/.*"command": "([^"]+)", "minimumVersion": "([^"]+)".*/\1|\2/p' "$manifest")
fi
if [ "$needs_packages" -eq 1 ]; then
  install_system_packages
  hash -r
else
  echo "Required WSL system packages are already available."
fi

nvim_version=""
nvim_required="$(sed -nE '/"name": "Neovim"/ s/.*"minimumVersion": "([^"]+)".*/\1/p' "$manifest")"
[[ "$nvim_required" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "ERROR: Invalid desired Neovim version: $nvim_required" >&2; exit 1; }
if command -v nvim >/dev/null 2>&1; then
  nvim_version="$(nvim --version | sed -n '1s/^NVIM v//p')"
fi
if [ -z "$nvim_version" ] || ! version_at_least "$nvim_version" "$nvim_required"; then
  architecture="$(uname -m)"
  case "$architecture" in
    x86_64) asset_arch="x86_64" ;;
    aarch64|arm64) asset_arch="arm64" ;;
    *) echo "ERROR: Unsupported Neovim architecture: $architecture" >&2; exit 1 ;;
  esac
  data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  tools_root="$data_home/init_lua/tools"
  install_root="$tools_root/nvim-$nvim_required"
  archive="$(mktemp)"
  extract_root="$(mktemp -d)"
  trap 'rm -f "$archive"; rm -rf "$extract_root"' EXIT
  curl -fL "https://github.com/neovim/neovim/releases/download/v$nvim_required/nvim-linux-$asset_arch.tar.gz" -o "$archive"
  tar -xzf "$archive" -C "$extract_root"
  mkdir -p "$tools_root" "$HOME/.local/bin"
  if [ -e "$install_root" ]; then
    mv "$install_root" "$install_root.backup_$(date +%Y%m%d_%H%M%S)"
  fi
  mv "$extract_root/nvim-linux-$asset_arch" "$install_root"
  if [ -e "$HOME/.local/bin/nvim" ] && [ ! -L "$HOME/.local/bin/nvim" ]; then
    mv "$HOME/.local/bin/nvim" "$HOME/.local/bin/nvim.backup_$(date +%Y%m%d_%H%M%S)"
  fi
  ln -sfn "$install_root/bin/nvim" "$HOME/.local/bin/nvim"
  rm -f "$archive"
  rmdir "$extract_root" 2>/dev/null || true
  trap - EXIT
fi

export PATH="$HOME/.local/bin:$PATH"
if [ "$skip_claude" -eq 0 ]; then
  claude_required="$(sed -nE '/"name": "Claude Code"/ s/.*"minimumVersion": "([^"]+)".*/\1/p' "$manifest")"
  claude_installer="$(sed -nE '/"name": "Claude Code"/ s/.*"installer": "([^"]+)".*/\1/p' "$manifest")"
  [ "$claude_installer" = "https://claude.ai/install.sh" ] || { echo "ERROR: Unexpected Claude installer: $claude_installer" >&2; exit 1; }
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

echo "WSL dependencies installed."
