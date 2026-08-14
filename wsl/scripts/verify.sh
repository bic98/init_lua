#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
platform_root="$(cd "$script_dir/.." && pwd -P)"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
nvim_dir="$config_home/nvim"
profile_path=""
shell_name="$(basename "${SHELL:-bash}")"
skip_tools=0
skip_plugins=0
skip_shell=0
skip_tmux=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --nvim-dir) nvim_dir="${2:-}"; shift 2 ;;
    --profile) profile_path="${2:-}"; shift 2 ;;
    --shell) shell_name="${2:-}"; shift 2 ;;
    --skip-tools) skip_tools=1; shift ;;
    --skip-plugins) skip_plugins=1; shift ;;
    --skip-shell) skip_shell=1; shift ;;
    --skip-tmux) skip_tmux=1; shift ;;
    *) echo "ERROR: Unknown verifier option: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$profile_path" ]; then
  [ "$shell_name" = "zsh" ] && profile_path="$HOME/.zshrc" || profile_path="$HOME/.bashrc"
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

extract_version() {
  printf '%s\n' "$1" | sed -E 's/^[^0-9]*([0-9]+(\.[0-9]+){1,3}).*/\1/'
}

manifest="$platform_root/desired-state.json"
[ -f "$manifest" ] && manifest_status=0 || manifest_status=1
add_check "$manifest_status" "Desired-state manifest" "$manifest"

if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
  add_check 0 "Platform" "WSL"
else
  add_check 1 "Platform" "not WSL"
fi

if [ "$skip_tools" -eq 0 ]; then
  while IFS='|' read -r label command_name minimum; do
    [ -n "$label" ] || continue
    if ! command -v "$command_name" >/dev/null 2>&1; then
      add_check 1 "$label" "command not found; required >= $minimum"
      continue
    fi
    command_path="$(command -v "$command_name")"
    case "$command_path" in
      /mnt/*)
        add_check 1 "$label" "Windows interop command is not a native WSL install: $command_path"
        continue
        ;;
    esac
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
fi

nvim_source="$platform_root/settings/nvim"
tree_matches=0
if [ -d "$nvim_source" ] && [ -d "$nvim_dir" ]; then
  tree_matches=1
  while IFS= read -r source_file; do
    relative="${source_file#"$nvim_source/"}"
    if [ ! -f "$nvim_dir/$relative" ] || ! cmp -s "$source_file" "$nvim_dir/$relative"; then
      tree_matches=0
      break
    fi
  done < <(find "$nvim_source" -type f -print)
fi
[ "$tree_matches" -eq 1 ] && add_check 0 "Neovim settings" "$nvim_dir" || add_check 1 "Neovim settings" "$nvim_dir"

theme_source="$platform_root/settings/oh-my-posh/illusi0n-dayfox.omp.json"
theme_destination="$config_home/init_lua/illusi0n-dayfox.omp.json"
if [ -f "$theme_destination" ] && cmp -s "$theme_source" "$theme_destination"; then
  add_check 0 "Oh My Posh theme" "$theme_destination"
else
  add_check 1 "Oh My Posh theme" "$theme_destination"
fi

if [ "$skip_shell" -eq 0 ]; then
  shell_source="$platform_root/settings/shell/init_lua.sh"
  extracted_block="$(mktemp)"
  sed -n '/^# >>> init_lua shell >>>$/,/^# <<< init_lua shell <<<$/{p;}' "$profile_path" 2>/dev/null > "$extracted_block" || true
  if cmp -s "$shell_source" "$extracted_block"; then
    add_check 0 "Shell profile block" "$profile_path"
  else
    add_check 1 "Shell profile block" "$profile_path"
  fi
  rm -f "$extracted_block"
fi

if [ "$skip_tmux" -eq 0 ]; then
  tmux_destination="$config_home/init_lua/tmux.conf"
  if [ -f "$tmux_destination" ] && cmp -s "$platform_root/settings/tmux.conf" "$tmux_destination" &&
      grep -Fq '# >>> init_lua tmux >>>' "$HOME/.tmux.conf" 2>/dev/null; then
    add_check 0 "tmux settings" "$tmux_destination"
  else
    add_check 1 "tmux settings" "$tmux_destination"
  fi
fi

if [ "$skip_plugins" -eq 0 ]; then
  source_lock="$nvim_source/lazy-lock.json"
  installed_lock="$nvim_dir/lazy-lock.json"
  if [ -f "$installed_lock" ] && cmp -s "$source_lock" "$installed_lock"; then
    add_check 0 "Neovim plugin lock" "$installed_lock"
  else
    add_check 1 "Neovim plugin lock" "$installed_lock"
  fi

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
  if [ -z "$plugin_mismatches" ] && [ "$plugin_count" -gt 0 ]; then
    add_check 0 "Neovim locked plugins" "$plugin_count plugins at locked commits"
  else
    add_check 1 "Neovim locked plugins" "mismatch:$plugin_mismatches"
  fi

  mason_root="$data_root/mason/packages"
  missing_mason=""
  mason_packages="$(sed -nE 's/.*"masonPackages": \[([^]]+)\].*/\1/p' "$manifest" | tr -d '",')"
  for package in $mason_packages; do
    [ -d "$mason_root/$package" ] && [ -f "$mason_root/$package/mason-receipt.json" ] || missing_mason="$missing_mason $package"
  done
  if [ -n "$mason_packages" ] && [ -z "$missing_mason" ]; then
    add_check 0 "Mason tools" "$mason_root"
  else
    add_check 1 "Mason tools" "missing:$missing_mason"
  fi
fi

if [ "$failures" -gt 0 ]; then
  echo "FAILED: $failures required WSL check(s)"
  exit 1
fi
if [ "$skip_tools" -eq 1 ] || [ "$skip_plugins" -eq 1 ] || [ "$skip_shell" -eq 1 ] || [ "$skip_tmux" -eq 1 ]; then
  echo "PASS: checked WSL subset matches; RESULT is not MATCHED"
else
  echo "PASS: WSL desired state matches"
fi
