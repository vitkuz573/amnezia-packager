#!/bin/bash
#
# Default configuration — override via environment or config/local.sh
#

# ── Application ────────────────────────────────────────────────────────
APP_NAME="${APP_NAME:-AmneziaVPN}"
APP_USER="${APP_USER:-${APP_NAME,,}}"  # lowercase
INSTALL_DIR="${INSTALL_DIR:-/opt/${APP_NAME}}"

# ── Repository ─────────────────────────────────────────────────────────
REPO_OWNER="${REPO_OWNER:-amnezia-vpn}"
REPO_NAME="${REPO_NAME:-amnezia-client}"
REPO="${REPO_OWNER}/${REPO_NAME}"

# ── Release ────────────────────────────────────────────────────────────
RELEASE_VERSION="${RELEASE_VERSION:-}"     # empty = latest
TAR_URL="${TAR_URL:-}"                     # overrides auto-detect
LOCAL_TAR="${LOCAL_TAR:-}"                 # path to local tarball

# ── Output ─────────────────────────────────────────────────────────────
OUTPUT_DIR="${OUTPUT_DIR:-${PWD}}"

# ── Platform ───────────────────────────────────────────────────────────
# auto | deb | rpm | arch
PACKAGE_TARGET="${PACKAGE_TARGET:-auto}"

# ── Dependencies (Debian names) ────────────────────────────────────────
DEPS_DEB="${DEPS_DEB:-libxcb-cursor0, libxcb-xinerama0, libxcb-icccm4, libxcb-keysyms1, libopengl0, libxkbcommon-x11-0}"

# ── Files inside the installer payload ─────────────────────────────────
DESKTOP_FILE="${DESKTOP_FILE:-${APP_NAME}.desktop}"
ICON_FILE="${ICON_FILE:-${APP_NAME}.png}"
SERVICE_FILE="${SERVICE_FILE:-${APP_NAME}.service}"
CLIENT_SCRIPT="${CLIENT_SCRIPT:-${APP_NAME}.sh}"
SERVICE_SCRIPT="${SERVICE_SCRIPT:-${APP_NAME}-service.sh}"

# ── Compression (Arch) ────────────────────────────────────────────────
ZSTD_LEVEL="${ZSTD_LEVEL:-3}"  # 1=fast…19=small

# ── Locale ─────────────────────────────────────────────────────────────
LANG="${LANG:-C}"
