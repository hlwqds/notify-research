#!/usr/bin/env bats
# tests/bash/notify-play.bats -- Tests for notify-play.sh
# Covers: BASH-01 (cooldown skip), BASH-02 (cooldown pass),
#         BASH-03 (platform branch), BASH-04 (always exit 0)

setup() {
    load test_helper

    # Create isolated lock directory (per D-01)
    LOCK_DIR="$(mktemp -d)"
    export NOTIFY_LOCK_DIR="$LOCK_DIR"
    CALLED_LOG="$(mktemp)"

    # Install paplay and afplay stubs via PATH-prepend (no root needed)
    STUB_DIR="$(mktemp -d)"

    cat > "$STUB_DIR/paplay" << STUB
#!/usr/bin/env bash
echo "paplay \$*" >> "$CALLED_LOG"
exit 0
STUB
    chmod +x "$STUB_DIR/paplay"

    cat > "$STUB_DIR/afplay" << STUB
#!/usr/bin/env bash
echo "afplay \$*" >> "$CALLED_LOG"
exit 0
STUB
    chmod +x "$STUB_DIR/afplay"

    export PATH="$STUB_DIR:$PATH"
}

teardown() {
    rm -rf "$STUB_DIR"
    rm -rf "$LOCK_DIR"
    rm -f "$CALLED_LOG"
}

# BASH-01: Cooldown skip when lock file exists and is younger than 5 seconds
@test "cooldown skip when lock file is younger than 5 seconds" {
    # Create lock file with current timestamp (within cooldown window)
    touch "$LOCK_DIR/claude-notify-complete.lock"

    run "$REPO_ROOT/scripts/notify-play.sh" complete "$REPO_ROOT/audio/notify-complete.mp3"
    [ "$status" -eq 0 ]
    # Player should NOT have been called
    ! grep -q "paplay" "$CALLED_LOG"
}

# BASH-02: Cooldown passes when lock file is older than 5 seconds
@test "cooldown pass when lock file is older than 5 seconds" {
    # GNU date (-d @epoch) is not available on macOS BSD date
    if [[ "$(uname -s)" == "Darwin" ]]; then
        skip "GNU date not available on macOS"
    fi
    # Create lock file and set its mtime to 10 seconds ago
    # BusyBox-safe: use date -d @epoch to compute timestamp, then touch -t
    touch "$LOCK_DIR/claude-notify-complete.lock"
    local old_epoch=$(( $(date +%s) - 10 ))
    local old_time
    old_time=$(date -d "@${old_epoch}" +%Y%m%d%H%M.%S)
    touch -t "$old_time" "$LOCK_DIR/claude-notify-complete.lock"

    run "$REPO_ROOT/scripts/notify-play.sh" complete "$REPO_ROOT/audio/notify-complete.mp3"
    [ "$status" -eq 0 ]
    # Player SHOULD have been called
    grep -q "paplay" "$CALLED_LOG"
}

# BASH-03: Platform branch -- Linux uses paplay, not afplay
@test "platform branch uses paplay on Linux" {
    # On Linux (uname -s == Linux), notify-play.sh should call paplay
    # No lock file exists, so cooldown check passes immediately
    run "$REPO_ROOT/scripts/notify-play.sh" complete "$REPO_ROOT/audio/notify-complete.mp3"
    [ "$status" -eq 0 ]
    # paplay should be called
    grep -q "paplay" "$CALLED_LOG"
    # afplay should NOT be called
    ! grep -q "afplay" "$CALLED_LOG"
}

# BASH-04: Always exits 0 even when player fails
@test "always exits 0 even when player command fails" {
    # Replace paplay stub with one that exits 1
    cat > "$STUB_DIR/paplay" << 'FAILSTUB'
#!/usr/bin/env bash
exit 1
FAILSTUB
    chmod +x "$STUB_DIR/paplay"

    # No lock file, so cooldown passes and player is invoked
    run "$REPO_ROOT/scripts/notify-play.sh" complete "$REPO_ROOT/audio/notify-complete.mp3"
    [ "$status" -eq 0 ]
}
