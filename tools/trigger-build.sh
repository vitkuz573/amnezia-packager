#!/bin/bash
set -euo pipefail

# trigger-build — Check upstream and trigger AppVeyor build via API if new version available
#
# Usage: ./tools/trigger-build.sh [--token API_TOKEN] [--account ACCOUNT] [--project PROJECT]
#
# Requires AppVeyor API token with "Build" permission.
# Get token at: https://ci.appveyor.com/api-token

APPVEYOR_ACCOUNT="${APPVEYOR_ACCOUNT:-vitkuz573}"
APPVEYOR_PROJECT="${APPVEYOR_PROJECT:-amnezia-packager}"
APPVEYOR_TOKEN="${APPVEYOR_TOKEN:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --token)    APPVEYOR_TOKEN="$2"; shift 2 ;;
        --account)  APPVEYOR_ACCOUNT="$2"; shift 2 ;;
        --project)  APPVEYOR_PROJECT="$2"; shift 2 ;;
        *) echo "Usage: $0 [--token TOKEN] [--account ACCOUNT] [--project PROJECT]"; exit 2 ;;
    esac
done

# Check upstream first
NEW_VER="$(cd "$(dirname "$0")/.." && tools/check-upstream.sh || true)"
if [[ -z "$NEW_VER" ]]; then
    echo "trigger-build: no new upstream version — nothing to trigger"
    exit 0
fi

echo "trigger-build: new version $NEW_VER detected — triggering AppVeyor build"

if [[ -z "$APPVEYOR_TOKEN" ]]; then
    echo "trigger-build: APPVEYOR_TOKEN not set — skipping API call" >&2
    echo "Set APPVEYOR_TOKEN or pass --token <token>" >&2
    exit 1
fi

# Trigger build via AppVeyor API
API_URL="https://ci.appveyor.com/api/builds"
RESPONSE="$(curl -sS -X POST "$API_URL" \
    -H "Authorization: Bearer ${APPVEYOR_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"accountName\": \"${APPVEYOR_ACCOUNT}\", \"projectSlug\": \"${APPVEYOR_PROJECT}\", \"branch\": \"main\", \"environmentVariables\": {\"TRIGGER\": \"check\"}}" 2>&1)"

echo "trigger-build: build triggered: $(echo "$RESPONSE" | jq -r '.version // .message // "unknown"')"
