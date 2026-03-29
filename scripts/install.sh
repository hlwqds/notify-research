#!/usr/bin/env bash
# install.sh — Install Claude Code notification hooks.
# Copies audio files and injects hook configuration into ~/.claude/settings.json.
# Idempotent: safe to run multiple times (per D-07).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
NOTIFY_PLAY="$REPO_ROOT/scripts/notify-play.sh"

# --- Prerequisite checks ---
for cmd in jq paplay; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $cmd not found. Please install $cmd first." >&2
        exit 1
    fi
done

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
trap "rm -f $TMPFILE" EXIT

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
