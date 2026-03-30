# uninstall.ps1 — Remove Claude Code notification hooks on Windows.
# Removes the 4 notification hook entries from settings.json and deletes audio files.
# Mirrors scripts/uninstall.sh behavior for Windows.
# Idempotent: safe to run multiple times.

$ErrorActionPreference = "Stop"

# --- Path setup (per D-07) ---
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$SettingsPath = Join-Path $ClaudeDir "settings.json"

# --- Prerequisite check ---
if (-not (Test-Path $SettingsPath)) {
    Write-Error "ERROR: $SettingsPath not found."
    exit 1
}

# --- Remove hooks from settings.json (mirrors uninstall.sh line 19) ---
$settings = Get-Content -Path $SettingsPath -Raw | ConvertFrom-Json
$modified = $false

if ($settings.PSObject.Properties["hooks"]) {
    # Remove each of the 4 notification event entries
    foreach ($eventName in @("Stop", "Notification", "StopFailure", "SubagentStop")) {
        if ($settings.hooks.PSObject.Properties[$eventName]) {
            $settings.hooks.PSObject.Properties.Remove($eventName)
            $modified = $true
        }
    }

    # If hooks object is now empty, remove it entirely
    # Note: PSMemberInfoIntegratingCollection.Count returns empty (not 0) when collection is empty,
    # so we wrap in @() to get a reliable count
    if (@($settings.hooks.PSObject.Properties).Count -eq 0) {
        $settings.PSObject.Properties.Remove("hooks")
    }

    if ($modified) {
        # Write back BOM-free (per D-04, RESEARCH Pattern 3)
        $jsonOutput = $settings | ConvertTo-Json -Depth 100
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($SettingsPath, $jsonOutput, $utf8NoBom)
        Write-Output "Hooks removed from settings.json."
    } else {
        Write-Output "No notification hooks found in settings.json."
    }
} else {
    Write-Output "No hooks section found in settings.json."
}

# --- Remove audio files (mirrors uninstall.sh lines 29-32) ---
foreach ($type in @("complete", "confirm", "error", "progress")) {
    $audioFile = Join-Path $ClaudeDir "notify-$type.mp3"
    if (Test-Path $audioFile) {
        Remove-Item $audioFile -Force
    }
}
Write-Output "Audio files removed from $ClaudeDir\."

Write-Output ""
Write-Output "Done! Notification hooks uninstalled."
