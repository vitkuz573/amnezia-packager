#!/bin/bash
#
# Stage: fetch — download release from GitHub with caching
#

run_fetch() {
    assert_cmds curl

    local api_url
    if [[ -z "$RELEASE_VERSION" ]]; then
        info "Fetching latest release info..."
        api_url="https://api.github.com/repos/${REPO}/releases/latest"
    else
        info "Fetching release info for v${RELEASE_VERSION}..."
        api_url="https://api.github.com/repos/${REPO}/releases/tags/${RELEASE_VERSION}"
    fi

    # ── Cache API response ──────────────────────────────────────────
    local cache_key cache_file
    if [[ "${CACHE_ENABLED:-true}" == "true" && -n "$CACHE_DIR" ]]; then
        mkdir -p "$CACHE_DIR"
        cache_key="$(echo "$api_url" | md5sum | cut -d' ' -f1)"
        cache_file="${CACHE_DIR}/api-${cache_key}.json"
        # Cache valid for 1 hour
        if [[ -f "$cache_file" && $(( $(date +%s) - $(stat -c%Y "$cache_file") )) -lt 3600 ]]; then
            local data; data=$(cat "$cache_file")
            RELEASE_VERSION="$(printf '%s' "$data" | grep '"tag_name"' | head -1 | sed 's/.*: "//;s/".*//')"
            RELEASE_VERSION="${RELEASE_VERSION#v}"
            TAR_URL="$(printf '%s' "$data" | grep '"browser_download_url"' | grep 'linux_x64\.tar' | head -1 | sed 's/.*: "//;s/".*//')"
            if [[ -n "$TAR_URL" ]]; then
                succ "v${RELEASE_VERSION} (cached)"
            fi
        fi
    fi

    if [[ -z "$TAR_URL" ]]; then
        local data
        data="$(curl -sf "$api_url")" || {
            err "GitHub API request failed"
            err "URL: ${api_url}"
            exit 1
        }

        # Cache API response
        [[ -n "$cache_file" ]] && echo "$data" > "$cache_file"

        RELEASE_VERSION="$(printf '%s' "$data" | grep '"tag_name"' | head -1 | sed 's/.*: "//;s/".*//')"
        RELEASE_VERSION="${RELEASE_VERSION#v}"

        TAR_URL="$(printf '%s' "$data" \
            | grep '"browser_download_url"' \
            | grep 'linux_x64\.tar' \
            | head -1 \
            | sed 's/.*: "//;s/".*//')"

        [[ -z "$TAR_URL" ]] && { err "No linux_x64.tar asset found"; exit 1; }
        succ "v${RELEASE_VERSION}"
    fi

    # ── Cache tarball ───────────────────────────────────────────────
    local tar_file
    if [[ "${CACHE_ENABLED:-true}" == "true" && -n "$CACHE_DIR" ]]; then
        tar_file="${CACHE_DIR}/${APP_USER}_${RELEASE_VERSION}_linux_x64.tar"
        if [[ -f "$tar_file" ]]; then
            LOCAL_TAR="$tar_file"
            succ "Cached: $(basename "$tar_file")"
            return 0
        fi
    fi

    tar_file="${WORKDIR}/${APP_USER}_${RELEASE_VERSION}_linux_x64.tar"
    info "Downloading…"
    curl -L# "$TAR_URL" -o "$tar_file"

    # Copy to cache
    if [[ "${CACHE_ENABLED:-true}" == "true" && -n "$CACHE_DIR" ]]; then
        cp "$tar_file" "${CACHE_DIR}/" 2>/dev/null || true
    fi

    LOCAL_TAR="$tar_file"
    succ "Downloaded: $(basename "$tar_file")"
}
