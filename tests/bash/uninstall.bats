#!/usr/bin/env bats
# tests/bash/uninstall.bats — Tests for uninstall.sh
# Covers: BASH-08 (hook removal), BASH-09 (mp3 deletion), BASH-10 (idempotent)

ORIGINAL_PAPLAY=""

setup() {
    # Create isolated HOME directory (per D-01)
    export HOME="$(mktemp -d)"
    CLAUDE_DIR="$HOME/.claude"
    mkdir -p "$CLAUDE_DIR"

    # Copy fixture settings.json (has PreToolUse hook, per D-07)
    cp /app/tests/fixtures/settings.json "$CLAUDE_DIR/settings.json"

    # Copy real MP3 files (per D-06)
    for type in complete confirm error progress; do
        cp "/app/audio/notify-${type}.mp3" "$CLAUDE_DIR/notify-${type}.mp3"
    done

    # Install paplay stub so install.sh prerequisite check passes
    ORIGINAL_PAPLAY=""
    if [ -f /usr/bin/paplay ]; then
        ORIGINAL_PAPLAY=$(cat /usr/bin/paplay)
    fi
    cat > /usr/bin/paplay << 'STUB'
#!/usr/bin/env bash
exit 0
STUB
    chmod +x /usr/bin/paplay

    # Add stubs to PATH for claude command mock
    export PATH="/app/tests/stubs:$PATH"
}

teardown() {
    # Restore original paplay
    if [ -n "$ORIGINAL_PAPLAY" ]; then
        printf '%s' "$ORIGINAL_PAPLAY" > /usr/bin/paplay
    else
        rm -f /usr/bin/paplay
    fi

    rm -rf "$HOME"
}

# Helper: run install.sh to populate hooks before testing uninstall
do_install() {
    /app/scripts/install.sh
}

# BASH-08: uninstall.sh removes all 4 hook events from settings.json
@test "uninstall removes 4 notification hook events" {
    do_install

    local settings="$HOME/.claude/settings.json"

    # Verify hooks exist after install
    jq -e '.hooks.Stop' "$settings" >/dev/null

    run /app/scripts/uninstall.sh
    [ "$status" -eq 0 ]

    # Verify all 4 notification hooks are removed
    ! jq -e '.hooks.Stop' "$settings" >/dev/null 2>&1
    ! jq -e '.hooks.Notification' "$settings" >/dev/null 2>&1
    ! jq -e '.hooks.StopFailure' "$settings" >/dev/null 2>&1
    ! jq -e '.hooks.SubagentStop' "$settings" >/dev/null 2>&1

    # Verify PreToolUse hook is preserved (per D-07)
    jq -e '.hooks.PreToolUse' "$settings" >/dev/null

    # Verify permissions are preserved
    jq -e '.permissions.allow' "$settings" >/dev/null
}

# BASH-09: uninstall.sh deletes MP3 files from CLAUDE_DIR
@test "uninstall deletes mp3 files" {
    do_install

    local mp3_dir="$HOME/.claude"

    # Verify MP3 files exist after install
    [ -f "$mp3_dir/notify-complete.mp3" ]
    [ -f "$mp3_dir/notify-confirm.mp3" ]
    [ -f "$mp3_dir/notify-error.mp3" ]
    [ -f "$mp3_dir/notify-progress.mp3" ]

    run /app/scripts/uninstall.sh
    [ "$status" -eq 0 ]

    # Verify all 4 MP3 files are deleted
    [ ! -f "$mp3_dir/notify-complete.mp3" ]
    [ ! -f "$mp3_dir/notify-confirm.mp3" ]
    [ ! -f "$mp3_dir/notify-error.mp3" ]
    [ ! -f "$mp3_dir/notify-progress.mp3" ]
}

# BASH-10: uninstall.sh is idempotent (no error on re-run)
@test "uninstall is idempotent — running twice produces no error" {
    do_install

    # First uninstall
    run /app/scripts/uninstall.sh
    [ "$status" -eq 0 ]

    # Second uninstall (no hooks to remove, but should not error)
    run /app/scripts/uninstall.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"Hooks removed"* ]]
}
