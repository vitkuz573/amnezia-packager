#!/bin/bash
#
# pipeline — stage orchestration with hooks, parallel builds, manifest
#

[[ -n "${__PIPELINE_LOADED:-}" ]] && return; __PIPELINE_LOADED=1

source "${PROJECT_ROOT}/src/core/logger.sh"
source "${PROJECT_ROOT}/src/core/bootstrap.sh"

# ── Hooks ──────────────────────────────────────────────────────────────
pipeline::hook() {
    local stage="$1" hook="$2"
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

# ── Build manifest ────────────────────────────────────────────────────
pipeline::write_manifest() {
    [[ "${OUTPUT_MANIFEST}" != "true" ]] && return
    local manifest_file="${OUTPUT_DIR}/build-manifest.json"
    local ts; ts=$(date -u +%FT%TZ)

    local artifacts=()
    local pkg; pkg="$(packager_get "${PACKAGE_TARGET}")"
    source "$pkg"
    local artifact; artifact="$(get_artifact)"
    [[ -n "$artifact" && -f "$artifact" ]] && artifacts+=("$artifact")

    local manifest
    manifest=$(cat <<-MANIFEST
{
  "tool": "amnezia-packager",
  "version": "${RELEASE_VERSION:-latest}",
  "target": "${PACKAGE_TARGET}",
  "arch": "${PACKAGE_ARCH}",
  "build_time": "${ts}",
  "correlation_id": "${CORRELATION_ID}",
  "artifacts": [$(for a in "${artifacts[@]}"; do
    local name; name=$(basename "$a")
    local size; size=$(stat -c%s "$a" 2>/dev/null || echo 0)
    local sha256; sha256=$(sha256sum "$a" 2>/dev/null | cut -d' ' -f1 || echo "")
    printf '\n    {"name":"%s","size":%d,"sha256":"%s"}' "$name" "$size" "$sha256"
  done)
  ],
  "config": {
    "repository": "${REPO}",
    "install_dir": "${INSTALL_DIR}",
    "target": "${PACKAGE_TARGET}"
  }
}
MANIFEST
)
    echo "$manifest" > "$manifest_file"
    succ "Manifest: ${manifest_file}"
}

# ── GPG signing ───────────────────────────────────────────────────────
pipeline::sign() {
    [[ "${OUTPUT_SIGN}" != "true" || -z "${GPG_KEY}" ]] && return
    assert_cmds gpg
    local pkg; pkg="$(packager_get "${PACKAGE_TARGET}")"
    source "$pkg"
    local artifact; artifact="$(get_artifact)"
    [[ -z "$artifact" || ! -f "$artifact" ]] && return
    info "Signing: $(basename "$artifact")"
    gpg --detach-sign --armor --default-key "${GPG_KEY}" -o "${artifact}.sig" "$artifact" 2>/dev/null || {
        warn "GPG signing failed — check GPG_KEY=${GPG_KEY}"
    }
    [[ -f "${artifact}.sig" ]] && succ "Signature: ${artifact}.sig"
}

# ── Plan (dry-run) ────────────────────────────────────────────────────
pipeline::plan() {
    local target; target="$(detect_target)"
    local pkg;    pkg="$(packager_get "$target")"

    local ver="$RELEASE_VERSION"
    [[ -z "$ver" && -n "$LOCAL_TAR" ]] && ver="$(basename "$LOCAL_TAR" | sed 's/.*_\([0-9].*\)_linux.*/\1/')"
    [[ -z "$ver" ]] && ver="latest"

    info "Pipeline plan:"
    printf "  \033[1;37m%-20s\033[0m %s\n" "Version"       "$ver"
    printf "  \033[1;37m%-20s\033[0m %s\n" "Target"        "$target"
    printf "  \033[1;37m%-20s\033[0m %s\n" "Architecture"  "${PACKAGE_ARCH}"
    printf "  \033[1;37m%-20s\033[0m %s\n" "Packager"      "$(basename "${pkg}")"
    printf "  \033[1;37m%-20s\033[0m %s\n" "Output"        "${OUTPUT_DIR}"
    printf "  \033[1;37m%-20s\033[0m %s\n" "Config"        "${CONFIG_PROFILE:-default}"
    printf "  \033[1;37m%-20s\033[0m %s\n" "Sign"          "${OUTPUT_SIGN:-false}"
    printf "  \033[1;37m%-20s\033[0m %s\n" "Manifest"      "${OUTPUT_MANIFEST:-true}"
    printf "  \033[1;37m%-20s\033[0m %s\n" "Correlation"   "${CORRELATION_ID}"
    [[ -n "$LOCAL_TAR" ]] && printf "  \033[1;37m%-20s\033[0m %s\n" "Local tar"  "${LOCAL_TAR}"
    echo ""
}

# ── Parallel multi-target build ───────────────────────────────────────
pipeline::build_parallel() {
    local -a targets=("$@")
    local -a pids=()
    local -a results=()
    local i=0

    for target in "${targets[@]}"; do
        info "Spawning build for: ${target}"
        (
            export PACKAGE_TARGET="$target"
            exec > >(while IFS= read -r line; do printf "[%s] %s\n" "$target" "$line"; done)
            pipeline::build_single
        ) &
        pids+=($!)
        results+=("$target")
        ((i++))
    done

    local failed=0
    i=0
    for pid in "${pids[@]}"; do
        wait "$pid" || { err "${results[$i]} failed"; ((failed++)); }
        ((i++))
    done
    [[ "$failed" -gt 0 ]] && { err "${failed} build(s) failed"; exit 1; }
}

pipeline::build_single() {
    local packager_script; packager_script="$(packager_get "${PACKAGE_TARGET}")"
    source "$packager_script"

    info "Target: ${PACKAGE_TARGET}  |  Output: ${OUTPUT_DIR}"
    mkdir -p "$OUTPUT_DIR"

    [[ -z "$LOCAL_TAR" ]] && pipeline::stage "fetch"
    pipeline::stage "extract"
    pipeline::stage "verify"

    info "── package ──"
    pipeline::hook "package" "pre"
    build_package
    pipeline::hook "package" "post"

    pipeline::sign
    pipeline::write_manifest
    succ "Done → ${OUTPUT_DIR}/"
}

# ── Main pipeline ─────────────────────────────────────────────────────
pipeline::run() {
    bootstrap_init
    config::load
    packager_discover

    # ── Parse CLI arguments ──────────────────────────────────────────
    local -a targets=()
    local dry_run=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--version)   RELEASE_VERSION="$2";       shift 2; continue ;;
            -o|--output)    OUTPUT_DIR="$2";             shift 2; continue ;;
            --tar)          LOCAL_TAR="$2";              shift 2; continue ;;
            --profile)      CONFIG_PROFILE="$2";         shift 2; continue ;;
            -d|--deb)       targets+=("deb");            shift;   continue ;;
            -r|--rpm)       targets+=("rpm");            shift;   continue ;;
            -a|--arch)      targets+=("arch");           shift;   continue ;;
            --all)          targets=("deb" "rpm" "arch"); shift;   continue ;;
            --sign)         OUTPUT_SIGN="true";           shift;   continue ;;
            --manifest)     OUTPUT_MANIFEST="true";       shift;   continue ;;
            --gpg-key)      GPG_KEY="$2";                shift 2; continue ;;
            --parallel)     PARALLEL="true";              shift;   continue ;;
            -n|--dry-run)   dry_run=true;                 shift;   continue ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "  -v, --version    Release version (default: latest)"
                echo "  -o, --output     Output directory (default: cwd)"
                echo "  --tar            Use local tarball instead of downloading"
                echo "  --profile        Config profile (default: default)"
                echo "  -d, --deb        Build Debian package"
                echo "  -r, --rpm        Build RPM package"
                echo "  -a, --arch       Build Arch package"
                echo "  --all            Build all targets"
                echo "  --sign           GPG-sign the package"
                echo "  --gpg-key        GPG key to use for signing"
                echo "  --manifest       Generate build manifest"
                echo "  --parallel       Build all specified targets in parallel"
                echo "  -n, --dry-run    Show pipeline plan without executing"
                echo "  -h, --help       This help"
                exit 0
                ;;
            *) err "Unknown: $1"; exit 1 ;;
        esac
        shift
    done

    # ── Dry-run (after all CLI parsed) ──────────────────────────────
    $dry_run && { pipeline::plan; exit 0; }

    # ── Resolve target(s) ───────────────────────────────────────────
    if [[ ${#targets[@]} -eq 0 ]]; then
        PACKAGE_TARGET="$(detect_target)"
        targets=("$PACKAGE_TARGET")
    fi

    # Reload config with potential profile override
    config::load

    if [[ "${PARALLEL:-false}" == "true" && ${#targets[@]} -gt 1 ]]; then
        pipeline::build_parallel "${targets[@]}"
    else
        for target in "${targets[@]}"; do
            PACKAGE_TARGET="$target"
            pipeline::build_single
        done
    fi
}
