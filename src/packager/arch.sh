#!/bin/bash
#
# Arch Linux .pkg.tar.zst packager
#

source "${PROJECT_ROOT}/src/packager/00-interface.sh"
packager_register_impl

build_package() {
    local pkgver="${RELEASE_VERSION//-/.}"
    local pkgname="${APP_USER}"

    info "Building Arch: ${pkgname}-${pkgver}"

    local pkgdir="${WORKDIR}/pkg"
    mkdir -p "${pkgdir}${INSTALL_DIR}"
    cp -a "$STAGING_DIR/." "${pkgdir}${INSTALL_DIR}/"
    fix_desktop_exec "${pkgdir}${INSTALL_DIR}"

    # ── .INSTALL ─────────────────────────────────────────────────────
    cat > "${WORKDIR}/.INSTALL" <<-'INSTALLBLOCK'
post_install() {
    APP_NAME="AmneziaVPN"
    APP_PATH="/opt/${APP_NAME}"
    mkdir -p /var/log/${APP_NAME}
    killall -9 "${APP_NAME}" 2>/dev/null || true
    if command -v systemctl >/dev/null 2>&1; then
        cp -f "${APP_PATH}/${APP_NAME}.service" /etc/systemd/system/
        chmod 644 /etc/systemd/system/${APP_NAME}.service
        systemctl daemon-reload
        systemctl enable "${APP_NAME}" 2>/dev/null || true
        systemctl start "${APP_NAME}" 2>/dev/null || true
    fi
    ln -sf "${APP_PATH}/client/${APP_NAME}.sh" "/usr/local/bin/${APP_NAME}"
    cp -f "${APP_PATH}/${APP_NAME}.desktop" /usr/share/applications/
    cp -f "${APP_PATH}/${APP_NAME}.png" /usr/share/pixmaps/
    chmod 644 /usr/share/applications/${APP_NAME}.desktop
    chmod -R a-w "${APP_PATH}/" 2>/dev/null || true
    chmod 755 "${APP_PATH}/client/bin/${APP_NAME}"
    chmod 755 "${APP_PATH}/service/bin/AmneziaVPN-service"
    chmod 555 "${APP_PATH}/client/${APP_NAME}.sh"
    chmod 555 "${APP_PATH}/service/${APP_NAME}-service.sh"
}

pre_remove() {
    APP_NAME="AmneziaVPN"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop "${APP_NAME}" 2>/dev/null || true
        systemctl disable "${APP_NAME}" 2>/dev/null || true
        rm -f /etc/systemd/system/${APP_NAME}.service
        systemctl daemon-reload
    fi
    killall -9 "${APP_NAME}" 2>/dev/null || true
    rm -f "/usr/local/bin/${APP_NAME}"
    rm -f "/usr/share/applications/${APP_NAME}.desktop"
    rm -f "/usr/share/pixmaps/${APP_NAME}.png"
}

post_remove() { :; }
INSTALLBLOCK

    # ── .PKGINFO ─────────────────────────────────────────────────────
    local size; size="$(compute_size_bytes "$STAGING_DIR")"

    cat > "${WORKDIR}/.PKGINFO" <<-PKGINFO
pkgname = ${pkgname}
pkgver = ${pkgver}-1
pkgdesc = AmneziaVPN — Client of your self-hosted VPN
url = https://github.com/${REPO}
builddate = $(date +%s)
packager = AmneziaVPN Packager <https://github.com/${REPO}>
size = ${size}
arch = any
license = GPL3
depend = xcb-util-cursor
depend = libxcb
depend = xcb-util-wm
depend = xcb-util-keysyms
depend = libglvnd
depend = libxkbcommon-x11
PKGINFO

    # ── Build archive ───────────────────────────────────────────────
    cd "$pkgdir"
    tar -cf "${WORKDIR}/pkg.tar" \
        --owner=0 --group=0 --sort=name \
        --mtime="@$(date +%s)" --numeric-owner \
        --format=posix \
        --transform 's,^\./,,' \
        .

    cd "$WORKDIR"
    tar -rf "${WORKDIR}/pkg.tar" \
        --owner=0 --group=0 --sort=name \
        --mtime="@$(date +%s)" --numeric-owner \
        --format=posix \
        --transform 's,^\./,,' \
        .PKGINFO .INSTALL

    local artifact="${OUTPUT_DIR}/${pkgname}-${pkgver}-1-x86_64.pkg.tar.zst"
    zstd "-${ZSTD_LEVEL}" -q -o "$artifact" "${WORKDIR}/pkg.tar"
    rm -f "${WORKDIR}/pkg.tar"

    succ "Arch: ${artifact}"
    ARTIFACT="$artifact"
}

get_artifact() { echo "$ARTIFACT"; }
get_deps()    { echo "xcb-util-cursor libxcb xcb-util-wm xcb-util-keysyms libglvnd libxkbcommon-x11"; }
