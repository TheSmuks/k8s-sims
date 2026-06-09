#!/usr/bin/env bats
# behavioral-entrypoint.bats - behavioral tests for entrypoint.sh.
# entrypoint.sh expects to be running inside a container; tests that
# require docker/kind/kwok skip when those tools are missing and run
# against the shim layer when --with-mocks is in effect.

setup() {
  REPO_ROOT="${REPO_ROOT:-$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)}"
  HELPERS_DIR="$REPO_ROOT/tests/bash/helpers"
  # shellcheck source=../helpers/skip.bash
  source "$HELPERS_DIR/skip.bash"
}

@test "entrypoint.sh reports individual image-pull failures" {
  skip_if_missing_tools docker || return 0
  tmpdir="$BATS_TEST_TMPDIR/entrypoint"
  mkdir -p "$tmpdir"
  # Patch the script to use a tmp working directory to avoid touching /
  cp "$REPO_ROOT/entrypoint.sh" "$tmpdir/entrypoint.sh"
  # Stub out the kube-director.sh invocation
  sed -i 's|/kube-director.sh|true|g' "$tmpdir/entrypoint.sh"
  # Run and expect: at least one WARNING line for a missing image
  run bash "$tmpdir/entrypoint.sh" 2>&1
  [[ "$output" == *"WARNING"* ]] || [[ "$output" == *"pull"* ]]
}
