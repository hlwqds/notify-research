# Feature Research

**Domain:** CLI TTS Audio Notification System for Claude Code
**Researched:** 2026-03-30
**Confidence:** MEDIUM (verified with official Claude Code hooks docs; TTS tooling from training data + WebSearch)

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Pre-recorded audio files for each notification type** | Core purpose -- no audio = no notifications | LOW | 4 fixed files: task-complete, needs-confirm, error, in-progress. Generated once via Spark-TTS. |
| **Claude Code hooks integration** | Must wire into Claude Code events to trigger playback | LOW | Hook config in `settings.json`. Events: `Stop` (task done), `Notification` (permission_prompt, idle_prompt), `StopFailure` (error). Non-blocking (`&`). |
| **Audio playback** | Must actually produce audible output on the user's machine | LOW | `paplay` on Fedora/PulseAudio. Single player is fine since target platform is Linux only. |
| **Non-blocking playback** | Notifications must not block Claude Code execution | LOW | `paplay ... 2>/dev/null &` -- background + suppress stderr. Confirmed pattern in hooks docs. |
| **One-command audio generation** | Users should not need to understand Spark-TTS, Docker, or TTS parameters | MEDIUM | Single script that handles Docker build, Spark-TTS invocation, ffmpeg conversion, and file placement. |
| **Pre-defined notification messages (Chinese)** | Users expect ready-to-use audio out of the box | LOW | Fixed Chinese phrases: task complete, please confirm, error occurred, in progress. No user customization needed for MVP. |
| **mp3 output format** | `paplay` can play mp3 via GStreamer plugins; most universal compressed audio format | LOW | ffmpeg handles Spark-TTS WAV-to-mp3 conversion. Already in Docker image per PROJECT.md. |

### Differentiators (Competitive Advantage)

Features that set the product apart from basic notification approaches.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Spark-TTS 0.5B neural voice quality** | Significantly better than espeak-ng robotic voice; warm, natural-sounding Chinese female voice | HIGH | Requires Docker container with GPU/CPU inference. ~8 min/sentence on CPU. Apache 2.0 license. |
| **Distinct voice messages per event type** | Users can identify event type by sound alone without looking at screen | LOW | Different Chinese phrases for each of the 4 notification types. Much better than a generic "ding" sound. |
| **Voice style tuning (female, low pitch, slow speed)** | Calm, non-intrusive notification style that does not startle | MEDIUM | `--gender female --pitch low --speed low` parameters in Spark-TTS. Projects a composed, warm tone. |
| **Docker-containerized TTS generation** | Zero host dependencies -- no conda, no Python, no model files on host machine | MEDIUM | Single `docker build` + `docker run` to generate all audio files. Self-contained. |
| **Correct file naming convention** | Files follow predictable `notify-{type}.mp3` pattern matching hook config | LOW | `notify-complete.mp3`, `notify-confirm.mp3`, `notify-error.mp3`, `notify-progress.mp3`. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems for this specific project.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Real-time TTS synthesis** | Generate custom messages dynamically | Spark-TTS CPU inference is ~8 min/sentence. Completely unusable for real-time notifications. Would require GPU + model always loaded. | Pre-recorded fixed phrases (project scope) |
| **Dynamic notification text** | "Say what the task was about" | Requires real-time TTS (see above). Also unpredictable message length and content makes notification spam worse. | Fixed, clear, short Chinese phrases |
| **Multi-language support** | Users might want English or other languages | Scope creep. Chinese is the stated target. Adding languages multiplies audio generation time (4 files per language x N languages). | Chinese only for v1; i18n as v2 if demand exists |
| **GUI notification (desktop popup)** | "Show a desktop notification too" | Out of scope per PROJECT.md. Adds complexity (notify-send, D-Bus, etc.) for marginal value when audio is the whole point. | Audio-only. User can add desktop notifications separately if desired. |
| **Notification queue/scheduler** | Avoid overlapping notifications when multiple events fire | Claude Code events are already serialized (one task at a time). Queue adds complexity for a problem that barely occurs. | Simple non-blocking `&` playback. If overlap happens, PulseAudio handles mixing. |
| **Volume control in notification system** | "I want quieter notifications" | System volume controls work fine. Adding per-notification volume creates configuration surface with no clear benefit. | Users adjust system/PulseAudio volume. |
| **Custom notification text input** | "Let me type what it should say" | Again requires real-time TTS. Pre-recorded phrases are the correct architecture for this tool. | Pre-recorded phrases. If user wants custom, they can run Spark-TTS Docker container themselves. |
| **Notification cooldown/rate limiting** | Prevent rapid-fire notifications | Claude Code events are inherently spaced (tasks take time). Adding cooldown adds state management for minimal benefit. | Trust that Claude Code events are reasonably spaced. |

