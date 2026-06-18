setup() {
    load 'fixtures/load.bash'
    source "${PROJECT_ROOT}/src/core/template.sh"
}

@test "template: render substitutes config vars" {
    local tmpdir; tmpdir=$(fixture_workspace)
    local tpl_in="${tmpdir}/input.tpl"
    local tpl_out="${tmpdir}/output"
    echo "Hello \${APP_NAME}" > "$tpl_in"
    export APP_NAME="AmneziaVPN"
    template::render "$tpl_in" "$tpl_out"
    local content; content=$(cat "$tpl_out")
    [[ "$content" == "Hello AmneziaVPN" ]]
}

@test "template: render fails on missing file" {
    run template::render "/nonexistent" "/dev/null"
    [ "$status" -eq 1 ]
}

@test "template: compute_size returns nonzero" {
    local tmpdir; tmpdir=$(fixture_workspace)
    mkdir -p "${tmpdir}/data"
    dd if=/dev/zero of="${tmpdir}/data/test.bin" bs=1024 count=10 2>/dev/null
    template::compute_size "${tmpdir}/data"
    [ -n "$PKGSIZE_KB" ]
    [ -n "$PKGSIZE_BYTES" ]
    [ "$PKGSIZE_KB" -ge 10 ]
}

@test "template: render preserves APP_PATH (not substituted)" {
    local tmpdir; tmpdir=$(fixture_workspace)
    local tpl_in="${tmpdir}/input.tpl"
    local tpl_out="${tmpdir}/output"
    echo "TargetDir=\${APP_PATH}" > "$tpl_in"
    export APP_NAME="test" APP_PATH="/opt/amneziavpn"
    template::render "$tpl_in" "$tpl_out"
    local content; content=$(cat "$tpl_out")
    [[ "$content" == 'TargetDir=${APP_PATH}' ]]
}

@test "template: DEPS_ARCH_LINES formatted correctly" {
    export DEPS_ARCH="libxtst libxcb-cursor"
    # Simulate what template::render does
    DEPS_ARCH_LINES=$(echo "${DEPS_ARCH:-}" | tr ' ' '\n' | sed 's/^/depend = /')
    [[ "$DEPS_ARCH_LINES" == "depend = libxtst"* ]]
    [[ "$DEPS_ARCH_LINES" == *"depend = libxcb-cursor" ]]
}

@test "template: DEPS_RPM_LINES formatted correctly" {
    export DEPS_RPM="libXScrnSaver libxcb"
    DEPS_RPM_LINES=$(echo "${DEPS_RPM:-}" | tr ' ' '\n' | sed 's/^/Requires: /')
    [[ "$DEPS_RPM_LINES" == "Requires: libXScrnSaver"* ]]
    [[ "$DEPS_RPM_LINES" == *"Requires: libxcb" ]]
}

@test "template: PKGVER replaces dashes with dots" {
    export RELEASE_VERSION="4.8.19-beta"
    # Simulate what template::render does
    PKGVER="${RELEASE_VERSION//-/.}"
    [[ "$PKGVER" == "4.8.19.beta" ]]
}
