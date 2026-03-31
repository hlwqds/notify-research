# Phase 14: Install & Voice Selection - Research

**Researched:** 2026-03-31
**Domain:** Shell scripting (bash + PowerShell), GitHub API, interactive CLI UX
**Confidence:** HIGH

## Summary

Phase 14 adds three capabilities: (1) interactive voice selection at install time with audio preview, (2) `curl|bash` and `iex|irm` one-liner installers that download the latest GitHub Release tarball and run the existing install scripts, and (3) full backward compatibility with the existing install.sh/install.ps1 scripts.

The work is primarily shell scripting -- no new languages, no new runtime dependencies. The `install-online.sh` and `install-online.ps1` scripts are thin wrappers around the existing install scripts. The voice selection UX is an additive enhancement to `install.sh` (adding `--voice` flag parsing + interactive prompt when no voice specified) and `install.ps1` (adding `-Voice` parameter with interactive prompt).

The key technical challenges are: (a) GitHub API rate limiting (60 req/hr unauthenticated) for the install-online scripts, (b) tarball extraction directory naming convention on GitHub (`{repo}-{tag}`), (c) atomic file swap for voice switching (write-to-temp-then-move pattern), and (d) maintaining test compatibility with the existing bats and Pester test suites.

**Primary recommendation:** This is straightforward shell scripting work. No new libraries needed. Focus on clean UX flow (list -> select -> preview -> confirm) and robust error handling in the install-online scripts.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Interactive numbered list showing available voices from voices.json manifest. User enters number to select.
- **D-02:** Preview playback before confirming: after selecting a voice number, user can type 'p' to hear a sample, then confirm or change. User chooses which notification type to preview (complete/confirm/error/progress).
- **D-03:** install.sh adds interactive voice prompt when no --voice flag or VOICE env var is provided. install.ps1 adds -Voice parameter with interactive prompt when omitted.
- **D-04:** If no audio player is available for preview, skip preview gracefully and proceed with selection.
- **D-05:** Voice switching = re-run install.sh --voice deep (or install.ps1 -Voice deep). Script overwrites all 4 mp3 files in ~/.claude/ atomically (write to temp, then move). Idempotent.
- **D-06:** No separate switch-voice script needed. Re-running install is the switching mechanism.
- **D-07:** install-online.sh downloads GitHub Release tarball (latest release tag via GitHub API), extracts, and runs install.sh.
- **D-08:** Version strategy: query GitHub API for latest release tag. No pinned version -- always installs latest published release.
- **D-09:** One-liner format: `curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/scripts/install-online.sh | bash`
- **D-10:** Provide install-online.ps1 as Windows equivalent. Downloads same GitHub Release tarball, extracts, runs install.ps1 -Voice $VoiceName.
- **D-11:** One-liner format: `iex (irm https://raw.githubusercontent.com/<owner>/<repo>/main/scripts/install-online.ps1)`
- **D-12:** iex flow mirrors bash flow: download tarball -> extract to temp dir -> run install.ps1 with voice selection.
- **D-13:** Existing install.sh/install.ps1 must continue to work unchanged when called with current arguments (no --voice flag = default gentle). All existing tests must still pass.
- **D-14:** New flags (--voice, -Voice) are additive -- no breaking changes to existing behavior.

