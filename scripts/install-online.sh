#!/usr/bin/env bash
# install-online.sh — Install Claude Code notification hooks via curl|bash.
# Downloads the latest GitHub Release, extracts, and delegates to install.sh.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/hlwqds/notify-research/main/scripts/install-online.sh | bash
#   curl -fsSL ... | bash -- --voice deep
#
# All arguments are passed through to install.sh (per D-12).
set -euo pipefail

GITHUB_REPO="hlwqds/notify-research"

# --- Prerequisite: jq and curl ---
if ! command -v jq &>/dev/null; then
    echo "ERROR: jq not found. Please install jq first." >&2
    exit 1
fi

if ! command -v curl &>/dev/null; then
    echo "ERROR: curl not found. Please install curl first." >&2
    exit 1
fi

if ! command -v tar &>/dev/null; then
    echo "ERROR: tar not found. Please install tar first." >&2
    exit 1
fi

echo "Fetching latest release for $GITHUB_REPO ..."

# --- Get latest release tag (per D-08: always latest) ---
API_RESPONSE=$(curl -fsSL -w "\n%{http_code}" "https://api.github.com/repos/$GITHUB_REPO/releases/latest" 2>/dev/null) || {
    echo "ERROR: Failed to connect to GitHub API. Check your network connection." >&2
    echo "  Alternative: git clone https://github.com/$GITHUB_REPO.git && cd notify-research && bash scripts/install.sh" >&2
    exit 1
}

HTTP_CODE=$(echo "$API_RESPONSE" | tail -1)
API_BODY=$(echo "$API_RESPONSE" | head -n -1)

# Handle API errors (per Pitfall 2, 3)
if [ "$HTTP_CODE" = "404" ]; then
    echo "ERROR: No GitHub releases found for $GITHUB_REPO." >&2
    echo "  The project may not have published any releases yet." >&2
    echo "  Alternative: git clone https://github.com/$GITHUB_REPO.git && cd notify-research && bash scripts/install.sh" >&2
    exit 1
fi

if [ "$HTTP_CODE" = "403" ]; then
    echo "ERROR: GitHub API rate limit exceeded (60 requests/hour for unauthenticated)." >&2
    echo "  Wait a few minutes or set GITHUB_TOKEN env var for higher limits." >&2
    echo "  Alternative: git clone https://github.com/$GITHUB_REPO.git && cd notify-research && bash scripts/install.sh" >&2
    exit 1
fi

if [ "$HTTP_CODE" != "200" ]; then
    echo "ERROR: GitHub API returned HTTP $HTTP_CODE." >&2
    exit 1
fi

LATEST_TAG=$(echo "$API_BODY" | jq -r '.tag_name')

if [ -z "$LATEST_TAG" ] || [ "$LATEST_TAG" = "null" ]; then
    echo "ERROR: Failed to parse release tag from GitHub API." >&2
    exit 1
fi

echo "Latest release: $LATEST_TAG"

# --- Download and extract source archive (per Pitfall 1) ---
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

ARCHIVE_URL="https://github.com/$GITHUB_REPO/archive/refs/tags/$LATEST_TAG.tar.gz"
echo "Downloading $ARCHIVE_URL ..."

curl -fsSL "$ARCHIVE_URL" | tar xz -C "$TMPDIR" || {
    echo "ERROR: Failed to download or extract archive." >&2
    exit 1
}

# Find extracted directory (per Pitfall 1: GitHub strips leading 'v' differently)
# Look for any directory containing the repo name
EXTRACTED_DIR=""
for dir in "$TMPDIR"/*/; do
    if [[ "$(basename "$dir")" == notify-research-* ]]; then
        EXTRACTED_DIR="$dir"
        break
    fi
done

if [ -z "$EXTRACTED_DIR" ] || [ ! -d "$EXTRACTED_DIR" ]; then
    echo "ERROR: Extraction failed — could not find extracted directory." >&2
    exit 1
fi

# Remove trailing slash
EXTRACTED_DIR="${EXTRACTED_DIR%/}"

echo "Running install.sh from $EXTRACTED_DIR ..."
echo ""

# Delegate to install.sh, passing through all arguments (per D-12)
# "$@" captures args passed after "bash" in the pipe: curl ... | bash -- --voice deep
bash "$EXTRACTED_DIR/scripts/install.sh" "$@"
