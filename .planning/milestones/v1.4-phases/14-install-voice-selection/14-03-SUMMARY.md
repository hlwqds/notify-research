# Phase 14 Plan 03 Summary — One-Liner Installers

Created curl|bash and irm|iex one-liner installers to enable seamless installation of the notification system without requiring manual git clone.

## Changes

### `scripts/install-online.sh`
- Created a thin wrapper for Linux/macOS.
- Queries GitHub API for the latest release tag.
- Downloads the source tarball, extracts it to a temporary directory.
- Delegates to `scripts/install.sh` with all command-line arguments passed through.
- Handles API errors (404, 403) and provides git-clone fallbacks.
- Cleans up temporary files on exit.

### `scripts/install-online.ps1`
- Created a thin wrapper for Windows.
- Queries GitHub API for the latest release tag via `Invoke-RestMethod`.
- Downloads and extracts the source archive using `tar` (available in modern Windows).
- Delegates to `scripts/install.ps1` using the `-RepoPath` parameter and optional `-Voice` parameter.
- Handles API errors and provides git-clone fallbacks.
- Cleans up temporary files in a `finally` block.

## Verification Results

- [x] `scripts/install-online.sh` exists and is executable.
- [x] `scripts/install-online.sh` contains `GITHUB_REPO` and `releases/latest`.
- [x] `scripts/install-online.sh` delegates to `install.sh` and passes `"$@"`.
- [x] `scripts/install-online.sh` handles 404/403 errors.
- [x] `scripts/install-online.ps1` exists.
- [x] `scripts/install-online.ps1` contains `GITHUB_REPO` and `releases/latest`.
- [x] `scripts/install-online.ps1` delegates to `install.ps1`.
- [x] `scripts/install-online.ps1` handles 404/403 errors.
