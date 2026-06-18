#!/bin/bash
#
# Debian/Ubuntu .deb packager
#

source "${PROJECT_ROOT}/src/packager/00-interface.sh"
packager_register_impl

build_package() {
    local pkgver="${RELEASE_VERSION#v}"
    local pkgname="${APP_USER}"

    info "Building .deb: ${pkgname}_${pkgver}"

    local pkgdir="${WORKDIR}/deb"
    mkdir -p "${pkgdir}/DEBIAN" "${pkgdir}${INSTALL_DIR}"
    cp -a "$STAGING_DIR/." "${pkgdir}${INSTALL_DIR}/"
    fix_desktop_exec "${pkgdir}${INSTALL_DIR}"

    local size; size="$(compute_size_kb "$STAGING_DIR")"

    cat > "${pkgdir}/DEBIAN/control" <<-CTRL
Package: ${pkgname}
Version: ${pkgver}
Section: net
Priority: optional
Architecture: amd64
Maintainer: AmneziaVPN <support@amnezia.com>
Depends: ${DEPS_DEB}
Installed-Size: ${size}
Description: AmneziaVPN — Client of your self-hosted VPN
 AmneziaVPN is a VPN client that allows you to create your own
 VPN server and connect to it using various protocols.
CTRL

    cat > "${pkgdir}/DEBIAN/postinst" <<-'POSTINST'
#!/bin/sh
set -e
APP_NAME="AmneziaVPN"
APP_PATH="/opt/${APP_NAME}"

case "$1" in
    configure)
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
        ;;
esac
exit 0
POSTINST

    cat > "${pkgdir}/DEBIAN/prerm" <<-'PRERM'
#!/bin/sh
set -e
APP_NAME="AmneziaVPN"
case "$1" in
    remove|purge)
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
        ;;
esac
exit 0
PRERM

    chmod 755 "${pkgdir}/DEBIAN/postinst" "${pkgdir}/DEBIAN/prerm"

    local artifact="${OUTPUT_DIR}/${pkgname}_${pkgver}_amd64.deb"
    if command -v fakeroot &>/dev/null; then
        fakeroot dpkg-deb --build "${pkgdir}" "${artifact}"
    else
        dpkg-deb --root-owner-group --build "${pkgdir}" "${artifact}"
    fi

    succ "Debian: ${artifact}"
    ARTIFACT="$artifact"
}

get_artifact() { echo "$ARTIFACT"; }
get_deps()    { echo "${DEPS_DEB}"; }
