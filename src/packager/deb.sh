#!/bin/bash
#
# Debian/Ubuntu .deb packager
#

source "${PROJECT_ROOT}/src/packager/00-interface.sh"
source "${PROJECT_ROOT}/src/core/template.sh"
packager_register_impl

build_package() {
    local pkgver="${RELEASE_VERSION#v}"
    local pkgname="${APP_USER}"

    info "Building .deb: ${pkgname}_${pkgver}"

    local pkgdir="${WORKDIR}/deb"
    mkdir -p "${pkgdir}/DEBIAN" "${pkgdir}${INSTALL_DIR}"
    cp -a "$STAGING_DIR/." "${pkgdir}${INSTALL_DIR}/"
    fix_desktop_exec "${pkgdir}${INSTALL_DIR}"

    # ── Compute sizes ───────────────────────────────────────────────
    template::compute_size "$STAGING_DIR"

    # ── Generate control & scripts from templates ───────────────────
    template::render "${PROJECT_ROOT}/templates/debian/control" "${pkgdir}/DEBIAN/control"
    template::render "${PROJECT_ROOT}/templates/debian/postinst" "${pkgdir}/DEBIAN/postinst"
    template::render "${PROJECT_ROOT}/templates/debian/prerm" "${pkgdir}/DEBIAN/prerm"
    chmod 755 "${pkgdir}/DEBIAN/postinst" "${pkgdir}/DEBIAN/prerm"

    # ── Build .deb ──────────────────────────────────────────────────
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
