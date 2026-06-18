#!/bin/bash
#
# provenance — Build provenance attestation (supply-chain transparency)
#
# Generates a signed JSON provenance document that links:
#   Source (official release URL + SHA256) → Build (config + command) → Artifact (package SHA256)
#
# Users can independently verify that a package was built from the official
# AmneziaVPN release by checking the provenance signature against the
# project GPG key and confirming the source SHA256 matches the official asset.

[[ -n "${__PROVENANCE_LOADED:-}" ]] && return; __PROVENANCE_LOADED=1

source "${PROJECT_ROOT}/src/core/logger.sh"

provenance::generate() {
    local output_file="$1"
    local source_hash="$2"
    local source_url="${3:-${TAR_URL:-}}"
    local artifact_path="${4:-}"

    local ts; ts=$(date -u +%FT%TZ)

    local artifacts_json="[]"
    if [[ -n "$artifact_path" && -f "$artifact_path" ]]; then
        local name; name=$(basename "$artifact_path")
        local sha256; sha256=$(sha256sum "$artifact_path" | cut -d' ' -f1)
        local size; size=$(stat -c%s "$artifact_path")
        artifacts_json=$(python3 -c "
import json
print(json.dumps([{
    'name': '$name',
    'sha256': '$sha256',
    'size': $size
}]))
")
    fi

    cat > "$output_file" <<-PROVENANCE
{
  "provenance": {
    "version": 1,
    "build_tool": "amnezia-packager",
    "build_tool_version": "2.0.0",
    "build_id": "${CORRELATION_ID:-local}",
    "build_time": "${ts}",
    "builder": {
      "type": "${BUILDER_TYPE:-manual}",
      "uri": "${BUILDER_URI:-}"
    }
  },
  "source": {
    "type": "github_release",
    "repo": "${REPO:-}",
    "version": "${RELEASE_VERSION:-}",
    "url": "${source_url}",
    "sha256": "${source_hash}"
  },
  "build": {
    "command": "${BUILD_COMMAND:-./build.sh}",
    "config_profile": "${CONFIG_PROFILE:-default}",
    "target": "${PACKAGE_TARGET:-}",
    "arch": "${PACKAGE_ARCH:-}"
  },
  "artifacts": ${artifacts_json}
}
PROVENANCE
    succ "Provenance: ${output_file}"
}

provenance::sign() {
    local provenance_file="$1"
    local gpg_key="${2:-${GPG_KEY:-}}"

    [[ -z "$gpg_key" ]] && { warn "No GPG key — provenance not signed"; return 0; }
    assert_cmds gpg

    gpg --detach-sign --armor --default-key "${gpg_key}" \
        -o "${provenance_file}.asc" "$provenance_file" 2>/dev/null || {
        warn "GPG signing failed for provenance"
        return 1
    }
    [[ -f "${provenance_file}.asc" ]] && succ "Provenance signed: ${provenance_file}.asc"
}

provenance::verify() {
    local provenance_file="$1"
    local gpg_keyring="${2:-}"

    if [[ -z "$provenance_file" || ! -f "$provenance_file" ]]; then
        err "Provenance file not found: ${provenance_file}"
        return 1
    fi

    if [[ -n "$gpg_keyring" && -f "${provenance_file}.asc" ]]; then
        if gpg --no-default-keyring --keyring "$gpg_keyring" \
            --verify "${provenance_file}.asc" "$provenance_file" 2>/dev/null; then
            succ "GPG signature: VALID"
        else
            err "GPG signature: INVALID"
            return 1
        fi
    fi

    python3 -c "
import json, sys, os, hashlib

prov = json.load(open('${provenance_file}'))

# Validate top-level structure
assert 'provenance' in prov, 'missing provenance block'
assert 'source' in prov, 'missing source block'
assert 'artifacts' in prov, 'missing artifacts block'

# Check source fields
src = prov['source']
assert src.get('url'), 'missing source.url'
assert src.get('sha256'), 'missing source.sha256'
print(f'Source: {src[\"url\"]}')
print(f'SHA256: {src[\"sha256\"]}')

# Check artifacts and verify hashes
for a in prov['artifacts']:
    apath = a['name']
    if os.path.exists(apath):
        actual = hashlib.sha256(open(apath, 'rb').read()).hexdigest()
        expected = a['sha256']
        if actual == expected:
            print(f'OK: {apath} (hash matches)')
        else:
            print(f'HASH MISMATCH: {apath}')
            print(f'  expected: {expected}')
            print(f'  actual:   {actual}')
            sys.exit(1)
    else:
        print(f'NOTE: {apath} not found (cannot verify hash)')

print(f'Verification: PASS ({len(prov[\"artifacts\"])} artifact(s))')
" || return 1
}
