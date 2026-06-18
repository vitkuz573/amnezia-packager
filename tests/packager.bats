setup() {
    load 'fixtures/load.bash'
    source "${PROJECT_ROOT}/src/core/bootstrap.sh"
    export PROJECT_ROOT="${PROJECT_ROOT}"
}

@test "packager: discover finds all packagers" {
    packager_discover
    [ "${#_PACKAGERS[@]}" -ge 3 ]
}

@test "packager: get returns deb packager path" {
    packager_discover
    run packager_get "deb"
    [ "$status" -eq 0 ]
    [[ "$output" == *"deb.sh" ]]
}

@test "packager: get returns arch packager path" {
    packager_discover
    run packager_get "arch"
    [ "$status" -eq 0 ]
    [[ "$output" == *"arch.sh" ]]
}

@test "packager: get returns rpm packager path" {
    packager_discover
    run packager_get "rpm"
    [ "$status" -eq 0 ]
    [[ "$output" == *"rpm.sh" ]]
}

@test "packager: deb packager has required functions" {
    packager_discover
    local pkg; pkg=$(packager_get "deb")
    source "$pkg"
    run declare -F build_package
    [ "$status" -eq 0 ]
    run declare -F get_artifact
    [ "$status" -eq 0 ]
    run declare -F get_deps
    [ "$status" -eq 0 ]
}

@test "packager: arch packager has required functions" {
    packager_discover
    local pkg; pkg=$(packager_get "arch")
    source "$pkg"
    run declare -F build_package
    [ "$status" -eq 0 ]
    run declare -F get_artifact
    [ "$status" -eq 0 ]
    run declare -F get_deps
    [ "$status" -eq 0 ]
}

@test "packager: rpm packager has required functions" {
    packager_discover
    local pkg; pkg=$(packager_get "rpm")
    source "$pkg"
    run declare -F build_package
    [ "$status" -eq 0 ]
    run declare -F get_artifact
    [ "$status" -eq 0 ]
    run declare -F get_deps
    [ "$status" -eq 0 ]
}

@test "packager: 00-interface.sh defines helpers" {
    source "${PROJECT_ROOT}/src/packager/00-interface.sh"
    run declare -F fix_desktop_exec
    [ "$status" -eq 0 ]
    run declare -F compute_size_kb
    [ "$status" -eq 0 ]
    run declare -F compute_size_bytes
    [ "$status" -eq 0 ]
}

@test "packager: all targets have registered packagers" {
    packager_discover
    for target in deb arch rpm; do
        local pkg; pkg=$(packager_get "$target")
        [ -n "$pkg" ] || { echo "Missing packager for $target"; return 1; }
    done
}

@test "packager: get fails for unknown target" {
    packager_discover
    run packager_get "nonexistent"
    [ "$status" -eq 1 ]
}
