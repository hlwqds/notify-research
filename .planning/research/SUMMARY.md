# Project Research Summary

**Project:** Claude Code Environment Replay
**Domain:** Dotfiles Management / Environment Replication
**Researched:** 2026-03-30
**Confidence:** MEDIUM

## Executive Summary

This project is a shell-script-based dotfiles manager specialized for Claude Code environments. It replicates a complete Claude Code configuration (settings, skills, workflows, memory, MCP servers) on a fresh Linux machine in one command. The research across three of four files (FEATURES, ARCHITECTURE, PITFALLS) converges on a consistent approach: a modular shell script (`setup.sh`) with numbered sync modules, symlink-first file deployment with automatic backup, dry-run mode for safety, and runtime secret prompting. The architecture follows established patterns from GNU Stow (symlink-based sync) combined with elements from chezmoi (secrets templating) and yadm (bootstrap patterns).

The recommended approach is a layered shell script architecture with four distinct layers: entry point (argument parsing), discovery (environment detection), sync (modular per-domain file deployment), and validation (post-install smoke tests). Idempotency and safety are non-negotiable -- every operation must be safe to run multiple times, and every overwrite must produce a timestamped backup. The key risks are accidentally destroying an existing Claude Code environment (mitigated by backup-before-overwrite), symlink breakage when the source directory moves (mitigated by validation and re-link commands), and secrets leaking into version control (mitigated by gitignore, pre-commit hooks, and template placeholders).

**Important note on STACK.md:** The STACK.md research file (updated 2026-03-30) covers a Docker-containerized Spark-TTS notification audio system, which is a separate subproject located in the `notify-research/` directory. It does not pertain to the core "Claude Code Environment Replay" project. The technology stack for the environment replay project itself is straightforward: Bash 4.x+, standard GNU coreutils, Docker (for testing only), and optionally `rsync` for directory sync. No exotic dependencies are needed.

## Key Findings

### Recommended Stack

The Claude Code Environment Replay project requires minimal technology. The core stack is Bash shell scripting with standard Linux utilities. Docker is used solely as a testing environment, not as a runtime dependency. No external language runtimes, frameworks, or package managers are needed.

**Core technologies:**
- **Bash 4.x+:** Core runtime -- every sync module, validation script, and the main entry point are shell scripts
- **GNU coreutils (cp, ln, mkdir, readlink, date):** File operations for sync, backup, and symlink management
- **rsync 3.2+ (optional):** Directory sync for skills/ and memory/ with delete mode for clean replication; efficient delta transfers and permission preservation
- **Docker 24.x+:** Isolated test environment to verify setup.sh without touching the host machine; enforce Docker-only development workflow
- **jq (optional):** JSON validation for settings.json schema checking in the validation layer

**What to avoid:** Puppet/Ansible (overkill for personal tool), Docker as runtime (wrong abstraction -- Docker is for testing only), cloud sync services (no Git history), configuration management tools (enterprise scale mismatch).

**For the separate notify-research subproject (Spark-TTS):** Python 3.12, PyTorch 2.5.1+cpu, Spark-TTS 0.5B model (~3.95 GB), multi-stage Docker build on python:3.12-slim. Fully documented in STACK.md but out of scope for the environment replay project.

### Expected Features

**Must have (table stakes):**
- **File synchronization (symlink)** -- Core purpose; symlink from `~/.claude/` to `$CLAUDE_DOTS/.claude/`. Symlinks preferred because changes in source immediately reflect in destination.
- **Idempotency** -- Safe to run multiple times without breaking existing setups. Check-if-exists, backup-before-overwrite patterns.
- **Dry-run mode** -- `--dry-run` flag to preview changes before applying. Essential for user trust; every major dotfiles tool supports this.
- **Source location config** -- `$CLAUDE_DOTS` environment variable with sensible default (`~/dots/claude-config/`).
- **Selective sync** -- Glob patterns or manifest file to control which files get synced.

**Should have (competitive differentiators):**
- **Secrets templating** -- Runtime prompts for API keys, template files with placeholder values. Differentiator vs. Stow (which has no secrets handling) and yadm (which requires external tools like git-crypt).
- **Backup before overwrite** -- Automatic timestamped backups. Differentiator vs. all competitors (Stow, chezmoi, yadm all require manual backup).
- **Verification** -- Post-install smoke tests confirming key files exist and symlinks resolve. No competitor offers this.
- **Atomic operations** -- All-or-nothing sync with rollback on failure.

