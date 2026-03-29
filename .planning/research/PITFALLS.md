# Pitfalls Research

**Domain:** Dotfiles / Environment Configuration Management
**Researched:** 2026-03-29
**Confidence:** MEDIUM

Note: WebSearch unavailable. Findings based on established domain knowledge from training data. Specific incidents and community discussions would increase confidence.

## Critical Pitfalls

### Pitfall 1: Overwriting Existing Configurations Without Backup

**What goes wrong:**
User runs the setup script on a machine that already has a configured Claude Code environment. The script silently overwrites `settings.json`, skills, and memory files. All existing customizations are lost.

**Why it happens:**
The overwrite-mode design (chosen for simplicity) combined with no automatic backup creates permanent data loss risk. Most dotfiles tools (GNU Stow, chezmoi, yadm) default to backup-before-overwrite; this project explicitly chose overwrite mode.

**How to avoid:**
1. Before any file write, detect if target exists and has content different from source
2. When conflict detected: rename existing file to `~/.claude/file.bak.timestamp` before writing
3. Log all backups created so user can recover
4. Add `--force` flag to explicitly opt into overwriting (default is safe)

**Warning signs:**
- Target file exists with recent modification date
- Diff shows meaningful differences between source and target
- User reports "where did my custom commands go?"

**Phase to address:**
Phase 02 (Idempotency & Safety) — backup system is a prerequisite for safe operation.

---

### Pitfall 2: Symlink Breaks When Source Directory Moves

**What goes wrong:**
User moves their `~/dots/claude-config/` directory to a different path. All symlinks in `~/.claude/` now point to non-existent locations. Claude Code appears broken — no skills, no settings, no memory.

**Why it happens:**
Symlinks store absolute paths. If `~/dots/claude-config/.claude/settings.json` is symlinked to `~/.claude/settings.json`, and the source moves, the symlink breaks. Relative symlinks help but don't solve all cases (rsync with symlinks can be tricky).

**How to avoid:**
1. Use copy semantics by default (less magical, more robust)
2. If using symlinks: validate source existence before creating symlink, and warn if `$CLAUDE_DOTS` path changes after initial setup
3. Provide a `verify-links` command to check all symlinks resolve
4. Consider using a manifest file that tracks what should exist where, rather than relying on filesystem symlinks

**Warning signs:**
- `ls -la ~/.claude/` shows symlinks with `->` pointing to moved path
- `test -e ~/.claude/settings.json` returns false despite symlink existing
- Claude Code shows "settings file not found" errors

**Phase to address:**
Phase 02 (Idempotency & Safety) — symlink strategy is core architecture decision.

---

### Pitfall 3: Hardcoded Secrets Leak Into Committed Files

**What goes wrong:**
Developer adds API keys, tokens, or credentials to `settings.json` or `secrets.yaml` and commits to version control. Secrets are exposed in dotfiles repo, git history, and any backup system.

**Why it happens:**
Settings files often contain placeholder examples with real-looking values. Developers forget these are secrets. Template files meant to be filled at runtime get committed with actual credentials.

**How to avoid:**
1. Never commit `secrets.yaml` — add to `.gitignore`
2. In `settings.json` template, use clearly invalid placeholder values like `YOUR_API_KEY_HERE` not `sk-xxxx`
3. Add pre-commit hook that scans for patterns resembling API keys (sk-, ghp_, Bearer, etc.)
4. Document the "secrets at runtime" requirement prominently in setup.sh output
5. Create a `secrets-template.yaml` showing required structure without real values

**Warning signs:**
- `git log --all --grep="sk-"` returns results in repo history
- `settings.json` contains strings matching `sk-[a-zA-Z0-9]{20,}` pattern
- User reports "my API key is in my dotfiles repo"

**Phase to address:**
Phase 01 (Core Setup) — secrets handling is foundational, must be correct from start.

---

### Pitfall 4: Permission Errors Break Installation

**What goes wrong:**
Script runs as user but tries to create files in directories owned by root or another user (e.g., `/usr/local/bin`, `/etc/claude/`). Installation fails silently or partially — some files get created, others don't.

**Why it happens:**
Claude Code may install plugins or tools to system directories. The script assumes all target paths are user-writable. Different Linux distributions have different conventions for where user-level tools live.

**How to avoid:**
1. Query `$CLAUDE_BASE_DIR` environment variable to find Claude Code's actual config directory
2. Never assume paths — derive them from environment or configuration
3. If permission error occurs: detect, report clearly ("Cannot write to /path — permission denied"), and exit with helpful message
4. Test on clean Ubuntu and Fedora VMs to catch distribution-specific path issues

**Warning signs:**
- `mkdir: cannot create directory '/usr/share/claude/...'` in output
- Installation completes but skills directory is empty
- Error about `/root/.claude/` when running as non-root user

**Phase to address:**
Phase 01 (Core Setup) — correct path detection is prerequisite to any file operations.

