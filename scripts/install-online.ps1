# install-online.ps1 — Install Claude Code notification hooks via irm|iex.
# Downloads the latest GitHub Release, extracts, and delegates to install.ps1.
#
# Usage:
#   iex (irm https://raw.githubusercontent.com/hlwqds/notify-research/main/scripts/install-online.ps1)
#   iex "& { $(irm ...) } -Voice deep"
#
# Parameters are passed through to install.ps1 (per D-12).

param(
    [string]$Voice
)

$ErrorActionPreference = "Stop"
$GITHUB_REPO = "hlwqds/notify-research"

Write-Host "Fetching latest release for $GITHUB_REPO ..."

# --- Get latest release tag (per D-08: always latest) ---
try {
    $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$GITHUB_REPO/releases/latest" -ErrorAction Stop
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 404) {
        Write-Error "ERROR: No GitHub releases found for $GITHUB_REPO."
        Write-Host "  The project may not have published any releases yet." -ForegroundColor Yellow
        Write-Host "  Alternative: git clone https://github.com/$GITHUB_REPO.git; cd notify-research; powershell -File scripts/install.ps1 -RepoPath ." -ForegroundColor Yellow
        exit 1
    } elseif ($statusCode -eq 403) {
        Write-Error "ERROR: GitHub API rate limit exceeded (60 requests/hour for unauthenticated)."
        Write-Host "  Wait a few minutes or set GITHUB_TOKEN env var for higher limits." -ForegroundColor Yellow
        exit 1
    } else {
        Write-Error "ERROR: Failed to connect to GitHub API (HTTP $statusCode). Check your network connection."
        Write-Host "  Alternative: git clone https://github.com/$GITHUB_REPO.git; cd notify-research; powershell -File scripts/install.ps1 -RepoPath ." -ForegroundColor Yellow
        exit 1
    }
}

$latestTag = $response.tag_name
if (-not $latestTag) {
    Write-Error "ERROR: Failed to parse release tag from GitHub API."
    exit 1
}

Write-Host "Latest release: $latestTag"

# --- Download and extract source archive ---
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "notify-install-$(Get-Random)"
try {
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    $archiveUrl = "https://github.com/$GITHUB_REPO/archive/refs/tags/$latestTag.tar.gz"
    $archivePath = Join-Path $tmpDir "archive.tar.gz"

    Write-Host "Downloading $archiveUrl ..."

    try {
        Invoke-WebRequest -Uri $archiveUrl -OutFile $archivePath -ErrorAction Stop
    } catch {
        Write-Error "ERROR: Failed to download archive."
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    # Extract using tar (available since Windows 10 17063, per Pitfall 5)
    Write-Host "Extracting archive ..."
    try {
        tar xzf $archivePath -C $tmpDir
    } catch {
        Write-Error "ERROR: Failed to extract archive. 'tar' command may not be available on your system."
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    # Find extracted directory (per Pitfall 1)
    $extractedDir = Get-ChildItem -Path $tmpDir -Directory | Where-Object { $_.Name -like "notify-research-*" } | Select-Object -First 1

    if (-not $extractedDir) {
        Write-Error "ERROR: Extraction failed - could not find extracted directory."
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    Write-Host "Running install.ps1 from $($extractedDir.FullName) ..."
    Write-Host ""

    # Build install.ps1 arguments
    $installArgs = @("-RepoPath", $extractedDir.FullName)
    if ($Voice) {
        $installArgs += "-Voice"
        $installArgs += $Voice
    }

    # Delegate to install.ps1
    pwsh -File (Join-Path $extractedDir.FullName "scripts\install.ps1") @installArgs

} finally {
    Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
