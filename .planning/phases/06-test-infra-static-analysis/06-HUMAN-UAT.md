---
status: partial
phase: 06-test-infra-static-analysis
source: [06-VERIFICATION.md]
started: 2026-03-30
updated: 2026-03-30
---

## Current Test

[awaiting human testing]

## Tests

### 1. PSScriptAnalyzer End-to-End via Docker
expected: Run `./test.sh --lint` — PSScriptAnalyzer runs on all 3 .ps1 files via mcr.microsoft.com/powershell:7.4 container and exits 0
result: [pending]

### 2. bats-core Docker Container Launch
expected: Run `./test.sh --bash` — bats/bats:1.11.0 container starts, mounts tests/bash/, runs bats (0 tests found — expected)
result: [pending]

### 3. Pester Docker Container Launch
expected: Run `./test.sh --powershell` — mcr.microsoft.com/powershell:7.4 container starts, Invoke-Pester runs against tests/powershell/ (0 tests found — expected)
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
