#!/usr/bin/env bash

set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "ERROR: This bootstrap is for macOS." >&2
  exit 1
fi

branch="${INIT_LUA_BRANCH:-main}"
if [[ ! "$branch" =~ ^[A-Za-z0-9._/-]+$ ]]; then
  echo "ERROR: Invalid Git branch: $branch" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1 || ! git --version >/dev/null 2>&1; then
  echo "Git requires the Xcode Command Line Tools. Starting the Apple installer..."
  xcode-select --install
  echo "Complete the Apple dialog, then rerun this bootstrap."
  exit 1
fi

repository_url="https://github.com/bic98/init_lua.git"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
target_path="$data_home/init_lua"

if [ -e "$target_path" ]; then
  if [ -d "$target_path/.git" ]; then
    remote="$(git -C "$target_path" remote get-url origin 2>/dev/null || true)"
    case "$remote" in
      https://github.com/bic98/init_lua|https://github.com/bic98/init_lua.git|git@github.com:bic98/init_lua.git|ssh://git@github.com/bic98/init_lua.git)
        ;;
      *)
        echo "ERROR: Existing init_lua directory has a different Git origin: $target_path" >&2
        exit 1
        ;;
    esac

    if [ -n "$(git -C "$target_path" status --porcelain)" ]; then
      echo "ERROR: Existing init_lua repository has local changes: $target_path" >&2
      exit 1
    fi
    current_branch="$(git -C "$target_path" branch --show-current)"
    if [ "$current_branch" != "$branch" ]; then
      echo "ERROR: Existing repository is on '$current_branch', not '$branch'." >&2
      exit 1
    fi

    echo "Updating init_lua..."
    git -C "$target_path" pull --ff-only origin "$branch"
  else
    backup_path="$target_path.backup_$(date +%Y%m%d_%H%M%S)"
    echo "Backing up the existing init_lua directory: $backup_path"
    mv "$target_path" "$backup_path"
    mkdir -p "$(dirname "$target_path")"
    git clone --branch "$branch" --single-branch "$repository_url" "$target_path"
  fi
else
  mkdir -p "$(dirname "$target_path")"
  git clone --branch "$branch" --single-branch "$repository_url" "$target_path"
fi

installer="$target_path/mac/install.sh"
if [ ! -f "$installer" ]; then
  echo "ERROR: macOS installer not found: $installer" >&2
  exit 1
fi

bash "$installer"
