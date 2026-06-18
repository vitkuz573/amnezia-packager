#!/bin/bash
#
# Arch Linux .pkg.tar.zst packager
#

source "${PROJECT_ROOT}/src/packager/00-interface.sh"
source "${PROJECT_ROOT}/src/core/template.sh"
packager_register_impl

build_package() {
    local pkgver="${RELEASE_VERSION//-/.}"
    local pkgname="${APP_USER}"

    info "Building Arch: ${pkgname}-${pkgver}"

    local pkgdir="${WORKDIR}/pkg"
    mkdir -p "${pkgdir}${INSTALL_DIR}"
    cp -a "$STAGING_DIR/." "${pkgdir}${INSTALL_DIR}/"
    fix_desktop_exec "${pkgdir}${INSTALL_DIR}"

    # ── Compute sizes ───────────────────────────────────────────────
    template::compute_size "$STAGING_DIR"

    # ── Generate metadata from templates ────────────────────────────
    template::render "${PROJECT_ROOT}/templates/arch/PKGINFO" "${WORKDIR}/.PKGINFO"
    template::render "${PROJECT_ROOT}/templates/arch/INSTALL" "${WORKDIR}/.INSTALL"

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
get_deps()    { echo "${DEPS_ARCH:-xcb-util-cursor libxcb xcb-util-wm xcb-util-keysyms libglvnd libxkbcommon-x11}"; }
