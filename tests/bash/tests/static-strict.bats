#!/usr/bin/env bats
# static-strict.bats - exercise the runner scripts under set -u and pipefail
# in a subshell to detect unbound variable and pipeline failures.
# This is a smoke test: it asserts the script parses cleanly under strict
# mode in a subshell, not that it runs end to end.

setup() {
  REPO_ROOT="${REPO_ROOT:-$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)}"
}

RUNTIME_SCRIPTS=(
  "kube-run.sh"
  "kube-director.sh"
  "entrypoint.sh"
)

@test "runtime scripts pass bash -n under set -u and pipefail" {
  local script
  for script in "${RUNTIME_SCRIPTS[@]}"; do
    if [[ ! -f "$REPO_ROOT/$script" ]]; then
      continue
    fi
    # Convert CRLF to LF on the fly so the strict-mode parser does not choke
    # on stray carriage returns when invoked from a CRLF checkout.
    bash -c "set -uo pipefail; bash -n <(tr -d '\r' < '$REPO_ROOT/$script')"
    [ "$?" -eq 0 ]
  done
}
