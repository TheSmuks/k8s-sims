#!/usr/bin/env bash
# bats.bash - resolve the locally bootstrapped bats binary and run helpers.

# shellcheck shell=bash

set -u

BATS_BOOTSTRAP_VERSION="${BATS_BOOTSTRAP_VERSION:-1.11.0}"
BATS_LOCAL_DIR="${BATS_LOCAL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.bats}"

# resolve_bats <bats_dir>
# Prints an absolute path to a bats executable.
# Search order: $BATS env, system bats, locally bootstrapped bats.
resolve_bats() {
  if [[ -n "${BATS:-}" && -x "$BATS" ]]; then
    printf '%s\n' "$BATS"
    return 0
  fi
  if command -v bats >/dev/null 2>&1; then
    command -v bats
    return 0
  fi
  local candidate="$BATS_LOCAL_DIR/install/bin/bats"
  if [[ -x "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  return 1
}

# report_write <reports_dir> <bats_output> <summary_kv...>
# Writes the TAP file and a key=value summary file under <reports_dir>.
# Args after <bats_output> are key=value pairs that are appended to the summary.
report_write() {
  local reports_dir="$1"; shift
  local bats_output="$1"; shift
  local timestamp
  timestamp=$(date -u +%Y%m%dT%H%M%SZ)
  mkdir -p "$reports_dir"
  cp "$bats_output" "$reports_dir/${timestamp}.tap"
  cp "$bats_output" "$reports_dir/latest.tap"
  {
    local kv
    for kv in "$@"; do
      printf '%s\n' "$kv"
    done
  } > "$reports_dir/${timestamp}.summary"
  cp "$reports_dir/${timestamp}.summary" "$reports_dir/latest.summary"
  printf '%s\n' "$reports_dir/${timestamp}.tap"
}

# summarize_tap <tap_file>
# Reads a TAP file and prints: pass_count fail_count skip_count
summarize_tap() {
  local tap_file="$1"
  local pass=0 fail=0 skip=0
  while IFS= read -r line; do
    case "$line" in
      "ok "*"# skip"*) skip=$((skip + 1)) ;;
      "ok "*) pass=$((pass + 1)) ;;
      "not ok "*) fail=$((fail + 1)) ;;
    esac
  done < "$tap_file"
  printf '%d %d %d\n' "$pass" "$fail" "$skip"
}
