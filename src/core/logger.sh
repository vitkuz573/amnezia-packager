#!/bin/bash
#
# logger — structured logging with levels, JSON output, file rotation
#

[[ -n "${__LOGGER_LOADED:-}" ]] && return; __LOGGER_LOADED=1

LOG_LEVEL="${LOG_LEVEL:-info}"
LOG_FORMAT="${LOG_FORMAT:-text}"
LOG_FILE="${LOG_FILE:-}"
LOG_MAX_SIZE="${LOG_MAX_SIZE:-10}"
LOG_MAX_FILES="${LOG_MAX_FILES:-3}"

# Correlation ID — one per process tree
CORRELATION_ID="${CORRELATION_ID:-$(uuidgen 2>/dev/null || echo "corr-${$}-$(date +%s)")}"
export CORRELATION_ID

_log_level_num() {
    case "$1" in
        debug) echo 0 ;;  info)  echo 1 ;;
        warn)  echo 2 ;;  error) echo 3 ;;
        silent)echo 4 ;;  *)     echo 1 ;;
    esac
}

_log_should() {
    [[ "$(_log_level_num "$1")" -ge "$(_log_level_num "$LOG_LEVEL")" ]]
}

_log_rotate() {
    [[ -z "$LOG_FILE" || ! -f "$LOG_FILE" ]] && return
    local size; size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    local max=$(( LOG_MAX_SIZE * 1024 * 1024 ))
    [[ "$size" -lt "$max" ]] && return

    local i=$LOG_MAX_FILES
    while (( i > 1 )); do
        local prev=$(( i - 1 ))
        [[ -f "${LOG_FILE}.${prev}" ]] && mv "${LOG_FILE}.${prev}" "${LOG_FILE}.${i}"
        (( i-- ))
    done
    [[ -f "$LOG_FILE" ]] && mv "$LOG_FILE" "${LOG_FILE}.1"
    touch "$LOG_FILE"
}

_log_file() {
    [[ -z "$LOG_FILE" ]] && return
    _log_rotate
    echo "$@" >> "$LOG_FILE"
}

_log() {
    local level="$1" label="$2" color="$3"
    shift 3
    _log_should "$level" || return 0
    local msg="$*"
    local ts; ts=$(date -u +%FT%TZ)
    local pid=$$

    if [[ "$LOG_FORMAT" == "json" ]]; then
        local escaped; escaped=$(printf '%s' "$msg" | sed 's/"/\\"/g')
        local line; line=$(printf '{"level":"%s","msg":"%s","time":"%s","pid":%d,"correlation_id":"%s"}' \
            "$level" "$escaped" "$ts" "$pid" "$CORRELATION_ID")
    else
        local line; line=$(printf '%s [%s] %s' "$ts" "$level" "$msg")
    fi

    if [[ "$LOG_FORMAT" == "text" ]]; then
        echo -e "${color}[${label}]\\033[0m ${msg}" >&"${_LOG_FD:-1}"
    fi
    # Always write JSON to file if configured
    if [[ -n "$LOG_FILE" ]]; then
        if [[ "$LOG_FORMAT" != "json" ]]; then
            _log_file "$(printf '{"level":"%s","msg":"%s","time":"%s","pid":%d,"correlation_id":"%s"}' \
                "$level" "$(printf '%s' "$msg" | sed 's/"/\\"/g')" "$ts" "$pid" "$CORRELATION_ID")"
        else
            _log_file "$line"
        fi
    fi
}

debug() { _log debug "…" "\033[1;90m" "$@"; }
info()  { _log info  "*" "\033[1;34m" "$@"; }
succ()  { _log info  "+" "\033[1;32m" "$@"; }
warn()  { _log warn  "!" "\033[1;33m" "$@"; }
err()   { _log error "-" "\033[1;31m" "$@" >&2; }

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