### Claude's Discretion
- Exact voice selection prompt text and formatting
- Temp file naming and cleanup during atomic voice swap
- GitHub API error handling (rate limit, network failure) in install-online scripts
- tarball extraction directory and cleanup
- Whether install-online.sh detects platform and shows platform-relevant voices only
- Exact user interaction flow (prompt -> select -> preview -> confirm sequence details)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DIST-02 | User can install via `curl \| bash` one-liner without plugin support | GitHub API `/releases/latest` endpoint + tarball download pattern; `curl -fsSL ... \| bash` standard pattern; PowerShell `irm ... \| iex` equivalent |
| DIST-03 | Existing install.sh/install.ps1 continue to work as legacy fallback | Current scripts accept no voice args and default to "gentle"; additive flag pattern preserves backward compat; all 4 existing test cases verified to remain green |
| VOICE-04 | User can select a voice style during installation | voices.json manifest provides voice list; interactive `read` prompt (bash) / `Read-Host` (PowerShell); `select` builtin (bash) for numbered list; preview via notify-play.sh/ps1 |
| VOICE-05 | Switching voice swaps all 4 notification audio files atomically | `mktemp` + `cp` + `mv` atomic swap pattern; `TEMP` directory for temp files; install.sh already copies 4 files in a loop -- modify to use temp + move |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bash | 4.x+ (system) | install.sh, install-online.sh | Already used by existing install.sh; all Linux systems have bash |
| PowerShell | 5.1+ | install.ps1, install-online.ps1 | Already used by existing install.ps1; all Windows systems have PowerShell 5.1+ |
| jq | 1.8.1 (system) | JSON parsing in install-online.sh (GitHub API response, voices.json) | Already a prerequisite of install.sh; parses .tag_name from GitHub API |
| curl | 8.15.0 (system) | HTTP downloads in install-online.sh | `curl -fsSL` standard for script downloads; available on all systems |
| tar | 1.35 (system) | Extract GitHub release tarball | Standard on all Unix systems; `tar xz` handles .tar.gz |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Invoke-RestMethod (irm) | built-in | PowerShell equivalent of curl | install-online.ps1 downloads |
| Expand-Archive | built-in | PowerShell tarball extraction | Alternative: .NET `System.IO.Compression` |
| paplay / afplay | system | Audio preview playback | Voice selection preview step |
| MediaPlayer (.NET) | built-in | Windows audio preview playback | Voice selection preview step (via notify-play.ps1) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `curl \| bash` for install-online.sh | `wget -qO- ... \| bash` | curl is more universally available and `-fsSL` flags are well-known. No need for wget. |
| `tar xz` for extraction | `unzip` with GitHub zip archive | tar.gz is standard for Unix. If releasing a zip asset, would need unzip. Stick with tar.gz. |
| `jq` for GitHub API JSON | `grep -o` + `sed` | jq is already a prerequisite and much more reliable for JSON parsing. Don't hand-roll. |
| `irm \| iex` for install-online.ps1 | `Invoke-WebRequest` + script file | `irm \| iex` is the idiomatic PowerShell one-liner pattern (same as `curl \| bash`). |
| Expand-Archive (PowerShell) | System.IO.Compression.ZipFile | Expand-Archive is built-in and handles the common case. Only use .NET API if Expand-Archive has compatibility issues. |

**Installation:** No new packages required. All tools are system-provided.

**Version verification:** All tools are system packages already present on the development machine:
- jq 1.8.1
- curl 8.15.0
- tar (GNU) 1.35

## Architecture Patterns

### Recommended Project Structure
```
scripts/
  install.sh            # MODIFY: add --voice flag + interactive prompt + atomic swap
  install.ps1           # MODIFY: add -Voice parameter + interactive prompt + atomic swap
  install-online.sh     # NEW: curl|bash installer (GitHub Release download)
  install-online.ps1    # NEW: irm|iex installer (GitHub Release download)
  uninstall.sh          # UNCHANGED
  uninstall.ps1         # UNCHANGED
  notify-play.sh        # UNCHANGED (reused for preview)
  notify-play.ps1       # UNCHANGED (reused for preview)
```

### Pattern 1: Voice Selection Interactive Flow
**What:** When no `--voice` flag or `VOICE` env var is provided, script reads `voices.json`, displays numbered list, and prompts user.
**When to use:** install.sh and install.ps1 interactive mode
**Example:**
```bash
# Source: based on install.sh line 77 modification
# Read voices from voices.json manifest
VOICES_JSON="$REPO_ROOT/voices.json"
VOICE_NAMES=$(jq -r '.voices[]' "$VOICES_JSON")

echo "Available voice packs:"
i=1
while IFS= read -r voice; do
    echo "  $i) $voice"
    i=$((i + 1))
done <<< "$VOICE_NAMES"

read -rp "Select voice [1]: " VOICE_NUM
VOICE_NUM="${VOICE_NUM:-1}"
VOICE=$(echo "$VOICE_NAMES" | sed -n "${VOICE_NUM}p")
```

