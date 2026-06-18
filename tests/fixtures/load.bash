#!/bin/bash
#
# Test fixture loader
#

export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"

# Load core modules
source "${PROJECT_ROOT}/src/core/logger.sh"

# Helper: create a temp workspace
fixture_workspace() {
    mktemp -d
}

# Helper: create a minimal mock tarball
fixture_mock_tar() {
    local dir="$1"
    local tar_file="$2"
    mkdir -p "${dir}/mock-installer"
    echo "mock" > "${dir}/mock-installer/AmneziaVPN_Linux_Installer.bin"
    chmod +x "${dir}/mock-installer/AmneziaVPN_Linux_Installer.bin"
    cd "$dir" && tar cf "$tar_file" mock-installer/
    echo "$tar_file"
}

# Helper: assert file exists
assert_file_exists() {
    [[ -f "$1" ]] || { echo "Expected file: $1"; return 1; }
}
