#!/usr/bin/env bats
# static-syntax.bats - run `bash -n` over every inventory entry.
# Verifies the parser accepts each script.

setup() {
  REPO_ROOT="${REPO_ROOT:-$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)}"
  HELPERS_DIR="$REPO_ROOT/tests/bash/helpers"
  EXCLUDED_FILE="$REPO_ROOT/tests/bash/excluded-scripts.bash"
  # shellcheck source=../helpers/inventory.bash
  source "$HELPERS_DIR/inventory.bash"
}

@test "inventory is non-empty" {
  run inventory_list "$EXCLUDED_FILE"
  [ "$status" -eq 0 ]
  [[ -n "$output" ]]
}

@test "every inventory entry has a parseable shell syntax" {
  while IFS= read -r script_path; do
    [[ -z "$script_path" ]] && continue
    run bash -n "$REPO_ROOT/$script_path"
    if [[ "$status" -ne 0 ]]; then
      echo "Parse error in $script_path: $output" >&2
      return 1
    fi
  done < <(inventory_list "$EXCLUDED_FILE")
}
