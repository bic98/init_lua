#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
manifest="$script_dir/desired-state.json"
[ -f "$manifest" ] || { echo "ERROR: Desired-state manifest not found: $manifest" >&2; exit 1; }
oh_my_posh_required="$(sed -nE '/"name": "Oh My Posh"/ s/.*"minimumVersion": "([^"]+)".*/\1/p' "$manifest")"
oh_my_posh_installer="$(sed -nE '/"name": "Oh My Posh"/ s/.*"installer": "([^"]+)".*/\1/p' "$manifest")"
[ "$oh_my_posh_installer" = "https://ohmyposh.dev/install.sh" ] || { echo "ERROR: Unexpected Oh My Posh installer: $oh_my_posh_installer" >&2; exit 1; }
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
nvim_source="$script_dir/settings/nvim"
nvim_destination="$config_home/nvim"
theme_source="$script_dir/settings/oh-my-posh/illusi0n-dayfox.omp.json"
theme_destination="$config_home/init_lua/illusi0n-dayfox.omp.json"
tmux_source="$script_dir/settings/tmux.conf"
tmux_destination="$config_home/init_lua/tmux.conf"

skip_oh_my_posh=0
skip_dependencies=0
skip_claude=0
skip_nvim=0
skip_nvim_plugins=0
skip_shell=0
skip_tmux=0
shell_name="$(basename "${SHELL:-bash}")"
profile_path=""

usage() {
  cat <<'EOF'
Usage: bash wsl/install.sh [options]
  --shell bash|zsh       Select the managed shell profile
  --profile PATH         Override the shell profile path
  --nvim-dir PATH        Override the Neovim config directory
  --skip-dependencies    Do not install declared required tools
  --skip-claude-code     Do not install the Claude Code CLI
  --skip-oh-my-posh      Do not install Oh My Posh when missing
  --skip-nvim            Do not synchronize the WSL Neovim files
  --skip-nvim-plugins    Do not install locked plugins and Mason tools
  --skip-shell           Do not update the shell profile
  --skip-tmux            Do not install tmux settings
EOF
}

version_at_least() {
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n 1)" = "$2" ]
}

extract_version() {
  printf '%s\n' "$1" | sed -E 's/^[^0-9]*([0-9]+(\.[0-9]+){1,3}).*/\1/'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --shell)
      shell_name="${2:-}"
      shift 2
      ;;
    --profile)
      profile_path="${2:-}"
      shift 2
      ;;
    --nvim-dir)
      nvim_destination="${2:-}"
      shift 2
      ;;
    --skip-oh-my-posh)
      skip_oh_my_posh=1
      shift
      ;;
    --skip-dependencies)
      skip_dependencies=1
      shift
      ;;
    --skip-claude-code)
      skip_claude=1
      shift
      ;;
    --skip-nvim)
      skip_nvim=1
      shift
      ;;
    --skip-nvim-plugins)
      skip_nvim_plugins=1
      shift
      ;;
    --skip-shell)
      skip_shell=1
      shift
      ;;
    --skip-tmux)
      skip_tmux=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

partial_run=0
if [ "$skip_oh_my_posh" -eq 1 ] || [ "$skip_dependencies" -eq 1 ] || [ "$skip_claude" -eq 1 ] ||
   [ "$skip_nvim" -eq 1 ] || [ "$skip_nvim_plugins" -eq 1 ] || [ "$skip_shell" -eq 1 ] ||
   [ "$skip_tmux" -eq 1 ]; then
  partial_run=1
fi

case "$shell_name" in
  bash|zsh)
    ;;
  *)
    echo "ERROR: Supported WSL shells are bash and zsh, not '$shell_name'." >&2
    exit 1
    ;;
esac

if [ -z "$profile_path" ]; then
  if [ "$shell_name" = "zsh" ]; then
    profile_path="$HOME/.zshrc"
  else
    profile_path="$HOME/.bashrc"
  fi
fi

sync_file() {
  local source="$1"
  local destination="$2"
  local label="$3"
  local backup=""

  if [ ! -f "$source" ]; then
    echo "ERROR: $label source not found: $source" >&2
    return 1
  fi
  mkdir -p "$(dirname "$destination")"
  if [ -f "$destination" ] && cmp -s "$source" "$destination"; then
    echo "  $label already matches: $destination"
    return 0
  fi
  if [ -e "$destination" ]; then
    backup="$destination.backup_$(date +%Y%m%d_%H%M%S)"
    cp -p "$destination" "$backup"
  fi
  cp "$source" "$destination"
  echo "  $label synchronized: $destination"
  if [ -n "$backup" ]; then
    echo "  Previous $label backup: $backup"
  fi
}