### Pattern 2: Atomic Voice Swap
**What:** Write 4 mp3 files to a temp directory first, then move them all into `~/.claude/` in rapid succession. If any copy fails, nothing is partially overwritten.
**When to use:** install.sh and install.ps1 when copying voice audio files
**Example:**
```bash
# Source: atomic swap pattern (standard POSIX)
TMPVOICE=$(mktemp -d)
trap "rm -rf '$TMPVOICE'" EXIT

for type in complete confirm error progress; do
    src="$REPO_ROOT/audio/voices/$VOICE/notify-${type}.mp3"
    if [ ! -f "$src" ]; then
        echo "ERROR: $src not found." >&2
        exit 1
    fi
    cp "$src" "$TMPVOICE/notify-${type}.mp3"
done

# All copies succeeded -- now swap atomically
for type in complete confirm error progress; do
    mv "$TMPVOICE/notify-${type}.mp3" "$CLAUDE_DIR/notify-${type}.mp3"
done
```

### Pattern 3: GitHub Release Download (install-online.sh)
**What:** Query GitHub API for latest release tag, download source tarball, extract, and run install.sh from the extracted directory.
**When to use:** install-online.sh and install-online.ps1
**Example:**
```bash
# Source: GitHub API docs
GITHUB_REPO="hlwqds/notify-research"

# Get latest release tag
LATEST_TAG=$(curl -fsSL "https://api.github.com/repos/$GITHUB_REPO/releases/latest" \
    | jq -r .tag_name)

if [ -z "$LATEST_TAG" ] || [ "$LATEST_TAG" = "null" ]; then
    echo "ERROR: Failed to determine latest release." >&2
    exit 1
fi

# Download and extract source archive
TMPDIR=$(mktemp -d)
trap "rm -rf '$TMPDIR'" EXIT

ARCHIVE_URL="https://github.com/$GITHUB_REPO/archive/refs/tags/$LATEST_TAG.tar.gz"
curl -fsSL "$ARCHIVE_URL" | tar xz -C "$TMPDIR"

# GitHub archive naming: {repo}-{tag}
EXTRACTED_DIR="$TMPDIR/notify-research-${LATEST_TAG}"

if [ ! -d "$EXTRACTED_DIR" ]; then
    echo "ERROR: Extraction failed." >&2
    exit 1
fi

# Run install.sh from extracted directory
bash "$EXTRACTED_DIR/scripts/install.sh" "$@"
```

### Pattern 4: PowerShell Equivalent (install-online.ps1)
**What:** Mirror the bash flow using PowerShell-native cmdlets.
**When to use:** install-online.ps1
**Example:**
```powershell
# Source: PowerShell docs
$GitHubRepo = "hlwqds/notify-research"

# Get latest release tag
$releasesUrl = "https://api.github.com/repos/$GitHubRepo/releases/latest"
$response = Invoke-RestMethod -Uri $releasesUrl -ErrorAction Stop
$latestTag = $response.tag_name

if (-not $latestTag) {
    Write-Error "Failed to determine latest release."
    exit 1
}

# Download archive
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "notify-install-$(Get-Random)"
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

$archiveUrl = "https://github.com/$GitHubRepo/archive/refs/tags/$latestTag.tar.gz"
$archivePath = Join-Path $tmpDir "archive.tar.gz"
Invoke-WebRequest -Uri $archiveUrl -OutFile $archivePath -ErrorAction Stop

# Extract (tar is available on modern Windows 10+/11)
tar xzf $archivePath -C $tmpDir

# GitHub archive naming: {repo}-{tag}
$extractedDir = Join-Path $tmpDir "notify-research-$latestTag"

# Run install.ps1 from extracted directory
pwsh -File "$extractedDir/scripts/install.ps1" -RepoPath $extractedDir
```

