#!/bin/bash
#
# Packager interface — each packager registers via packager_register
#
# Contract:
#   build_package()  — produce artifact in OUTPUT_DIR
#   get_artifact()   — echo path to built artifact
#   get_deps()       — echo array of dependencies
#

[[ -n "${__PACKAGER_IFACE_LOADED:-}" ]] && return; __PACKAGER_IFACE_LOADED=1

packager_register_impl() {
    local path; path="$(readlink -f "${BASH_SOURCE[1]}")"
    packager_register "$path"
}

# Helpers for concrete packagers
fix_desktop_exec() {
    local dir="$1"
    local file="${dir}/${DESKTOP_FILE}"
    [[ -f "$file" ]] && sed -i "s|^Exec=.*|Exec=${APP_NAME}|" "$file"
}

compute_size_kb() { du -sk "$1" | cut -f1; }
compute_size_bytes() { du -sb "$1" | cut -f1; }
