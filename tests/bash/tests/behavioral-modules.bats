#!/usr/bin/env bats
# behavioral-modules.bats - module loading and log presence for module scripts.

setup() {
  REPO_ROOT="${REPO_ROOT:-$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)}"
  HELPERS_DIR="$REPO_ROOT/tests/bash/helpers"
  # shellcheck source=../helpers/skip.bash
  source "$HELPERS_DIR/skip.bash"
}

@test "each module script sources without error and prints a log line" {
  for module in kwok kubemark kube-sched simkube opensim; do
    [ -f "$REPO_ROOT/modules/$module/module.sh" ] || continue
    # Source kube-run.sh up to (but not including) the entry point so the `log`
    # function and SCRIPT_DIR are available, then source the module.
    run bash -c "
      set +e
      for ((i=1; i<=50; i++)); do
        line=\$(sed -n "\${i}p" '$REPO_ROOT/kube-run.sh')
        case \$line in
          '# Entry point'*) exit 0 ;;
        esac
      done
      exit 0
    "
    preamble="$output"
    # Extract lines before the entry point, then source them together with the module.
    run bash -c "
      awk '/^# Entry point$/{exit} {print}' '$REPO_ROOT/kube-run.sh' > /tmp/kube-run-preamble.sh
      source /tmp/kube-run-preamble.sh
      source '$REPO_ROOT/modules/$module/module.sh'
    " 2>&1
    if [[ "$status" -ne 0 ]]; then
      echo "Module $module failed to source: $output" >&2
      return 1
    fi
    if [[ "$output" != *"module loaded"* ]]; then
      echo "Module $module did not emit 'module loaded' line: $output" >&2
      return 1
    fi
  done
}
