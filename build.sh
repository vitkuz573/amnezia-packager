#!/bin/bash
#
# AmneziaVPN Packager — Enterprise-Grade Build System
# https://github.com/amnezia-vpn/amnezia-client
#
set -euo pipefail

export PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

# ── Bootstrap: load core in order ─────────────────────────────────────
source "${PROJECT_ROOT}/config/default.sh"
source "${PROJECT_ROOT}/src/core/logger.sh"
source "${PROJECT_ROOT}/src/core/bootstrap.sh"
source "${PROJECT_ROOT}/src/core/pipeline.sh"

# ── CLI ───────────────────────────────────────────────────────────────
pipeline::run "$@"
