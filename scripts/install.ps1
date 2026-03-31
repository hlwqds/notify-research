# install.ps1 — Install Claude Code notification hooks on Windows.
# Copies audio files and injects hook configuration into settings.json.
# Requires: Claude Code >= 2.1.78 (StopFailure hook event), PowerShell 5.1+.
# Idempotent: safe to run multiple times.
#
# Usage: powershell -File install.ps1 -RepoPath <path-to-repo-root>
#   -RepoPath: Path to the cloned repository root (contains audio/ and scripts/ directories).

param(
    [Parameter(Mandatory=$true)][string]$RepoPath
)

$ErrorActionPreference = "Stop"

# --- Path setup (per D-06, D-07) ---
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$SettingsPath = Join-Path $ClaudeDir "settings.json"
# Default voice pack (Phase 14 adds interactive selection)
$VoiceName = "gentle"
$AudioSource = Join-Path $RepoPath "audio\voices\$VoiceName"
$NotifyPlayScript = Join-Path $RepoPath "scripts\notify-play.ps1"

# --- Prerequisite checks ---
# Check Claude Code version (>= 2.1.78 for StopFailure hook event)
$claudeCmd = Get-Command "claude" -ErrorAction SilentlyContinue
if ($claudeCmd) {
    try {
        $claudeVersion = & claude --version 2>$null | Select-String -Pattern '\d+\.\d+\.\d+' | Select-Object -First 1
        if ($claudeVersion) {
            $version = [version]::new(($claudeVersion.ToString() -split '\s+')[0])
            $minVersion = [version]::new("2.1.78")
            if ($version -lt $minVersion) {
                Write-Warning "Claude Code $version detected, requires >= $minVersion (StopFailure hook event)."
                Write-Warning "  StopFailure notification will not work. Other hooks (Stop, Notification, SubagentStop) are unaffected."
            }
        }
    } catch {
        Write-Warning "Could not determine Claude Code version. Requires >= 2.1.78 for full hook support."
    }
} else {
    Write-Warning "'claude' command not found. Cannot verify Claude Code version."
    Write-Warning "  Requires Claude Code >= 2.1.78 for full hook support (StopFailure event)."
}

# Check settings.json exists
if (-not (Test-Path $SettingsPath)) {
    Write-Error "ERROR: $SettingsPath not found."
    exit 1
}

# Check notify-play.ps1 exists
if (-not (Test-Path $NotifyPlayScript)) {
    Write-Error "ERROR: $NotifyPlayScript not found."
    exit 1
}

# Check audio source directory exists
if (-not (Test-Path $AudioSource -PathType Container)) {
    Write-Error "ERROR: $AudioSource directory not found."
    exit 1
}

# Check all 4 mp3 files exist
$audioFiles = @("notify-complete.mp3", "notify-confirm.mp3", "notify-error.mp3", "notify-progress.mp3")
foreach ($file in $audioFiles) {
    if (-not (Test-Path (Join-Path $AudioSource $file))) {
        Write-Error "ERROR: $(Join-Path $AudioSource $file) not found. Run generate.sh first."
        exit 1
    }
}

# --- Copy audio files (mirrors install.sh lines 73-81) ---
Write-Host "Copying audio files to $ClaudeDir\ ..."

if (-not (Test-Path $ClaudeDir -PathType Container)) {
    New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
}

foreach ($file in $audioFiles) {
    Copy-Item (Join-Path $AudioSource $file) (Join-Path $ClaudeDir $file) -Force
}

# --- Forward-slash path conversion (per D-05, WIN-05) ---
function ConvertTo-ForwardSlash([string]$Path) {
    return $Path -replace '\\', '/'
}

$fwdNotifyPlay = ConvertTo-ForwardSlash $NotifyPlayScript
$fwdClaudeDir = ConvertTo-ForwardSlash $ClaudeDir

# --- Inject hooks into settings.json (mirrors install.sh lines 93-116) ---
# Event mapping (must match install.sh exactly):
#   Stop          -> notify-complete.mp3  (type: complete)
#   Notification  -> notify-confirm.mp3   (type: confirm)
#   StopFailure   -> notify-error.mp3     (type: error)
#   SubagentStop  -> notify-progress.mp3  (type: progress)

Write-Host "Configuring hooks in $SettingsPath ..."

$settings = Get-Content -Path $SettingsPath -Raw | ConvertFrom-Json

# Ensure hooks object exists
if (-not ($settings.PSObject.Properties["hooks"])) {
    $settings | Add-Member -NotePropertyName "hooks" -NotePropertyValue ([PSCustomObject]@{}) -Force
}

# Build hook entries with forward-slash paths and "shell": "powershell" (per WIN-04)
$events = @{
    "Stop"          = @{ "type" = "complete"; "file" = "notify-complete.mp3" }
    "Notification"  = @{ "type" = "confirm";  "file" = "notify-confirm.mp3" }
    "StopFailure"   = @{ "type" = "error";    "file" = "notify-error.mp3" }
    "SubagentStop"  = @{ "type" = "progress"; "file" = "notify-progress.mp3" }
}

foreach ($eventName in $events.Keys) {
    $type = $events[$eventName]["type"]
    $file = $events[$eventName]["file"]
    $audioPath = "$fwdClaudeDir/$file"
    $command = "powershell -File $fwdNotifyPlay $type $audioPath"

    $hookEntry = [PSCustomObject]@{
        type    = "command"
        shell   = "powershell"
        command = $command
        async   = $true
        timeout = 10
    }

    $hookArray = @([PSCustomObject]@{ hooks = @($hookEntry) })
    $settings.hooks | Add-Member -NotePropertyName $eventName -NotePropertyValue $hookArray -Force
}

# Write back BOM-free (per D-04, RESEARCH Pattern 3)
# DO NOT use Set-Content or Out-File (BOM issue per Pitfall 1)
# DO use -Depth 100 (per Pitfall 4)
$jsonOutput = $settings | ConvertTo-Json -Depth 100
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($SettingsPath, $jsonOutput, $utf8NoBom)

Write-Host "Done! Notification hooks installed."
Write-Host "  Stop          -> notify-complete.mp3"
Write-Host "  Notification  -> notify-confirm.mp3"
Write-Host "  StopFailure   -> notify-error.mp3"
Write-Host "  SubagentStop  -> notify-progress.mp3"
Write-Host ""
Write-Host "Run 'powershell -File uninstall.ps1' to remove."
