#!/usr/bin/env bash
set -euo pipefail

if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
export PATH="$HOME/.local/bin:$PATH"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
platform_root="$(cd "$script_dir/.." && pwd -P)"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
nvim_dir="$config_home/nvim"
profile_path=""
shell_name="$(basename "${SHELL:-zsh}")"
skip_tools=0
skip_plugins=0
skip_shell=0
skip_tmux=0
skip_font=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --nvim-dir) nvim_dir="${2:-}"; shift 2 ;;
    --profile) profile_path="${2:-}"; shift 2 ;;
    --shell) shell_name="${2:-}"; shift 2 ;;
    --skip-tools) skip_tools=1; shift ;;
    --skip-plugins) skip_plugins=1; shift ;;
    --skip-shell) skip_shell=1; shift ;;
    --skip-tmux) skip_tmux=1; shift ;;
    --skip-font) skip_font=1; shift ;;
    *) echo "ERROR: Unknown verifier option: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$profile_path" ]; then
  [ "$shell_name" = "bash" ] && profile_path="$HOME/.bashrc" || profile_path="$HOME/.zshrc"
fi

failures=0
add_check() {
  if [ "$1" -eq 0 ]; then
    printf 'PASS\t%s\t%s\n' "$2" "$3"
  else
    printf 'FAIL\t%s\t%s\n' "$2" "$3"
    failures=$((failures + 1))
  fi
}

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
extract_version() { printf '%s\n' "$1" | sed -E 's/^[^0-9]*([0-9]+(\.[0-9]+){1,3}).*/\1/'; }

manifest="$platform_root/desired-state.json"
[ -f "$manifest" ] && add_check 0 "Desired-state manifest" "$manifest" || add_check 1 "Desired-state manifest" "$manifest"
if [ "$(uname -s)" = "Darwin" ]; then
  add_check 0 "Platform" "macOS"
elif [ "${INIT_LUA_TEST_MODE:-0}" = "1" ]; then
  add_check 0 "Platform" "non-macOS isolated test mode"
else
  add_check 1 "Platform" "not macOS"
fi

if [ "$skip_tools" -eq 0 ]; then
  while IFS='|' read -r label command_name minimum; do
    [ -n "$label" ] || continue
    if ! command -v "$command_name" >/dev/null 2>&1; then
      add_check 1 "$label" "command not found; required >= $minimum"
      continue
    fi
    case "$command_name" in
      tmux) raw_version="$(tmux -V </dev/null 2>&1)" ;;
      oh-my-posh) raw_version="$(oh-my-posh version </dev/null 2>&1)" ;;
      *) raw_version="$($command_name --version </dev/null 2>&1 | head -n 1)" ;;
    esac
    actual="$(extract_version "$raw_version")"
    if { [ "$command_name" = "claude" ] || [ "$command_name" = "oh-my-posh" ]; } &&
        [ "$(command -v "$command_name")" != "$HOME/.local/bin/$command_name" ]; then
      add_check 1 "$label" "$raw_version; expected native path $HOME/.local/bin/$command_name"
    elif version_at_least "$actual" "$minimum"; then
      add_check 0 "$label" "$raw_version"
    else
      add_check 1 "$label" "$raw_version; required >= $minimum"
    fi
  done < <(sed -nE 's/.*"name": "([^"]+)", "command": "([^"]+)", "minimumVersion": "([^"]+)".*/\1|\2|\3/p' "$manifest")
  if [ "$(command -v claude 2>/dev/null || true)" = "$HOME/.local/bin/claude" ] && claude auth status >/dev/null 2>&1; then
    add_check 0 "Claude Code authentication" "logged in"
  else
    add_check 1 "Claude Code authentication" "run: claude auth login"
  fi
  xcode-select -p >/dev/null 2>&1 && add_check 0 "Xcode Command Line Tools" "installed" || add_check 1 "Xcode Command Line Tools" "missing"
fi

nvim_source="$platform_root/settings/nvim"
tree_matches=0
if [ -d "$nvim_source" ] && [ -d "$nvim_dir" ]; then
  tree_matches=1
  while IFS= read -r source_file; do
    relative="${source_file#"$nvim_source/"}"
    if [ ! -f "$nvim_dir/$relative" ] || ! cmp -s "$source_file" "$nvim_dir/$relative"; then tree_matches=0; break; fi
  done < <(find "$nvim_source" -type f -print)
fi
[ "$tree_matches" -eq 1 ] && add_check 0 "Neovim settings" "$nvim_dir" || add_check 1 "Neovim settings" "$nvim_dir"

theme_source="$platform_root/settings/oh-my-posh/illusi0n-dayfox.omp.json"
theme_destination="$config_home/init_lua/illusi0n-dayfox.omp.json"
[ -f "$theme_destination" ] && cmp -s "$theme_source" "$theme_destination" && add_check 0 "Oh My Posh theme" "$theme_destination" || add_check 1 "Oh My Posh theme" "$theme_destination"