sync_tree() {
  local source="$1"
  local destination="$2"
  local label="$3"
  local source_abs destination_parent destination_abs source_file relative target changed backup legacy_checkout remote

  if [ ! -d "$source" ]; then
    echo "ERROR: $label source directory not found: $source" >&2
    return 1
  fi
  source_abs="$(cd "$source" && pwd -P)"
  destination_parent="$(dirname "$destination")"
  mkdir -p "$destination_parent"
  destination_abs="$(cd "$destination_parent" && pwd -P)/$(basename "$destination")"
  case "$source_abs/" in
    "$destination_abs/"*)
      echo "  $label sync skipped because this is a legacy checkout inside the destination."
      return 0
      ;;
  esac

  legacy_checkout=0
  if [ -e "$destination/.git" ] && command -v git >/dev/null 2>&1; then
    remote="$(git -C "$destination" remote get-url origin 2>/dev/null || true)"
    case "$remote" in
      https://github.com/bic98/init_lua|https://github.com/bic98/init_lua.git|git@github.com:bic98/init_lua.git|ssh://git@github.com/bic98/init_lua.git)
        legacy_checkout=1
        ;;
    esac
  fi

  changed="$legacy_checkout"
  if [ ! -d "$destination" ]; then
    changed=1
  elif [ "$changed" -eq 0 ]; then
    while IFS= read -r source_file; do
      relative="${source_file#"$source/"}"
      target="$destination/$relative"
      if [ ! -f "$target" ] || ! cmp -s "$source_file" "$target"; then
        changed=1
        break
      fi
    done < <(find "$source" -type f -print)
  fi

  if [ "$changed" -eq 0 ]; then
    echo "  $label already matches: $destination"
    return 0
  fi

  backup=""
  if [ -d "$destination" ]; then
    backup="$destination.backup_$(date +%Y%m%d_%H%M%S)"
    if [ "$legacy_checkout" -eq 1 ]; then
      mv "$destination" "$backup"
      mkdir -p "$destination"
    else
      cp -R -p "$destination" "$backup"
    fi
  else
    mkdir -p "$destination"
  fi
  cp -R "$source/." "$destination/"
  echo "  $label synchronized: $destination"
  if [ -n "$backup" ]; then
    echo "  Previous $label backup: $backup"
  fi
}

sync_managed_block() {
  local source="$1"
  local destination="$2"
  local start_marker="$3"
  local end_marker="$4"
  local label="$5"
  local stripped updated backup

  if [ ! -f "$source" ]; then
    echo "ERROR: $label source not found: $source" >&2
    return 1
  fi
  mkdir -p "$(dirname "$destination")"
  [ -f "$destination" ] || : > "$destination"
  stripped="$(mktemp)"
  updated="$(mktemp)"
  awk -v start="$start_marker" -v end="$end_marker" '
    function flush_blanks() { for (i = 0; i < blank_count; i++) print ""; blank_count = 0 }
    $0 == start { in_block = 1; next }
    $0 == end { in_block = 0; next }
    in_block { next }
    /^[[:space:]]*$/ { blank_count++; next }
    { flush_blanks(); print }
  ' "$destination" > "$stripped"
  if [ -s "$stripped" ]; then
    cat "$stripped" > "$updated"
    printf '\n\n' >> "$updated"
  fi
  cat "$source" >> "$updated"
  printf '\n' >> "$updated"

  if cmp -s "$updated" "$destination"; then
    echo "  $label already contains the current init_lua block."
    rm -f "$stripped" "$updated"
    return 0
  fi
  backup=""
  if [ -s "$destination" ]; then
    backup="$destination.backup_$(date +%Y%m%d_%H%M%S)"
    cp -p "$destination" "$backup"
  fi
  mv "$updated" "$destination"
  rm -f "$stripped"
  echo "  $label synchronized: $destination"
  if [ -n "$backup" ]; then
    echo "  Previous $label backup: $backup"
  fi
}

echo
echo "=== init_lua WSL configuration ==="
echo "The declared WSL desired state will be installed and verified."

echo
echo "[1/7] Required tools"
if [ "$skip_dependencies" -eq 1 ]; then
  echo "  Dependency installation skipped by explicit request."
else
  dependency_args=()
  [ "$skip_claude" -eq 1 ] && dependency_args+=(--skip-claude-code)
  bash "$script_dir/scripts/install-dependencies.sh" "${dependency_args[@]}"
  export PATH="$HOME/.local/bin:$PATH"
fi

echo
echo "[2/7] Neovim configuration"
if [ "$skip_nvim" -eq 1 ]; then
  echo "  Neovim configuration synchronization skipped."
else
  sync_tree "$nvim_source" "$nvim_destination" "Neovim configuration"
fi

echo
echo "[3/7] Neovim plugins and Mason tools"
if [ "$skip_nvim" -eq 1 ] || [ "$skip_nvim_plugins" -eq 1 ]; then
  echo "  Neovim plugin installation skipped by explicit request."
elif ! command -v nvim >/dev/null 2>&1; then
  echo "ERROR: Neovim is required to install locked plugins." >&2
  exit 1
