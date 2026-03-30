#!/usr/bin/env bash
# notify-play.sh — Plays notification audio with 5-second cooldown per type.
# Usage: notify-play.sh <type> <audio_file>
# Always exits 0 (critical: Stop/SubagentStop hooks block on non-zero exit).
#
# Per D-05: same audio does not repeat within 5 seconds.
# Per D-06: cooldown via /tmp/claude-notify-{type}.lock timestamp file.
# macOS: uses afplay (built-in) with stat -f %m (BSD). Linux: uses paplay with stat -c %Y (GNU).

set -euo pipefail

TYPE="$1"
AUDIO_FILE="$2"
LOCK_DIR="${NOTIFY_LOCK_DIR:-/tmp}"
LOCK_FILE="$LOCK_DIR/claude-notify-${TYPE}.lock"
COOLDOWN_SEC=5
OS="$(uname -s)"

# Check cooldown: if lock file exists and is younger than COOLDOWN_SEC, skip
if [ -f "$LOCK_FILE" ]; then
    if [[ "$OS" == "Darwin" ]]; then
        LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE") ))
    else
        LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE") ))
    fi
    if [ "$LOCK_AGE" -lt "$COOLDOWN_SEC" ]; then
        exit 0  # Within cooldown window, skip playback
    fi
fi

# Update lock timestamp and play audio
touch "$LOCK_FILE"
if [[ "$OS" == "Darwin" ]]; then
    afplay "$AUDIO_FILE" 2>/dev/null || true
else
    paplay "$AUDIO_FILE" 2>/dev/null || true
fi
exit 0
