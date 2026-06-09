#!/usr/bin/env bats
# helper-integration.bats - assert utils/validate-checkpoint.sh exposes
# the bash-tests subcommand and that it propagates the suite's exit code.

setup() {
  REPO_ROOT="${REPO_ROOT:-$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)}"
}

@test "validate-checkpoint.sh lists bash-tests in the usage line" {
  run bash "$REPO_ROOT/utils/validate-checkpoint.sh" not-a-real-subcommand
  [ "$status" -eq 2 ]
  [[ "$output" == *"bash-tests"* ]]
}

@test "validate-checkpoint.sh bash-tests subcommand runs the runner" {
  cd "$REPO_ROOT"
  if [[ ! -x "tests/bash/.bats/install/bin/bats" ]] && ! command -v bats >/dev/null 2>&1; then
    skip "bats is not available locally; bootstrap the suite to enable this test"
  fi
  # The recursion guard in run.sh exits 0 when BATS_RUN_SH_REENTRANT is set,
  # so this test simply asserts the helper propagates that exit code and that
  # the bash-tests step is recognized.
  BASH_TEST_REPORT_DIR="$BATS_TEST_TMPDIR/reports" \
    run bash "$REPO_ROOT/utils/validate-checkpoint.sh" bash-tests
  # Either the suite ran and exited 0, or the recursion guard kicked in.
  [ "$status" -eq 0 ]
  # The helper prints either the run report path or the recursion-guard note.
  [[ "$output" == *"bash test suite"* ]]
}
