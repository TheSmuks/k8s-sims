#!/usr/bin/env bash
# run.sh - bats-based bash correctness suite runner.
# Discovers the script inventory, bootstraps bats on first run, runs every
# test under tests/bash/tests/, and writes TAP + summary reports.

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
HELPERS_DIR="$HERE/helpers"
TESTS_DIR="$HERE/tests"
REPORTS_DIR="$HERE/.reports"
MOCKS_BIN_DIR="$REPO_ROOT/tests/mocks/bin"
EXCLUDED_FILE="$HERE/excluded-scripts.bash"

WITH_MOCKS=0
PRINT_INVENTORY=0
BATS_OVERRIDE=""
REPORT_DIR_OVERRIDE=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

  --with-mocks          Prepend tests/mocks/bin to PATH and force behavioral tests.
  --bats <path>         Use a specific bats binary instead of the bootstrapped one.
  --report-dir <path>   Override the per-run report directory.
  --print-inventory     Print the discovered inventory and exit.
  -h, --help            Show this help.

Examples:
  ./tests/bash/run.sh
  ./tests/bash/run.sh --with-mocks
  ./tests/bash/run.sh --print-inventory
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-mocks) WITH_MOCKS=1; shift ;;
    --bats) BATS_OVERRIDE="$2"; shift 2 ;;
    --report-dir) REPORT_DIR_OVERRIDE="$2"; shift 2 ;;
    --print-inventory) PRINT_INVENTORY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage; exit 2 ;;
  esac
done

# shellcheck source=helpers/inventory.bash
source "$HELPERS_DIR/inventory.bash"

if [[ "$PRINT_INVENTORY" -eq 1 ]]; then
  inventory_list "$EXCLUDED_FILE"
  exit 0
fi

# Read BATS_BOOTSTRAP_VERSION from the bootstrap script so the summary matches.
BATS_BOOTSTRAP_VERSION="$(grep -E '^BATS_BOOTSTRAP_VERSION=' "$HERE/bootstrap-bats.sh" | head -1 | cut -d= -f2- | tr -d '"' | sed -E 's/\$\{BATS_BOOTSTRAP_VERSION:-([0-9.]+)\}/\1/')"
BATS_BOOTSTRAP_VERSION="${BATS_BOOTSTRAP_VERSION:-1.11.0}"
export BATS_BOOTSTRAP_VERSION

if [[ -n "$REPORT_DIR_OVERRIDE" ]]; then
  REPORTS_DIR="$REPORT_DIR_OVERRIDE"
fi
mkdir -p "$REPORTS_DIR"

# Resolve bats
BATS_BIN=""
if [[ -n "$BATS_OVERRIDE" ]]; then
  BATS_BIN="$BATS_OVERRIDE"
elif [[ -x "$REPO_ROOT/tests/bash/.bats/install/bin/bats" ]]; then
  BATS_BIN="$REPO_ROOT/tests/bash/.bats/install/bin/bats"
elif command -v bats >/dev/null 2>&1; then
  BATS_BIN=$(command -v bats)
else
  if [[ -t 1 ]]; then
    printf '[run.sh] bats not found locally; bootstrapping...\n' >&2
  fi
  if ! bash "$HERE/bootstrap-bats.sh"; then
    printf '[run.sh] ERROR: failed to bootstrap bats. See tests/bash/bootstrap-bats.sh.\n' >&2
    exit 2
  fi
  BATS_BIN="$REPO_ROOT/tests/bash/.bats/install/bin/bats"
fi
if [[ ! -x "$BATS_BIN" ]]; then
  printf '[run.sh] ERROR: bats binary not executable: %s\n' "$BATS_BIN" >&2
  exit 2
fi

# Inventory
INVENTORY_TMP=$(mktemp)
trap 'rm -f "$INVENTORY_TMP"' EXIT
inventory_list "$EXCLUDED_FILE" > "$INVENTORY_TMP"
INVENTORY_SIZE=$(wc -l < "$INVENTORY_TMP" | tr -d ' ')

if [[ "$INVENTORY_SIZE" -eq 0 ]]; then
  printf '[run.sh] ERROR: inventory is empty.\n' >&2
  exit 2
fi

# Build environment
EXTRA_PATH=""
if [[ "$WITH_MOCKS" -eq 1 ]]; then
  if [[ -d "$MOCKS_BIN_DIR" ]]; then
    EXTRA_PATH="$MOCKS_BIN_DIR"
  else
    printf '[run.sh] WARNING: --with-mocks requested but %s does not exist; running without mocks.\n' "$MOCKS_BIN_DIR" >&2
  fi
fi

# Recursion guard: when bats invokes this runner from within a bats test,
# environment variable BATS_RUN_SH_REENTRANT is set so we exit cleanly.
if [[ -n "${BATS_RUN_SH_REENTRANT:-}" ]]; then
  printf '[run.sh] BATS_RUN_SH_REENTRANT set; skipping recursive run.\n' >&2
  exit 0
fi
export BATS_RUN_SH_REENTRANT=1

TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
TAP_FILE="$REPORTS_DIR/${TIMESTAMP}.tap"
SUMMARY_FILE="$REPORTS_DIR/${TIMESTAMP}.summary"
LATEST_TAP="$REPORTS_DIR/latest.tap"
LATEST_SUMMARY="$REPORTS_DIR/latest.summary"

START_TIME=$(date +%s)
PATH="$EXTRA_PATH${EXTRA_PATH:+:}$PATH" \
  "$BATS_BIN" --tap "$TESTS_DIR" > "$TAP_FILE" 2>&1
BATS_EXIT=$?
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Parse TAP
PASS=$(grep -c '^ok ' "$TAP_FILE" 2>/dev/null | head -1)
FAIL=$(grep -c '^not ok ' "$TAP_FILE" 2>/dev/null | head -1)
SKIP=$(grep -c '# skip' "$TAP_FILE" 2>/dev/null | head -1)
: "${PASS:=0}"
: "${FAIL:=0}"
: "${SKIP:=0}"

BRANCH=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
MOCKED_FLAG="false"
[[ "$WITH_MOCKS" -eq 1 ]] && MOCKED_FLAG="true"

{
  printf 'timestamp=%s\n' "$TIMESTAMP"
  printf 'branch=%s\n' "$BRANCH"
  printf 'bats_path=%s\n' "$BATS_BIN"
  printf 'framework_version=%s\n' "$BATS_BOOTSTRAP_VERSION"
  printf 'mocked=%s\n' "$MOCKED_FLAG"
  printf 'inventory_size=%s\n' "$INVENTORY_SIZE"
  printf 'pass_count=%s\n' "$PASS"
  printf 'fail_count=%s\n' "$FAIL"
  printf 'skip_count=%s\n' "$SKIP"
  printf 'duration_seconds=%s\n' "$DURATION"
} > "$SUMMARY_FILE"
cp "$TAP_FILE" "$LATEST_TAP"
cp "$SUMMARY_FILE" "$LATEST_SUMMARY"

# Stream TAP to stdout for live observability
cat "$TAP_FILE"

printf '\n[run.sh] report: %s\n' "$TAP_FILE" >&2
printf '[run.sh] summary: %s\n' "$SUMMARY_FILE" >&2
printf '[run.sh] pass=%s fail=%s skip=%s duration=%ss\n' "$PASS" "$FAIL" "$SKIP" "$DURATION" >&2

# Exit with bats' own exit code (0 only when nothing failed)
exit $BATS_EXIT
