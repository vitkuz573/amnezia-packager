#!/bin/bash
#
# verify.sh — Verify package provenance (supply-chain transparency)
#
# Users can independently verify that a package was built from the official
# AmneziaVPN release by checking the provenance attestation.
#
# Usage:
#   tools/verify.sh [options] <package.deb|package.rpm|package.pkg.tar.zst>
#
# Options:
#   --provenance FILE    Path to provenance JSON (default: <package>.provenance or <package>.provenance.json)
#   --key FILE           GPG public keyring for signature verification
#   --source-url URL     Expected source URL (optional, for extra checking)
#   --source-sha256 HASH Expected source hash (optional, for extra checking)
#   -q, --quiet          Minimal output
#   -h, --help           Show this help
#
# Exit codes:
#   0 — verification passed
#   1 — verification failed
#   2 — usage error
#
# Examples:
#   tools/verify.sh amneziavpn_4.8.19.0_amd64.deb
#   tools/verify.sh --key repo-public-key.asc amneziavpn_4.8.19.0_amd64.deb
#   tools/verify.sh --provenance build-provenance.json amneziavpn-4.8.19.0-1-x86_64.pkg.tar.zst
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

quiet=false
provenance_file=""
gpg_keyring=""
expected_source_url=""
expected_source_sha256=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [options] <package>

Verify a package's provenance attestation.

Options:
  --provenance FILE    Path to provenance JSON (auto-detected if not given)
  --key FILE           GPG public keyring for signature verification
  --source-url URL     Expected source URL
  --source-sha256 HASH Expected source SHA256
  -q, --quiet          Minimal output
  -h, --help           Show this help

Exit codes: 0 = pass, 1 = fail, 2 = usage error
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --provenance)   provenance_file="$2"; shift 2 ;;
        --key)          gpg_keyring="$2"; shift 2 ;;
        --source-url)   expected_source_url="$2"; shift 2 ;;
        --source-sha256) expected_source_sha256="$2"; shift 2 ;;
        -q|--quiet)     quiet=true; shift ;;
        -h|--help)      usage ;;
        -*)             echo "Unknown: $1"; exit 2 ;;
        *)              pkg_file="$1"; shift ;;
    esac
done

[[ -z "${pkg_file:-}" ]] && { echo "Usage: $(basename "$0") <package>"; exit 2; }
[[ -f "$pkg_file" ]] || { echo "Package not found: $pkg_file"; exit 1; }

pkg_basename="$(basename "$pkg_file")"
pkg_dir="$(dirname "$(readlink -f "$pkg_file")")"

# Auto-detect provenance file
if [[ -z "$provenance_file" ]]; then
    for ext in ".provenance" ".provenance.json" "-provenance.json"; do
        candidate="${pkg_dir}/${pkg_basename}${ext}"
        [[ -f "$candidate" ]] && { provenance_file="$candidate"; break; }
    done
    # Also try the generic name
    if [[ -z "$provenance_file" ]]; then
        for f in "${pkg_dir}"/*-provenance.json; do
            [[ -f "$f" ]] && { provenance_file="$f"; break; }
        done
    fi
fi

[[ -z "$provenance_file" || ! -f "$provenance_file" ]] && {
    echo "Provenance file not found. Use --provenance to specify."
    exit 1
}

$quiet || echo "Provenance: $(basename "$provenance_file")"
$quiet || echo "Package:    ${pkg_file}"

# Source the provenance module for ::verify
source "${PROJECT_ROOT}/src/core/logger.sh" 2>/dev/null || true
export LOG_LEVEL=silent

# Run verification
failed=false

# Verify GPG signature
if [[ -n "$gpg_keyring" ]]; then
    sig_file="${provenance_file}.asc"
    if [[ -f "$sig_file" ]]; then
        if gpg --no-default-keyring --keyring "$gpg_keyring" \
            --verify "$sig_file" "$provenance_file" &>/dev/null; then
            $quiet || echo "GPG signature: VALID"
        else
            echo "GPG signature: INVALID"
            failed=true
        fi
    else
        $quiet || echo "GPG signature: NONE (--key given but no .asc found)"
    fi
fi

# Validate JSON and check artifact hash
check_result=$(python3 -c "
import json, sys, os, hashlib

try:
    prov = json.load(open('${provenance_file}'))
except Exception as e:
    print(f'Invalid JSON: {e}')
    sys.exit(1)

errs = []

# Validate structure
for key in ['provenance', 'source', 'artifacts']:
    if key not in prov:
        errs.append(f'Missing \"{key}\" block')

src = prov.get('source', {})
if not src.get('url'):
    errs.append('Missing source.url')
if not src.get('sha256'):
    errs.append('Missing source.sha256')

# Verify artifact hash
for a in prov.get('artifacts', []):
    apath = os.path.join('${pkg_dir}', a.get('name', ''))
    if os.path.exists(apath):
        actual = hashlib.sha256(open(apath, 'rb').read()).hexdigest()
        expected = a.get('sha256', '')
        if actual == expected:
            print(f'OK: {a[\"name\"]} (hash matches)')
        else:
            errs.append(f'HASH MISMATCH: {a[\"name\"]}')
            errs.append(f'  expected: {expected}')
            errs.append(f'  actual:   {actual}')
    else:
        errs.append(f'Artifact not found: {a[\"name\"]}')

# Extra checks
${expected_source_url:+if src.get('url') != '$expected_source_url': errs.append(f'Source URL mismatch')}
${expected_source_sha256:+if src.get('sha256') != '$expected_source_sha256': errs.append(f'Source SHA256 mismatch')}

if errs:
    for e in errs:
        print(f'FAIL: {e}')
    sys.exit(1)

# Summary
print(f'Source: {src[\"url\"]}')
print(f'Source SHA256: {src[\"sha256\"]}')
print(f'Built: {prov.get(\"provenance\", {}).get(\"build_time\", \"?\")}')
print(f'Verification: PASS')
") || failed=true

echo "$check_result"

$failed && exit 1 || exit 0
