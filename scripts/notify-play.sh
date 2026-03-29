#!/usr/bin/env bash
# notify-play.sh — Plays notification audio with 5-second cooldown per type.
# Usage: notify-play.sh <type> <audio_file>
# Always exits 0 (critical: Stop/SubagentStop hooks block on non-zero exit).
#
# Per D-05: same audio does not repeat within 5 seconds.
# Per D-06: cooldown via /tmp/claude-notify-{type}.lock timestamp file.

set -euo pipefail

TYPE="$1"
AUDIO_FILE="$2"
LOCK_FILE="/tmp/claude-notify-${TYPE}.lock"
COOLDOWN_SEC=5

# Check cooldown: if lock file exists and is younger than COOLDOWN_SEC, skip
if [ -f "$LOCK_FILE" ]; then
    LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE") ))
    if [ "$LOCK_AGE" -lt "$COOLDOWN_SEC" ]; then
        exit 0  # Within cooldown window, skip playback
    fi
fi

# Update lock timestamp and play audio
touch "$LOCK_FILE"
/usr/bin/paplay "$AUDIO_FILE" 2>/dev/null || true
exit 0
