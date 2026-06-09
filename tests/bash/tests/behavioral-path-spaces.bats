#!/usr/bin/env bats
# behavioral-path-spaces.bats - cover path-with-spaces for kube-gen.py and the runner.
# Uses tests/bash/fixtures/experiment-spaced.

setup() {
  REPO_ROOT="${REPO_ROOT:-$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)}"
  HELPERS_DIR="$REPO_ROOT/tests/bash/helpers"
  # shellcheck source=../helpers/skip.bash
  source "$HELPERS_DIR/skip.bash"
}

@test "kube-gen.py can be invoked with a spaced output path" {
  skip_if_missing_tools python || return 0
  out="$BATS_TEST_TMPDIR/path with spaces"
  mkdir -p "$out"
  run python "$REPO_ROOT/utils/kube-gen.py" -o "$out" -c 1 -i 1
  # The generator prints ASCII art; we just need the exit code
  [ "$status" -eq 0 ]
}
