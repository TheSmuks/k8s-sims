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
