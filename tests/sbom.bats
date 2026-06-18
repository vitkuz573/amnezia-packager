setup() {
    load 'fixtures/load.bash'
    export PROJECT_ROOT="${PROJECT_ROOT}"
    export OUTPUT_DIR; OUTPUT_DIR=$(mktemp -d)
    export STAGING_DIR; STAGING_DIR=$(mktemp -d)
    export RELEASE_VERSION="4.8.19"
    export PACKAGE_ARCH="amd64"
    export APP_NAME="AmneziaVPN"
    export APP_USER="amneziavpn"
    export CORRELATION_ID="test-456"
    source "${PROJECT_ROOT}/src/core/sbom.sh"

    # Create mock binaries
    mkdir -p "${STAGING_DIR}/client/bin"
    echo "mock binary 1" > "${STAGING_DIR}/client/bin/amneziavpn"
    echo "mock binary 2" > "${STAGING_DIR}/client/bin/amnezia-service"
    chmod +x "${STAGING_DIR}/client/bin"/*
}

teardown() {
    rm -rf "$OUTPUT_DIR" "$STAGING_DIR"
}

@test "sbom: generates valid CycloneDX JSON" {
    local sbom_file="${OUTPUT_DIR}/test-sbom.json"
    sbom::generate "$sbom_file"
    [ -f "$sbom_file" ]
    run python3 -c "import json; json.load(open('$sbom_file'))"
    [ "$status" -eq 0 ]
}

@test "sbom: contains correct metadata" {
    local sbom_file="${OUTPUT_DIR}/test-sbom.json"
    sbom::generate "$sbom_file"
    run python3 -c "
import json
s = json.load(open('$sbom_file'))
assert s['bomFormat'] == 'CycloneDX'
assert s['specVersion'] == '1.5'
assert s['metadata']['component']['name'] == 'AmneziaVPN'
assert s['metadata']['component']['version'] == '4.8.19'
"
    [ "$status" -eq 0 ]
}

@test "sbom: includes binary components" {
    local sbom_file="${OUTPUT_DIR}/test-sbom.json"
    sbom::generate "$sbom_file"
    run python3 -c "
import json
s = json.load(open('$sbom_file'))
components = {c['name'] for c in s['components']}
assert 'amneziavpn' in components
assert 'amnezia-service' in components
"
    [ "$status" -eq 0 ]
}

@test "sbom: each component has hash and purl" {
    local sbom_file="${OUTPUT_DIR}/test-sbom.json"
    sbom::generate "$sbom_file"
    run python3 -c "
import json
s = json.load(open('$sbom_file'))
for c in s['components']:
    assert c['hashes'][0]['alg'] == 'SHA-256'
    assert 'purl' in c
    assert 'licenses' in c
"
    [ "$status" -eq 0 ]
}