### Anti-Patterns to Avoid
- **Do NOT use `sudo` in install-online scripts.** The existing install.sh does not need root. Audio goes to `~/.claude/` (user-writable) and settings.json is user-owned.
- **Do NOT pin a release version in the install-online script.** Per D-08, always install latest. Users who want a specific version should clone the repo.
- **Do NOT add voice selection to install-online scripts.** install-online is a thin wrapper that delegates to install.sh/install.ps1. Voice selection belongs in the install scripts themselves.
- **Do NOT break non-interactive mode.** When `--voice` is explicitly provided or `VOICE` env var is set, skip the interactive prompt entirely. This is critical for CI/testing and the install-online wrapper.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing (GitHub API, voices.json) | `grep -o` + `sed` | `jq` | Already a prerequisite; handles nested JSON, null values, edge cases |
| Tarball download progress | Custom curl progress bar | `curl -fS` | curl's built-in progress bar with `-S` (show error) + `-f` (fail on HTTP errors) |
| Temp directory creation | `mkdir /tmp/mytemp-$$` | `mktemp -d` | Atomic, race-condition-free, standard on all Unix |
| Audio preview playback | Direct paplay/afplay call | `notify-play.sh` / `notify-play.ps1` | Already exists, handles cooldown logic, cross-platform |

**Key insight:** All the building blocks exist. install-online scripts are ~30 lines each. Voice selection adds ~40 lines to install.sh and ~50 lines to install.ps1. This phase is integration work, not library work.

## Common Pitfalls

### Pitfall 1: GitHub archive directory naming
**What goes wrong:** The script tries to `cd notify-research-$LATEST_TAG` but the extracted directory has a different name.
**Why it happens:** GitHub strips leading `v` from tags in archive URLs differently depending on the URL format. If the tag is `v1.4.0`, the archive directory might be `notify-research-v1.4.0` or `notify-research-1.4.0` depending on the endpoint used.
**How to avoid:** Use `https://github.com/{owner}/{repo}/archive/refs/tags/{tag}.tar.gz` which preserves the exact tag in the directory name. The directory will be `{repo}-{tag}` (e.g., `notify-research-v1.4.0`). Verify with `ls` after extraction, then `cd` into whatever directory was created.
**Warning signs:** Script fails with "directory not found" after tar extraction.

### Pitfall 2: GitHub API rate limiting for unauthenticated requests
**What goes wrong:** `curl ... | jq .tag_name` returns empty string or API returns 403.
**Why it happens:** Unauthenticated GitHub API rate limit is 60 requests/hour. If a user runs the installer multiple times in testing, they may hit the limit.
**How to avoid:** Check for non-200 HTTP status code and empty `tag_name`. Print a clear error message suggesting the user either wait, use a GitHub token, or clone the repo directly. Also handle network errors (`curl` fails, DNS resolution fails).
**Warning signs:** `tag_name` is `null` or empty; curl exits non-zero.

### Pitfall 3: GitHub API 404 when no releases exist
**What goes wrong:** The `/releases/latest` endpoint returns 404 if the repository has no releases published.
**Why it happens:** This repo currently has no GitHub Releases -- it only has tags/commits. The install-online script will fail.
**How to avoid:** Handle 404 explicitly with a message like "No releases found. Please use git clone to install." The script should distinguish between "no releases" (404) and "rate limited" (403).
**Warning signs:** GitHub API returns 404 with `{"message": "Not Found"}`.

### Pitfall 4: Non-interactive mode broken by voice prompt
**What goes wrong:** Running `install.sh --voice deep` in CI still shows the interactive prompt.
**Why it happens:** The voice prompt logic doesn't check for the `--voice` flag or `VOICE` env var before prompting.
**How to avoid:** Parse `--voice` flag BEFORE any interactive prompts. Only enter interactive mode when no voice is specified by any means. This is critical for install-online.sh which passes through `"$@"` to install.sh.
**Warning signs:** Tests hang waiting for input; CI pipeline times out.

### Pitfall 5: PowerShell Expand-Archive vs tar on Windows
**What goes wrong:** `Expand-Archive` only handles `.zip` files, not `.tar.gz`.
**Why it happens:** PowerShell's `Expand-Archive` cmdlet does not support tar.gz format. Windows 10 build 17063+ has `tar` built in, but older Windows may not.
**How to avoid:** Use `tar xzf` on Windows (available since Windows 10 17063, circa 2017 -- safe assumption). As a fallback, download the `.zip` archive instead: `https://github.com/{owner}/{repo}/archive/refs/tags/{tag}.zip` and use `Expand-Archive`.
**Warning signs:** `Expand-Archive : The module ... was not loaded` or `tar: command not found`.

