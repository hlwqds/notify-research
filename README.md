# Claude Code Voice Notifications

Cross-platform voice notifications for Claude Code. Get audio alerts when tasks complete, need input, or fail -- so you don't have to keep checking the terminal.

![CI](https://github.com/hlwqds/notify-research/actions/workflows/ci.yml/badge.svg)

## Install

### Linux / macOS

```bash
git clone https://github.com/hlwqds/notify-research.git
cd notify-research
bash scripts/install.sh
```

### Windows

```powershell
git clone https://github.com/hlwqds/notify-research.git
cd notify-research
powershell -File scripts/install.ps1 -RepoPath (Get-Location)
```

Requires: Claude Code >= 2.1.78, jq + paplay (Linux), afplay (macOS). No extra deps on Windows.

## Hook Configuration

The install script configures 4 Claude Code hook events automatically:

| Event          | Sound                | Trigger              |
|----------------|----------------------|----------------------|
| `Stop`         | notify-complete.mp3  | Task finished        |
| `Notification` | notify-confirm.mp3   | Needs user input     |
| `StopFailure`  | notify-error.mp3     | Task failed          |
| `SubagentStop` | notify-progress.mp3  | Sub-agent finished   |

Example `settings.json` snippet for one event:

```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "/path/to/scripts/notify-play.sh complete ~/.claude/notify-complete.mp3",
        "async": true,
        "timeout": 10
      }]
    }]
  }
}
```

The install script configures all 4 events automatically. This example shows the structure for reference.

## Uninstall

```bash
# Linux/macOS
bash scripts/uninstall.sh

# Windows
powershell -File scripts/uninstall.ps1
```

## Links

- [Spark-TTS](https://github.com/SparkAudio/Spark-TTS) -- TTS engine
- License: Apache 2.0
