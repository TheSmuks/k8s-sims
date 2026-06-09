#!/usr/bin/env bats
# with-mocks.bats - assert that --with-mocks prepends the shim layer to PATH.

setup() {
  REPO_ROOT="${REPO_ROOT:-$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)}"
  HELPERS_DIR="$REPO_ROOT/tests/bash/helpers"
  MOCKS_BIN="$REPO_ROOT/tests/mocks/bin"
}

@test "shim kwokctl is on PATH when --with-mocks is in effect" {
  out=$(PATH="$MOCKS_BIN:$PATH" tests/mocks/bin/kwokctl get clusters 2>&1)
  [ "$?" -eq 0 ]
  # The shim logs the invocation; we expect an empty line for the default rule
  log_file="$REPO_ROOT/tests/bash/.reports/mock-kwokctl.log"
  [ -f "$log_file" ]
  grep -q 'kwokctl' "$log_file"
}

@test "shim records the matching rule response" {
  rm -f "$REPO_ROOT/tests/bash/.reports/mock-kubectl.log"
  out=$(PATH="$MOCKS_BIN:$PATH" tests/mocks/bin/kubectl get serviceaccount default 2>&1)
  [ "$?" -eq 0 ]
  [[ "$out" == *"default"* ]]
  log_file="$REPO_ROOT/tests/bash/.reports/mock-kubectl.log"
  [ -f "$log_file" ]
}

@test "run.sh accepts --with-mocks and runs the suite to completion" {
  cd "$REPO_ROOT"
  if [[ ! -x "tests/bash/.bats/install/bin/bats" ]] && ! command -v bats >/dev/null 2>&1; then
    skip "bats is not available locally; bootstrap the suite to enable this test"
  fi
  # The recursive run.sh invocation triggers the BATS_RUN_SH_REENTRANT guard
  # in run.sh, which exits 0 without writing a nested report. That is the
  # expected behavior: a bats test must not transitively re-enter run.sh.
  report_dir="$BATS_TEST_TMPDIR/reports"
  mkdir -p "$report_dir"
  run bash tests/bash/run.sh --with-mocks --report-dir "$report_dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BATS_RUN_SH_REENTRANT"* ]] || [ -f "$report_dir/latest.summary" ]
}
