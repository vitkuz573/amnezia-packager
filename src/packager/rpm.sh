#!/bin/bash
#
# RPM packager — Fedora / RHEL / openSUSE .rpm builder
#

source "${PROJECT_ROOT}/src/packager/00-interface.sh"
source "${PROJECT_ROOT}/src/core/template.sh"
packager_register_impl

build_package() {
    local pkgver="${RELEASE_VERSION//-/.}"
    local pkgname="${APP_USER}"

    info "Building RPM: ${pkgname}-${pkgver}"

    assert_cmds rpmbuild

    local pkgdir="${WORKDIR}/rpmbuild"
    mkdir -p "${pkgdir}/SOURCES" "${pkgdir}/SPECS" "${pkgdir}/BUILD" "${pkgdir}/RPMS"

    # ── Prepare payload ─────────────────────────────────────────────
    local payload="${pkgdir}/SOURCES/${pkgname}-${pkgver}"
    mkdir -p "${payload}${INSTALL_DIR}"
    cp -a "$STAGING_DIR/." "${payload}${INSTALL_DIR}/"
    fix_desktop_exec "${payload}${INSTALL_DIR}"

    # ── Compute sizes ───────────────────────────────────────────────
    template::compute_size "$STAGING_DIR"

    # ── Generate .spec from template ────────────────────────────────
    template::render "${PROJECT_ROOT}/templates/rpm/spec" "${pkgdir}/SPECS/${pkgname}.spec"

    # ── Create source tarball for rpmbuild ──────────────────────────
    cd "${pkgdir}/SOURCES"
    tar czf "${pkgname}-${pkgver}.tar.gz" "${pkgname}-${pkgver}"
    rm -rf "${payload}"

    # ── Build ───────────────────────────────────────────────────────
    rpmbuild --define "_topdir ${pkgdir}" \
             --define "_rpmfilename ${pkgname}-${pkgver}-1.${PACKAGE_ARCH}.rpm" \
             -bb "${pkgdir}/SPECS/${pkgname}.spec" 2>&1 | grep -v "^error: " || true

    # ── Collect artifact ───────────────────────────────────────────
    local rpm_file
    rpm_file=$(find "${pkgdir}/RPMS" -name "*.rpm" -type f 2>/dev/null | head -1)
    if [[ -z "$rpm_file" ]]; then
        warn "rpmbuild may have failed — checking for errors..."
        find "${pkgdir}" -name "*.rpm" -type f 2>/dev/null || true
        # Fallback: build manually
        local artifact="${OUTPUT_DIR}/${pkgname}-${pkgver}-1.${PACKAGE_ARCH}.rpm"
        cd "${pkgdir}/SOURCES"
        tar xzf "${pkgname}-${pkgver}.tar.gz"
        cd "${pkgname}-${pkgver}"

        # Manual RPMS structure for direct rpmbuild call
        mkdir -p "${pkgdir}/BUILDROOT/${pkgname}-${pkgver}-1.${PACKAGE_ARCH}"
        cp -a * "${pkgdir}/BUILDROOT/${pkgname}-${pkgver}-1.${PACKAGE_ARCH}/"
        cd "${pkgdir}/BUILDROOT/${pkgname}-${pkgver}-1.${PACKAGE_ARCH}"

        rpmbuild --define "_topdir ${pkgdir}" \
                 --define "_buildroot ${pkgdir}/BUILDROOT/${pkgname}-${pkgver}-1.${PACKAGE_ARCH}" \
                 -bb --buildroot "${pkgdir}/BUILDROOT/${pkgname}-${pkgver}-1.${PACKAGE_ARCH}" \
                 "${pkgdir}/SPECS/${pkgname}.spec" 2>&1 | tail -5 || true
        rpm_file=$(find "${pkgdir}/RPMS" -name "*.rpm" -type f 2>/dev/null | head -1)
    fi

    if [[ -n "$rpm_file" ]]; then
        cp "$rpm_file" "${OUTPUT_DIR}/"
        local out_name; out_name=$(basename "$rpm_file")
        ARTIFACT="${OUTPUT_DIR}/${out_name}"
        succ "RPM: ${ARTIFACT}"
    else
        err "RPM build failed — no .rpm produced"
        exit 1
    fi
}

get_artifact() { echo "$ARTIFACT"; }
get_deps()    { echo "${DEPS_RPM:-libxcb-cursor libxcb-xinerama libxcb-icccm4 libxcb-keysyms1 libopengl0 libxkbcommon-x11}"; }
