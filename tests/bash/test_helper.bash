# tests/bash/test_helper.bash -- Shared test setup for all bats files
# Derives REPO_ROOT from the test file's directory location.
# All .bats files are at tests/bash/, so repo root is 2 levels up.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
