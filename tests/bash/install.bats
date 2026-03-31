#!/usr/bin/env bats
# tests/bash/install.bats — Tests for install.sh
# Covers: BASH-05 (hook injection), BASH-06 (idempotent), BASH-07 (prerequisite checks)

setup() {
    load test_helper

    # Create isolated HOME directory (per D-01)
    export HOME="$(mktemp -d)"
    CLAUDE_DIR="$HOME/.claude"
    mkdir -p "$CLAUDE_DIR"

    # Copy fixture settings.json (has PreToolUse hook, per D-07)
    cp "$REPO_ROOT/tests/fixtures/settings.json" "$CLAUDE_DIR/settings.json"

    # Copy real MP3 files (per D-06: install.sh checks they exist)
    for type in complete confirm error progress; do
        cp "$REPO_ROOT/audio/notify-${type}.mp3" "$CLAUDE_DIR/notify-${type}.mp3"
    done

    # Install paplay stub via PATH-prepend (no root needed)
    STUB_DIR="$(mktemp -d)"
    cat > "$STUB_DIR/paplay" << 'STUB'
#!/usr/bin/env bash
exit 0
STUB
    chmod +x "$STUB_DIR/paplay"
    export PATH="$STUB_DIR:$PATH"

    # Add stubs to PATH for claude command mock
    export PATH="$REPO_ROOT/tests/stubs:$PATH"
}

teardown() {
    rm -rf "$STUB_DIR"
    rm -rf "$HOME"
}

# BASH-05: install.sh injects 4 hook events into settings.json
@test "install injects 4 hook events into settings.json" {
    local settings="$HOME/.claude/settings.json"

    run "$REPO_ROOT/scripts/install.sh"
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
    run "$REPO_ROOT/scripts/install.sh"
    [ "$status" -eq 0 ]

    # Capture settings after first install
    local first_run
    first_run=$(jq -S . "$settings")

    # Second run
    run "$REPO_ROOT/scripts/install.sh"
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
    run "$REPO_ROOT/scripts/install.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]

    # Restore settings.json for next checks
    cp "$REPO_ROOT/tests/fixtures/settings.json" "$settings"

    # Test: missing paplay (remove stub AND use empty PATH except for jq)
    rm -f "$STUB_DIR/paplay"
    PATH_BACKUP="$PATH"
    # Create a dir with only jq stub so the PATH is fully controlled
    EMPTY_DIR="$(mktemp -d)"
    cat > "$EMPTY_DIR/jq" << 'STUB'
#!/usr/bin/env bash
cat
STUB
    chmod +x "$EMPTY_DIR/jq"
    export PATH="$EMPTY_DIR"
    run "$REPO_ROOT/scripts/install.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"paplay not found"* ]]
    export PATH="$PATH_BACKUP"
    rm -rf "$EMPTY_DIR"

    # Reinstall paplay stub for subsequent tests
    cat > "$STUB_DIR/paplay" << 'STUB'
#!/usr/bin/env bash
exit 0
STUB
    chmod +x "$STUB_DIR/paplay"

    # Test: missing MP3 file (remove one of the 4 required files)
    rm "$HOME/.claude/notify-complete.mp3"
    run "$REPO_ROOT/scripts/install.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}
