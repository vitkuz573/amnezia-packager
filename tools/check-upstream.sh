#!/bin/bash
set -euo pipefail

# check-upstream — Check upstream repo for new AmneziaVPN releases
#
# Compares the latest upstream release tag against the last built version
# stored on gh-pages. Exits 0 if a new version is available (and prints it),
# exits 1 if already up-to-date or on error.
#
# Usage: ./tools/check-upstream.sh [--last-version X.Y.Z.W]
#   --last-version  Override the last-built version check (for CI)

UPSTREAM_OWNER="amnezia-vpn"
UPSTREAM_REPO="amnezia-client"
LAST_VERSION_URL="https://vitkuz573.github.io/amnezia-packager/.last-version"

# Parse args
LAST_VERSION=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --last-version) LAST_VERSION="$2"; shift 2 ;;
        *) echo "Usage: $0 [--last-version X.Y.Z.W]"; exit 2 ;;
    esac
done

# Fetch latest upstream release tag
LATEST_TAG="$(curl -sS "https://api.github.com/repos/${UPSTREAM_OWNER}/${UPSTREAM_REPO}/releases/latest" | jq -r '.tag_name // empty')"

if [[ -z "$LATEST_TAG" ]]; then
    echo "check-upstream: failed to fetch latest upstream release" >&2
    exit 1
fi

echo "check-upstream: upstream latest: $LATEST_TAG" >&2

# Strip leading 'v' if present (upstream tags are bare: 4.8.19.0)
LATEST="${LATEST_TAG#v}"

# Determine last built version
if [[ -n "$LAST_VERSION" ]]; then
    LAST="$LAST_VERSION"
else
    LAST="$(curl -sS --connect-timeout 5 "$LAST_VERSION_URL" 2>/dev/null || echo "")"
fi

if [[ -z "$LAST" ]]; then
    echo "check-upstream: no previous build found — will build $LATEST" >&2
    echo "$LATEST"
    exit 0
fi

echo "check-upstream: last built: $LAST" >&2

# Simple version string comparison (works for X.Y.Z.W format)
if [[ "$LATEST" == "$LAST" ]]; then
    echo "check-upstream: already up-to-date at $LATEST" >&2
    exit 1
fi

# Verify LATEST is actually newer by sorting
HIGHER="$(printf '%s\n%s\n' "$LAST" "$LATEST" | sort -V | tail -1)"
if [[ "$HIGHER" != "$LATEST" ]]; then
    echo "check-upstream: last built ($LAST) is newer than upstream ($LATEST) — odd, skipping" >&2
    exit 1
fi

echo "check-upstream: new version available: $LATEST" >&2
echo "$LATEST"
exit 0
