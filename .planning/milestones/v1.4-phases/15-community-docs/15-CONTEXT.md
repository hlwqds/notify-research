# Phase 15: Community & Docs - Context

## Goals
Finalize the project for community discovery by establishing a permissive license, overhauling the README to favor the plugin system, and recommending GitHub topic tags for visibility.

## Decisions
- **License**: Adopt the **MIT License**. Remove all references to Apache 2.0.
- **Primary Install**: Document the Claude Code `/plugin` system as the first and best way to install.
- **Secondary Install**: Document `curl | bash` and `irm | iex` as the seamless one-liner alternatives.
- **GitHub Tags**: Apply `claude-code`, `hooks`, `notifications`, `tts`.
- **Project Name**: Use "Claude Code Voice Notifications" consistently in documentation.

## the agent's Discretion
- **Submission**: the agent should provide a clear list of community "Awesome" repositories to submit the project to.
- **README Tone**: Focus on ease of use and "Zero-config" experience.
- **Troubleshooting**: Include a small "Requirements" section for `jq`, `afplay` (macOS), and `paplay` (Linux).

## Deferred Ideas
- **npm Package**: Distributing as a global npm package is deferred as it adds complexity without matching the native plugin experience.
- **Official Marketplace Entry**: Deferred until the submission process is publicly documented by Anthropic.
