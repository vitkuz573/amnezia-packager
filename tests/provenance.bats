setup() {
    load 'fixtures/load.bash'
    export PROJECT_ROOT="${PROJECT_ROOT}"
    export OUTPUT_DIR; OUTPUT_DIR=$(mktemp -d)
    export RELEASE_VERSION="4.8.19"
    export PACKAGE_TARGET="deb"
    export PACKAGE_ARCH="amd64"
    export CORRELATION_ID="test-prov-001"
    export APP_USER="amneziavpn"
    export INSTALL_DIR="/opt/amneziavpn"
    export REPO="amnezia-vpn/amnezia-client"
    export TAR_URL="https://github.com/amnezia-vpn/amnezia-client/releases/download/4.8.19.0/AmneziaVPN_4.8.19.0_linux_x64.tar"
    source "${PROJECT_ROOT}/src/core/provenance.sh"
}

teardown() {
    rm -rf "$OUTPUT_DIR"
}

@test "provenance: generates valid JSON" {
    local pf="${OUTPUT_DIR}/provenance.json"
    provenance::generate "$pf" "abc123deadbeef" "" ""
    [ -f "$pf" ]
    python3 -c "import json; json.load(open('$pf'))"
}

@test "provenance: contains source and artifact blocks" {
    local pf="${OUTPUT_DIR}/provenance.json"
    provenance::generate "$pf" "abc123" "$TAR_URL" ""
    python3 -c "
import json
p = json.load(open('$pf'))
assert p['provenance']['version'] == 1
assert p['source']['sha256'] == 'abc123'
assert p['source']['url'] == '$TAR_URL'
assert p['build']['target'] == 'deb'
"
}

@test "provenance: artifact info included when file specified" {
    local artifact="${OUTPUT_DIR}/test-artifact.bin"
    dd if=/dev/urandom bs=1024 count=1 of="$artifact" 2>/dev/null
    local pf="${OUTPUT_DIR}/provenance.json"
    provenance::generate "$pf" "abc123" "" "$artifact"
    python3 -c "
import json
p = json.load(open('$pf'))
assert len(p['artifacts']) == 1
assert p['artifacts'][0]['name'] == 'test-artifact.bin'
assert p['artifacts'][0]['size'] == 1024
assert len(p['artifacts'][0]['sha256']) == 64
"
}

@test "provenance: verify passes for valid provenance" {
    local artifact="${OUTPUT_DIR}/test-verify.bin"
    echo "verify test data" > "$artifact"
    local pf="${OUTPUT_DIR}/provenance.json"
    provenance::generate "$pf" "sourcehash123" "" "$artifact"
    cd "$OUTPUT_DIR"
    run provenance::verify "$pf"
    [ "$status" -eq 0 ]
}

@test "provenance: verify fails for tampered artifact" {
    local artifact="${OUTPUT_DIR}/test-tamper.bin"
    echo "original data" > "$artifact"
    local pf="${OUTPUT_DIR}/provenance.json"
    provenance::generate "$pf" "hash123" "" "$artifact"
    # Tamper with the artifact
    echo "TAMPERED" >> "$artifact"
    cd "$OUTPUT_DIR"
    run provenance::verify "$pf"
    [ "$status" -eq 1 ]
}

@test "provenance: verify fails on invalid JSON" {
    local pf="${OUTPUT_DIR}/bad-provenance.json"
    echo "not json" > "$pf"
    run provenance::verify "$pf"
    [ "$status" -eq 1 ]
}
