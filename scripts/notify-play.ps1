# notify-play.ps1 — Plays notification audio with 5-second cooldown per type.
# Usage: powershell -File notify-play.ps1 <type> <audio_file>
# Always exits 0 (critical: Stop/SubagentStop hooks block on non-zero exit).
#
# Mirrors scripts/notify-play.sh behavior for Windows.
# Uses System.Windows.Media.MediaPlayer (.NET) for headless MP3 playback.
# Lock file in $env:TEMP for cooldown debounce.

param(
    [Parameter(Mandatory=$true)][string]$Type,
    [Parameter(Mandatory=$true)][string]$AudioFile
)

$ErrorActionPreference = "Stop"
$CooldownSec = 5

# Fallback temp path if $env:TEMP is empty
$TempDir = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
$LockFile = Join-Path $TempDir "claude-notify-$Type.lock"

try {
    # Cooldown check: if lock file exists and is younger than CooldownSec, skip
    if (Test-Path $LockFile) {
        $lockAge = ((Get-Date) - (Get-Item $LockFile).LastWriteTime).TotalSeconds
        if ($lockAge -lt $CooldownSec) {
            exit 0  # Within cooldown window, skip playback
        }
    }

    # Update lock timestamp
    Set-Content -Path $LockFile -Value (Get-Date).ToString() -NoNewline

    # Play audio via MediaPlayer (PresentationCore assembly only -- no WPF deps)
    Add-Type -AssemblyName PresentationCore
    $player = New-Object System.Windows.Media.MediaPlayer
    $player.Open([System.Uri]::new($AudioFile))
    Start-Sleep -Milliseconds 500  # Wait for media to load

    $player.Play()

    # Wait for playback to finish (per Pitfall 3: script must not exit before playback completes)
    # Check NaturalDuration.HasTimeSpan first (may not be available immediately after Open)
    while ($player.NaturalDuration.HasTimeSpan -and $player.Position -lt $player.NaturalDuration.TimeSpan) {
        Start-Sleep -Milliseconds 100
    }

    $player.Close()
} catch {
    # Silently ignore all errors -- hook must never block Claude
}
exit 0
