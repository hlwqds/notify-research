# Pitfalls Research: Distribution, Multi-Voice, and Community Promotion for Claude Code Notification System

**Domain:** Adding `curl | bash` distribution, multi-voice audio variants, GitHub community presence, and cross-platform installation docs to an existing shell/PowerShell Claude Code hooks project
**Researched:** 2026-03-31
**Confidence:** MEDIUM-HIGH
**Scope:** Pitfalls specific to ADDING distribution packaging, multi-voice audio, community promotion, and documentation to the existing v1.3 notification system. Builds on prior PITFALLS.md files covering cross-platform runtime (v1.1) and test infrastructure (v1.2).

## Critical Pitfalls

Mistakes that cause security incidents, repo bloat, user trust loss, or community backlash.

### Pitfall 1: `curl | bash` Remote Install Script Has No Integrity Verification

**What goes wrong:**
The one-line install command (`curl -fsSL https://... | bash`) downloads and immediately executes a script with zero cryptographic verification. If the GitHub account is compromised, the domain expires, or a CDN serves malicious content, every user who runs the command is compromised silently. Unlike `apt` or `brew` which verify GPG signatures, the raw pipe-to-shell pattern has no integrity chain.

**Why it happens:**
It is the standard pattern for developer tools (Homebrew, rustup, nvm, Docker all use it). It maximizes conversion by reducing friction to a single copy-paste. The convenience pressure makes integrity verification feel like over-engineering for a small notification tool. However, the 2026 attack surface is real: [Codecov bash uploader compromise (2021)](https://about.codecov.io/security-update/) and [polyfill.io domain takeover (2024)](https://www.kb.cert.org/vuls/id/979398/) demonstrate that supply-chain attacks on install scripts are not hypothetical.

**How to avoid:**
1. **Provide a two-step alternative** alongside the one-liner in docs:
   ```bash
   # One-liner (convenient)
   curl -fsSL https://raw.githubusercontent.com/<repo>/main/scripts/remote-install.sh | bash

   # Two-step (verifiable)
   curl -fsSL https://raw.githubusercontent.com/<repo>/main/scripts/remote-install.sh -o install.sh
   less install.sh          # inspect
   bash install.sh
   ```
2. **Pin the URL to a tagged release** (not `main` branch) so the script content is immutable:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/<repo>/v1.4.0/scripts/remote-install.sh | bash
   ```
3. **Publish checksums** in the GitHub Release alongside the script. Document the verification step even if most users skip it:
   ```bash
   sha256sum install.sh  # compare with RELEASE_SHA256 in release notes
   ```
4. **Never use `sudo`** in the pipe-to-shell command. The existing install.sh writes to `~/.claude/` which does not require root. This limits blast radius.
5. **Keep the remote install script minimal** -- it should only `git clone` and call the local `install.sh`, not implement installation logic itself.

**Warning signs:**
- Install script downloads and executes additional scripts from the network (chained downloads)
- Script requires `sudo` or writes to system directories
- No tagged version in the curl URL (points to `main`)
- Script source has been modified since the user last checked

**Phase to address:**
Phase 1 (remote install script) -- integrity verification must be designed in from the start, not bolted on later.

---

### Pitfall 2: Adding Audio Variants Bloats Git History Permanently

**What goes wrong:**
Adding new voice styles (e.g., male/female, different tones) multiplies the 4 existing MP3 files. If each variant adds 4 files at ~10-15 KB each, and variants are swapped or updated during development, the git history accumulates binary blobs that are never garbage-collected. A future `git clone` downloads the entire history including every audio file variant ever committed. After 5-6 variant experiments, the `.git` directory could grow significantly larger than the actual repo content.

**Why it happens:**
The existing repo already commits MP3 files directly (no Git LFS). This was a deliberate v1.0 decision to eliminate Docker dependency at runtime. Adding more variants doubles or triples the committed audio. Binary files in Git are stored per-commit (not as deltas), so every modification creates a full copy in the object store.

**How to avoid:**
1. **Keep audio files small.** The current 4 MP3s total ~47 KB. If new variants are also short notification sounds (1-3 seconds), each will be ~10-15 KB. At this size, Git LFS overhead (pointer files, `git lfs pull` friction) is NOT worth it. The Stack Overflow [consensus](https://stackoverflow.com/questions/49018053/how-large-does-a-large-file-have-to-be-to-benefit-from-git-lfs) is that LFS helps for files above ~500 KB.
2. **Do NOT use Git LFS for files under 100 KB.** LFS adds complexity (users need `git lfs install`, GitHub has [bandwidth/storage quotas](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-storage-and-bandwidth-usage)), and the benefit for 10-15 KB files is negative.
3. **Use `.gitattributes` to document audio file tracking** even without LFS:
   ```gitattributes
   audio/*.mp3 binary
   ```
   This ensures Git never attempts text diff on audio files.
4. **Avoid committing intermediate/experimental audio variants.** Generate variants, preview locally, and only commit the final selection. If experimenting, use a separate branch and squash before merging.
5. **If variant count exceeds ~10 files** (>150 KB total), consider a downloadable audio pack (tarball in GitHub Release) instead of committing to the repo.

**Warning signs:**
- `git clone` takes noticeably longer than expected for a small shell script project
- `.git/objects/pack/` is much larger than the working directory
- Multiple audio files with names like `notify-complete-v2.mp3`, `notify-complete-final.mp3`, `notify-complete-old.mp3` in the repo

**Phase to address:**
Phase 2 (multi-voice audio) -- establish audio management policy before generating variants.

---

### Pitfall 3: settings.json Path Hardcoding Breaks on Different Claude Code Installations

**What goes wrong:**
The current install scripts hardcode `$HOME/.claude` as the target directory and assume `settings.json` exists there. The remote install script will run on machines where Claude Code uses a different configuration path (custom `CLAUDE_CONFIG_DIR`, project-level `.claude/settings.json`, or different OS conventions). Users on NixOS, containers, or systems with unusual home directory setups will see cryptic "settings.json not found" errors.

**Why it happens:**
The existing scripts were designed for the developer's own machine. The v1.0 milestone validated `~/.claude/settings.json` as the path. But Claude Code supports multiple configuration scopes (user, project, workspace), and the remote installer needs to handle all of them. Additionally, the `CLAUDE_CONFIG_DIR` environment variable (if it exists) changes the base path.

**How to avoid:**
1. **Detect the Claude Code configuration directory** rather than assuming `~/.claude`:
   ```bash
   CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
   ```
2. **Let users specify the target directory** via CLI flag:
   ```bash
   bash install.sh --claude-dir /custom/path/.claude
   ```
3. **Create `settings.json` if it does not exist**, rather than failing. A minimal empty settings file is valid JSON:
   ```json
   {}
   ```
4. **Document the scopes** clearly: user-level (`~/.claude/settings.json`) for global installation, project-level (`.claude/settings.json`) for per-project installation.
5. **Check if Claude Code is installed** before attempting hooks injection. The existing scripts already check `claude --version` but only warn -- the remote installer should provide clearer guidance.

**Warning signs:**
- Users report "settings.json not found" errors on GitHub issues
- Works on Ubuntu but not NixOS or Alpine
- Claude Code settings in project directories are not recognized

**Phase to address:**
Phase 1 (remote install script) -- configuration path detection must be robust before the installer goes public.

---

### Pitfall 4: Competitor Landscape Is Already Crowded -- Differentiation Is Critical

**What goes wrong:**
The project is submitted to awesome-claude-code lists and community channels, but gets no traction because multiple competitors already offer the same core feature (audio notifications for Claude Code hooks). The project is seen as redundant rather than complementary.

**Why it happens:**
Research of the current ecosystem reveals at least **5 existing competitors** already listed in awesome-claude-code repos:

| Project | Approach | Differentiator |
|---------|----------|----------------|
| [pascalporedda/awesome-claude-code](https://github.com/pascalporedda/awesome-claude-code) | TypeScript hooks via `npx tsx`, global installer, macOS system sounds, event logging | Full-featured with logging and macOS-native sounds |
| [Claudio](https://github.com/hesreallyhim/awesome-claude-code) (by Christopher Toth) | "No-frills library" adding OS-native sounds via hooks | Simplicity, delightful UX |
| [CC Notify](https://github.com/hesreallyhim/awesome-claude-code) (by dazuiba) | Desktop notifications + VS Code one-click jump | GUI integration, task duration display |
| [claude-devtools](https://github.com/hesreallyhim/awesome-claude-code) (by matt1398) | Desktop app with session observability + custom notification triggers | Rich dashboard, subagent tracking |
| [ChanMeng666/claude-code-audio-hooks](https://github.com/ChanMeng666/claude-code-audio-hooks) | Audio hooks for Claude Code | Audio-specific |

The project's unique value (Chinese TTS-generated voice, Spark-TTS 0.5B) is a differentiator, but if promotion focuses on "audio notifications for Claude Code" generically, it will be lost in the noise.

**How to avoid:**
1. **Position the project around Chinese voice notifications specifically**, not generic audio alerts. The Spark-TTS 0.5B integration for Chinese TTS is genuinely unique -- no other project offers this.
2. **Lead with the one-liner install** as the differentiator. Most competitors require Node.js (`npx tsx`) or more complex setup. A pure-bash `curl | bash` with zero runtime dependencies (no Node.js, no Docker at runtime) is a real advantage.
3. **Target Chinese-speaking Claude Code users** specifically. Cross-post to Chinese developer communities (V2EX, Ruby China, SegmentFault, Juejin) where Chinese-language tooling is valued.
4. **In awesome-list PRs**, emphasize what is different: "Chinese TTS voice notifications, pure bash (no Node.js), zero runtime dependencies." Do not submit as just another notification hook.
5. **Check the awesome-lists' contribution guidelines** before submitting. [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) requires using their CONTRIBUTING.md workflow -- PRs submitted without following the process will be rejected.

**Warning signs:**
- Awesome-list PR is rejected or gets no response
- "Show HN" post gets zero comments
- Users on Reddit say "there's already X that does this"
- README copy is too similar to competitor READMEs

**Phase to address:**
Phase 3 (community promotion) -- positioning and messaging must be crafted before any public announcement. The messaging strategy determines whether the project is noticed.

---

### Pitfall 5: Multi-Voice Selection Breaks Idempotent Installation

**What goes wrong:**
The current install scripts copy exactly 4 hardcoded MP3 files (`notify-complete.mp3`, `notify-confirm.mp3`, `notify-error.mp3`, `notify-progress.mp3`) and inject hardcoded paths into `settings.json`. Adding a voice selection mechanism (e.g., `install.sh --voice female`) means the script must conditionally copy from different subdirectories and inject different filenames. If a user switches voices, the old files remain in `~/.claude/` and the old `settings.json` paths may become stale or conflicting.

**Why it happens:**
The current install.sh is idempotent because it always copies the same 4 files and overwrites the same hooks. Adding voice selection introduces state: "which voice did the user choose?" This state is not tracked anywhere -- not in a config file, not in `settings.json`, not in an environment variable. Re-running the installer with a different voice option will overwrite some files but may leave orphaned files from the previous voice.

**How to avoid:**
1. **Store the selected voice in a manifest file** in `~/.claude/`:
   ```bash
   echo "female" > ~/.claude/notify-voice.txt
   ```
   The install script reads this file to know which variant to use, and the uninstall script reads it to clean up the correct files.
2. **Use a consistent filename scheme** so the hook commands in `settings.json` do not need to change:
   ```
   audio/
     voices/
       default/  notify-complete.mp3, notify-confirm.mp3, ...
       female/   notify-complete.mp3, notify-confirm.mp3, ...
       male/     notify-complete.mp3, notify-confirm.mp3, ...
   ```
   The install script always copies 4 files named `notify-{type}.mp3` to `~/.claude/`, but from different source directories. The `settings.json` paths never change.
3. **Clean up old voice files** during installation if the voice changes:
   ```bash
   # Before copying new voice files, remove any existing notify-*.mp3
   rm -f "$CLAUDE_DIR"/notify-*.mp3
   ```
4. **The uninstall script must not be voice-aware.** It removes all `notify-*.mp3` files regardless of voice -- this is already the current behavior and should remain unchanged.
5. **Test voice switching** in the bats test suite: install with voice A, install with voice B, verify only voice B files remain.

**Warning signs:**
- `~/.claude/` accumulates `notify-complete.mp3`, `notify-complete-female.mp3`, `notify-complete-male.mp3` simultaneously
- Switching voices leaves hooks pointing to old files
- Uninstall does not remove voice-specific files

**Phase to address:**
Phase 2 (multi-voice audio) -- the voice selection architecture must be designed before generating audio variants.

---

## Moderate Pitfalls

Mistakes that cause degraded user experience or incomplete functionality.

### Pitfall 6: README Installation Instructions Assume Linux, Confuse Windows/macOS Users

**What goes wrong:**
The installation documentation presents the bash one-liner prominently, with Windows PowerShell instructions buried or presented as an afterthought. Windows users see `curl | bash` and assume the tool is not for them. macOS users may have compatibility issues that are not documented.

**Why it happens:**
The developer's primary platform is Linux (Fedora). The existing README already has install instructions for all three platforms, but a distribution-focused rewrite may inadvertently prioritize the bash path. The remote install script only exists for bash -- Windows users must still clone and run `install.ps1`.

**How to avoid:**
1. **Present all three platforms equally** in the README "Quick Start" section, with tabbed or side-by-side layouts.
2. **The remote install is Linux/macOS only** -- clearly state this. For Windows, document the PowerShell equivalent:
   ```powershell
   irm https://raw.githubusercontent.com/<repo>/v1.4.0/scripts/install.ps1 -OutFile install.ps1; powershell -File install.ps1
   ```
   (PowerShell's `Invoke-WebRequest` / `irm` is more idiomatic than `curl` on Windows.)
3. **Test the documented commands on a fresh machine** for each platform. GitHub Actions CI covers this for the existing scripts, but the remote install URL must be verified separately.
4. **Document prerequisites clearly**: `jq` on Linux, no prerequisites on macOS, PowerShell 5.1 on Windows.
5. **Include a troubleshooting section** that covers the most common failure modes: "paplay not found", "settings.json not found", "jq not found".

**Phase to address:**
Phase 4 (installation documentation) -- documentation must be tested on all three platforms before publication.

---

### Pitfall 7: Show HN / Community Post Timing and Format Gets No Engagement

**What goes wrong:**
A Show HN post or Reddit submission is published at a bad time (Friday evening US, during a major conference), with a generic title, and gets zero engagement. The post sinks without a trace and the developer concludes the tool has no audience, when in reality the problem is the launch strategy.

**Why it happens:**
Developer tool launches require specific timing and messaging. The HN guidelines say "Show HN is for something you've made that other people can play with." A notification script is hard to demo in a text post -- there is no screenshot or GIF that conveys the experience.

**How to avoid:**
1. **Timing:** Post on Tuesday-Thursday US morning (9-11 AM EST). Avoid weekends, holidays, and major event weeks.
2. **Title format:** Use "Show HN: Claude Code notifies you in Chinese when tasks complete -- pure bash, zero dependencies". The title must convey: (a) what it does, (b) what makes it unique, (c) how easy it is.
3. **Include an audio sample** -- embed a short demo video or link to a playable audio clip so readers can hear the notification without installing.
4. **Lead with the one-liner install** in the post body. Developer tools that require >3 steps to try get skipped.
5. **Be present for the first 2 hours** after posting to respond to comments. HN engagement is front-loaded.

**Phase to address:**
Phase 3 (community promotion) -- draft the launch post well before publishing and get feedback from peers.

---

### Pitfall 8: Awesome-List PR Rejected for Not Following Contribution Guidelines

**What goes wrong:**
A PR is submitted to [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) adding the project, but it is rejected because it does not follow the repository's CONTRIBUTING.md process. The project has a specific submission format, category requirements, and quality bar. The [pascalporedda/awesome-claude-code](https://github.com/pascalporedda/awesome-claude-code) list has different (simpler) requirements.

**Why it happens:**
The hesreallyhim list explicitly states: "Please do not open a PR to submit a recommendation -- the only person who is allowed to submit PRs to this repo is Claude." This means PRs from third parties are auto-rejected. Instead, contributors must open an issue following the CONTRIBUTING.md template. Skipping this step wastes everyone's time.

**How to avoid:**
1. **Read the CONTRIBUTING.md** of each awesome-list before submitting. For hesreallyhim, the process is: open an issue (not a PR) with specific format.
2. **Check the existing list entries** for the category format. The Hooks section entries follow a specific structure: project name by author -- one-line description. Additional details follow.
3. **Verify the project meets the quality bar**: working CI, clear README, no broken links, active maintenance.
4. **Submit to multiple lists** -- both hesreallyhim and pascalporedda have different scopes and audiences. The pascalporedda list is specifically about hooks, which is a better fit.
5. **Do not spam** -- submit to at most 2-3 lists simultaneously. Wait for response before trying others.

**Phase to address:**
Phase 3 (community promotion) -- read contribution guidelines before any submission.

---

### Pitfall 9: Forward-Slash Path Requirement Not Documented for Advanced Users

**What goes wrong:**
Advanced users who manually edit `settings.json` to customize hook commands use Windows backslash paths (`C:\Users\...`). Claude Code hooks silently fail because backslashes in JSON strings are escape characters. This is already handled by `install.ps1` (which uses `ConvertTo-ForwardSlash`), but users who customize hooks manually are not warned.

**Why it happens:**
The forward-slash requirement is documented in the project's Key Decisions (WIN-05) but is not surfaced in user-facing documentation. Users who read the awesome-list description or a community post and manually configure hooks will miss this detail.

**How to avoid:**
1. **Add a prominent note in the README** troubleshooting section: "On Windows, all paths in settings.json hooks must use forward slashes (/), not backslashes."
2. **The install scripts already handle this**, so most users will not hit this. But for the edge case of manual configuration, document it.
3. **Consider adding a validation step** in the install script that warns if backslashes are detected in the generated `settings.json`.

**Phase to address:**
Phase 4 (installation documentation) -- ensure the forward-slash requirement is in the user-facing docs.

---

## Minor Pitfalls

### Pitfall 10: GitHub Release Audio Pack Forgetting to Update Checksums

**What goes wrong:**
Audio variant packs are published as GitHub Release assets (tarballs), but the SHA256 checksums in the release notes are not updated or are computed incorrectly. Users who verify checksums get false failures, or users who skip verification are exposed to tampering.

**How to avoid:**
1. Automate checksum generation in the release script:
   ```bash
   sha256sum notify-audio-female.tar.gz >> CHECKSUMS.txt
   ```
2. Include checksums in the GitHub Release body automatically via CI.

**Phase to address:**
Phase 2 (multi-voice audio) -- if audio packs are released separately, include checksum automation.

---

### Pitfall 11: README Becomes Overwhelming with Too Many Installation Options

**What goes wrong:**
The README grows to include: one-liner install, git clone install, voice selection options, platform-specific instructions, troubleshooting, and contribution guidelines. New users are overwhelmed and leave without installing.

**How to avoid:**
1. **Lead with exactly one install command** per platform at the top. Everything else goes below a fold line.
2. **Use collapsible sections** (`<details>`) for advanced options (voice selection, manual installation, uninstall).
3. **Link to separate docs** (GitHub Wiki or `/docs/` directory) for detailed troubleshooting.

**Phase to address:**
Phase 4 (installation documentation) -- test the README with a cold-read by someone unfamiliar with the project.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-T Cost | When Acceptable |
|----------|-------------------|-------------|-----------------|
| Skip checksum verification in install docs | Simpler docs, fewer steps | Zero integrity guarantee for remote install | Acceptable for MVP if two-step alternative is documented |
| Commit all voice variants to repo | No separate download step, simpler install | Repo grows with each variant; old variants permanent in history | Acceptable if total audio < 200 KB and variants are curated (< 5 voices) |
| Submit PR instead of issue to awesome-lists | Feels more direct | Rejected due to contribution guidelines | Never -- read guidelines first |
| Use `main` branch in curl URL | Always latest, no version bumps | Content can change; TOCTOU risk | Never -- pin to release tag |
| Skip forward-slash docs | Saves README lines | Silent hook failures for Windows manual config | Never -- this is a known Windows pitfall |
| Hardcode voice list in install.sh | Simpler script | Adding voices requires code changes | Acceptable for < 5 voices; consider config file if more |

## Integration Gotchas

Common mistakes when connecting to external services and platforms.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| GitHub raw URLs for install scripts | Using `main` branch (mutable content) | Pin to release tag: `raw.githubusercontent.com/<repo>/v1.4.0/scripts/...` |
| Claude Code hooks settings.json | Using backslash paths on Windows | Always use forward slashes; `install.ps1` already converts |
| GitHub awesome-lists | Opening a PR instead of an issue | Read CONTRIBUTING.md; hesreallyhim requires issues, not PRs |
| GitHub Actions CI for remote install | Not testing the remote install URL in CI | Add a CI step that `curl`s the remote install script and validates it parses correctly |
| Spark-TTS Docker for audio generation | Rebuilding Docker image for each variant | Generate all variants in one Docker run; reuse the same container |
| GitHub Release assets | Manual checksum computation | Automate in release workflow; include `CHECKSUMS.txt` |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| All audio in repo | Clone time grows with each variant | Cap total committed audio at ~200 KB; use GitHub Releases for packs | At 5+ voices with multiple styles |
| Remote install script downloads full repo | Slow install for users on slow connections | Keep repo small; the install script should be < 5 KB | At 10+ committed audio files |
| settings.json jq parsing on every install | Not a performance issue (single invocation) | N/A -- this is fine | Never |

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Remote install script uses HTTP, not HTTPS | MITM can inject arbitrary code | Always use HTTPS URLs; verify TLS certificate |
| Install script writes to system directories | Root-level compromise | Only write to `~/.claude/` -- never `/usr/`, `/etc/`, etc. |
| Install script exposes environment variables | API keys, tokens leaked in logs or errors | Do not log or display env vars; use `set -euo pipefail` |
| No version pinning in curl URL | Content can change post-review | Pin to release tag SHA or version tag |
| Install script does not validate downloads | Corrupted or truncated files cause silent failures | Check file size or checksum after download |

## UX Pitfalls

Common user experience mistakes in this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No audio preview before install | User installs, hears the voice, dislikes it, must uninstall | Provide audio preview links in README so users can hear before installing |
| Voice selection only at install time | User wants to change voice later but uninstall/reinstall is unclear | Support `install.sh --voice female` as a re-configuration command (idempotent) |
| No visual feedback during install | User runs install, sees nothing for 10 seconds, wonders if it worked | Print clear step-by-step progress: "Copying audio...", "Configuring hooks...", "Done!" (already implemented) |
| Error messages reference internal paths | User sees "/app/scripts/install.sh: line 42" and does not know what to do | Use user-friendly error messages: "Could not find ~/.claude/settings.json. Is Claude Code installed?" |
| Chinese-only TTS with no English alternative | Non-Chinese-speaking users want notifications too | Document that Chinese voice is the primary offering; suggest system sounds as alternative for non-Chinese users |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Remote install URL:** Does the curl URL point to a tagged release (not `main`)? Verify by checking the URL resolves correctly.
- [ ] **Voice manifest:** Does `~/.claude/notify-voice.txt` exist after voice selection? Verify install and uninstall handle this correctly.
- [ ] **settings.json forward slashes:** After install on Windows, do all hook commands use forward slashes? Verify by reading settings.json.
- [ ] **Orphaned audio files:** After switching voices, are only the new voice's files in `~/.claude/`? Verify by listing the directory.
- [ ] **README on all platforms:** Does the documented install command work on a fresh Linux, macOS, and Windows machine? Verify with GitHub Actions CI.
- [ ] **Awesome-list submission:** Did you read the contribution guidelines before submitting? Verify by checking the repo's CONTRIBUTING.md.
- [ ] **Checksum verification:** If a CHECKSUMS.txt is published, does it match the actual files? Verify by running `sha256sum -c CHECKSUMS.txt`.
- [ ] **Uninstall completeness:** After uninstall, is `~/.claude/` clean (no orphaned notify files, no voice manifest)? Verify by listing the directory.

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Remote install URL serves wrong content | LOW | 1. Pin URL to a specific git tag. 2. Add CI check that validates the script. 3. Publish checksums. |
| Git history bloated by audio variants | MEDIUM | 1. If total is still < 500 KB, accept it. 2. If bloated, use `git filter-repo` to remove old variants. 3. All contributors must re-clone. |
| Awesome-list PR rejected | LOW | 1. Read contribution guidelines. 2. Re-submit following the correct process (issue, not PR). |
| settings.json corrupted by install | MEDIUM | 1. The install script uses `jq` with a temp file and atomic `mv`, so corruption is unlikely. 2. If it happens, user can restore from git: `cp ~/.claude/settings.json.backup ~/.claude/settings.json`. 3. Add backup step to install script. |
| Voice switching leaves orphan files | LOW | 1. Run `rm -f ~/.claude/notify-*.mp3` before copying new voice. 2. Update install script to do this automatically. |
| Show HN post gets no engagement | LOW | 1. Wait 2 weeks. 2. Rewrite title and post at better time. 3. Try Reddit r/ClaudeAI or r/commandline instead. |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Pitfall 1 (no integrity verification) | Phase 1 (remote install) | Verify curl URL points to tagged release; two-step alternative documented |
| Pitfall 2 (repo bloat from audio) | Phase 2 (multi-voice) | Verify total committed audio < 200 KB; `.gitattributes` marks audio as binary |
| Pitfall 3 (hardcoded settings path) | Phase 1 (remote install) | Test install on custom CLAUDE_CONFIG_DIR; test on fresh machine without Claude Code |
| Pitfall 4 (crowded competitor space) | Phase 3 (community promotion) | Verify README leads with Chinese TTS differentiator; awesome-list entry text is unique |
| Pitfall 5 (voice breaks idempotent install) | Phase 2 (multi-voice) | Test: install voice A, then voice B, verify only voice B files remain |
| Pitfall 6 (README assumes Linux) | Phase 4 (docs) | Verify README install instructions work on all three platforms |
| Pitfall 7 (bad launch timing) | Phase 3 (community promotion) | Draft launch post; get peer review; schedule for Tue-Thu US morning |
| Pitfall 8 (awesome-list PR rejected) | Phase 3 (community promotion) | Read CONTRIBUTING.md before submitting; verify submission format |
| Pitfall 9 (forward-slash not documented) | Phase 4 (docs) | Verify troubleshooting section mentions forward-slash requirement |
| Pitfall 10 (checksums not updated) | Phase 2 (multi-voice) | Verify release workflow includes checksum generation |
| Pitfall 11 (README overload) | Phase 4 (docs) | Cold-read test by unfamiliar user; verify quick-start is < 5 lines |

## Sources

### HIGH Confidence (Official Documentation / Verified Repositories)

- [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) -- Hooks section, contribution guidelines, competitor landscape (verified 2026-03-31)
- [pascalporedda/awesome-claude-code](https://github.com/pascalporedda/awesome-claude-code) -- sound notification hooks implementation, global installer pattern (verified 2026-03-31)
- [Show HN Guidelines](https://news.ycombinator.com/showhn.html) -- official Show HN submission requirements (verified 2026-03-31)
- [CLI Guidelines (clig.dev)](https://clig.dev/) -- community-driven CLI best practices (verified 2026-03-31)
- [Git LFS official documentation](https://git-lfs.github.com/) -- LFS behavior and tradeoffs (verified 2026-03-31)

### MEDIUM Confidence (Multiple Sources Agree)

- [Security Stack Exchange: Is `curl | sudo bash` safe?](https://security.stackexchange.com/questions/213401/is-curl-something-sudo-bash-a-reasonably-safe-installation-method) -- auditability concerns (verified 2026-03-31)
- [Netdata Issue #3551: Stop encouraging curl | bash](https://github.com/netdata/netdata/issues/3551) -- community pushback against pipe-to-shell (verified 2026-03-31)
- [javapro.io: curl | bash | hacked (2026)](https://javapro.io/2026/03/25/curl-bash-hacked-the-unseen-dangers-in-your-dev-lifecycle/) -- recent 2026 coverage of supply chain risks (verified 2026-03-31)
- [Stack Overflow: How large for Git LFS benefit?](https://stackoverflow.com/questions/49018053/how-large-does-a-large-file-have-to-be-to-benefit-from-git-lfs) -- LFS threshold consensus ~500 KB (verified 2026-03-31)
- [Reddit r/git: Git LFS for small MP3 files](https://www.reddit.com/r/git/comments/11xwhkt/will_using_git_lfs_track_mp3_also_use_gitlfs_to/) -- LFS tracks all files regardless of size (verified 2026-03-31)
- [How to Launch a Dev Tool on Hacker News (markepear.dev)](https://www.markepear.dev/blog/dev-tool-hacker-news-launch) -- HN launch strategy (verified 2026-03-31)
- [Apple Developer: Shell Scripting for Cross-Platform](https://developer.apple.com/library/archive/documentation/OpenSource/Conceptual/ShellScripting/PortingScriptstoMacOSX/PortingScriptstoMacOSX.html) -- GNU vs BSD coreutils (verified 2026-03-31)

### LOW Confidence (Training Data / Single Source / Unverified)

- ChanMeng666/claude-code-audio-hooks -- referenced in CLAUDE.md but not directly reviewed; may or may not be a direct competitor
- Domain expiration attack on install script URLs -- theoretical risk, no specific incidents involving developer tool install scripts found
- Show HN engagement rate for developer tools -- no quantitative data found on typical engagement rates
- Audio file size estimates for voice variants -- based on existing 4 files (~10-15 KB each), untested with new voices

---
*Pitfalls research for: Claude Code notification system v1.4 distribution and community*
*Researched: 2026-03-31*
