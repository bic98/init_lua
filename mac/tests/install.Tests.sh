#!/usr/bin/env bash
set -euo pipefail

platform_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
temp_root="${TMPDIR:-/tmp}"
case_dir="$(mktemp -d "$temp_root/init-lua-mac-test.XXXXXX")"

if grep -Eq '^[[:space:]]*(sudo|apt|apt-get|brew|dnf|pacman|choco|winget|scoop)([[:space:]]|$)' "$platform_root/install.sh"; then
  printf '%s\n' 'FAIL: macOS installer must not invoke a package manager or sudo' >&2
  exit 1
fi
grep -Fq 'bash -s -- -d "$HOME/.local/bin"' "$platform_root/install.sh"
grep -Fq "+Lazy! restore" "$platform_root/install.sh"
! grep -Fq "+Lazy! sync" "$platform_root/install.sh"
grep -Fq 'rev-parse HEAD' "$platform_root/scripts/verify.sh"
dependency_check="$(bash "$platform_root/scripts/install-dependencies.sh" --check)"
grep -Fq 'PASS: macOS dependency manifest is valid' <<< "$dependency_check"

cleanup() {
  [[ "$(dirname -- "$case_dir")" == "$temp_root" ]] || return 1
  [[ "$(basename -- "$case_dir")" == init-lua-mac-test.* ]] || return 1
  rm -rf -- "$case_dir"
}
trap cleanup EXIT

test_home="$case_dir/home"
nvim_dir="$test_home/.config/nvim"
profile_path="$test_home/.bashrc"
mkdir -p "$nvim_dir"
printf '%s\n' 'return { personal = true }' > "$nvim_dir/personal.lua"
printf '%s\n' '# personal shell line' > "$profile_path"

run_install() {
  env \
    HOME="$test_home" \
    XDG_CONFIG_HOME="$test_home/.config" \
    SHELL=/bin/bash \
    INIT_LUA_TEST_MODE=1 \
    bash "$platform_root/install.sh" \
      --shell bash \
      --skip-dependencies \
      --skip-claude-code \
      --skip-oh-my-posh \
      --skip-font \
      --skip-nvim-plugins \
      --skip-tmux \
      --profile "$profile_path" \
      --nvim-dir "$nvim_dir"
}

run_install
test -f "$nvim_dir/init.lua"
test -f "$nvim_dir/personal.lua"
cmp "$platform_root/settings/nvim/init.lua" "$nvim_dir/init.lua"
cmp \
  "$platform_root/settings/oh-my-posh/illusi0n-dayfox.omp.json" \
  "$test_home/.config/init_lua/illusi0n-dayfox.omp.json"
grep -Fq '# personal shell line' "$profile_path"
grep -Fq '# >>> init_lua shell >>>' "$profile_path"

first_backups="$(find "$test_home/.config" -maxdepth 1 -type d -name 'nvim.backup_*' | wc -l)"
test "$first_backups" -eq 1

run_install
second_backups="$(find "$test_home/.config" -maxdepth 1 -type d -name 'nvim.backup_*' | wc -l)"
test "$second_backups" -eq "$first_backups"
test "$(grep -Fc '# >>> init_lua shell >>>' "$profile_path")" -eq 1

rm -f "$test_home/.config/init_lua/illusi0n-dayfox.omp.json"
if env \
  HOME="$test_home" \
  XDG_CONFIG_HOME="$test_home/.config" \
  SHELL=/bin/bash \
  INIT_LUA_TEST_MODE=1 \
  bash "$platform_root/scripts/verify.sh" \
    --nvim-dir "$nvim_dir" \
    --profile "$profile_path" \
    --shell bash \
    --skip-tools \
    --skip-plugins \
    --skip-tmux \
    --skip-font >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: strict macOS verifier accepted a missing managed theme' >&2
  exit 1
fi

printf '%s\n' 'PASS: macOS isolated install, idempotency, and strict mismatch rejection'
