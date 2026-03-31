# tests/powershell/notify-play.Tests.ps1 -- Tests for notify-play.ps1
# Covers: PS-01 (cooldown skip), PS-02 (cooldown pass),
#         PS-03 (MediaPlayer mock), PS-04 (always exit 0)

Describe "notify-play.ps1 cooldown and playback" {
    BeforeAll {
        $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        if (-not (Test-Path (Join-Path $RepoRoot "tests" "fixtures" "settings.json"))) {
            $RepoRoot = (Get-Item .).FullName
        }
    }

    BeforeEach {
        # Dot-source to load function definitions (invocation guard prevents main from running)
        . "$RepoRoot/scripts/notify-play.ps1" -Type "complete" -AudioFile "$RepoRoot/audio/voices/gentle/notify-complete.mp3"

        # Isolate lock directory (per D-02, D-06)
        $TestDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-notify-$(Get-Random)"
        New-Item -ItemType Directory -Path $TestDir -Force | Out-Null
        $env:NOTIFY_LOCK_DIR = $TestDir
    }

    AfterEach {
        Remove-Item -Path $TestDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item Env:NOTIFY_LOCK_DIR -ErrorAction SilentlyContinue
    }

    It "skips playback when lock file is younger than 5 seconds (PS-01)" {
        # Create recent lock file
        $lockFile = Join-Path $env:NOTIFY_LOCK_DIR "claude-notify-complete.lock"
        Set-Content -Path $lockFile -Value "recent" -NoNewline

        Mock Invoke-MediaPlayer {}

        Invoke-NotifyPlayCore -Type "complete" -AudioFile "$RepoRoot/audio/voices/gentle/notify-complete.mp3"

        Should -Invoke Invoke-MediaPlayer -Times 0 -Exactly
    }

    It "plays audio when lock file is older than 5 seconds (PS-02)" {
        $lockFile = Join-Path $env:NOTIFY_LOCK_DIR "claude-notify-complete.lock"
        Set-Content -Path $lockFile -Value "old" -NoNewline

        # Set mtime to 10 seconds ago
        (Get-Item $lockFile).LastWriteTime = (Get-Date).AddSeconds(-10)

        Mock Invoke-MediaPlayer {}

        Invoke-NotifyPlayCore -Type "complete" -AudioFile "$RepoRoot/audio/voices/gentle/notify-complete.mp3"

        Should -Invoke Invoke-MediaPlayer -Times 1 -Exactly
    }

    It "mocks MediaPlayer without real audio hardware (PS-03)" {
        # No lock file -- cooldown passes immediately
        Mock Invoke-MediaPlayer {}

        Invoke-NotifyPlayCore -Type "error" -AudioFile "$RepoRoot/audio/voices/gentle/notify-error.mp3"

        # Verify the mock was called with the correct AudioFile parameter
        Should -Invoke Invoke-MediaPlayer -Times 1 -Exactly -ParameterFilter {
            $AudioFile -like "*notify-error.mp3*"
        }
    }

    It "always exits 0 even when playback fails (PS-04)" {
        # PS-04 MUST use child process invocation (not dot-source)
        # because we're testing the script's exit code behavior
        # Use pwsh -File which runs in a child process (bypasses invocation guard)
        $result = pwsh -File "$RepoRoot/scripts/notify-play.ps1" -Type "complete" -AudioFile "/nonexistent/file.mp3" 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}
