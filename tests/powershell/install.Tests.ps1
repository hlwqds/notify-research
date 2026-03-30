# tests/powershell/install.Tests.ps1 -- Tests for install.ps1
# Covers: PS-05 (4 hook injection + shell=powershell), PS-06 (forward-slash paths),
#         PS-07 (BOM-free JSON), PS-08 (idempotent re-run)

Describe "install.ps1 hook injection and configuration" {
    BeforeEach {
        # Isolate USERPROFILE to temp directory (per D-02, D-06)
        $TestHome = Join-Path ([System.IO.Path]::GetTempPath()) "pester-install-$(Get-Random)"
        New-Item -ItemType Directory -Path $TestHome -Force | Out-Null
        $env:USERPROFILE = $TestHome

        # Create .claude directory and copy fixture settings.json
        $ClaudeDir = Join-Path $TestHome ".claude"
        New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
        Copy-Item /app/tests/fixtures/settings.json (Join-Path $ClaudeDir "settings.json")
    }

    AfterEach {
        Remove-Item -Path $TestHome -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item Env:USERPROFILE -ErrorAction SilentlyContinue
    }

    It "injects 4 hook events with shell=powershell into settings.json (PS-05)" {
        $settingsPath = Join-Path $env:USERPROFILE ".claude" "settings.json"

        # Run install (child process -- install.ps1 uses exit)
        & /app/scripts/install.ps1 -RepoPath /app
        $LASTEXITCODE | Should -Be 0

        # Parse output settings
        $settings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json

        # Verify all 4 notification hooks exist
        $settings.hooks.PSObject.Properties["Stop"] | Should -Not -BeNullOrEmpty
        $settings.hooks.PSObject.Properties["Notification"] | Should -Not -BeNullOrEmpty
        $settings.hooks.PSObject.Properties["StopFailure"] | Should -Not -BeNullOrEmpty
        $settings.hooks.PSObject.Properties["SubagentStop"] | Should -Not -BeNullOrEmpty

        # Verify PreToolUse hook is preserved (from fixture)
        $settings.hooks.PSObject.Properties["PreToolUse"] | Should -Not -BeNullOrEmpty

        # Verify permissions are preserved
        $settings.permissions.allow | Should -Not -BeNullOrEmpty

        # Verify shell is "powershell" for each hook
        foreach ($eventName in @("Stop", "Notification", "StopFailure", "SubagentStop")) {
            $hookEntry = $settings.hooks.$eventName[0].hooks[0]
            $hookEntry.shell | Should -Be "powershell"
        }
    }

    It "uses forward slashes in hook command paths (PS-06)" {
        $settingsPath = Join-Path $env:USERPROFILE ".claude" "settings.json"

        & /app/scripts/install.ps1 -RepoPath /app
        $LASTEXITCODE | Should -Be 0

        $settings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json

        foreach ($eventName in @("Stop", "Notification", "StopFailure", "SubagentStop")) {
            $command = $settings.hooks.$eventName[0].hooks[0].command
            # Command must NOT contain backslash characters (forward-slash only)
            $command | Should -Not -Match '\\' -Because "hook command paths must use forward slashes"
            # Command must contain forward-slash path to notify-play.ps1
            $command | Should -Match 'notify-play\.ps1'
            # Command must contain forward-slash path to mp3
            $command | Should -Match 'notify-.*\.mp3'
        }
    }

    It "writes settings.json without UTF-8 BOM (PS-07)" {
        $settingsPath = Join-Path $env:USERPROFILE ".claude" "settings.json"

        & /app/scripts/install.ps1 -RepoPath /app
        $LASTEXITCODE | Should -Be 0

        # Read first 3 bytes and verify not BOM signature (per D-03)
        $bytes = [System.IO.File]::ReadAllBytes($settingsPath)
        $bytes.Length | Should -BeGreaterOrEqual 3

        $bomPresent = ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        $bomPresent | Should -BeFalse -Because "settings.json should be written without UTF-8 BOM (per D-03)"
    }

    It "is idempotent -- running twice produces same settings (PS-08)" {
        $settingsPath = Join-Path $env:USERPROFILE ".claude" "settings.json"

        # First run
        & /app/scripts/install.ps1 -RepoPath /app
        $LASTEXITCODE | Should -Be 0
        $firstContent = Get-Content -Path $settingsPath -Raw

        # Second run
        & /app/scripts/install.ps1 -RepoPath /app
        $LASTEXITCODE | Should -Be 0
        $secondContent = Get-Content -Path $settingsPath -Raw

        # Compare normalized JSON (ConvertFrom-Json -> ConvertTo-Json -Depth 100)
        $firstNormalized = $firstContent | ConvertFrom-Json | ConvertTo-Json -Depth 100
        $secondNormalized = $secondContent | ConvertFrom-Json | ConvertTo-Json -Depth 100
        $firstNormalized | Should -Be $secondNormalized -Because "second install should produce identical JSON output"
    }
}
