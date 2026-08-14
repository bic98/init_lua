# >>> init_lua shell >>>
# Managed by wsl/install.sh. Personal shell content outside the markers is preserved.

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

__init_lua_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
__init_lua_shell="$(basename "${SHELL:-bash}")"
if command -v oh-my-posh >/dev/null 2>&1; then
  eval "$(oh-my-posh init "$__init_lua_shell" --config "$__init_lua_config_home/init_lua/illusi0n-dayfox.omp.json")"
fi

alias v='nvim'
alias vi='nvim'
unset __init_lua_config_home __init_lua_shell
# <<< init_lua shell <<<