**Defer (v2+):**
- **Per-machine overrides** -- Hostname-based conditionals for different settings on different machines
- **Shell compatibility checks** -- Detect and warn about incompatible shell configurations
- **MCP server detection/reinstallation** -- Parse mcp-servers.json and reinstall; high complexity, uncertain ROI, sparse documentation
- **Drift detection** -- Alert when local config diverges from source

**Our differentiator:** Combine Stow-style symlinks with chezmoi-style templating and automatic backups. No existing tool offers this combination.

### Architecture Approach

The recommended architecture is a modular shell script with four layers: entry point (`setup.sh` for orchestration and argument parsing), discovery layer (environment detection and source file location), sync layer (numbered per-domain modules: 01-cfg.sh through 06-plugins.sh), and validation layer (post-install checks). Shared utilities live in `lib/` (logging, sync primitives, detection functions). Configuration constants live in `config/defaults.sh`. Secrets prompting is isolated in `prompt/secrets.sh` so it can be skipped in CI or dry-run mode.

The architecture is stateless -- state is derived from source directory contents and target directory current state. Rollback is via timestamped backup files. Key patterns include: modular sync modules with consistent interfaces (each can run standalone or be sourced), symlink-first with automatic backup, dry-run via global flag propagation (`DRY_RUN` variable checked before every filesystem write), and strict idempotency (check-if-exists, skip-if-correct before every operation).

**Build order is strict:** lib/ -> config/defaults.sh -> sync/ modules -> prompt/ -> validate/ -> setup.sh orchestration

**Major components:**
1. **setup.sh** -- Entry point, argument parsing, orchestrates sync modules in numbered order
2. **lib/ (logging.sh, detect.sh, sync.sh)** -- Shared primitives: logging, environment detection, sync/backup functions
3. **sync/ (01-cfg through 06-plugins)** -- One file per sync domain; numbered for execution order; each can run standalone
4. **validate/ (01-files, 02-symlinks, 03-config)** -- Post-install verification; runs independently after sync
5. **prompt/secrets.sh** -- Interactive API key collection; isolated for CI/dry-run skip
6. **config/defaults.sh** -- Constants and default paths in one place

### Critical Pitfalls

Eight pitfalls were identified, ordered by severity:

1. **Overwriting existing configurations without backup** -- Running on a machine with existing Claude Code setup silently destroys customizations. Prevention: rename existing file to `.bak.timestamp` before any write; add `--force` flag to require explicit opt-in to overwrite.

2. **Symlink breaks when source directory moves** -- Symlinks store absolute paths; if `$CLAUDE_DOTS` moves, all links break and Claude Code appears broken. Prevention: validate source existence before linking; provide `verify-links` command for detection and recovery; consider a manifest file tracking what should exist where.

3. **Hardcoded secrets leak into committed files** -- API keys in `settings.json` or `secrets.yaml` committed to git. Prevention: never commit `secrets.yaml`; use clearly invalid placeholder values (`YOUR_API_KEY_HERE`); add pre-commit hook scanning for API key patterns (`sk-`, `ghp_`, `Bearer`).

4. **Idempotency violation -- running twice breaks things** -- Second run accumulates backup files, duplicates entries, or corrupts state. Prevention: check if target already matches source before writing; use atomic write-to-temp-then-rename; test explicitly by running setup twice and diffing results.

5. **Breaking existing Claude Code state** -- Sync overwrites user's runtime state (new MCP servers, custom commands, conversation context). Prevention: never sync memory/ by default (user-generated at runtime); only sync keys explicitly in template for settings.json; preserve user-added keys.

6. **Permission errors break installation silently** -- Script assumes user-writable paths; fails on distribution-specific paths. Prevention: query environment for actual config directory; never hardcode paths; detect and report permission errors clearly.

7. **No store/deploy separation** -- All changes are live with no rollback path. Prevention: snapshot existing state before any sync; add `--revert` command to restore from backups.

8. **Testing on production** -- Development on host machine risks destroying live Claude Code environment. Prevention: enforce Docker-only testing via `docker compose run test`; document explicitly: never run setup.sh directly on host during development.

