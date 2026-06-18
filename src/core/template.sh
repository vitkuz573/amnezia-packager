#!/bin/bash
#
# template — envsubst-based template engine with helpers
#

[[ -n "${__TEMPLATE_LOADED:-}" ]] && return; __TEMPLATE_LOADED=1

source "${PROJECT_ROOT}/src/core/logger.sh"

template::render() {
    local template_file="$1" output_file="$2"
    [[ -f "$template_file" ]] || { err "Template not found: $template_file"; return 1; }

    # Build env vars for substitution — only these get replaced by envsubst
    export APP_NAME APP_USER INSTALL_DIR
    export REPO_OWNER REPO_NAME REPO
    export RELEASE_VERSION PACKAGE_ARCH
    export DESKTOP_FILE ICON_FILE SERVICE_FILE
    export CLIENT_SCRIPT SERVICE_SCRIPT
    export DEPS_DEB DEPS_ARCH DEPS_RPM
    export PACKAGE_VENDOR="${PACKAGE_VENDOR:-AmneziaVPN}"
    export PACKAGE_LICENSE="${PACKAGE_LICENSE:-GPL3}"
    export PACKAGE_DESCRIPTION="${PACKAGE_DESCRIPTION:-AmneziaVPN — Client of your self-hosted VPN}"
    export PACKAGE_URL="${PACKAGE_URL:-https://github.com/${REPO}}"
    export PACKAGE_MAINTAINER="${PACKAGE_MAINTAINER:-AmneziaVPN <support@amnezia.com>}"
    export PKGVER="${RELEASE_VERSION//-/.}"
    export PKGNAME="${APP_USER}"
    export PKGSIZE_KB PKGSIZE_BYTES

    # Format dependency lists for each package format
    DEPS_ARCH_LINES=$(echo "${DEPS_ARCH:-}" | tr ' ' '\n' | sed 's/^/depend = /')
    DEPS_RPM_LINES=$(echo "${DEPS_RPM:-}" | tr ' ' '\n' | sed 's/^/Requires: /')
    export DEPS_ARCH_LINES DEPS_RPM_LINES

    # Only substitute config vars, not shell/runtime variables like APP_PATH
    local vars
    vars='$APP_NAME $APP_USER $INSTALL_DIR $REPO_OWNER $REPO_NAME $REPO'
    vars+=' $RELEASE_VERSION $PACKAGE_ARCH'
    vars+=' $DESKTOP_FILE $ICON_FILE $SERVICE_FILE $CLIENT_SCRIPT $SERVICE_SCRIPT'
    vars+=' $DEPS_DEB $DEPS_ARCH $DEPS_RPM'
    vars+=' $DEPS_ARCH_LINES $DEPS_RPM_LINES'
    vars+=' $PACKAGE_VENDOR $PACKAGE_LICENSE $PACKAGE_DESCRIPTION $PACKAGE_URL $PACKAGE_MAINTAINER'
    vars+=' $PKGVER $PKGNAME $PKGSIZE_KB $PKGSIZE_BYTES'

    envsubst "$vars" < "$template_file" > "$output_file"
}

template::compute_size() {
    local dir="$1"
    PKGSIZE_KB=$(du -sk "$dir" | cut -f1)
    PKGSIZE_BYTES=$(du -sb "$dir" | cut -f1)
    export PKGSIZE_KB PKGSIZE_BYTES
}
