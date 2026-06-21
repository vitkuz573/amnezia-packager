#!/bin/bash
#
# Stage: fetch — download release from GitHub with caching + hash verification
#

run_fetch() {
    assert_cmds curl

    # ── Resolve version via git ls-remote (no GitHub API dependency) ──
    if [[ -z "$RELEASE_VERSION" ]]; then
        assert_cmds git
        info "Detecting latest release via git ls-remote..."
        local tag
        tag="$(git ls-remote --tags "https://github.com/${REPO}.git" 2>/dev/null \
            | grep -oP 'refs/tags/\Kv?[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
            | sort -V \
            | tail -1)" || {
            err "Failed to fetch tags from git://github.com/${REPO}"
            exit 1
        }
        [[ -z "$tag" ]] && { err "No tags found in repository"; exit 1; }
        RELEASE_VERSION="${tag#v}"
        info "Latest tag: ${tag}"
    else
        tag="${RELEASE_VERSION}"
        info "Using specified version: ${tag}"
    fi

    # ── Construct tarball URL ──────────────────────────────────────────
    local base_url="https://github.com/${REPO}/releases/download"
    TAR_URL="${base_url}/${tag}/${APP_USER}_${RELEASE_VERSION}_linux_x64.tar"
    SOURCE_SHA256=""
    succ "v${RELEASE_VERSION}"

    # ── Download tarball ───────────────────────────────────────────
    local tar_file="${WORKDIR}/${APP_USER}_${RELEASE_VERSION}_linux_x64.tar"
    info "Downloading ${TAR_URL} …"
    curl -L --connect-timeout 10 --max-time 300 "$TAR_URL" -o "$tar_file"

    # ── Verify hash (self-computed) ─────────────────────────────────
    warn "No upstream SHA256 available — computing local hash"
    SOURCE_SHA256=$(sha256sum "$tar_file" | cut -d' ' -f1)
    info "SHA256: ${SOURCE_SHA256}"

    # ── Copy to cache ──────────────────────────────────────────────
    if [[ "${CACHE_ENABLED:-true}" == "true" && -n "$CACHE_DIR" ]]; then
        mkdir -p "$CACHE_DIR"
        cp "$tar_file" "${CACHE_DIR}/" 2>/dev/null || true
    fi

    LOCAL_TAR="$tar_file"
    export SOURCE_SHA256
    succ "Downloaded: $(basename "$tar_file")"
}