if [ "$skip_font" -eq 0 ]; then
  if find "$HOME/Library/Fonts" -maxdepth 1 -type f \( -iname 'JetBrainsMono*NerdFont*.ttf' -o -iname 'JetBrainsMono*NF*.ttf' \) -print -quit 2>/dev/null | grep -q .; then
    add_check 0 "JetBrainsMono Nerd Font" "$HOME/Library/Fonts"
  else
    add_check 1 "JetBrainsMono Nerd Font" "$HOME/Library/Fonts"
  fi
fi

if [ "$skip_shell" -eq 0 ]; then
  extracted_block="$(mktemp)"
  sed -n '/^# >>> init_lua shell >>>$/,/^# <<< init_lua shell <<<$/{p;}' "$profile_path" 2>/dev/null > "$extracted_block" || true
  cmp -s "$platform_root/settings/shell/init_lua.sh" "$extracted_block" && add_check 0 "Shell profile block" "$profile_path" || add_check 1 "Shell profile block" "$profile_path"
  rm -f "$extracted_block"
fi

if [ "$skip_tmux" -eq 0 ]; then
  tmux_destination="$config_home/init_lua/tmux.conf"
  if [ -f "$tmux_destination" ] && cmp -s "$platform_root/settings/tmux.conf" "$tmux_destination" && grep -Fq '# >>> init_lua tmux >>>' "$HOME/.tmux.conf" 2>/dev/null; then
    add_check 0 "tmux settings" "$tmux_destination"
  else
    add_check 1 "tmux settings" "$tmux_destination"
  fi
fi

if [ "$skip_plugins" -eq 0 ]; then
  source_lock="$nvim_source/lazy-lock.json"
  installed_lock="$nvim_dir/lazy-lock.json"
  [ -f "$installed_lock" ] && cmp -s "$source_lock" "$installed_lock" && add_check 0 "Neovim plugin lock" "$installed_lock" || add_check 1 "Neovim plugin lock" "$installed_lock"
  app_name="$(basename "$nvim_dir")"
  data_root="${XDG_DATA_HOME:-$HOME/.local/share}/$app_name"
  lazy_root="$data_root/lazy"
  plugin_mismatches=""
  plugin_count=0
  while IFS='|' read -r plugin expected_commit; do
    [ -n "$plugin" ] || continue
    plugin_count=$((plugin_count + 1))
    plugin_dir="$lazy_root/$plugin"
    if [ ! -d "$plugin_dir" ]; then
      plugin_mismatches="$plugin_mismatches $plugin(missing)"
      continue
    fi
    actual_commit="$(git -C "$plugin_dir" rev-parse HEAD </dev/null 2>/dev/null || true)"
    if [ "$actual_commit" != "$expected_commit" ]; then
      plugin_mismatches="$plugin_mismatches $plugin(commit-mismatch)"
    elif [ -n "$(git -C "$plugin_dir" status --porcelain </dev/null 2>/dev/null | sed '/^?? doc\/tags$/d' || true)" ]; then
      plugin_mismatches="$plugin_mismatches $plugin(dirty-worktree)"
    fi
  done < <(sed -nE 's/^  "([^"]+)": \{.*"commit": "([0-9a-f]+)".*/\1|\2/p' "$source_lock")
  [ -z "$plugin_mismatches" ] && [ "$plugin_count" -gt 0 ] && add_check 0 "Neovim locked plugins" "$plugin_count plugins at locked commits" || add_check 1 "Neovim locked plugins" "mismatch:$plugin_mismatches"
  mason_root="$data_root/mason/packages"
  missing_mason=""
  mason_packages="$(sed -nE 's/.*"masonPackages": \[([^]]+)\].*/\1/p' "$manifest" | tr -d '",')"
  for package in $mason_packages; do [ -d "$mason_root/$package" ] && [ -f "$mason_root/$package/mason-receipt.json" ] || missing_mason="$missing_mason $package"; done
  [ -n "$mason_packages" ] && [ -z "$missing_mason" ] && add_check 0 "Mason tools" "$mason_root" || add_check 1 "Mason tools" "missing:$missing_mason"
fi

if [ "$failures" -gt 0 ]; then echo "FAILED: $failures required macOS check(s)"; exit 1; fi
if [ "$skip_tools" -eq 1 ] || [ "$skip_plugins" -eq 1 ] || [ "$skip_shell" -eq 1 ] || [ "$skip_tmux" -eq 1 ] || [ "$skip_font" -eq 1 ]; then
  echo "PASS: checked macOS subset matches; RESULT is not MATCHED"
else
  echo "PASS: macOS desired state matches"
fi
