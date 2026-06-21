#!/bin/bash
#
# Stage: fetch — download release from GitHub with caching + hash verification
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
        if [[ -f "$cache_file" && $(( $(date +%s) - $(stat -c%Y "$cache_file") )) -lt 3600 ]]; then
            local data; data=$(cat "$cache_file")
            RELEASE_VERSION="$(printf '%s' "$data" | grep '"tag_name"' | head -1 | sed 's/.*: "//;s/".*//')"
            RELEASE_VERSION="${RELEASE_VERSION#v}"
            TAR_URL="$(printf '%s' "$data" | grep '"browser_download_url"' | grep 'linux_x64\.tar' | head -1 | sed 's/.*: "//;s/".*//')"
            SOURCE_SHA256="$(printf '%s' "$data" | grep -A5 '"browser_download_url".*linux_x64\.tar' | grep '"digest"' | head -1 | sed 's/.*sha256://;s/".*//')"
            if [[ -n "$TAR_URL" ]]; then
                succ "v${RELEASE_VERSION} (cached)"
            fi
        fi
    fi

    if [[ -z "$TAR_URL" ]]; then
        local data
        local curl_cmd=("curl" "-sS" "--connect-timeout" "10" "--max-time" "30")
        [[ -n "${GITHUB_TOKEN:-}" ]] && curl_cmd+=(-H "Authorization: token ${GITHUB_TOKEN}")
        data="$("${curl_cmd[@]}" "$api_url")" || {
            err "GitHub API request failed"
            err "URL: ${api_url}"
            exit 1
        }

        [[ -n "$cache_file" ]] && echo "$data" > "$cache_file"

        RELEASE_VERSION="$(printf '%s' "$data" | grep '"tag_name"' | head -1 | sed 's/.*: "//;s/".*//')"
        RELEASE_VERSION="${RELEASE_VERSION#v}"

        TAR_URL="$(printf '%s' "$data" \
            | grep '"browser_download_url"' \
            | grep 'linux_x64\.tar' \
            | head -1 \
            | sed 's/.*: "//;s/".*//')"

        SOURCE_SHA256="$(printf '%s' "$data" \
            | grep -A5 '"browser_download_url".*linux_x64\.tar' \
            | grep '"digest"' \
            | head -1 \
            | sed 's/.*sha256://;s/".*//')"

        [[ -z "$TAR_URL" ]] && { err "No linux_x64.tar asset found"; exit 1; }
        succ "v${RELEASE_VERSION}"
    fi

    # ── Cache tarball ───────────────────────────────────────────────
    local tar_file
    if [[ "${CACHE_ENABLED:-true}" == "true" && -n "$CACHE_DIR" ]]; then
        tar_file="${CACHE_DIR}/${APP_USER}_${RELEASE_VERSION}_linux_x64.tar"
        if [[ -f "$tar_file" ]]; then
            # Verify cached hash
            if [[ -n "$SOURCE_SHA256" ]]; then
                local cached_hash
                cached_hash=$(sha256sum "$tar_file" | cut -d' ' -f1)
                if [[ "$cached_hash" != "$SOURCE_SHA256" ]]; then
                    warn "Cached tarball hash mismatch — re-downloading"
                    rm -f "$tar_file"
                else
                    succ "Cached: $(basename "$tar_file") (hash verified)"
                fi
            else
                succ "Cached: $(basename "$tar_file")"
            fi
            if [[ -f "$tar_file" ]]; then
                LOCAL_TAR="$tar_file"
                export SOURCE_SHA256
                return 0
            fi
        fi
    fi

    tar_file="${WORKDIR}/${APP_USER}_${RELEASE_VERSION}_linux_x64.tar"
    info "Downloading…"
    curl -L --connect-timeout 10 --max-time 300 "$TAR_URL" -o "$tar_file"

    # ── Verify hash against GitHub API digest ────────────────────────
    if [[ -n "$SOURCE_SHA256" ]]; then
        local actual_hash
        actual_hash=$(sha256sum "$tar_file" | cut -d' ' -f1)
        if [[ "$actual_hash" != "$SOURCE_SHA256" ]]; then
            err "Tarball hash MISMATCH!"
            err "  Expected (GitHub API): ${SOURCE_SHA256}"
            err "  Actual:               ${actual_hash}"
            err "  URL: ${TAR_URL}"
            err "The download may have been tampered with or corrupted."
            exit 1
        fi
        succ "Tarball hash verified: ${SOURCE_SHA256}"
    else
        warn "No source SHA256 from API — tarball not verified"
        SOURCE_SHA256=$(sha256sum "$tar_file" | cut -d' ' -f1)
    fi

    # Copy to cache
    if [[ "${CACHE_ENABLED:-true}" == "true" && -n "$CACHE_DIR" ]]; then
        cp "$tar_file" "${CACHE_DIR}/" 2>/dev/null || true
    fi

    LOCAL_TAR="$tar_file"
    export SOURCE_SHA256
    succ "Downloaded: $(basename "$tar_file")"
}
