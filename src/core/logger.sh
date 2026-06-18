#!/bin/bash
#
# logger — structured logging with levels
#

[[ -n "${__LOGGER_LOADED:-}" ]] && return; __LOGGER_LOADED=1

LOG_LEVEL="${LOG_LEVEL:-info}"  # debug | info | warn | error | silent
LOG_FORMAT="${LOG_FORMAT:-text}" # text | json

_log_level_num() {
    case "$1" in
        debug) echo 0 ;;
        info)  echo 1 ;;
        warn)  echo 2 ;;
        error) echo 3 ;;
        silent)echo 4 ;;
        *)     echo 1 ;;
    esac
}

_log_should() {
    local level="$1"
    [[ "$(_log_level_num "$level")" -ge "$(_log_level_num "$LOG_LEVEL")" ]]
}

_log() {
    local level="$1" label="$2" color="$3"
    shift 3
    _log_should "$level" || return 0
    local msg="$*"
    if [[ "$LOG_FORMAT" == "json" ]]; then
        printf '{"level":"%s","msg":"%s","time":%d}\n' \
            "$level" "$(printf '%s' "$msg" | sed 's/"/\\"/g')" "$(date +%s)"
    else
        echo -e "${color}[${label}]\\033[0m ${msg}"
    fi
}

debug() { _log debug "…" "\033[1;90m" "$@"; }
info()  { _log info  "*" "\033[1;34m" "$@"; }
succ()  { _log info  "+" "\033[1;32m" "$@"; }
warn()  { _log warn  "!" "\033[1;33m" "$@"; }
err()   { _log error "-" "\033[1;31m" "$@" >&2; }

# ── Assertions ─────────────────────────────────────────────────────────
assert_cmds() {
    local fail=0
    for cmd in "$@"; do
        command -v "$cmd" &>/dev/null || { err "missing: ${cmd}"; fail=1; }
    done
    if [[ "$fail" -ne 0 ]]; then exit 1; fi
    return 0
}

assert_file() {
    [[ -f "$1" ]] && return 0
    err "file not found: $1"; exit 1
}

assert_dir() {
    [[ -d "$1" ]] && return 0
    err "directory not found: $1"; exit 1
}
