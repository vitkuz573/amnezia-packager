run_fetch() {
    local ver="${RELEASE_VERSION:-4.8.19.0}"
    local owner="${REPO_OWNER:-amnezia-vpn}"
    local repo="${REPO_NAME:-amnezia-client}"
    local app="${APP_USER:-amneziavpn}"

    TAR_URL="https://github.com/${owner}/${repo}/releases/download/${ver}/${app}_${ver}_linux_x64.tar"
    local tar_file="/tmp/${app}_${ver}_linux_x64.tar"

    info "Downloading ${TAR_URL} …"
    if command -v wget &>/dev/null; then
        wget -q --timeout=300 "$TAR_URL" -O "$tar_file"
    else
        curl -sL --connect-timeout 10 --max-time 300 "$TAR_URL" -o "$tar_file"
    fi

    if [[ ! -f "$tar_file" ]]; then
        err "Download failed — no file at ${TAR_URL}"
        exit 1
    fi

    SOURCE_SHA256=$(sha256sum "$tar_file" | cut -d' ' -f1)
    LOCAL_TAR="$tar_file"
    export SOURCE_SHA256 LOCAL_TAR
    succ "Downloaded $(basename "$tar_file") (SHA256: ${SOURCE_SHA256})"
}
