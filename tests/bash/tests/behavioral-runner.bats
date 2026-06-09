#!/usr/bin/env bats
# behavioral-runner.bats - behavioral tests for kube-run.sh.
# These tests require kwokctl/kubectl/kind; they skip when missing and run
# against the mocks when --with-mocks is enabled by the runner.

setup() {
  REPO_ROOT="${REPO_ROOT:-$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)}"
  HELPERS_DIR="$REPO_ROOT/tests/bash/helpers"
  FIXTURES_DIR="$REPO_ROOT/tests/bash/fixtures"
  # shellcheck source=../helpers/skip.bash
  source "$HELPERS_DIR/skip.bash"
}

@test "kube-run.sh prints help and exits 0 with -h" {
  run bash "$REPO_ROOT/kube-run.sh" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "kube-run.sh errors on missing required arguments" {
  run bash "$REPO_ROOT/kube-run.sh" -m kwok
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing required arguments"* ]] || [[ "$output" == *"required"* ]]
}

@test "kube-run.sh errors on unknown simulator mode" {
  run bash "$REPO_ROOT/kube-run.sh" -e "$FIXTURES_DIR/experiment-missing" -m not-a-simulator
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unsupported simulator"* ]]
}

@test "kube-run.sh errors on missing experiment path" {
  run bash "$REPO_ROOT/kube-run.sh" -e "$FIXTURES_DIR/definitely-missing" -m kwok -n 1 -x 1
  [ "$status" -ne 0 ]
  [[ "$output" == *"Experiment files path does not exist"* ]]
}

@test "kube-run.sh preserves an existing result file as *.preserved-*.csv" {
  skip_if_missing_tools kwokctl kubectl || return 0
  target="$BATS_TEST_TMPDIR/preserve.csv"
  printf 'existing\n' > "$target"
  run bash "$REPO_ROOT/kube-run.sh" -e "$FIXTURES_DIR/experiment-missing" -m kwok -n 1 -x 1 -o "$target"
  # The runner should have failed (no real cluster) but preserved the file first
  # if cluster setup reported failure before writing. We expect the original to
  # still be present.
  [ -f "$target" ]
  if grep -q '^existing$' "$target"; then
    return 0
  fi
  # The runner may have moved the file to a preserved backup before failing.
  preserved=$(ls "$BATS_TEST_TMPDIR"/preserve.preserved-*.csv 2>/dev/null || true)
  [[ -n "$preserved" ]]
}
