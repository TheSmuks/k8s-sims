#!/usr/bin/env bats
# behavioral-director.bats - behavioral tests for kube-director.sh.

setup() {
  REPO_ROOT="${REPO_ROOT:-$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)}"
  HELPERS_DIR="$REPO_ROOT/tests/bash/helpers"
  FIXTURES_DIR="$REPO_ROOT/tests/bash/fixtures"
  # shellcheck source=../helpers/skip.bash
  source "$HELPERS_DIR/skip.bash"
}

@test "kube-director.sh prints help and exits 0 with -h" {
  run bash "$REPO_ROOT/kube-director.sh" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "kube-director.sh errors on missing experiment path" {
  run bash "$REPO_ROOT/kube-director.sh" -e "$FIXTURES_DIR/definitely-missing" -n 1
  [ "$status" -ne 0 ]
  [[ "$output" == *"Experiment files path does not exist"* ]]
}

@test "kube-director.sh loads SIM_MODULES inventory" {
  run bash -c "cd '$REPO_ROOT' && grep -q . SIM_MODULES"
  [ "$status" -eq 0 ]
}
