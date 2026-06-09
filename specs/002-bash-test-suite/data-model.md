# Data Model: Bash Correctness Test Suite

## Test Suite Run

Represents one execution of the bats suite. Written to `tests/bash/.reports/<timestamp>.tap` (TAP) and `tests/bash/.reports/<timestamp>.summary` (text).

**Fields**:
- `timestamp`: ISO 8601 local time of the run.
- `branch`: Active git branch when the run started.
- `framework_version`: Resolved bats version (1.11.0 or the user's local bats).
- `bats_path`: Absolute path to the bats binary used.
- `mocked`: `true` if `--with-mocks` was passed, otherwise `false`.
- `inventory_size`: Number of shell scripts auto-discovered.
- `pass_count`, `fail_count`, `skip_count`: Counts from the TAP summary.
- `duration_seconds`: Wall-clock duration of the suite.

**Validation rules**:
- The TAP file MUST start with `1..N` where N is the inventory size or the test file count.
- The summary file MUST be parseable as a small `key=value` document so the checkpoint log can include the run without re-running the suite.
- When `mocked=false` and a test requires an external tool, the test file MUST `skip` with a clear `reason` and the framework MUST record the reason in the TAP output.

**Relationships**:
- Produced by the test runner.
- Consumed by the maintainer (and by `specs/002-bash-test-suite/checkpoints.md` if the user wants to record a run).

## Script Inventory

Represents the set of shell scripts the suite is responsible for. Auto-discovered at run time from the expected globs; allowlist maintained at `tests/bash/excluded-scripts.bash`.

**Fields**:
- `path`: Path relative to the repository root (POSIX form).
- `category`: One of `root`, `entrypoint`, `module`, `utility`.
- `glob_source`: Which glob produced the entry (`*.sh` at root, `modules/*/module.sh`, etc.).
- `static_required`: `true` if the suite MUST emit at least one static test (e.g., `bash -n`) for this script.
- `behavioral_required`: `true` if the suite SHOULD emit at least one behavioral test for this script; `false` when the script is a vendored template or has no observable behavior (e.g., `modules/template/module.sh`).
- `required_external_tools`: List of tool names that a behavioral test for this script depends on. When any are missing, the test is skipped with the missing tool name as the reason.
- `allowlisted_for_skip`: `true` when the script is in `tests/bash/excluded-scripts.bash` and the suite MUST NOT generate tests for it.

**Validation rules**:
- Adding or removing a tracked shell script under the expected globs MUST require no test changes; the inventory reflects the new state on the next run.
- A script listed in `tests/bash/excluded-scripts.bash` MUST NOT appear in the inventory.
- A behavioral test that names a script by path MUST fail with a clear error if the script is missing at run time.

**Relationships**:
- Used by the test runner to enumerate `*.bats` test files via `tests/bash/tests/<category>/<basename>.bats` globs.
- Used by the static check to invoke `bash -n` for every inventory entry.
- Used by the `--with-mocks` runner to know which behavioral tests can be forced to run with shims.

## Mock Binary

Represents a shim binary that emulates an external tool for behavioral tests. Lives under `tests/mocks/bin/<name>`.

**Fields**:
- `name`: The shim's filename, matching the real tool name (e.g., `kwokctl`).
- `real_tool`: The real tool this shim emulates.
- `default_exit_code`: Default exit code when the shim is invoked with no matching behavior.
- `responses`: A set of `<arg-substring>` → `<stdout-line>;<exit-code>` rules. The shim searches the rules in order and applies the first match.
- `log_file`: Optional path under `tests/bash/.reports/` where the shim appends each invocation (name + args) so behavioral tests can assert on tool calls.

**Validation rules**:
- The shim MUST be a small POSIX shell script (no `bash` required for the shim itself).
- The shim MUST exit with the configured code for the matched rule, or `default_exit_code` if no rule matches.
- The shim MUST be silent on stdout unless a rule specifies output, and MUST log every invocation to its log file.

**Relationships**:
- Picked up by the `--with-mocks` runner via a `PATH` prepend.
- Used by individual behavioral tests to drive `kube-run.sh`, `entrypoint.sh`, `kube-director.sh`, and module scripts through the same code paths they would take with real tools, but with deterministic responses.

## Test Fixture

Represents a small, versioned file or directory that a behavioral test depends on. Lives under `tests/bash/fixtures/`.

**Fields**:
- `name`: Relative path under `tests/bash/fixtures/`.
- `kind`: One of `experiment-dir`, `spaced-path`, `output-csv`, `simulator-config`.
- `purpose`: Short string describing the behavior the fixture exercises.
- `expected_behavior`: The behavior the test asserts against (e.g., "runner preserves the existing file as `<base>.preserved-*.csv`").

**Validation rules**:
- Fixtures MUST be small enough to be reviewed in a single diff.
- Fixtures MUST NOT contain secrets, real kubeconfigs, or real `.env` content.
- Fixtures MUST be referenced by name from the test file and the test file MUST assert on the fixture's expected behavior.

**Relationships**:
- Consumed by behavioral tests.

## Skip Reason

Represents the textual reason a test was skipped, recorded in the TAP output and the per-run summary.

**Fields**:
- `missing_tool`: The first external tool the test depends on that is not on `PATH`. Empty if the skip is for a non-tool reason.
- `reason_text`: Free-form explanation, always beginning with `missing tool: <name>` when `missing_tool` is set.
- `documentation_reference`: Optional pointer to the docs that explain the skip (e.g., `SIM_MODULES.md` for missing `kwokctl`).

**Validation rules**:
- The reason MUST identify the missing tool by name when the cause is a missing binary.
- The reason MUST be human-readable and short (one line).
- The reason MUST be included in the TAP output so consumers can filter skipped tests.

**Relationships**:
- Recorded by the test runner when a behavioral test's `requires_tools` check fails.
- Displayed in the per-run summary.

## Agent Context Reference

Represents the auto-managed `AGENTS.md` block that tells future agents where the active plan lives. The `<!-- SPECKIT START -->` ... `<!-- SPECKIT END -->` block in `AGENTS.md` is updated to point to this feature's `plan.md`.

**Fields**:
- `path`: Project-relative path to the active plan (e.g., `specs/002-bash-test-suite/plan.md`).
- `updated_at`: ISO 8601 timestamp of the last update.

**Validation rules**:
- The block MUST be the only Spec-Kit-managed content in `AGENTS.md`.
- Other hand-written content in `AGENTS.md` MUST be preserved verbatim.
- The block MUST NOT be deleted by tooling; tooling rewrites only the lines between the markers.

**Relationships**:
- Owned by the agent-context extension.
- Updated by `/speckit-plan` and `/speckit-tasks` workflows.
