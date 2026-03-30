# tests/powershell/uninstall.Tests.ps1 -- Tests for uninstall.ps1
# Covers: PS-09 (4 hook removal), PS-10 (empty hooks cleanup),
#         PS-11 (mp3 deletion), PS-12 (idempotent re-run)

Describe "uninstall.ps1 hook removal and cleanup" {
    BeforeEach {
        # Isolate USERPROFILE to temp directory (per D-02, D-06)
        $TestHome = Join-Path ([System.IO.Path]::GetTempPath()) "pester-uninstall-$(Get-Random)"
        New-Item -ItemType Directory -Path $TestHome -Force | Out-Null
        $env:USERPROFILE = $TestHome

        # Create .claude directory with fixture settings.json
        $ClaudeDir = Join-Path $TestHome ".claude"
        New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
        Copy-Item /app/tests/fixtures/settings.json (Join-Path $ClaudeDir "settings.json")

        # Run install to populate hooks before testing uninstall (child process)
        pwsh -File /app/scripts/install.ps1 -RepoPath /app
    }

    AfterEach {
        Remove-Item -Path $TestHome -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item Env:USERPROFILE -ErrorAction SilentlyContinue
    }

    It "removes all 4 notification hook events (PS-09)" {
        $settingsPath = Join-Path $env:USERPROFILE ".claude" "settings.json"

        # Verify hooks exist after install (sanity check)
        $before = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
        $before.hooks.PSObject.Properties["Stop"] | Should -Not -BeNullOrEmpty

        # Run uninstall
        pwsh -File /app/scripts/uninstall.ps1
        $LASTEXITCODE | Should -Be 0

        # Verify all 4 notification hooks are removed
        $after = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
        $after.hooks.PSObject.Properties["Stop"] | Should -BeNullOrEmpty
        $after.hooks.PSObject.Properties["Notification"] | Should -BeNullOrEmpty
        $after.hooks.PSObject.Properties["StopFailure"] | Should -BeNullOrEmpty
        $after.hooks.PSObject.Properties["SubagentStop"] | Should -BeNullOrEmpty

        # Verify PreToolUse hook is preserved
        $after.hooks.PSObject.Properties["PreToolUse"] | Should -Not -BeNullOrEmpty

        # Verify permissions are preserved
        $after.permissions.allow | Should -Not -BeNullOrEmpty
    }

    It "removes hooks object when empty after removing notification hooks (PS-10)" {
        $settingsPath = Join-Path $env:USERPROFILE ".claude" "settings.json"

        # Create a settings.json with ONLY the 4 notification hooks (no PreToolUse)
        # This ensures that after removing the 4 hooks, the hooks object is empty
        # and gets removed entirely
        $settings = @{
            hooks = @{
                Stop = @(@{ hooks = @(@{ type = "command"; command = "test" }) })
                Notification = @(@{ hooks = @(@{ type = "command"; command = "test" }) })
                StopFailure = @(@{ hooks = @(@{ type = "command"; command = "test" }) })
                SubagentStop = @(@{ hooks = @(@{ type = "command"; command = "test" }) })
            }
        }
        $jsonSettings = $settings | ConvertTo-Json -Depth 10
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($settingsPath, $jsonSettings, $utf8NoBom)

        # Run uninstall
        pwsh -File /app/scripts/uninstall.ps1
        $LASTEXITCODE | Should -Be 0

        # Verify hooks object is completely removed (not just empty)
        $after = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
        $after.PSObject.Properties["hooks"] | Should -BeNullOrEmpty -Because "hooks object should be removed when empty"
    }

    It "deletes all 4 mp3 files (PS-11)" {
        $ClaudeDir = Join-Path $env:USERPROFILE ".claude"

        # Verify MP3 files exist after install
        Test-Path (Join-Path $ClaudeDir "notify-complete.mp3") | Should -BeTrue
        Test-Path (Join-Path $ClaudeDir "notify-confirm.mp3") | Should -BeTrue
        Test-Path (Join-Path $ClaudeDir "notify-error.mp3") | Should -BeTrue
        Test-Path (Join-Path $ClaudeDir "notify-progress.mp3") | Should -BeTrue

        # Run uninstall
        pwsh -File /app/scripts/uninstall.ps1
        $LASTEXITCODE | Should -Be 0

        # Verify all 4 MP3 files are deleted
        Test-Path (Join-Path $ClaudeDir "notify-complete.mp3") | Should -BeFalse
        Test-Path (Join-Path $ClaudeDir "notify-confirm.mp3") | Should -BeFalse
        Test-Path (Join-Path $ClaudeDir "notify-error.mp3") | Should -BeFalse
        Test-Path (Join-Path $ClaudeDir "notify-progress.mp3") | Should -BeFalse
    }

    It "is idempotent -- running twice produces no error (PS-12)" {
        $settingsPath = Join-Path $env:USERPROFILE ".claude" "settings.json"

        # First uninstall
        pwsh -File /app/scripts/uninstall.ps1
        $LASTEXITCODE | Should -Be 0

        # Capture settings after first uninstall
        $firstContent = Get-Content -Path $settingsPath -Raw

        # Second uninstall (no hooks to remove, but should not error)
        pwsh -File /app/scripts/uninstall.ps1
        $LASTEXITCODE | Should -Be 0

        # Verify settings unchanged by second run
        $secondContent = Get-Content -Path $settingsPath -Raw
        $firstContent | Should -Be $secondContent -Because "second uninstall should not modify settings"
    }
}