## Implications for Roadmap

Based on combined research, the following phase structure addresses dependencies, architecture patterns, and pitfall prevention:

### Phase 1: Foundation and Core Sync
**Rationale:** The lib/ primitives (logging, sync, detection) and config/defaults.sh must exist before any sync module can function. The Docker-based testing workflow must be established from the start to prevent the critical "testing on production" pitfall (Pitfall 8). This phase delivers the project skeleton and the first sync module, proving the core pattern works.
**Delivers:** Project structure (`lib/`, `sync/`, `validate/`, `prompt/`, `config/` directories), lib/ primitives (logging.sh, detect.sh, sync.sh), config/defaults.sh, Docker test environment (docker-compose.yml with test target), first sync module (01-cfg.sh for settings.json and commands.md), basic setup.sh entry point with argument parsing and `--dry-run` flag
**Addresses:** File synchronization (symlink), Source location config ($CLAUDE_DOTS), basic dry-run mode from FEATURES.md
**Avoids:** Pitfall 3 (secrets -- via .gitignore), Pitfall 4 (permissions -- Docker testing catches distribution-specific issues), Pitfall 8 (testing on production -- Docker-first workflow enforced)

### Phase 2: Idempotency and Safety
**Rationale:** This is the most critical phase for user trust. Without idempotency and backup, the tool is dangerous to run on any machine with an existing Claude Code setup. This phase addresses 5 of 8 identified pitfalls (1, 2, 4, 5, 7). It should come immediately after core sync works because every subsequent sync module inherits these safety guarantees from lib/.
**Delivers:** Backup-before-overwrite system (`.bak.timestamp` files), idempotent operations (check-before-write, skip-if-identical), atomic file operations (write-to-temp-then-rename), selective sync via manifest, `--force` flag, all remaining sync modules (02-skills.sh through 06-plugins.sh), `--revert` rollback command
**Addresses:** Idempotency, Backup before overwrite, Selective sync, Atomic operations from FEATURES.md. Avoids Pitfalls 1, 2, 4, 5, 7 from PITFALLS.md.
**Research flag:** Standard patterns -- backup-and-symlink, idempotent file operations, and manifest-based sync are well-established in Stow/chezmoi/yadm. Skip `/gsd:research-phase`.

### Phase 3: Secrets and Validation
**Rationale:** Secrets handling benefits from having the sync framework solid first. Validation confirms everything installed correctly. These are the "should have" features that make the tool feel complete and safe for real-world use.
**Delivers:** Secrets templating (prompt-secrets.sh with interactive API key collection), pre-commit hook for secret scanning, secrets-template.yaml with placeholder structure, post-install validation layer (validate/01-files.sh, 02-symlinks.sh, 03-config.sh), verification that critical files exist and symlinks resolve
**Addresses:** Secrets templating, Verification from FEATURES.md. Avoids Pitfall 3 (secrets leak) and Pitfall 5 (breaking existing state via selective sync).
**Research flag:** Standard patterns -- secret prompting in shell scripts and post-install validation are straightforward. Skip `/gsd:research-phase`.

### Phase 4: Polish and Edge Cases
**Rationale:** Only after the core is solid and safe should effort go into edge cases and user experience improvements. This phase handles things that make the tool robust in daily usage but are not blockers for initial deployment.
**Delivers:** `verify-links` command, progress messages during install, clear error codes and messages, shell compatibility detection, handling of per-machine overrides
**Addresses:** Per-machine overrides, Shell compatibility from FEATURES.md. Addresses UX pitfalls (no feedback, silent failures) from PITFALLS.md.
**Research flag:** May need `/gsd:research-phase` for per-machine override patterns and shell compatibility detection -- niche topic with less community documentation.

### Phase Ordering Rationale

- **Foundation first** -- lib/ and config/ are dependencies for all sync modules; must build in strict order per ARCHITECTURE.md build order
- **Docker testing established immediately** -- prevents the most insidious pitfall (Pitfall 8: testing on production) from day one
- **Safety before features** -- idempotency and backup must work before adding more sync domains; overwriting existing configs is the top critical pitfall
- **Secrets after sync framework** -- secrets prompt needs the config infrastructure to know which secrets to prompt for
- **Validation after sync** -- validation verifies what sync created; cannot run before sync modules exist
- **Polish last** -- edge cases only matter once the happy path works flawlessly

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 4 (Polish):** Per-machine override patterns and shell compatibility detection are niche topics with sparse documentation. Consider `/gsd:research-phase` if these features are prioritized.
- **Phase 2 (Safety):** Memory/ directory handling -- PITFALLS.md strongly recommends never syncing memory/ by default (user-generated runtime data), but PROJECT.md lists it as a requirement. This tension needs resolution during requirements definition or Phase 2 planning.

