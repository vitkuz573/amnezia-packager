#!/bin/bash
#
# Stage: fetch — download release from GitHub
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

    local data
    data="$(curl -sf "$api_url")" || {
        err "GitHub API request failed"
        err "URL: ${api_url}"
        exit 1
    }

    RELEASE_VERSION="$(printf '%s' "$data" | grep '"tag_name"' | head -1 | sed 's/.*: "//;s/".*//')"
    RELEASE_VERSION="${RELEASE_VERSION#v}"

    TAR_URL="$(printf '%s' "$data" \
        | grep '"browser_download_url"' \
        | grep 'linux_x64\.tar' \
        | head -1 \
        | sed 's/.*: "//;s/".*//')"

    [[ -z "$TAR_URL" ]] && { err "No linux_x64.tar asset found"; exit 1; }

    succ "v${RELEASE_VERSION}"

    local tar_file="${WORKDIR}/${APP_USER}_${RELEASE_VERSION}_linux_x64.tar"
    info "Downloading…"
    curl -L# "$TAR_URL" -o "$tar_file"
    LOCAL_TAR="$tar_file"
    succ "Downloaded: $(basename "$tar_file")"
}
