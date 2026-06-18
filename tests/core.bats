setup() {
    load 'fixtures/load.bash'
}

@test "logger: log levels" {
    LOG_LEVEL=debug
    run debug "test debug"
    [ "$status" -eq 0 ]
}

@test "logger: silent level suppresses output" {
    LOG_LEVEL=silent
    run info "should be silent"
    [ -z "$output" ]
}

@test "bootstrap: detect_target returns arch on Arch Linux" {
    [[ -f /etc/arch-release ]] || skip "not on Arch"
    PACKAGE_TARGET=auto
    run detect_target
    [ "$output" = "arch" ]
}

@test "bootstrap: detect_target returns explicit target" {
    PACKAGE_TARGET=deb
    run detect_target
    [ "$output" = "deb" ]
}

@test "config: load exports APP_NAME" {
    PROJECT_ROOT="$BATS_TEST_DIRNAME/.."
    source "${PROJECT_ROOT}/src/core/config.sh"
    run config::load
    [ -n "$APP_NAME" ]
}

@test "config: JSON schema validates" {
    run config::validate "${PROJECT_ROOT}/config/default.json"
    [ "$status" -eq 0 ]
}

@test "pipeline: assert_cmds passes for existing commands" {
    run assert_cmds bash
    [ "$status" -eq 0 ]
}

@test "pipeline: assert_cmds fails for missing commands" {
    run assert_cmds nonexistent_cmd_xyz
    [ "$status" -eq 1 ]
}
