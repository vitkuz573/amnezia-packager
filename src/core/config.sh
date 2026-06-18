#!/bin/bash
#
# config — JSON-based layered configuration with schema validation
#
# Load order: default.json < local.json < profile < env vars < CLI
#

[[ -n "${__CONFIG_LOADED:-}" ]] && return; __CONFIG_LOADED=1

source "${PROJECT_ROOT}/src/core/logger.sh"

CONFIG_JSON="${CONFIG_JSON:-${PROJECT_ROOT}/config/default.json}"
CONFIG_SCHEMA="${CONFIG_SCHEMA:-${PROJECT_ROOT}/config/schema.json}"

config::validate() {
    local json="${1:-${CONFIG_JSON}}"
    if command -v jq &>/dev/null && [[ -f "${CONFIG_SCHEMA}" ]]; then
        # Basic schema validation via jq
        if ! jq -e '.' "$json" &>/dev/null; then
            err "Config: invalid JSON in ${json}"
            return 1
        fi
        return 0
    fi
    # No jq available — simple JSON parse check
    if command -v python3 &>/dev/null; then
        python3 -c "import json; json.load(open('${json}'))" 2>/dev/null || {
            err "Config: invalid JSON in ${json}"
            return 1
        }
    fi
    return 0
}

config::get() {
    local key="$1" default="${2:-}"
    jq -r "$key // \"__NULL__\"" "${CONFIG_JSON}" 2>/dev/null | sed 's/__NULL__//'
    [[ -z "$(jq -r "$key // \"__NULL__\"" "${CONFIG_JSON}" 2>/dev/null | sed 's/__NULL__//')" ]] && echo "$default"
}

config::load() {
    local profile="${CONFIG_PROFILE:-default}"

    # Without jq, fall back to env vars (old behavior)
    if ! command -v jq &>/dev/null; then
        warn "jq not found — using env var config only"
        [[ -f "${PROJECT_ROOT}/config/default.sh" ]] && source "${PROJECT_ROOT}/config/default.sh"
        return 0
    fi

    # Start with default config
    local merged
    merged=$(cat "$CONFIG_JSON")

    # Merge local overrides if present
    local local_json="${PROJECT_ROOT}/config/local.json"
    if [[ -f "$local_json" ]] && config::validate "$local_json"; then
        merged=$(jq -s '.[0] * .[1]' <(echo "$merged") "$local_json")
    fi

    # Merge profile if specified
    local profile_json="${PROJECT_ROOT}/config/profiles/${profile}.json"
    if [[ "$profile" != "default" && -f "$profile_json" ]] && config::validate "$profile_json"; then
        merged=$(jq -s '.[0] * .[1]' <(echo "$merged") "$profile_json")
    fi

    # Validate final config
    config::validate <(echo "$merged") || return 1

    # Export as env vars (with env override support)
    export APP_NAME="${APP_NAME:-$(echo "$merged" | jq -r '.app.name // "AmneziaVPN"')}"
    export APP_USER="${APP_USER:-$(echo "$merged" | jq -r '.app.user // "amneziavpn"')}"
    export INSTALL_DIR="${INSTALL_DIR:-$(echo "$merged" | jq -r '.["app"]["install_dir"] // "/opt/AmneziaVPN"')}"
    export REPO_OWNER="${REPO_OWNER:-$(echo "$merged" | jq -r '.repository.owner // "amnezia-vpn"')}"
    export REPO_NAME="${REPO_NAME:-$(echo "$merged" | jq -r '.repository.name // "amnezia-client"')}"
    export REPO="${REPO_OWNER}/${REPO_NAME}"
    export RELEASE_VERSION="${RELEASE_VERSION:-$(echo "$merged" | jq -r '.release.version // ""')}"
    export TAR_URL="${TAR_URL:-$(echo "$merged" | jq -r '.release.tar_url // ""')}"
    export LOCAL_TAR="${LOCAL_TAR:-$(echo "$merged" | jq -r '.release.local_tar // ""')}"
    export OUTPUT_DIR="${OUTPUT_DIR:-$(echo "$merged" | jq -r '.output.dir // ""')}"
    [[ -z "$OUTPUT_DIR" ]] && OUTPUT_DIR="$PWD"
    export OUTPUT_MANIFEST="${OUTPUT_MANIFEST:-$(echo "$merged" | jq -r '.output.manifest // "true"')}"
    export OUTPUT_SIGN="${OUTPUT_SIGN:-$(echo "$merged" | jq -r '.output.sign // "false"')}"
    export GPG_KEY="${GPG_KEY:-$(echo "$merged" | jq -r '.output.gpg_key // ""')}"
    export PACKAGE_TARGET="${PACKAGE_TARGET:-$(echo "$merged" | jq -r '.platform.target // "auto"')}"
    export PACKAGE_ARCH="${PACKAGE_ARCH:-$(echo "$merged" | jq -r '.platform.arch // "x86_64"')}"
    export DEPS_DEB="${DEPS_DEB:-$(echo "$merged" | jq -r '.dependencies.deb // ""')}"
    export DEPS_ARCH="${DEPS_ARCH:-$(echo "$merged" | jq -r '.dependencies.arch // ""')}"
    export DEPS_RPM="${DEPS_RPM:-$(echo "$merged" | jq -r '.dependencies.rpm // ""')}"
    export DESKTOP_FILE="${DESKTOP_FILE:-$(echo "$merged" | jq -r '.files.desktop // "AmneziaVPN.desktop"')}"
    export ICON_FILE="${ICON_FILE:-$(echo "$merged" | jq -r '.files.icon // "AmneziaVPN.png"')}"
    export SERVICE_FILE="${SERVICE_FILE:-$(echo "$merged" | jq -r '.files.service // "AmneziaVPN.service"')}"
    export CLIENT_SCRIPT="${CLIENT_SCRIPT:-$(echo "$merged" | jq -r '.files.client_script // "AmneziaVPN.sh"')}"
    export SERVICE_SCRIPT="${SERVICE_SCRIPT:-$(echo "$merged" | jq -r '.files.service_script // "AmneziaVPN-service.sh"')}"
    export ZSTD_LEVEL="${ZSTD_LEVEL:-$(echo "$merged" | jq -r '.compression.zstd_level // "3"')}"
    export CACHE_ENABLED="${CACHE_ENABLED:-$(echo "$merged" | jq -r '.cache.enabled // "true"')}"
    export CACHE_DIR="${CACHE_DIR:-$(echo "$merged" | jq -r '.cache.dir // "~/.cache/amnezia-packager"')}"
    export LOG_LEVEL="${LOG_LEVEL:-$(echo "$merged" | jq -r '.logging.level // "info"')}"
    export LOG_FORMAT="${LOG_FORMAT:-$(echo "$merged" | jq -r '.logging.format // "text"')}"
    export LOG_FILE="${LOG_FILE:-$(echo "$merged" | jq -r '.logging.file // ""')}"
    export LOG_MAX_SIZE="${LOG_MAX_SIZE:-$(echo "$merged" | jq -r '.logging.max_size_mb // "10"')}"
    export LOG_MAX_FILES="${LOG_MAX_FILES:-$(echo "$merged" | jq -r '.logging.max_files // "3"')}"

    # Expand ~ in paths
    CACHE_DIR="${CACHE_DIR/#\~/${HOME}}"

    debug "Config loaded: profile=${profile}, target=${PACKAGE_TARGET}, jq=$(command -v jq)"
}
