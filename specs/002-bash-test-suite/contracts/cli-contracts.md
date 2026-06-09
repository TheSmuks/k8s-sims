# CLI Contracts: Bash Correctness Test Suite

This project is script-based, so the contracts below describe how the test suite is invoked and what it promises to callers (maintainers, CI, and `utils/validate-checkpoint.sh`).

## Contract: Run the bash test suite

**Command family**: bats-based test runner.

**Inputs**:
- Optional `--with-mocks` flag that prepends `tests/mocks/bin/` to `PATH` and forces the behavioral tests to use shim binaries instead of the real tools.
- Optional `--bats <path>` flag to override the bootstrap or system bats binary.
- Optional `--report-dir <path>` to override the per-run report directory (default `tests/bash/.reports/`).

**Preconditions**:
- The repository root is the current working directory.
- `bash` is on `PATH`.
- If `--with-mocks` is set, `tests/mocks/bin/` exists and contains at least the shim binaries referenced by the behavioral tests.

**Successful behavior**:
- Bootstrap step: if `bats` is not on `PATH`, the runner downloads bats-core 1.11.0 into `tests/bash/.bats/` and uses it. The download is skipped on subsequent runs.
- Inventory step: the runner globs `*.sh` at the repo root, `modules/*/module.sh`, `utils/*.sh`, and `entrypoint.sh`, then applies `tests/bash/excluded-scripts.bash` to remove template or vendor copies.
- Run step: every test under `tests/bash/tests/` is executed once, with a per-test timeout of 30 seconds.
- Report step: TAP output is written to `tests/bash/.reports/<timestamp>.tap` and a small `key=value` summary to `tests/bash/.reports/<timestamp>.summary`. The most recent run is also symlinked or copied to `tests/bash/.reports/latest.tap` and `tests/bash/.reports/latest.summary`.
- Exit code: 0 if all tests pass or are skipped; non-zero if any test fails.

**Failure behavior**:
- A failing test MUST emit a TAP `not ok` line that includes the test name and the failure message.
- A behavioral test that requires an external tool MUST `skip` (TAP `ok` with `# skip` directive) and the reason MUST start with `missing tool: <name>`.
- A static check that finds a syntax error MUST print the script path and the parser error and exit the suite non-zero.

## Contract: Discover the script inventory

**Command family**: inventory enumeration.

**Inputs**:
- None (the inventory is auto-discovered from the repo layout).

**Preconditions**:
- The current working directory is a git repository with the expected layout.

**Successful behavior**:
- The inventory is the union of:
  - `*.sh` at the repo root, excluding `modules/`, `utils/`, and any path in `tests/bash/excluded-scripts.bash`.
  - `entrypoint.sh` at the repo root.
  - `modules/*/module.sh` for every `modules/<name>/` directory, excluding entries in `tests/bash/excluded-scripts.bash`.
  - `utils/*.sh`, excluding `tests/bash/`.
- The inventory is sorted lexicographically by path.

**Failure behavior**:
- If the inventory is empty, the runner emits a clear error and exits non-zero.
- If a script referenced by name from a test file is missing, the runner emits a clear error and exits non-zero.

## Contract: Mock binary

**Command family**: external-tool shim.

**Inputs**:
- Tool name (matches the real tool, e.g., `kwokctl`).
- Any arguments the real tool would accept.

**Preconditions**:
- The shim is on `PATH` (the runner prepends `tests/mocks/bin/` for behavioral tests).
- The shim's `<name>.conf` file is present next to it, or the shim falls back to its built-in defaults.

**Successful behavior**:
- The shim searches its `<name>.conf` for the first rule whose `match` substring appears in the concatenated arguments.
- If a rule matches, the shim prints the rule's `stdout` and exits with the rule's `exit_code`.
- If no rule matches, the shim prints nothing on stdout, exits with `default_exit_code`, and logs the invocation to `tests/bash/.reports/mock-<name>.log`.
- Every invocation is appended to the same log file with a timestamp, the basename of the shim, and the arguments.

**Failure behavior**:
- A syntax error in the shim's `<name>.conf` causes the shim to print a clear error and exit 2.

## Contract: Per-run report

**Command family**: run summary.

**Inputs**:
- Path to the TAP file and the summary file under `tests/bash/.reports/`.

**Preconditions**:
- The runner completed (pass, fail, or skip).

**Successful behavior**:
- The TAP file is a valid TAP 13 document.
- The summary file contains exactly these `key=value` lines, one per line, in this order:
  - `timestamp=<iso8601>`
  - `branch=<git-branch>`
  - `bats_path=<absolute-path>`
  - `framework_version=<version>`
  - `mocked=<true|false>`
  - `inventory_size=<int>`
  - `pass_count=<int>`
  - `fail_count=<int>`
  - `skip_count=<int>`
  - `duration_seconds=<float>`

**Failure behavior**:
- A summary file with missing or malformed lines MUST be treated by downstream tooling as a corrupted run, not a passing run.

## Contract: Integration with `utils/validate-checkpoint.sh`

**Command family**: existing validation helper.

**Inputs**:
- A new `bash-tests` subcommand.
- The existing subcommands remain (`baseline`, `plotting`, `path-spaces`, `collision`, `docs`, `all`).

**Preconditions**:
- `bash` is on `PATH`.
- The repo is a git repository.

**Successful behavior**:
- `utils/validate-checkpoint.sh bash-tests` invokes the bats runner and propagates its exit code.
- `utils/validate-checkpoint.sh all` runs the existing subcommands and the new `bash-tests` step in sequence, with `bash-tests` last so a syntax regression does not block the other validations.
- The helper prints the per-run summary path at the end of `bash-tests` so the maintainer can copy it into the checkpoint log.

**Failure behavior**:
- If `bash-tests` fails, `all` continues to the next subcommand and reports a non-zero overall exit code at the end, matching the existing helper behavior.
