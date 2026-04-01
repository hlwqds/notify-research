# Claude Code Voice Notifications

[![CI](https://github.com/hlwqds/notify-research/actions/workflows/ci.yml/badge.svg)](https://github.com/hlwqds/notify-research/actions)

Cross-platform voice notifications for Claude Code. Get audio alerts when tasks complete, need input, or fail -- so you don't have to keep checking the terminal.

## Plugin Installation (Recommended)

The easiest way to install. No git clone, no manual setup -- Claude Code handles everything.

```bash
# Step 1: Add this repository as a marketplace
/plugin marketplace add hlwqds/notify-research

# Step 2: Install the notification plugin
/plugin install claude-voice-notify@hlwqds

# Step 3: Reload plugins to apply
/reload-plugins
```

## One-Liner Installation (Alternative)

If you prefer a traditional install or don't have plugin support yet:

**Linux / macOS**

```bash
curl -fsSL https://raw.githubusercontent.com/hlwqds/notify-research/main/scripts/install-online.sh | bash
```

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/hlwqds/notify-research/main/scripts/install-online.ps1 | iex
```

## Voice Configuration

Choose between two voice packs to customize your notification sound.

**Plugin users:**

```
/plugin configure claude-voice-notify
```

**Legacy install users:**

```bash
bash scripts/install.sh --voice deep
```

Available voices: `gentle` (default), `deep`.

## How It Works

The plugin installs 4 Claude Code hook events that play audio notifications automatically:

| Event          | Trigger              | What You Hear         |
|----------------|----------------------|-----------------------|
| `Stop`         | Task finished        | "Complete" sound      |
| `Notification` | Needs user input     | "Please confirm" sound|
| `StopFailure`  | Task failed          | "Error" sound         |
| `SubagentStop` | Sub-agent finished   | "Progress" sound      |

All hooks run asynchronously (`async: true`) so they never block your workflow.

## Requirements

- **Claude Code** >= 2.1.88
- **Linux**: `paplay` (PipeWire/PulseAudio) + `jq`
- **macOS**: `afplay` (built-in)
- **Windows**: No extra dependencies

## Troubleshooting

**No sound after install?**

- Plugin users: make sure you ran `/reload-plugins` after install
- Legacy users: run `bash scripts/install.sh` again to repair

**Audio not playing on Linux?**

- Verify `paplay` is available: `which paplay`
- Check PipeWire/PulseAudio is running: `pactl info`
- Fallback: install `mpv` and the hooks will use it automatically

**Plugin not updating after a new release?**

- Run `/plugin marketplace update` to refresh the marketplace listing
- The auto-update interval is ~10 minutes — if it doesn't pick up the new version, use the command above
- If that still doesn't work, clear the cache and reinstall:
  ```bash
  rm -rf ~/.claude/plugins/cache/hlwqds/claude-voice-notify/
  /plugin install claude-voice-notify@hlwqds
  /reload-plugins
  ```

**Hook not triggering?**

- Check hooks are registered: `/plugin` → Installed tab → claude-voice-notify
- Verify hook events are listed (Stop, Notification, StopFailure, SubagentStop)

**Double notification (sound plays twice)?**

- Plugin and legacy hooks are mutually exclusive — do not use both
- If you previously used `install.sh` / `install.ps1`, run the uninstall script first:
  ```bash
  bash scripts/uninstall.sh       # Linux/macOS
  powershell -File scripts/uninstall.ps1  # Windows
  ```
- Then install via plugin: `/plugin install claude-voice-notify@hlwqds`

## Uninstall

**Plugin:**

```
/plugin uninstall claude-voice-notify
```

**Legacy:**

```bash
# Linux/macOS
bash scripts/uninstall.sh

# Windows
powershell -File scripts/uninstall.ps1
```

## Links

- [Spark-TTS](https://github.com/SparkAudio/Spark-TTS) -- TTS engine

## License

[MIT License](LICENSE)
