#!/usr/bin/env bats
# skip-reason.bats - assert that behavioral tests emit a skip TAP line with
# "missing tool: <name>" when an external tool is absent.

setup() {
  REPO_ROOT="${REPO_ROOT:-$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)}"
  HELPERS_DIR="$REPO_ROOT/tests/bash/helpers"
  # shellcheck source=../helpers/skip.bash
  source "$HELPERS_DIR/skip.bash"
}

@test "skip_if_missing_tools emits missing-tool reason for absent tool" {
  reason=$(PATH="/usr/bin:/bin" bash -c "source '$HELPERS_DIR/skip.bash'; missing_tool_reason definitely-not-a-tool-xyz" 2>&1)
  [[ "$reason" == *"missing tool: definitely-not-a-tool-xyz"* ]]
}

@test "skip_if_missing_tools returns empty reason when all tools exist" {
  reason=$(PATH="/usr/bin:/bin" bash -c "source '$HELPERS_DIR/skip.bash'; missing_tool_reason bash" 2>&1)
  [[ -z "$reason" ]]
}
