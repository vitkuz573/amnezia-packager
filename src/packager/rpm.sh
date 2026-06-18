#!/bin/bash
#
# RPM packager — placeholder for Fedora / RHEL / openSUSE
#

source "${PROJECT_ROOT}/src/packager/00-interface.sh"
packager_register_impl

build_package() {
    warn "RPM packager: not implemented yet"
    warn "Contributions: https://github.com/${REPO}"
    exit 1
}

get_artifact() { echo ""; }
get_deps()    { echo "libxcb-cursor libxcb-xinerama libxcb-icccm4 libxcb-keysyms1 libopengl0 libxkbcommon-x11"; }
