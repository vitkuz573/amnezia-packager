#!/bin/bash
#
# Stage: verify — validate extracted application structure
#

run_verify() {
    assert_dir "$STAGING_DIR"
    assert_dir "${STAGING_DIR}/client"
    assert_dir "${STAGING_DIR}/service"

    local errors=0

    check() {
        if [[ ! -e "$1" ]]; then
            err "  MISSING: $1"
            ((errors++))
        fi
    }

    check "${STAGING_DIR}/client/bin/${APP_NAME}"
    check "${STAGING_DIR}/client/${CLIENT_SCRIPT}"
    check "${STAGING_DIR}/service/bin/AmneziaVPN-service"
    check "${STAGING_DIR}/service/${SERVICE_SCRIPT}"
    check "${STAGING_DIR}/${DESKTOP_FILE}"
    check "${STAGING_DIR}/${ICON_FILE}"
    check "${STAGING_DIR}/${SERVICE_FILE}"

    if (( errors > 0 )); then
        err "${errors} critical file(s) missing in extracted payload"
        exit 1
    fi

    succ "All required files present"
}
