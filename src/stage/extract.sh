#!/bin/bash
#
# Stage: extract — run IFW installer headless to obtain application files
#

run_extract() {
    assert_cmds tar
    [[ -f "$LOCAL_TAR" ]] || { err "No tarball: ${LOCAL_TAR:-<empty>}"; exit 1; }

    # ── Extract tarball ─────────────────────────────────────────────
    local extract_dir="${WORKDIR}/extract"
    mkdir -p "$extract_dir"

    if [[ "$LOCAL_TAR" != "${WORKDIR}/"* ]]; then
        # Copy to workspace if external
        cp "$LOCAL_TAR" "${WORKDIR}/"
        LOCAL_TAR="${WORKDIR}/$(basename "$LOCAL_TAR")"
    fi

    info "Extracting tarball…"
    tar xf "$LOCAL_TAR" -C "$extract_dir"

    local installer
    installer="$(find "$extract_dir" -maxdepth 1 -name '*Installer*.bin' -type f | head -1)"
    [[ -z "$installer" ]] && { err "No *Installer*.bin in tarball"; exit 1; }

    chmod +x "$installer"
    succ "Installer: $(basename "$installer")"

    # ── Version from installer (if not set) ─────────────────────────
    if [[ -z "$RELEASE_VERSION" ]]; then
        RELEASE_VERSION="$(basename "$LOCAL_TAR" | sed 's/.*_\([0-9].*\)_linux.*/\1/')"
    fi

    # ── Run headless ────────────────────────────────────────────────
    local target="${WORKDIR}/target"
    mkdir -p "$target"

    info "Running IFW installer headless (needs sudo)…"
    sudo env QT_QPA_PLATFORM=offscreen "$installer" install \
        --root "$target" \
        --accept-licenses \
        --confirm-command 2>&1 | grep -v "^\[" || true

    # ── Verify ──────────────────────────────────────────────────────
    if [[ ! -f "${target}/client/bin/${APP_NAME}" ]]; then
        err "Extraction failed — ${APP_NAME} binary not found"
        ls -la "${target}/" 2>/dev/null | head -20
        exit 1
    fi

    # ── Strip IFW artefacts ─────────────────────────────────────────
    sudo rm -f "$target/maintenancetool"   \
          "$target/maintenancetool.dat"    \
          "$target/maintenancetool.ini"    \
          "$target/installer.dat"          \
          "$target/components.xml"         \
          "$target/network.xml"            \
          "$target/InstallationLog.txt"    \
          2>/dev/null || true
    sudo rm -rf "$target/installerResources" 2>/dev/null || true

    STAGING_DIR="$target"
    succ "Extracted → ${STAGING_DIR} ($(du -sh "$STAGING_DIR" | cut -f1))"
}
