#!/bin/bash
#
# healthcheck — post-install validation script
# Pairs with generated build-manifest.json
#

set -euo pipefail

APP_NAME="${APP_NAME:-AmneziaVPN}"
APP_USER="${APP_USER:-amneziavpn}"
INSTALL_DIR="${INSTALL_DIR:-/opt/AmneziaVPN}"
DESKTOP_FILE="${DESKTOP_FILE:-AmneziaVPN.desktop}"
ICON_FILE="${ICON_FILE:-AmneziaVPN.png}"
SERVICE_FILE="${SERVICE_FILE:-AmneziaVPN.service}"
CLIENT_SCRIPT="${CLIENT_SCRIPT:-AmneziaVPN.sh}"

PASS=0
FAIL=0

check() {
    local desc="$1"
    if eval "$2" &>/dev/null; then
        echo "  [PASS] ${desc}"
        ((PASS++))
    else
        echo "  [FAIL] ${desc}"
        ((FAIL++))
    fi
}

echo "Post-install Health Check — ${APP_NAME} ${RELEASE_VERSION:-unknown}"
echo ""

echo "Binary:"
check "client binary"          "[[ -x '${INSTALL_DIR}/client/bin/${APP_NAME}' ]]"
check "service binary"         "[[ -x '${INSTALL_DIR}/service/bin/AmneziaVPN-service' ]]"
check "client launcher"        "[[ -f '${INSTALL_DIR}/client/${CLIENT_SCRIPT}' ]]"
check "service launcher"       "[[ -f '${INSTALL_DIR}/service/${SERVICE_SCRIPT}' ]]"

echo "Integration:"
check "CLI symlink"            "[[ -L '/usr/local/bin/${APP_USER}' ]]"
check "desktop file"           "[[ -f '/usr/share/applications/${DESKTOP_FILE}' ]]"
check "icon file"              "[[ -f '/usr/share/pixmaps/${ICON_FILE}' ]]"

echo "Systemd:"
check "service unit"           "[[ -f '/etc/systemd/system/${SERVICE_FILE}' ]]"
check "service enabled"        "systemctl is-enabled '${APP_NAME}' 2>/dev/null | grep -q enabled"
check "service active"         "systemctl is-active '${APP_NAME}' 2>/dev/null | grep -q active"

echo "Filesystem:"
check "install dir exists"     "[[ -d '${INSTALL_DIR}' ]]"
check "install dir read-only"  "[[ -w '${INSTALL_DIR}' ]] && false || true"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] && echo "Status: HEALTHY" || echo "Status: UNHEALTHY"
exit "$FAIL"
