# Governance and Validation Evidence

## .specify/memory/constitution.md

# k8s-sims Constitution

## Core Principles

### I. Shell Safety

All shell scripts must pass `bash -n` syntax checking, use `set -u` for unbound variable detection, and quote all variable expansions. The bash correctness test suite (`tests/bash/run.sh`) enforces this on every inventory entry.

### II. Conventional Commits (NON-NEGOTIABLE)

All commits MUST follow the [Conventional Commits](https://www.conventionalcommits.org/) v1.0.0 specification. Format:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Allowed types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`, `build`, `perf`, `revert`.

**Scopes**: `runner`, `director`, `modules`, `entrypoint`, `utils`, `tests`, `deps`, `docker`, `spec`, `infra`, or omitted for repo-wide changes.

Examples:
- `feat(runner): add --with-mocks flag for shim-based testing`
- `fix(director): quote experiment path in module invocation`
- `docs: update ARCHITECTURE.md with test suite layer`
- `test(modules): add behavioral tests for kwok and simkube`
- `chore(deps): pin bats-core to 1.11.0`

Non-conforming commit messages must be amended before merge.

### III. Conventional Branches (NON-NEGOTIABLE)

All non-trunk branches MUST follow the [Conventional Branch](https://conventionalbranch.org/) specification. Format:

```
<type>/<description>
```

**Allowed types**: `feature` (or `feat`), `bugfix` (or `fix`), `hotfix`, `release`, `chore`.

**Trunk branches**: `main`, `develop` (no prefix).

**Rules**:
- Lowercase alphanumerics and hyphens only (no underscores, no spaces, no uppercase).
- No consecutive, leading, or trailing hyphens.
- Descriptions must be concise and descriptive.
- Include ticket numbers where applicable (e.g., `feat/issue-12-bash-test-suite`).

Examples:
- `feature/bash-test-suite`
- `fix/quote-paths-in-director`
- `hotfix/entrypoint-image-pull`
- `release/v1.2.0`
- `chore/pin-bats-version`

Non-conforming branch names must be renamed before merge.

### IV. Test-First for Shell Changes

Any change to a shell script in the inventory must be accompanied by a corresponding test in the bats suite. Red-Green-Refactor: write or update the test, confirm it fails, then make the change, confirm it passes.

### V. No Silent Overwrites

Result files (`results/*.csv`) are never silently overwritten. The runner preserves existing files as `*.preserved-YYYYmmdd-HHMMSS.csv`. Plotting tools ignore preserved backups by default.

### VI. Privileged Execution Awareness

Full simulator execution requires Docker-in-Docker, host cgroup access, or network pulls. Non-privileged validation paths (syntax checks, Python compilation, fixture plotting, bash test suite) must always remain available and passing.

## Development Constraints

- **Platform**: Scripts must work on POSIX sh (bash 5+) and be validated on both Linux and Windows/Git-Bash (MSYS2).
- **Line endings**: CRLF is the repo default; all tools must handle it.
- **Python**: 3.12+; dependencies listed in `requirements.txt`.
- **External tools**: kwokctl, kubectl, kind, docker, cgexec are runtime-only dependencies. Tests skip gracefully when these are absent; `--with-mocks` provides PATH shims for forced execution.

## Workflow

1. Create a feature branch from `main` using the Spec Kit workflow or manually with conventional commit prefix.
2. Implement changes with tests.
3. Validate: `bash tests/bash/run.sh` and `utils/validate-checkpoint.sh all`.
4. Commit with conventional commit format.
5. Push and open a PR for review.

## Governance

This constitution supersedes ad-hoc practices. Amendments require documentation in this file, a conventional commit of type `docs(spec)`, and verification that existing tests still pass.

**Version**: 1.1.0 | **Ratified**: 2026-06-09 | **Last Amended**: 2026-06-09




## utils/validate-checkpoint.sh

#!/bin/bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALID_FIXTURES="$ROOT_DIR/tests/fixtures/results/valid"
EDGE_FIXTURES="$ROOT_DIR/tests/fixtures/results/edge-cases"
OUT_BASE="${TMPDIR:-/tmp}/k8s-sims-validation"
PYTHON_BIN="${PYTHON:-python}"

run() {
  echo "+ $*"
  "$@"
}

section() {
  printf '\n== %s ==\n' "$1"
}

cmd_baseline() {
  section "shell syntax"
  run bash -n "$ROOT_DIR/kube-director.sh" "$ROOT_DIR/kube-run.sh" "$ROOT_DIR/entrypoint.sh" "$ROOT_DIR"/modules/*/module.sh "$ROOT_DIR"/utils/*.sh
  section "python compile"
  run "$PYTHON_BIN" -m py_compile "$ROOT_DIR"/utils/*.py
  section "dataset generator"
  rm -rf "$OUT_BASE/gen"
  run "$PYTHON_BIN" "$ROOT_DIR/utils/kube-gen.py" -o "$OUT_BASE/gen" -c 1 -i 1
  test -f "$OUT_BASE/gen/nodes-1.yaml"
  test -f "$OUT_BASE/gen/pods-1.yaml"
}

cmd_plotting() {
  section "plot valid fixtures"
  rm -rf "$OUT_BASE/plots" "$OUT_BASE/summary"
  run "$PYTHON_BIN" "$ROOT_DIR/utils/kube-plot.py" -d "$VALID_FIXTURES" -o "$OUT_BASE/plots" -l -b
  run "$PYTHON_BIN" "$ROOT_DIR/utils/min-max-avg.py" -d "$VALID_FIXTURES" -o "$OUT_BASE/summary"
  test -s "$OUT_BASE/summary/summary.json"
  section "plot edge fixtures"
  run "$PYTHON_BIN" "$ROOT_DIR/utils/kube-plot.py" -d "$EDGE_FIXTURES" -o "$OUT_BASE/edge-plots" -l -b
  section "missing directory expected failure"
  if "$PYTHON_BIN" "$ROOT_DIR/utils/kube-plot.py" -d "$OUT_BASE/does-not-exist" -o "$OUT_BASE/missing" -l; then
    echo "Expected missing-directory plotting command to fail" >&2
    return 1
  fi
}

cmd_path_spaces() {
  local path="$OUT_BASE/path with spaces"
  rm -rf "$path"
  run "$PYTHON_BIN" "$ROOT_DIR/utils/kube-gen.py" -o "$path" -c 1 -i 1
  test -f "$path/nodes-1.yaml"
  test -f "$path/pods-1.yaml"
  (cd "${TMPDIR:-/tmp}" && run bash "$ROOT_DIR/kube-run.sh" -e "$path" -m kwok -n 1 -x 1) || true
}

cmd_collision() {
  local out="$OUT_BASE/results/example.csv"
  rm -rf "$OUT_BASE/results"
  mkdir -p "$OUT_BASE/results"
  printf 'existing\n' > "$out"
  if bash "$ROOT_DIR/kube-run.sh" -e "$OUT_BASE/missing-exp" -m kwok -o "$out" >/tmp/k8s-sims-collision.log 2>&1; then
    echo "Expected missing experiment path to fail before writing" >&2
    return 1
  fi
  grep -q 'Experiment files path does not exist' /tmp/k8s-sims-collision.log
  grep -q '^existing$' "$out"
  echo "Existing output remained untouched when validation failed before writing."
}

cmd_docs() {
  section "documentation discovery"
  git -C "$ROOT_DIR" grep -n "sarteco-2026\|privileged\|simulator mode\|reproduc" -- . ':!data/**'
}

cmd_bash_tests() {
  section "bash test suite"
  if [[ ! -x "$ROOT_DIR/tests/bash/run.sh" ]]; then
    echo "Bash test suite is not installed: $ROOT_DIR/tests/bash/run.sh missing" >&2
    return 1
  fi
  local report_dir="${BASH_TEST_REPORT_DIR:-$OUT_BASE/bash-tests}"
  run bash "$ROOT_DIR/tests/bash/run.sh" --report-dir "$report_dir"
  local rc=$?
  if [[ -f "$report_dir/latest.summary" ]]; then
    echo
    echo "Bash test summary ($report_dir/latest.summary):"
    cat "$report_dir/latest.summary"
  fi
  return $rc
}

case "${1:-all}" in
  baseline) cmd_baseline ;;
  plotting) cmd_plotting ;;
  path-spaces) cmd_path_spaces ;;
  collision) cmd_collision ;;
  docs) cmd_docs ;;
  bash-tests) cmd_bash_tests ;;
  all) cmd_baseline && cmd_plotting && cmd_path_spaces && cmd_collision && cmd_docs && cmd_bash_tests ;;
  *) echo "Usage: $0 {baseline|plotting|path-spaces|collision|docs|bash-tests|all}" >&2; exit 2 ;;
esac




## tests/bash/run.sh

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

... (168 total lines, showing first 150)


