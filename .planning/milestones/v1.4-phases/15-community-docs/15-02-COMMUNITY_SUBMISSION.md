# GitHub Discovery & Community Submission Guide

**Phase:** 15 - Community & Docs
**Purpose:** Finalize GitHub repository discovery settings and prepare community submission content.
**Status:** Draft — requires human action to apply settings and submit.

---

## 1. GitHub Repository Metadata

Apply these settings via **GitHub → Settings → General** or the GitHub API.

### Description

```
Cross-platform voice notifications for Claude Code (macOS, Linux, Windows). Get audio alerts when tasks finish, fail, or need input.
```

### Topic Tags

Add these to **Settings → Topics** (comma-separated):

```
claude-code, hooks, notifications, tts, accessibility, audio-alerts, voice-assistant
```

| Tag | Why |
|-----|-----|
| `claude-code` | Primary discovery keyword for Claude Code users |
| `hooks` | Claude Code hooks system |
| `notifications` | Core functionality |
| `tts` | Text-to-speech technology used |
| `accessibility` | Audio alerts enable screen-free monitoring |
| `audio-alerts` | Alternative discovery term |
| `voice-assistant` | Broader AI voice ecosystem |

### Homepage URL

```
https://github.com/hlwqds/notify-research#readme
```

---

## 2. Community Submission: Awesome Claude Code

**Repository:** [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code)

### Submission Method

Open an issue or PR with the following entry:

**Category:** Plugins / Hooks

```markdown
- [Claude Code Voice Notifications](https://github.com/hlwqds/notify-research) - Cross-platform voice notifications for Claude Code. Multiple voices (gentle, deep), dual-platform hooks, one-liner install. MIT License.
```

### Alternative Lists

Consider also submitting to:

| List | URL | Notes |
|------|-----|-------|
| Awesome Claude | Search GitHub for active lists | Check if it accepts plugins |
| Reddit r/ClaudeAI | https://reddit.com/r/ClaudeAI | Share as a "Show Claude" post |

---

## 3. Pre-Submission Checklist

Before submitting to any community list:

- [ ] **CI badge is green** — check [GitHub Actions](https://github.com/hlwqds/notify-research/actions)
- [ ] **MIT License is visible** — confirm it appears on the repo sidebar
- [ ] **README renders correctly** — preview at github.com/hlwqds/notify-research
- [ ] **Description and topics are set** — verify on repo homepage
- [ ] **Repository is public** — community lists require public repos

---

## 4. GitHub API (Optional Automation)

If you prefer to set metadata via the GitHub CLI:

```bash
# Set repository description
gh repo edit hlwqds/notify-research \
  --description "Cross-platform voice notifications for Claude Code (macOS, Linux, Windows). Get audio alerts when tasks finish, fail, or need input."

# Set topic tags
gh repo edit hlwqds/notify-research \
  --add-topic claude-code \
  --add-topic hooks \
  --add-topic notifications \
  --add-topic tts \
  --add-topic accessibility \
  --add-topic audio-alerts \
  --add-topic voice-assistant
```

---

_Generated as part of Phase 15 (Community & Docs). Requires human action to apply._
