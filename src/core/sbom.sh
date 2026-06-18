#!/bin/bash
#
# SBOM — CycloneDX Software Bill of Materials generator
#

[[ -n "${__SBOM_LOADED:-}" ]] && return; __SBOM_LOADED=1

source "${PROJECT_ROOT}/src/core/logger.sh"

sbom::generate() {
    local output_file="$1"
    local ts; ts=$(date -u +%FT%TZ)

    # Build components array using python3 for proper JSON
    local components_json="[]"
    local bin_dir="${STAGING_DIR}/client/bin"

    if command -v python3 &>/dev/null && [[ -d "$bin_dir" ]]; then
        components_json=$(python3 -c "
import json, os, hashlib

components = []
bin_dir = os.environ.get('STAGING_DIR', '') + '/client/bin'
version = os.environ.get('RELEASE_VERSION', '0.0.0')
arch = os.environ.get('PACKAGE_ARCH', 'x86_64')

if os.path.isdir(bin_dir):
    for f in sorted(os.listdir(bin_dir)):
        fp = os.path.join(bin_dir, f)
        if not os.path.isfile(fp) or f.endswith('.sha256'):
            continue
        sha256 = hashlib.sha256(open(fp, 'rb').read()).hexdigest()
        components.append({
            'type': 'application',
            'name': f,
            'version': version,
            'hashes': [{'alg': 'SHA-256', 'content': sha256}],
            'licenses': [{'license': {'id': 'GPL-3.0-only'}}],
            'purl': f'pkg:generic/{f}@{version}?arch={arch}'
        })

print(json.dumps(components, indent=2))
")
    fi

    cat > "$output_file" <<-SBOM
{
  "\$schema": "http://cyclonedx.org/schema/bom-1.5.schema.json",
  "bomFormat": "CycloneDX",
  "specVersion": "1.5",
  "serialNumber": "urn:uuid:${CORRELATION_ID}",
  "version": 1,
  "metadata": {
    "timestamp": "${ts}",
    "tools": [{
      "vendor": "amnezia-packager",
      "name": "amnezia-packager",
      "version": "2.0.0"
    }],
    "component": {
      "type": "application",
      "name": "${APP_NAME}",
      "version": "${RELEASE_VERSION}",
      "purl": "pkg:generic/${APP_USER}@${RELEASE_VERSION}?arch=${PACKAGE_ARCH}"
    }
  },
  "components": ${components_json}
}
SBOM
    succ "SBOM: ${output_file}"
}
