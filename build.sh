#!/bin/bash
#
# AmneziaVPN Packager — Enterprise-Grade Build System
# https://github.com/vitkuz573/amnezia-packager
#
# set -euo pipefail

export PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

# ── Bootstrap: load core in order ─────────────────────────────────────
source "${PROJECT_ROOT}/src/core/logger.sh"
source "${PROJECT_ROOT}/src/core/config.sh"
source "${PROJECT_ROOT}/src/core/bootstrap.sh"
source "${PROJECT_ROOT}/src/core/pipeline.sh"

# ── CLI ───────────────────────────────────────────────────────────────
pipeline::run "$@"
rc=$?
if [[ $rc -ne 0 ]]; then
    err "Pipeline exited with code ${rc}"
fi
exit $rc
