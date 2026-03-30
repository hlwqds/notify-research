#!/usr/bin/env bats
# tests/bash/notify-play.bats -- Tests for notify-play.sh
# Covers: BASH-01 (cooldown skip), BASH-02 (cooldown pass),
#         BASH-03 (platform branch), BASH-04 (always exit 0)

# Save originals so we can restore them
ORIGINAL_PAPLAY=""
ORIGINAL_AFPLAY=""

setup() {
    # Create isolated lock directory (per D-01)
    LOCK_DIR="$(mktemp -d)"
    export NOTIFY_LOCK_DIR="$LOCK_DIR"
    export CALLED_LOG="$(mktemp)"

    # Stub /usr/bin/paplay and /usr/bin/afplay with logging stubs
    # Container runs as root, /usr/bin is writable
    ORIGINAL_PAPLAY=""
    if [ -f /usr/bin/paplay ]; then
        ORIGINAL_PAPLAY=$(cat /usr/bin/paplay)
    fi
    ORIGINAL_AFPLAY=""
    if [ -f /usr/bin/afplay ]; then
        ORIGINAL_AFPLAY=$(cat /usr/bin/afplay)
    fi

    # Install paplay stub (logs calls, exits 0)
    cat > /usr/bin/paplay << 'STUB'
#!/usr/bin/env bash
echo "paplay $*" >> "${CALLED_LOG:-/dev/null}"
exit 0
STUB
    chmod +x /usr/bin/paplay

    # Install afplay stub (logs calls, exits 0)
    cat > /usr/bin/afplay << 'STUB'
#!/usr/bin/env bash
echo "afplay $*" >> "${CALLED_LOG:-/dev/null}"
exit 0
STUB
    chmod +x /usr/bin/afplay
}

teardown() {
    # Restore original player commands
    if [ -n "$ORIGINAL_PAPLAY" ]; then
        printf '%s' "$ORIGINAL_PAPLAY" > /usr/bin/paplay
    else
        rm -f /usr/bin/paplay
    fi
    if [ -n "$ORIGINAL_AFPLAY" ]; then
        printf '%s' "$ORIGINAL_AFPLAY" > /usr/bin/afplay
    else
        rm -f /usr/bin/afplay
    fi

    rm -rf "$LOCK_DIR"
    rm -f "$CALLED_LOG"
}

# BASH-01: Cooldown skip when lock file exists and is younger than 5 seconds
@test "cooldown skip when lock file is younger than 5 seconds" {
    # Create lock file with current timestamp (within cooldown window)
    touch "$LOCK_DIR/claude-notify-complete.lock"

    run /app/scripts/notify-play.sh complete /app/audio/notify-complete.mp3
    [ "$status" -eq 0 ]
    # Player should NOT have been called
    ! grep -q "paplay" "$CALLED_LOG"
}

# BASH-02: Cooldown passes when lock file is older than 5 seconds
@test "cooldown pass when lock file is older than 5 seconds" {
    # Create lock file and set its mtime to 10 seconds ago
    # BusyBox-safe: use date -d @epoch to compute timestamp, then touch -t
    touch "$LOCK_DIR/claude-notify-complete.lock"
    local old_epoch=$(( $(date +%s) - 10 ))
    local old_time
    old_time=$(date -d "@${old_epoch}" +%Y%m%d%H%M.%S)
    touch -t "$old_time" "$LOCK_DIR/claude-notify-complete.lock"

    run /app/scripts/notify-play.sh complete /app/audio/notify-complete.mp3
    [ "$status" -eq 0 ]
    # Player SHOULD have been called
    grep -q "paplay" "$CALLED_LOG"
}

# BASH-03: Platform branch -- Linux uses paplay, not afplay
@test "platform branch uses paplay on Linux" {
    # On Linux (uname -s == Linux), notify-play.sh should call /usr/bin/paplay
    # No lock file exists, so cooldown check passes immediately
    run /app/scripts/notify-play.sh complete /app/audio/notify-complete.mp3
    [ "$status" -eq 0 ]
    # paplay should be called
    grep -q "paplay" "$CALLED_LOG"
    # afplay should NOT be called
    ! grep -q "afplay" "$CALLED_LOG"
}

# BASH-04: Always exits 0 even when player fails
@test "always exits 0 even when player command fails" {
    # Replace paplay stub with one that exits 1
    cat > /usr/bin/paplay << 'FAILSTUB'
#!/usr/bin/env bash
exit 1
FAILSTUB
    chmod +x /usr/bin/paplay

    # No lock file, so cooldown passes and player is invoked
    run /app/scripts/notify-play.sh complete /app/audio/notify-complete.mp3
    [ "$status" -eq 0 ]
}
