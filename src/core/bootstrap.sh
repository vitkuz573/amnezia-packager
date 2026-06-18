#!/bin/bash
#
# bootstrap — workspace setup, cleanup, signal handling
#

[[ -n "${__BOOTSTRAP_LOADED:-}" ]] && return; __BOOTSTRAP_LOADED=1

source "${PROJECT_ROOT}/src/core/logger.sh"

# ── Workspace ──────────────────────────────────────────────────────────
declare -a _WORKDIRS=()

workspace_create() {
    local d; d="$(mktemp -d)"
    _WORKDIRS+=("$d")
    echo "$d"
}

workspace_cleanup() {
    local dir
    for dir in "${_WORKDIRS[@]}"; do
        [[ -d "$dir" ]] && rm -rf "$dir" 2>/dev/null
        [[ -d "$dir" ]] && sudo rm -rf "$dir" 2>/dev/null
    done
}

cleanup_handler() {
    local rc=$?
    workspace_cleanup
    exit $rc
}

bootstrap_init() {
    trap cleanup_handler EXIT INT TERM
    WORKDIR="$(workspace_create)"
    STAGING_DIR=""  # set by extract stage
}

# ── Distro detection ──────────────────────────────────────────────────
detect_target() {
    case "${PACKAGE_TARGET}" in
        auto)
            if [[ -f /etc/arch-release ]]; then
                echo "arch"
            elif [[ -f /etc/debian_version ]]; then
                echo "deb"
            elif [[ -f /etc/redhat-release ]] || [[ -f /etc/fedora-release ]]; then
                echo "rpm"
            elif command -v dpkg-deb &>/dev/null; then
                echo "deb"
            elif command -v rpmbuild &>/dev/null; then
                echo "rpm"
            elif command -v makepkg &>/dev/null; then
                echo "arch"
            else
                err "Cannot auto-detect distro. Set PACKAGE_TARGET=deb|rpm|arch"
                exit 1
            fi
            ;;
        deb|rpm|arch) echo "${PACKAGE_TARGET}" ;;
        *) err "Invalid PACKAGE_TARGET: ${PACKAGE_TARGET}"; exit 1 ;;
    esac
}

# ── Packager registry (discovery) ─────────────────────────────────────
declare -a _PACKAGERS=()

packager_register() {
    _PACKAGERS+=("$1")
}

packager_discover() {
    local script
    for script in "${PROJECT_ROOT}/src/packager/"*.sh; do
        [[ -f "$script" ]] || continue
        # shellcheck source=/dev/null
        source "$script"
    done
}

packager_get() {
    local target="$1" script
    for script in "${_PACKAGERS[@]}"; do
        local name; name="$(basename "$script" .sh)"
        [[ "$name" == "$target" ]] && { echo "$script"; return 0; }
    done
    err "No packager found for: ${target}"
    err "Available: ${_PACKAGERS[*]}"
    exit 1
}