else
  XDG_CONFIG_HOME="$(dirname "$nvim_destination")" NVIM_APPNAME="$(basename "$nvim_destination")" \
    nvim --headless -i NONE -n '+Lazy! restore' '+Lazy! clean' '+qa'
  XDG_CONFIG_HOME="$(dirname "$nvim_destination")" NVIM_APPNAME="$(basename "$nvim_destination")" \
    nvim --headless -i NONE -n '+MasonToolsInstallSync' '+qa'
  echo "  Locked Neovim plugins and Mason tools synchronized."
fi

echo
echo "[4/7] Oh My Posh"
export PATH="$HOME/.local/bin:$PATH"
oh_my_posh_current=0
if command -v oh-my-posh >/dev/null 2>&1; then
  oh_my_posh_version="$(extract_version "$(oh-my-posh version 2>&1 | head -n 1)")"
  version_at_least "$oh_my_posh_version" "$oh_my_posh_required" && oh_my_posh_current=1
fi
if [ "$oh_my_posh_current" -eq 1 ]; then
  echo "  Oh My Posh ready: $(command -v oh-my-posh) ($oh_my_posh_version)"
elif [ "$skip_oh_my_posh" -eq 1 ]; then
  echo "  Oh My Posh installation skipped."
elif ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl is required by the official Oh My Posh user installer." >&2
  exit 1
else
  mkdir -p "$HOME/.local/bin"
  curl -fsSL "$oh_my_posh_installer" | bash -s -- -d "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"
  command -v oh-my-posh >/dev/null 2>&1 || {
    echo "ERROR: Oh My Posh installation finished but the command is unavailable." >&2
    exit 1
  }
  oh_my_posh_version="$(extract_version "$(oh-my-posh version 2>&1 | head -n 1)")"
  version_at_least "$oh_my_posh_version" "$oh_my_posh_required" || {
    echo "ERROR: Oh My Posh $oh_my_posh_version is below required version $oh_my_posh_required." >&2
    exit 1
  }
fi
sync_file "$theme_source" "$theme_destination" "Oh My Posh theme"

echo
echo "[5/7] $shell_name profile"
if [ "$skip_shell" -eq 1 ]; then
  echo "  Shell profile synchronization skipped."
else
  sync_managed_block \
    "$script_dir/settings/shell/init_lua.sh" \
    "$profile_path" \
    "# >>> init_lua shell >>>" \
    "# <<< init_lua shell <<<" \
    "$shell_name profile"
fi

echo
echo "[6/7] tmux"
if [ "$skip_tmux" -eq 1 ]; then
  echo "  tmux synchronization skipped."
else
  sync_file "$tmux_source" "$tmux_destination" "tmux settings"
  tmux_block="$(mktemp)"
  cat > "$tmux_block" <<EOF
# >>> init_lua tmux >>>
source-file "$tmux_destination"
# <<< init_lua tmux <<<
EOF
  sync_managed_block "$tmux_block" "$HOME/.tmux.conf" "# >>> init_lua tmux >>>" "# <<< init_lua tmux <<<" "tmux profile"
  rm -f "$tmux_block"
fi

echo
echo "[7/7] Verification"
failures=0
[ "$skip_nvim" -eq 1 ] || [ -f "$nvim_destination/init.lua" ] || { echo "  FAIL: Neovim configuration"; failures=$((failures + 1)); }
[ -f "$theme_destination" ] || { echo "  FAIL: Oh My Posh theme"; failures=$((failures + 1)); }
[ "$skip_shell" -eq 1 ] || grep -Fq "# >>> init_lua shell >>>" "$profile_path" || { echo "  FAIL: shell profile block"; failures=$((failures + 1)); }
[ "$skip_tmux" -eq 1 ] || grep -Fq "# >>> init_lua tmux >>>" "$HOME/.tmux.conf" || { echo "  FAIL: tmux profile block"; failures=$((failures + 1)); }
if [ "$failures" -gt 0 ]; then
  echo "ERROR: init_lua WSL configuration failed $failures basic check(s)." >&2
  exit 1
fi
verification_args=(--nvim-dir "$nvim_destination" --profile "$profile_path" --shell "$shell_name")
[ "$skip_dependencies" -eq 1 ] && verification_args+=(--skip-tools)
[ "$skip_nvim_plugins" -eq 1 ] && verification_args+=(--skip-plugins)
[ "$skip_shell" -eq 1 ] && verification_args+=(--skip-shell)
[ "$skip_tmux" -eq 1 ] && verification_args+=(--skip-tmux)
bash "$script_dir/scripts/verify.sh" "${verification_args[@]}"
if [ "$partial_run" -eq 1 ]; then
  echo "init_lua WSL partial run complete; RESULT is not MATCHED."
else
  echo "init_lua WSL configuration complete. Restart the shell to load it."
fi