## Feature Dependencies

```
Spark-TTS Docker Environment
    └──requires──> Docker (installed on host)
    └──produces──> Pre-recorded Audio Files (notify-*.mp3)

Pre-recorded Audio Files
    └──requires──> Spark-TTS Docker Environment
    └──requires──> ffmpeg (WAV to mp3 conversion)
    └──placed in──> ~/.claude/ directory

Claude Code Hooks Configuration
    └──requires──> Pre-recorded Audio Files (must exist before hooks fire)
    └──references──> paplay playback command

Audio Playback
    └──requires──> paplay (PulseAudio on Fedora)
    └──requires──> Pre-recorded Audio Files
    └──triggered by──> Claude Code Hooks Configuration

One-command Generation Script
    └──orchestrates──> Docker Build → Spark-TTS Inference → ffmpeg Convert → File Placement
```

### Dependency Notes

- **Spark-TTS Docker Environment produces Pre-recorded Audio Files:** The entire generation pipeline runs inside Docker. ffmpeg converts Spark-TTS WAV output to mp3. Files land in `~/.claude/`.
- **Pre-recorded Audio Files must exist before Hooks Configuration is active:** If hooks fire and audio files are missing, `paplay` silently fails (stderr suppressed). This is acceptable but suboptimal. The generation script should verify files exist after generation.
- **Claude Code Hooks Configuration references playback command:** The hook in `settings.json` runs `paplay ~/.claude/notify-confirm.mp3 2>/dev/null &`. This is a static shell command -- no dynamic logic needed.
- **One-command Generation Script orchestrates everything:** This is the only entry point users interact with for audio generation. It must handle: Docker image existence check, build if needed, run Spark-TTS for each phrase, convert WAV to mp3, copy to `~/.claude/`.

## MVP Definition

### Launch With (v1)

Minimum viable product -- generate and play voice notifications.

- [ ] **Dockerfile for Spark-TTS 0.5B** -- Contains Python, Spark-TTS, model weights, ffmpeg. Builds once, reused for all audio generation.
- [ ] **Generation script (`generate.sh` or equivalent)** -- Builds Docker image if missing, runs Spark-TTS for 4 phrases with `--gender female --pitch low --speed low`, converts to mp3, places in `~/.claude/`.
- [ ] **4 pre-recorded Chinese notification audio files** -- `notify-complete.mp3`, `notify-confirm.mp3`, `notify-error.mp3`, `notify-progress.mp3` in `~/.claude/`.
- [ ] **Claude Code hooks configuration** -- `settings.json` entries for `Stop`, `Notification` (permission_prompt, idle_prompt), `StopFailure` events running `paplay` commands.
- [ ] **Non-blocking playback** -- Hook commands run with `&` backgrounding.

### Add After Validation (v1.x)

Features to add once core is working and validated.

- [ ] **Playback verification** -- Test that `paplay` can actually produce sound on the system (detect missing PulseAudio/sink before hooks fire).
- [ ] **Audio file integrity check** -- Verify mp3 files are valid and non-empty after generation.
- [ ] **Re-generation command** -- Easy way to re-generate specific audio files without rebuilding Docker image.

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] **Custom phrase support** -- Allow users to define additional notification phrases and regenerate.
- [ ] **Additional notification events** -- E.g., `PermissionRequest` for specific tools, `PostToolUseFailure` for tool-level errors.
- [ ] **Alternative TTS engine** -- Support edge-tts as a faster (but lower quality) alternative to Spark-TTS.
- [ ] **Audio player fallback chain** -- `aplay || paplay || mpv` for broader Linux distribution support beyond Fedora/PulseAudio.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Pre-recorded audio files (4 types) | HIGH | MEDIUM | P1 |
| Claude Code hooks integration | HIGH | LOW | P1 |
| Non-blocking playback | HIGH | LOW | P1 |
| One-command audio generation | HIGH | MEDIUM | P1 |
| Spark-TTS Docker environment | HIGH | HIGH | P1 |
| mp3 output format | MEDIUM | LOW | P1 |
| Voice style tuning (female, low, slow) | MEDIUM | LOW | P1 |
| Distinct messages per event type | HIGH | LOW | P1 |
| Playback verification | LOW | LOW | P2 |
| Audio file integrity check | LOW | LOW | P2 |
| Re-generation command | MEDIUM | LOW | P2 |
| Custom phrase support | LOW | MEDIUM | P3 |
| Additional notification events | LOW | LOW | P3 |
| Alternative TTS engine | LOW | MEDIUM | P3 |
| Audio player fallback chain | LOW | LOW | P3 |