Phases with standard patterns (skip `/gsd:research-phase`):
- **Phase 1 (Foundation):** Shell script structure, argument parsing, Docker testing, symlink creation -- well-documented, established patterns from Stow/dotbot/chezmoi.
- **Phase 2 (Safety):** Backup-before-overwrite, idempotent operations, manifest-based sync -- the research file provides sufficient code patterns to implement directly.
- **Phase 3 (Secrets/Validation):** Secret prompting in shell, pre-commit hooks, post-install smoke tests -- straightforward with clear patterns from the research.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM-HIGH | STACK.md covers a different subproject (Spark-TTS notifications). The actual stack for environment replay (Bash, coreutils, Docker for testing) is simple and well-understood, giving HIGH practical confidence despite the STACK.md misalignment. |
| Features | MEDIUM | Thorough competitor analysis (Stow, yadm, chezmoi, dotbot) with clear feature dependency mapping and prioritization matrix. No web search available for verification. |
| Architecture | MEDIUM | Four-layer model (entry, discovery, sync, validate) with strict build order is well-structured and based on established dotfiles manager architectures. Component boundaries are clear. |
| Pitfalls | MEDIUM | Eight pitfalls identified with concrete prevention strategies and phase mappings. Based on domain knowledge from training data; no web search verification available. The pitfall-to-phase mapping is actionable. |

**Overall confidence:** MEDIUM

### Gaps to Address

- **STACK.md misalignment:** STACK.md documents a Spark-TTS notification system, not the Claude Code Environment Replay. The roadmapper should be aware that no dedicated stack research exists for the core project. This is partially mitigated by the simplicity of the stack (Bash + coreutils), but a dedicated STACK.md for the environment replay project would strengthen the research foundation.
- **MCP server reinstallation patterns:** The architecture includes sync/05-mcp.sh but the specifics of detecting and reinstalling MCP servers are not well-researched. The mcp-servers.json format and installation procedures should be validated during Phase 2 planning.
- **Memory/ directory tension:** PITFALLS.md strongly recommends never syncing memory/ by default (user-generated runtime data), but PROJECT.md lists memory sync as an active requirement. This must be resolved during requirements definition -- clarify whether memory sync is opt-in or opt-out, and what subset of memory/ (if any) should sync by default.
- **No web search verification:** All research was based on training data knowledge rather than live web searches. Official Claude Code documentation on hooks, settings, and directory structure should be verified during implementation.

## Sources

### Primary (HIGH confidence)
- GNU Stow documentation (https://www.gnu.org/software/stow/) -- symlink-based dotfiles management patterns
- yadm project (https://yadm.io/) -- bootstrap and encryption patterns
- chezmoi documentation (https://www.chezmoi.io/) -- template-based dotfiles management, secrets handling
- dotbot project (https://github.com/anishathalye/dotbot) -- lightweight installer script patterns
- rcm documentation (https://github.com/thoughtbot/rcm) -- tag-based file synchronization

### Secondary (MEDIUM confidence)
- Spark-TTS Official GitHub (https://github.com/SparkAudio/Spark-TTS) -- for notify-research subproject only; requirements.txt, CLI usage, Docker patterns
- Spark-TTS Docker PR #40 (breakstring) -- Dockerfile and Docker Compose patterns (notify subproject)
- Domain knowledge from established dotfiles management practices -- community standard patterns
- Claude Code hooks documentation (https://code.claude.com/docs/en/hooks) -- hook system and Notification event

### Tertiary (LOW confidence)
- Community dotfiles workflows (various GitHub repos) -- feature expectations and anti-patterns
- Common community mistakes in dotfiles Reddit/DevOps discussions -- pitfall identification
- Claude Code audio hooks (ChanMeng666) -- community reference, not directly reviewed

---
*Research completed: 2026-03-30*
*Ready for roadmap: yes*
