#!/usr/bin/env bash
# uninstall.sh — Remove Claude Code notification hooks.
# Removes the 4 notify hook events from settings.json and deletes audio files.
# Per D-08: clean removal of hooks and audio.
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

if [ ! -f "$SETTINGS" ]; then
    echo "ERROR: $SETTINGS not found." >&2
    exit 1
fi

# Remove hook entries via jq (per D-08, D-09)
TMPFILE=$(mktemp)
cleanup() { rm -f "$TMPFILE"; }
trap cleanup EXIT

jq 'del(.hooks.Stop, .hooks.Notification, .hooks.StopFailure, .hooks.SubagentStop)' "$SETTINGS" > "$TMPFILE"

if [ ! -s "$TMPFILE" ]; then
    echo "ERROR: jq produced empty output, settings.json not modified." >&2
    exit 1
fi

mv "$TMPFILE" "$SETTINGS"
echo "Hooks removed from settings.json."

# Remove audio files (per D-08)
for type in complete confirm error progress; do
    rm -f "$CLAUDE_DIR/notify-${type}.mp3"
done
echo "Audio files removed from $CLAUDE_DIR/."

echo "Done! Notification hooks uninstalled."