---

### Pitfall 5: Idempotency Violation — Running Twice Breaks Things

**What goes wrong:**
User runs setup twice. First run creates a backup file `settings.json.bak`. Second run overwrites `settings.json.bak` thinking it's the real file, or creates duplicate skill entries, or corrupts state.

**Why it happens:**
Idempotency means "safe to run multiple times" — but the implementation has edge cases. Running twice without changes should produce identical state. Instead, the script accumulates backup files or duplicates entries.

**How to avoid:**
1. Track what version of setup has been applied (e.g., `.claude/.setup-version`)
2. Before any write, check if target already matches source — skip if identical
3. Use atomic operations: write to temp file, then rename (prevents partial writes)
4. Maintain a manifest of installed items — check against manifest before installing
5. Test idempotency explicitly: run setup twice in a row, verify second run changes nothing

**Warning signs:**
- Second run produces different output than first run
- `~/.claude/` contains multiple `.bak` files with timestamps
- Log shows "Installing skill X" on every run instead of "Skill X already installed"

**Phase to address:**
Phase 02 (Idempotency & Safety) — this is the defining feature of the safety requirements.

---

### Pitfall 6: Breaking Existing Claude Code State

**What goes wrong:**
User has a working Claude Code setup. They run the dotfiles sync, and afterward:
- MCP servers stop connecting (config format mismatch)
- Custom commands stop working (commands.md format issue)
- Memory context is lost or corrupted (memory file overwritten with stale version)

**Why it happens:**
The dotfiles repo captures a snapshot in time. Running the sync applies that snapshot over the current state. If the user's current state has diverged from the snapshot (new skills learned, new MCP servers configured), sync overwrites with older data.

**How to avoid:**
1. Never sync memory/ context files by default — these are user-created at runtime
2. Implement a sync strategy: `sync --incoming` (pull from dotfiles repo) vs `sync --outgoing` (push to dotfiles repo) vs `sync --merge`
3. For settings.json: only sync keys that are explicitly in the template, preserve user-added keys
4. Default to not touching memory/ — this is explicitly "user-generated at runtime" not "configured once"

**Warning signs:**
- User reports "I lost my conversation context from last week"
- MCP server connections fail after sync
- Custom commands that user added manually are gone

**Phase to address:**
Phase 02 (Idempotency & Safety) — selective sync is core to avoiding this pitfall.

---

### Pitfall 7: No Store/Deploy Separation — Destructive Changes to Live System

**What goes wrong:**
setup.sh runs directly on the host machine and immediately modifies `~/.claude/`. All changes are live — there is no "store" mechanism to snapshot the existing state before changes, and no "deploy" mechanism to safely propagate validated configurations. Running setup.sh on a configured system corrupts the live environment with no rollback path.

**Why it happens:**
The architecture conflates "testing/configuring" with "deploying to live system". There is no Docker-first workflow where:
1. New configurations are built and tested in isolation (Docker)
2. Validated changes are safely deployed to the host

**How to avoid:**
1. **Store mechanism**: Before any sync operation, snapshot existing `~/.claude/` to a timestamped backup directory
2. **Deploy mechanism**: Changes first validated in Docker container, then explicitly "deployed" to host with `setup.sh --deploy`
3. **Docker-first workflow**: All development and testing happens inside `docker compose run test`, never directly on host
4. **Explicit deploy step**: require user to run `setup.sh --deploy` after `--dry-run` confirmation, rather than auto-applying

**Warning signs:**
- setup.sh creates symlinks or modifies files outside of Docker container
- No way to "preview" what would change without actually changing it
- Backup files go to a flat `backups/` directory instead of a versioned store
- No rollback command to restore previous state

**Phase to address:**
Phase 02 (Idempotency & Safety) — store/deploy separation is foundational to safe operation.

---

### Pitfall 8: Testing on Production — No Environment Isolation

**What goes wrong:**
Development and testing happens directly on the host machine. Bugs, typos, or misconfigurations in setup.sh or sync modules immediately affect the user's actual Claude Code environment. The "just test it" approach destroys live configuration.

**Why it happens:**
No documented Docker-based development workflow. setup.sh and sync modules are edited and tested on the host, with "I'll test it in Docker later" being aspirational rather than enforced. Docker volume mounts make host changes easy "for debugging" and become permanent.

**How to avoid:**
1. Enforce Docker-only testing: setup.sh and sync modules must be tested exclusively via `docker compose run test`
2. Volume mounts should be read-only for the test environment when possible
3. Document explicitly: "NEVER run setup.sh directly on host during development"
4. CI/CD pipeline should verify all changes work in Docker before allowing merge
5. Add a `setup.sh --dry-run-in-docker` command that explicitly runs validation in container

