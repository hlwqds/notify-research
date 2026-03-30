#!/usr/bin/env bats
# tests/bash/install.bats — Tests for install.sh
# Covers: BASH-05 (hook injection), BASH-06 (idempotent), BASH-07 (prerequisite checks)

ORIGINAL_PAPLAY=""

setup() {
    # Create isolated HOME directory (per D-01)
    export HOME="$(mktemp -d)"
    CLAUDE_DIR="$HOME/.claude"
    mkdir -p "$CLAUDE_DIR"

    # Copy fixture settings.json (has PreToolUse hook, per D-07)
    cp /app/tests/fixtures/settings.json "$CLAUDE_DIR/settings.json"

    # Copy real MP3 files (per D-06: install.sh checks they exist)
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

# BASH-05: install.sh injects 4 hook events into settings.json
@test "install injects 4 hook events into settings.json" {
    local settings="$HOME/.claude/settings.json"

    run /app/scripts/install.sh
    [ "$status" -eq 0 ]

    # Verify all 4 notification hooks exist
    jq -e '.hooks.Stop' "$settings" >/dev/null
    jq -e '.hooks.Notification' "$settings" >/dev/null
    jq -e '.hooks.StopFailure' "$settings" >/dev/null
    jq -e '.hooks.SubagentStop' "$settings" >/dev/null

    # Verify PreToolUse hook is preserved (per D-07)
    jq -e '.hooks.PreToolUse' "$settings" >/dev/null

    # Verify permissions are preserved
    jq -e '.permissions.allow' "$settings" >/dev/null

    # Verify hook commands contain notify-play.sh and correct mp3 files
    local stop_cmd
    stop_cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$settings")
    [[ "$stop_cmd" == *"notify-play.sh"*"complete"* ]]

    local notif_cmd
    notif_cmd=$(jq -r '.hooks.Notification[0].hooks[0].command' "$settings")
    [[ "$notif_cmd" == *"notify-play.sh"*"confirm"* ]]

    local stopfail_cmd
    stopfail_cmd=$(jq -r '.hooks.StopFailure[0].hooks[0].command' "$settings")
    [[ "$stopfail_cmd" == *"notify-play.sh"*"error"* ]]

    local substop_cmd
    substop_cmd=$(jq -r '.hooks.SubagentStop[0].hooks[0].command' "$settings")
    [[ "$substop_cmd" == *"notify-play.sh"*"progress"* ]]
}

# BASH-06: install.sh is idempotent (no duplicate hooks on re-run)
@test "install is idempotent — running twice produces same settings" {
    local settings="$HOME/.claude/settings.json"

    # First run
    run /app/scripts/install.sh
    [ "$status" -eq 0 ]

    # Capture settings after first install
    local first_run
    first_run=$(jq -S . "$settings")

    # Second run
    run /app/scripts/install.sh
    [ "$status" -eq 0 ]

    # Capture settings after second install
    local second_run
    second_run=$(jq -S . "$settings")

    # Sorted JSON should be identical (no duplicates, no changes)
    [ "$first_run" = "$second_run" ]
}

# BASH-07: install.sh exits 1 when prerequisites are missing
@test "install fails when prerequisites are missing" {
    local settings="$HOME/.claude/settings.json"

    # Test: missing settings.json
    rm "$settings"
    run /app/scripts/install.sh
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]

    # Restore settings.json for next checks
    cp /app/tests/fixtures/settings.json "$settings"

    # Test: missing paplay (remove stub AND ensure no real paplay elsewhere)
    rm -f /usr/bin/paplay
    PATH_BACKUP="$PATH"
    export PATH="/app/tests/stubs:/usr/local/bin:/usr/bin:/bin"  # minimal PATH: has bash but no paplay
    run /app/scripts/install.sh
    [ "$status" -ne 0 ]
    [[ "$output" == *"paplay not found"* ]]
    export PATH="$PATH_BACKUP"

    # Reinstall paplay stub for subsequent tests
    cat > /usr/bin/paplay << 'STUB'
#!/usr/bin/env bash
exit 0
STUB
    chmod +x /usr/bin/paplay

    # Test: missing MP3 file (remove one of the 4 required files)
    rm "$HOME/.claude/notify-complete.mp3"
    run /app/scripts/install.sh
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}
