#!/usr/bin/env bash
# test.sh — Unified test entry point for Claude Code voice notification.
# Usage: test.sh {--lint|--bash|--powershell|--all}
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
BATS_IMAGE="bats/bats:1.11.0"
PWSH_IMAGE="mcr.microsoft.com/powershell:7.4-alpine-3.20"

usage() {
    echo "Usage: $0 {--lint|--bash|--powershell|--all}"
    echo ""
    echo "  --lint         Run ShellCheck + PSScriptAnalyzer"
    echo "  --bash         Run bats-core tests in Docker"
    echo "  --powershell   Run Pester tests in Docker"
    echo "  --all          Run lint, then bash, then powershell"
    exit 1
}

run_lint() {
    local rc=0

    echo "=== ShellCheck (bash scripts) ==="
    # Per D-06: severity warning. Per D-07: all 3 bash scripts.
    # Use Docker if shellcheck not installed locally.
    if command -v shellcheck &>/dev/null; then
        shellcheck --severity warning --check-sourced \
            "$REPO_ROOT/scripts/install.sh" \
            "$REPO_ROOT/scripts/uninstall.sh" \
            "$REPO_ROOT/scripts/notify-play.sh" || rc=$?
    else
        echo "  shellcheck not found locally, using Docker..."
        docker run --rm -v "$REPO_ROOT:/app:ro" koalaman/shellcheck:stable \
            --severity warning --check-sourced \
            /app/scripts/install.sh \
            /app/scripts/uninstall.sh \
            /app/scripts/notify-play.sh || rc=$?
    fi

    if [ $rc -ne 0 ]; then
        echo "FAIL: ShellCheck found issues"
        return $rc
    fi
    echo "OK: ShellCheck passed"

    echo ""
    echo "=== PSScriptAnalyzer (PowerShell scripts) ==="
    # Per D-06: severity Warning. Per D-07: all 3 PS1 scripts.
    # Per RESEARCH Pitfall 4: Install PSScriptAnalyzer if not pre-installed.
    docker run --rm -v "$REPO_ROOT:/app:ro" "$PWSH_IMAGE" \
        pwsh -Command "
            if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
                Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser -ErrorAction Stop
            }
            Import-Module PSScriptAnalyzer
            \$results = Invoke-ScriptAnalyzer -Path /app/scripts -Severity Warning -Recurse
            if (\$results) {
                \$results | Format-Table -AutoSize
                exit 1
            }
            Write-Host 'OK: PSScriptAnalyzer passed'
        " || rc=$?

    if [ $rc -ne 0 ]; then
        echo "FAIL: PSScriptAnalyzer found issues"
        return $rc
    fi
    return 0
}

run_bash_tests() {
    echo "=== bats-core tests (Docker) ==="
    docker run --rm --entrypoint /bin/sh -v "$REPO_ROOT:/app" "$BATS_IMAGE" \
        -c "apk add --no-cache jq > /dev/null 2>&1 && bats /app/tests/bash"
}

run_powershell_tests() {
    echo "=== Pester tests (Docker) ==="
    docker run --rm -v "$REPO_ROOT:/app" "$PWSH_IMAGE" \
        pwsh -Command "
            if (-not (Get-Module -ListAvailable -Name Pester)) {
                Install-Module -Name Pester -RequiredVersion 5.6.1 -Force -Scope CurrentUser
            }
            Import-Module Pester
            Invoke-Pester -Path /app/tests/powershell -Output Detailed
        "
}

case "${1:-}" in
    --lint)
        run_lint
        ;;
    --bash)
        run_bash_tests
        ;;
    --powershell)
        run_powershell_tests
        ;;
    --all)
        echo "=== Running all tests ==="
        run_lint || { echo ""; echo "FAIL: lint errors found, aborting tests."; exit 1; }
        echo ""
        run_bash_tests
        echo ""
        run_powershell_tests
        echo ""
        echo "=== All tests passed ==="
        ;;
    *)
        usage
        ;;
esac