**Warning signs:**
- Developer runs `bash setup.sh` directly on host to "test quickly"
- `docker-compose.yml` has volume mounts that write back to host (`.:/app` with read-write)
- No CI verification that setup.sh works in Docker

**Phase to address:**
Phase 01 (Foundation & Core Sync) — Docker-first development workflow must be established from the start.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `cp` instead of `rsync` | Simpler code | Loses permissions, timestamps, ignores hidden files | MVP only, never for production |
| Skip validation after install | Faster development | Silent failures leave broken state | Never |
| Skip `.gitignore` | Works immediately | Secrets leak | Never |
| Hardcode `~/.claude` path | Easy coding | Fails on non-standard installs | Never |
| No dry-run mode | Simpler UX | User can't preview changes | Only if interactive prompts explain everything |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Git | Committing secrets files | Use `git update-index --assume-unchanged` for user-specific files |
| MCP Servers | Wrong JSON format for servers config | Validate JSON structure before writing; MCP config has strict schema |
| Skills | Symlinking entire skill directories | Skills may have their own state files; copy is safer than symlink |
| External tools (jq, fzf) | Assuming tools exist on fresh system | Check tool existence, provide install hints if missing |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Scanning entire home directory | Script takes minutes to run | Only scan known locations (`~/.claude/`, not `~/`) | At 1M+ files in home |
| Large memory/ directory | Sync takes long, produces large diffs | Exclude memory/ from automatic sync or implement delta sync | Memory dir > 100MB |
| Recursive symlink creation | Infinite loop, script hangs | Detect symlink cycles, limit recursion depth | When skills have internal symlinks |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Committing `secrets.yaml` | API keys exposed publicly | Explicit `.gitignore` entry, pre-commit hook |
| Printing secrets to stdout | Secrets in logs, CI output | Never echo secret values; mask in output |
| Storing secrets in environment | Visible in `/proc/*/environ` | Prompt at runtime, never store |
| World-readable dotfiles repo | Others can read your configs and keys | Use private repo, fix permissions with `chmod 700` |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No feedback during install | User thinks script hung | Progress messages for each step |
| Silent failures | User doesn't know something went wrong | Exit with clear error code and message |
| Asking for secrets without explanation | User doesn't understand why | Prompt explains: "API key needed for X feature, stored nowhere, used only for Y" |
| No way to undo | User afraid to try script | Include `setup.sh --revert` that restores from backups |

---

## "Looks Done But Isn't" Checklist

- [ ] **Idempotency:** Script ran twice in a row — does second run produce identical state?
- [ ] **Backup:** Ran on machine with existing config — were old files backed up?
- [ ] **Dry-run:** Did dry-run accurately predict what would change?
- [ ] **Secrets:** Does the repo contain any real API keys or tokens?
- [ ] **Permissions:** Does script work when run as non-root user?
- [ ] **Symlinks:** If using symlinks, did you test after moving the source directory?
- [ ] **Validation:** After install, did you verify skills load, settings apply, memory accessible?

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Overwritten config | MEDIUM | Restore from `.bak.timestamp` files created by script |
| Broken symlinks | LOW | Re-run setup with `--re-link` flag to recreate symlinks from manifest |
| Secrets in git history | HIGH | Use `git filter-repo` to rewrite history; revoke exposed keys immediately |
| Permission errors | LOW | Run with correct user, or manually create missing directories with proper permissions |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Overwriting existing configs | Phase 02: Idempotency & Safety | Test: run on machine with existing config, verify backups created |
| Symlink breakage | Phase 02: Idempotency & Safety | Test: move source directory, verify links or detect breakage |
| Hardcoded secrets | Phase 01: Core Setup | Audit: `grep -r "sk-\\|ghp_\|Bearer" ~/dots/claude-config/` should return nothing |
| Permission errors | Phase 01: Core Setup | Test: run as non-root user on fresh system |
| Idempotency violations | Phase 02: Idempotency & Safety | Test: run setup twice, diff should be empty second time |
| Breaking existing state | Phase 02: Idempotency & Safety | Test: make changes after install, re-run setup, changes should persist |
| Secrets leak | Phase 01: Core Setup | Pre-commit hook validates no secret patterns in commits |
| No feedback during install | Phase 03: Validation & Polish | Manual: observe install, should see progress messages |
| Store/Deploy separation | Phase 02: Idempotency & Safety | Test: snapshot exists before deploy, rollback restores state |
| Environment isolation | Phase 01: Foundation | Test: all changes verified in Docker before touching host |

---

## Sources

- Domain knowledge from established dotfiles management practices (Stow, chezmoi, yadm, bare-git-repo patterns)
- Common community mistakes documented in dotfiles Reddit/DevOps discussions
- Claude Code configuration requirements from project requirements
- Note: WebSearch unavailable for this research; confidence MEDIUM due to reliance on training data

---
*Pitfalls research for: Claude Code Environment Replay / dotfiles management*
*Researched: 2026-03-29*