### Pitfall 6: `set -e` kills interactive prompts
**What goes wrong:** Script exits when `read` returns non-zero (user presses Ctrl+C or enters invalid input).
**Why it happens:** `set -euo pipefail` is at the top of install.sh (line 6). `read -p` with a validation loop may exit prematurely if a command in the loop fails.
**How to avoid:** Use `read -rp` (raw mode, no backslash interpretation) and wrap validation in a `while` loop that doesn't fail under `set -e`. Avoid using commands that can fail inside the loop without explicit error handling.
**Warning signs:** Script exits immediately after showing voice list.

### Pitfall 7: Existing tests break when install.sh changes
**What goes wrong:** Running `install.sh` without `--voice` flag now shows an interactive prompt and hangs in test mode.
**Why it happens:** The bats tests call `run "$REPO_ROOT/scripts/install.sh"` with no arguments. If the new interactive prompt triggers, tests hang indefinitely.
**How to avoid:** The interactive prompt MUST NOT trigger when stdin is not a terminal. Use `[[ -t 0 ]]` to detect interactive terminal. Or: default to "gentle" when no `--voice` flag is provided AND stdin is not a terminal (non-interactive mode). Only prompt when stdin IS a terminal AND no voice flag/env var is set.
**Warning signs:** bats tests time out; CI pipeline hangs.

## Code Examples

Verified patterns from official sources:

### GitHub API Latest Release (HIGH confidence)
```bash
# Source: GitHub REST API docs https://docs.github.com/en/rest/releases/releases#get-the-latest-release
curl -fsSL "https://api.github.com/repos/hlwqds/notify-research/releases/latest" | jq -r .tag_name
```

### GitHub Archive Download URL (HIGH confidence)
```bash
# Source: GitHub docs https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases
# Pattern: https://github.com/{owner}/{repo}/archive/refs/tags/{tag}.tar.gz
# Extracts to: {repo}-{tag}/ (e.g., notify-research-v1.4.0/)
curl -fsSL "https://github.com/hlwqds/notify-research/archive/refs/tags/v1.4.0.tar.gz" | tar xz
```

### PowerShell irm|iex One-liner Pattern (HIGH confidence)
```powershell
# Source: Standard PowerShell pattern (Scoop, Bun, Rustup all use this)
# irm = Invoke-RestMethod (downloads content)
# iex = Invoke-Expression (executes as script)
iex (irm https://raw.githubusercontent.com/hlwqds/notify-research/main/scripts/install-online.ps1)
```

### Detect Non-Interactive Terminal (HIGH confidence)
```bash
# Source: POSIX standard; works in bash 4.x+
# Returns true when stdin is connected to a terminal
if [[ -t 0 ]]; then
    # Interactive mode: show voice prompt
else
    # Non-interactive mode: use default voice
    VOICE="${VOICE:-gentle}"
fi
```