**Priority key:**
- P1: Must have for launch (can hear notifications after one command)
- P2: Should have, improves reliability
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | claude-code-audio-hooks (ChanMeng666) | GitHub Issue #15795 (proposal) | Native terminal bell (`\a`) | Our Approach |
|---------|---------------------------------------|-------------------------------|---------------------------|--------------|
| **Audio type** | Desktop notification + sound file | Configurable sound file | System beep | Pre-recorded Chinese neural voice |
| **Voice synthesis** | None (uses existing sound files) | None (uses existing sound files) | None (system beep) | Spark-TTS 0.5B neural TTS |
| **Language** | N/A (sound files) | N/A (sound files) | N/A (beep) | Chinese (natural speech) |
| **Event granularity** | Basic (permission prompt) | Configurable (onPermissionRequest, onTaskComplete) | None (manual) | 4 event types with distinct phrases |
| **Integration method** | Claude Code hooks | Native settings proposal | Manual script | Claude Code hooks |
| **Customization** | Limited | Config field for sound file | None | Docker-based, voice parameters tunable |
| **Complexity** | Low (just sound files + hook config) | Zero (native feature) | Zero (built-in) | Medium (Docker + TTS + hooks) |

**Key observations:**
- **claude-code-audio-hooks** provides the closest existing solution but lacks voice synthesis entirely. It plays a generic notification sound, not speech. No Chinese language support.
- **GitHub Issue #15795** requests native audio notification support in Claude Code. Not yet implemented. Would only support sound files, not TTS.
- **Terminal bell** is the simplest approach but provides zero information content (just "something happened") and can be silenced by terminal settings.
- **Our differentiator:** Actual Chinese neural voice notifications that tell you WHAT happened (task complete vs. error vs. needs confirmation), not just THAT something happened. This is a significant UX improvement over sound files or beeps.

### Additional Context: CLI TTS Tools

| Tool | Quality | Speed | Offline | Chinese | License | Notes |
|------|---------|-------|---------|---------|---------|-------|
| **Spark-TTS 0.5B** | HIGH (neural) | ~8 min/sentence (CPU) | Yes | Yes (good) | Apache 2.0 | Selected for this project. GPU makes it faster. |
| **edge-tts** | HIGH (Microsoft neural) | Fast (streaming) | No (cloud API) | Yes (excellent) | Free (unofficial) | Rate limits exist (403 errors). No API key needed. |
| **espeak-ng** | LOW (robotic) | Fast | Yes | Yes (poor) | GPL v3 | Too robotic for pleasant notifications. |
| **Festival/Flite** | LOW | Fast | Yes | Yes (poor) | BSD/GPL | Academic quality, not suitable for production notifications. |
| **Piper** | MEDIUM | Fast | Yes | Yes (varies by voice) | MIT | On-device neural TTS. Quality varies. Worth evaluating as Spark-TTS alternative. |
| **Coqui TTS** | HIGH | Slow | Yes | Yes | MPL 2.0 | Powerful but heavy dependency. Overkill for 4 fixed phrases. |

## Sources

### Primary (HIGH confidence)
- Claude Code official hooks documentation (https://code.claude.com/docs/en/hooks) -- verified 2026-03-30 via WebReader. Defines all hook events, JSON schemas, exit codes, async hook support.
- PROJECT.md (`/home/huanglin/code/claude-config/notify-research/.planning/PROJECT.md`) -- project requirements, constraints, key decisions. Source of Spark-TTS 0.5B selection, Docker containerization, Fedora/paplay target, 4 notification types.

### Secondary (MEDIUM confidence)
- GitHub Issue #15795 (https://github.com/anthropics/claude-code/issues/15795) -- feature request for audio notifications, confirms community demand.
- ChanMeng666/claude-code-audio-hooks -- existing competitor, desktop notification + sound approach.
- Spark-TTS 0.5B -- Apache 2.0, Chinese support documented in project's active requirements.

### Tertiary (LOW confidence)
- edge-tts capabilities -- from training data, not verified via official docs in this session. Known to have rate limits.
- espeak-ng quality assessment -- from training data, not verified via testing.
- Piper TTS -- from training data. Listed as potential alternative but not deeply investigated.

---
*Feature research for: Claude Code voice notification system (Spark-TTS + hooks)*
*Researched: 2026-03-30*
