setup() {
    load 'fixtures/load.bash'
    export PROJECT_ROOT="${PROJECT_ROOT}"
    export OUTPUT_MANIFEST="true"
    export OUTPUT_DIR; OUTPUT_DIR=$(mktemp -d)
    export RELEASE_VERSION="4.8.19"
    export PACKAGE_TARGET="deb"
    export PACKAGE_ARCH="amd64"
    export CORRELATION_ID="test-123"
    export APP_USER="amneziavpn"
    export INSTALL_DIR="/opt/amneziavpn"
    export REPO="vitkuz573/amnezia-packager"
    source "${PROJECT_ROOT}/src/core/bootstrap.sh"
    source "${PROJECT_ROOT}/src/core/pipeline.sh"
}

teardown() {
    rm -rf "$OUTPUT_DIR"
}

@test "manifest: writes valid JSON" {
    packager_discover
    pipeline::write_manifest
    [ -f "${OUTPUT_DIR}/build-manifest.json" ]
    python3 -c "import json; json.load(open('${OUTPUT_DIR}/build-manifest.json'))"
}

@test "manifest: contains correct fields" {
    packager_discover
    pipeline::write_manifest
    local mf="${OUTPUT_DIR}/build-manifest.json"
    python3 -c "
import json
m = json.load(open('$mf'))
assert m['tool'] == 'amnezia-packager'
assert m['version'] == '4.8.19'
assert m['target'] == 'deb'
assert m['arch'] == 'amd64'
assert m['correlation_id'] == 'test-123'
assert m['config']['repository'] == 'vitkuz573/amnezia-packager'
"
}

@test "manifest: artifact info included when file exists" {
    local artifact="${OUTPUT_DIR}/test.deb"
    echo "mock" > "$artifact"
    ARTIFACT="$artifact"
    packager_discover
    pipeline::write_manifest
    local mf="${OUTPUT_DIR}/build-manifest.json"
    python3 -c "
import json
m = json.load(open('$mf'))
assert len(m['artifacts']) == 1
assert m['artifacts'][0]['name'] == 'test.deb'
assert m['artifacts'][0]['size'] > 0
assert 'sha256' in m['artifacts'][0]
"
}

@test "manifest: not written when OUTPUT_MANIFEST=false" {
    export OUTPUT_MANIFEST="false"
    pipeline::write_manifest
    [ ! -f "${OUTPUT_DIR}/build-manifest.json" ]
}
