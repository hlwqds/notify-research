#!/usr/bin/env bash
# install.sh — Install Claude Code notification hooks.
# Copies audio files and injects hook configuration into ~/.claude/settings.json.
# Requires: Claude Code >= 2.1.78 (StopFailure hook event), jq, paplay (Linux) or afplay (macOS).
# Idempotent: safe to run multiple times (per D-07).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
NOTIFY_PLAY="$REPO_ROOT/scripts/notify-play.sh"

# --- Prerequisite checks ---
# Portable version comparison (pure bash, works on macOS bash 3.2+)
version_gte() {
    [ "$1" = "$2" ] && return 0
    local IFS=.
    local i
    # shellcheck disable=SC2206 # Intentional version string splitting for numeric comparison
    local a=($1) b=($2)
    for ((i=0; i<${#b[@]}; i++)); do
        ((10#${a[i]:-0} < 10#${b[i]})) && return 1
        ((10#${a[i]:-0} > 10#${b[i]})) && return 0
    done
    return 0
}
# Check Claude Code version (>= 2.1.78 for StopFailure hook event)
if command -v claude &>/dev/null; then
    CLAUDE_VERSION=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [ -n "$CLAUDE_VERSION" ]; then
        MIN_VERSION="2.1.78"
        if ! version_gte "$CLAUDE_VERSION" "$MIN_VERSION"; then
            echo "WARNING: Claude Code $CLAUDE_VERSION detected, requires >= $MIN_VERSION (StopFailure hook event)." >&2
            echo "  StopFailure notification will not work. Other hooks (Stop, Notification, SubagentStop) are unaffected." >&2
        fi
    fi
else
    echo "WARNING: 'claude' command not found. Cannot verify Claude Code version." >&2
    echo "  Requires Claude Code >= 2.1.78 for full hook support (StopFailure event)." >&2
fi

# jq is required on all platforms (per D-02)
if ! command -v jq &>/dev/null; then
    echo "ERROR: jq not found. Please install jq first." >&2
    exit 1
fi

# Platform-specific audio player check (per D-01)
OS="$(uname -s)"
if [[ "$OS" == "Darwin" ]]; then
    # afplay is built into macOS -- verify it exists
    if ! command -v afplay &>/dev/null; then
        echo "ERROR: afplay not found (unexpected on macOS)." >&2
        exit 1
    fi
else
    if ! command -v paplay &>/dev/null; then
        echo "ERROR: paplay not found. Please install paplay first." >&2
        exit 1
    fi
fi

if [ ! -f "$SETTINGS" ]; then
    echo "ERROR: $SETTINGS not found." >&2
    exit 1
fi

if [ ! -x "$NOTIFY_PLAY" ]; then
    echo "ERROR: $NOTIFY_PLAY not found or not executable." >&2
    exit 1
fi

# --- Copy audio files (per D-01, D-02) ---
echo "Copying audio files to $CLAUDE_DIR/ ..."
for type in complete confirm error progress; do
    src="$REPO_ROOT/audio/notify-${type}.mp3"
    if [ ! -f "$src" ]; then
        echo "ERROR: $src not found. Run generate.sh first." >&2
        exit 1
    fi
    cp "$src" "$CLAUDE_DIR/notify-${type}.mp3"
done

# --- Inject hooks via jq (per D-07, D-09) ---
# Per D-03 event mapping:
#   Stop -> notify-complete.mp3
#   Notification -> notify-confirm.mp3
#   StopFailure -> notify-error.mp3
#   SubagentStop -> notify-progress.mp3
# Per RESEARCH: use async:true instead of shell & (native Claude Code mechanism)
# Per D-10: absolute paths in hook commands

echo "Configuring hooks in $SETTINGS ..."

TMPFILE=$(mktemp)
cleanup() { rm -f "$TMPFILE"; }
trap cleanup EXIT

jq \
  --arg complete_cmd "$NOTIFY_PLAY complete $CLAUDE_DIR/notify-complete.mp3" \
  --arg confirm_cmd "$NOTIFY_PLAY confirm $CLAUDE_DIR/notify-confirm.mp3" \
  --arg error_cmd "$NOTIFY_PLAY error $CLAUDE_DIR/notify-error.mp3" \
  --arg progress_cmd "$NOTIFY_PLAY progress $CLAUDE_DIR/notify-progress.mp3" \
  '
    .hooks.Stop = [{"hooks": [{"type": "command", "command": $complete_cmd, "async": true, "timeout": 10}]}] |
    .hooks.Notification = [{"hooks": [{"type": "command", "command": $confirm_cmd, "async": true, "timeout": 10}]}] |
    .hooks.StopFailure = [{"hooks": [{"type": "command", "command": $error_cmd, "async": true, "timeout": 10}]}] |
    .hooks.SubagentStop = [{"hooks": [{"type": "command", "command": $progress_cmd, "async": true, "timeout": 10}]}]
  ' "$SETTINGS" > "$TMPFILE"

# Verify jq succeeded (per RESEARCH Pitfall 2: don't clobber on error)
if [ ! -s "$TMPFILE" ]; then
    echo "ERROR: jq produced empty output, settings.json not modified." >&2
    exit 1
fi

mv "$TMPFILE" "$SETTINGS"

echo "Done! Notification hooks installed."
echo "  Stop          -> notify-complete.mp3"
echo "  Notification  -> notify-confirm.mp3"
echo "  StopFailure   -> notify-error.mp3"
echo "  SubagentStop  -> notify-progress.mp3"
echo ""
echo "Run 'bash $SCRIPT_DIR/uninstall.sh' to remove."