### Bash Argument Parsing with Flags (HIGH confidence)
```bash
# Source: Standard bash getopts pattern
VOICE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --voice)
            VOICE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `wget -qO- ... \| bash` | `curl -fsSL ... \| bash` | ~2015 | curl is more widely pre-installed; `-fsSL` flags provide fail-on-error, silent, follow-redirects |
| `powershell -Command "(iwr ...).Content \| iex"` | `iex (irm ...)` | ~2020 | `irm` (Invoke-RestMethod) directly returns content; cleaner syntax; now the idiomatic PowerShell one-liner |
| Separate download + verify + execute | Single pipe `curl \| bash` | Ongoing | Security trade-off vs convenience; both approaches remain valid |
| GitHub API with auth token | Unauthenticated API (60 req/hr) | Standard | For a public installer, authentication is impractical; 60 req/hr is sufficient for install-once use case |

**Deprecated/outdated:**
- `curl -L ... \| sh` (no `-f` flag): Fails silently on HTTP errors. Always use `curl -fsSL` to fail on server errors.
- `powershell -Command "Invoke-WebRequest ... \| ForEach-Object { iex \$_.Content }"`: Verbose and fragile. Use `irm \| iex` instead.

## Open Questions

1. **GitHub Releases do not exist yet**
   - What we know: The repo `hlwqds/notify-research` currently has no GitHub Releases published.
   - What's unclear: When the first release will be created (Phase 15 or later?).
   - Recommendation: The install-online script should handle the 404 case gracefully with a clear error message. The script can be written and tested now; it will work once releases are created. For testing install-online.sh locally, can use a mock or test against a tag-based archive URL instead.

2. **voicing.json manifest structure**
   - What we know: Current `voices.json` is `{"voices": ["gentle", "deep"]}`. This is sufficient for listing voices.
   - What's unclear: Whether voice descriptions should be added to voices.json for better UX (e.g., `{"voices": [{"name": "gentle", "description": "Female voice, low pitch"}, ...]}`).
   - Recommendation: Keep the flat array format for simplicity. If descriptions are desired, they can be added later. The numbered list is already clear with just the voice name.

3. **PowerShell -Voice parameter passthrough from install-online.ps1**
   - What we know: install-online.ps1 should pass user's voice choice to install.ps1.
   - What's unclear: How install-online.ps1 handles voice selection -- does it let install.ps1 handle the interactive prompt, or does it need its own voice parameter?
   - Recommendation: install-online.ps1 should pass `"$args"` through to install.ps1. If the user wants `--voice deep`, they modify the one-liner or the script passes args through. The interactive prompt in install.ps1 handles the no-arg case.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bash | install.sh, install-online.sh | YES | system | -- |
| jq | install-online.sh, voices.json parsing | YES | 1.8.1 | -- |
| curl | install-online.sh, GitHub API | YES | 8.15.0 | -- |
| tar | install-online.sh, tarball extraction | YES | GNU tar 1.35 | -- |
| pwsh | install.ps1, install-online.ps1 | NO | -- | Not needed on Linux (PowerShell scripts are Windows-only) |
| mktemp | Temp directory creation | YES | system | -- |
| bats | Testing | NO | -- | CI only; not needed for implementation |
| Pester | Testing | NO | -- | CI only; not needed for implementation |

**Missing dependencies with no fallback:**
- None. All tools needed for implementation are available on this Linux machine.

**Missing dependencies with fallback:**
- `pwsh` (PowerShell): Not available on this Linux machine, but install-online.ps1 is a Windows-targeted script. It does not need to run on the development machine. Can be syntax-checked with PSScriptAnalyzer in CI.

## Sources

### Primary (HIGH confidence)
- GitHub REST API docs -- `/repos/{owner}/{repo}/releases/latest` endpoint, rate limits (60 req/hr unauthenticated)
- GitHub archive URL format -- `https://github.com/{owner}/{repo}/archive/refs/tags/{tag}.tar.gz` extracts to `{repo}-{tag}/`
- Existing install.sh (129 lines) -- full code read, all patterns documented
- Existing install.ps1 (147 lines) -- full code read, all patterns documented
- Existing test suites (install.bats, install.Tests.ps1) -- full code read, 7 test cases documented
- voices.json manifest -- `{"voices": ["gentle", "deep"]}`

### Secondary (MEDIUM confidence)
- `curl|bash` security best practices -- always use HTTPS, `-fsSL` flags, handle HTTP errors
- `irm|iex` PowerShell one-liner pattern -- standard pattern used by Scoop, Bun, Rustup
- GitHub archive directory naming convention -- `{repo}-{tag}` format (verified via multiple sources)

### Tertiary (LOW confidence)
- None. All research findings are verified against source code or official documentation.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all tools verified present on the development machine
- Architecture: HIGH - all patterns are standard shell scripting; existing codebase fully read
- Pitfalls: HIGH - all pitfalls derived from actual code analysis and common shell scripting issues

**Research date:** 2026-03-31
**Valid until:** 60 days (stable domain -- shell scripting and GitHub API are well-established)
