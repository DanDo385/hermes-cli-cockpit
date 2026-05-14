# Sourceable zsh helper for Hermes CLI Cockpit context routing.
#
# Usage:
#   source /Users/openclaw/Code/hermes-cli-cockpit/bin/cctx-hook.zsh
#   cctx-on          # update cctx automatically after every cd
#   cctx-off         # disable automatic updates
#   cctx-refresh     # manually refresh the current directory
#   cctx-env         # safely import the last cctx state into this shell
#
# This file is intentionally opt-in. It does not edit ~/.zshrc for you.

if [[ -z "${ZSH_VERSION:-}" ]]; then
  echo "cctx-hook.zsh: this helper is for zsh; source it from zsh, not bash" >&2
  return 1 2>/dev/null || exit 1
fi

_cctx_hook_script_dir="${0:A:h}"
_cctx_hook_bin="${CCTX_BIN:-${_cctx_hook_script_dir}/cctx}"
_cctx_hook_state="${CCTX_STATE_FILE:-${XDG_CACHE_HOME:-$HOME/.cache}/hermes-cli-cockpit/cctx.env}"

cctx-refresh() {
  if [[ ! -x "$_cctx_hook_bin" ]]; then
    echo "cctx-refresh: cctx not executable: $_cctx_hook_bin" >&2
    return 1
  fi
  "$_cctx_hook_bin" --print-env "$PWD" >/dev/null
}

cctx-env() {
  if [[ -r "$_cctx_hook_state" ]]; then
    local key value
    while IFS=$'\t' read -r key value; do
      case "$key" in
        CMUX_CONTEXT_PATH|CMUX_CONTEXT_KIND|CMUX_CONTEXT_NAME|CMUX_REPO_DIR|CMUX_BROWSER_URL|CMUX_MISSION_HINT|OBSIDIAN_VAULT_PATH)
          typeset -gx "$key=$value"
          ;;
      esac
    done < <(python3 - "$_cctx_hook_state" <<'PY'
import shlex
import sys

allowed = {
    "CMUX_CONTEXT_PATH",
    "CMUX_CONTEXT_KIND",
    "CMUX_CONTEXT_NAME",
    "CMUX_REPO_DIR",
    "CMUX_BROWSER_URL",
    "CMUX_MISSION_HINT",
    "OBSIDIAN_VAULT_PATH",
}

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as fh:
        for raw in fh:
            raw = raw.strip()
            if not raw or raw.startswith("#"):
                continue
            try:
                parts = shlex.split(raw, posix=True)
            except ValueError:
                continue
            if len(parts) != 2 or parts[0] != "export" or "=" not in parts[1]:
                continue
            key, value = parts[1].split("=", 1)
            if key in allowed:
                print(f"{key}\t{value}")
except OSError:
    pass
PY
    )
    echo "cctx-env: loaded $_cctx_hook_state"
  else
    echo "cctx-env: no state file yet: $_cctx_hook_state" >&2
    return 1
  fi
}

_cctx_chpwd_hook() {
  [[ "${CMUX_AUTO_CONTEXT:-1}" == "1" ]] || return 0
  cctx-refresh >/dev/null 2>&1 || true
}

cctx-on() {
  autoload -Uz add-zsh-hook
  add-zsh-hook -d chpwd _cctx_chpwd_hook 2>/dev/null || true
  add-zsh-hook chpwd _cctx_chpwd_hook
  cctx-refresh >/dev/null 2>&1 || true
  echo "cctx-on: automatic context routing enabled for this zsh session"
}

cctx-off() {
  autoload -Uz add-zsh-hook
  add-zsh-hook -d chpwd _cctx_chpwd_hook 2>/dev/null || true
  echo "cctx-off: automatic context routing disabled for this zsh session"
}

ccd() {
  builtin cd "$@" || return
  cctx-refresh >/dev/null 2>&1 || true
}
