#!/bin/bash
#
# pipeline — stage orchestration with hooks
#

[[ -n "${__PIPELINE_LOADED:-}" ]] && return; __PIPELINE_LOADED=1

source "${PROJECT_ROOT}/src/core/logger.sh"
source "${PROJECT_ROOT}/src/core/bootstrap.sh"

# ── Hooks ──────────────────────────────────────────────────────────────
pipeline::hook() {
    local stage="$1" hook="$2"  # hook = pre | post
    local script="${PROJECT_ROOT}/src/stage/${stage}.sh"
    local fn="${hook}_${stage}"
    if [[ -f "$script" ]]; then
        source "$script" 2>/dev/null || true
        if declare -F "$fn" &>/dev/null; then
            debug "[hook] ${stage}:${hook}"
            $fn
        fi
    fi
}

pipeline::stage() {
    local stage="$1"
    info "── ${stage} ──"
    pipeline::hook "$stage" "pre"
    source "${PROJECT_ROOT}/src/stage/${stage}.sh"
    "run_${stage}"
    pipeline::hook "$stage" "post"
    succ "✔ ${stage}"
}

# ── Plan (dry-run) ────────────────────────────────────────────────────
pipeline::plan() {
    local target; target="$(detect_target)"
    local pkg;    pkg="$(packager_get "$target")"

    local ver="$RELEASE_VERSION"
    [[ -z "$ver" && -n "$LOCAL_TAR" ]] && ver="$(basename "$LOCAL_TAR" | sed 's/.*_\([0-9].*\)_linux.*/\1/')"
    [[ -z "$ver" ]] && ver="latest"

    info "Pipeline plan:"
    printf "  \033[1;37m%-20s\033[0m %s\n" "Version"    "$ver"
    printf "  \033[1;37m%-20s\033[0m %s\n" "Target"     "$target"
    printf "  \033[1;37m%-20s\033[0m %s\n" "Packager"   "$(basename "${pkg}")"
    printf "  \033[1;37m%-20s\033[0m %s\n" "Output"     "${OUTPUT_DIR}"
    [[ -n "$LOCAL_TAR" ]] && printf "  \033[1;37m%-20s\033[0m %s\n" "Local tar"  "${LOCAL_TAR}"
    echo ""
}

# ── Main pipeline ─────────────────────────────────────────────────────
pipeline::run() {
    bootstrap_init
    packager_discover

    # ── Parse CLI arguments ──────────────────────────────────────────
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--version)   RELEASE_VERSION="$2";       shift 2; continue ;;
            -o|--output)    OUTPUT_DIR="$2";             shift 2; continue ;;
            --tar)          LOCAL_TAR="$2";              shift 2; continue ;;
            -d|--deb)       PACKAGE_TARGET="deb";        shift;   continue ;;
            -r|--rpm)       PACKAGE_TARGET="rpm";        shift;   continue ;;
            -a|--arch)      PACKAGE_TARGET="arch";       shift;   continue ;;
            -n|--dry-run)   pipeline::plan; exit 0 ;;
            -h|--help)
                echo "Usage: $0 [-v VERSION] [-o DIR] [--tar FILE] [-d|-r|-a] [-n]"
                echo ""
                echo "  -v, --version    Release version (default: latest)"
                echo "  -o, --output     Output directory (default: cwd)"
                echo "  --tar            Use local tarball instead of downloading"
                echo "  -d, --deb        Build Debian package"
                echo "  -r, --rpm        Build RPM package"
                echo "  -a, --arch       Build Arch package"
                echo "  -n, --dry-run    Show pipeline plan without executing"
                echo "  -h, --help       This help"
                exit 0
                ;;
            *) err "Unknown: $1"; exit 1 ;;
        esac
        shift
    done

    # ── Resolve target ──────────────────────────────────────────────
    PACKAGE_TARGET="$(detect_target)"
    local packager_script; packager_script="$(packager_get "${PACKAGE_TARGET}")"
    # shellcheck source=/dev/null
    source "$packager_script"

    info "Target: ${PACKAGE_TARGET}  |  Output: ${OUTPUT_DIR}"
    mkdir -p "$OUTPUT_DIR"

    # ── Pipeline stages ─────────────────────────────────────────────
    [[ -z "$LOCAL_TAR" ]] && pipeline::stage "fetch"
    pipeline::stage "extract"
    pipeline::stage "verify"

    info "── package ──"
    pipeline::hook "package" "pre"
    build_package
    pipeline::hook "package" "post"

    succ "Done → ${OUTPUT_DIR}/"
}
