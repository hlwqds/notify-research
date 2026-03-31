# Claude Code Voice Notifications

Cross-platform voice notifications for Claude Code. Get audio alerts when tasks complete, need input, or fail -- so you don't have to keep checking the terminal.

![CI](https://github.com/hlwqds/notify-research/actions/workflows/ci.yml/badge.svg)

## Plugin Installation (Recommended)

The easiest way to install. No git clone, no manual setup -- Claude Code handles everything.

```bash
# Step 1: Add this repository as a marketplace
/plugin marketplace add hlwqds/notify-research

# Step 2: Install the notification plugin
/plugin install claude-voice-notify@hlwqds
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
