# Feature Specification: Bash Correctness Test Suite

**Feature Branch**: `002-bash-test-suite`
**Created**: 2026-06-09
**Status**: Draft
**Input**: User description: "Add bash correctness check to each script, like a test suite, so we know that we haven't regressed after changes or discover errors."

## Clarifications

### Session 2026-06-09

- Q: How should the suite handle a host where `bats` is not installed? → A: Bootstrap bats on first run by downloading a pinned release into a gitignored directory under `tests/bash/.bats/`.
- Q: How is the script inventory sourced for the test suite? → A: Auto-discover the inventory by globbing the expected paths (root `*.sh`, `modules/*/module.sh`, `utils/*.sh`, `entrypoint.sh`). No manual list.

## User Scenarios & Testing

### User Story 1 - Detect script regressions before commit (Priority: P1)

A maintainer changing a shell script wants a fast, automated way to know whether their change broke argument parsing, error handling, or result preservation behavior. The test suite is run locally with a single command and reports clear pass/fail information per script so regressions are isolated and easy to fix.

**Why this priority**: This is the core reason the feature exists. Catching regressions at edit time is more valuable than catching them at release time, and it is the only way the suite justifies its own cost.

**Independent Test**: Run the suite once after the implementation is complete. Every script under test passes the static checks. Behavioral tests for the parts of the suite that do not require external tools pass; tests that require external tools that are not installed on the local host are reported as skipped with a clear reason.

**Acceptance Scenarios**:
1. **Given** the repository with the test suite installed, **When** the maintainer runs the suite with no arguments, **Then** every test is executed once and the result is a TAP summary that shows the number of tests run, passed, failed, and skipped.
2. **Given** a script that has a syntax error, **When** the maintainer runs the suite, **Then** the test for that script reports a failure with the line number or the parse error message, and the overall suite exits non-zero.
3. **Given** a script that no longer emits a required warning or error path, **When** the maintainer runs the suite, **Then** the specific behavioral test for that path fails and the failure message names the missing behavior.

---

### User Story 2 - Run behavioral checks on hosts without simulator tooling (Priority: P1)

A maintainer on a Windows/Git-Bash or minimal Linux machine does not have Docker, kind, kwok, kubectl, or OpenSimulator installed. They still want the behavioral tests for the parts of the runner that do not require real simulators to be exercised, so that argument parsing, path handling, output preservation, and the warn-or-fail message paths are tested even when full execution is impossible.

**Why this priority**: Without this, the suite would be useless on the most common contributor machines and would force the same `kwokctl: command not found` environment blocker on every run, which defeats the purpose of regression detection.

**Independent Test**: Run the suite on a host without simulator tools. Every test that requires only `bash`, `python`, and the repository files passes or skips. No test silently fails because of a missing tool; the skip reason is recorded.

**Acceptance Scenarios**:
1. **Given** a host without `kwokctl`, `kind`, `kubectl`, or `docker`, **When** the maintainer runs the suite, **Then** tests that require those tools are reported as skipped and the reason is the missing tool name, and tests that only use `bash` and the repo files run and pass.
2. **Given** a path containing spaces in a test fixture, **When** the maintainer runs the suite, **Then** the path-with-spaces tests pass and the suite reports the location of the fixture used.
3. **Given** a test environment where the test runner can install the optional PATH-shim mocks, **When** the maintainer runs the suite with the `--with-mocks` flag, **Then** the behavioral tests for module-loading, result preservation, and cleanup use the shim binaries and are reported as `pass` rather than `skip`.

---

### User Story 3 - Integrate the suite into the existing validation helper (Priority: P2)

A maintainer who already runs `utils/validate-checkpoint.sh` to validate checkpoints should not need a second command for shell correctness. The new test suite is wired into the existing helper so the existing baseline, plotting, path-with-spaces, collision, and docs commands stay available and a new `bash-tests` command is added.

**Why this priority**: Discoverability and adoption. Without a single entry point, the suite is more likely to be skipped.

**Independent Test**: Run `utils/validate-checkpoint.sh` with the new `bash-tests` subcommand. The test suite runs as part of the helper and its summary is included in the helper's output.

**Acceptance Scenarios**:
1. **Given** the helper is updated, **When** the maintainer runs `utils/validate-checkpoint.sh bash-tests`, **Then** the suite runs to completion and the helper's exit code reflects the suite's overall result.
2. **Given** the helper is run without arguments (`all`), **When** the maintainer executes it, **Then** the bash-tests step is included in the sequence and its output is interleaved with the other validation steps.

### Edge Cases

- What happens when a shell script uses CRLF line endings? The static test should not fail on CRLF; behavioral tests that source a module should still work because bash on Git-Bash accepts CRLF only when the script is invoked through a shebang. The suite documents which scripts are expected to be CRLF and treats a shebang-on-second-line breakage as a script bug, not a test bug.
- What happens when an existing script is renamed or removed? The suite's script inventory is auto-discovered from a discoverable list so that a missing file fails the inventory test and forces the maintainer to update the suite rather than silently leaving an unused test behind.
- What happens when a test fixture is edited so that a positive case becomes a negative case? The test name, the fixture path, and the expected behavior are versioned together via the test file, so a behavioral change must update the test, not just the fixture.
- What happens when a script depends on a tool that is present on some hosts but not others? The test that requires that tool uses the skip helper and records the missing tool in the skip message. The `--with-mocks` flag and a small mock directory under `tests/mocks/bin/` exist so the test can be forced to run in CI even when the real tool is missing.
- What happens when a script's behavior changes for a reason documented in `SIM_MODULES.md` or `SECURITY.md`? The relevant test is updated at the same time and the test's `name:` and `bats skip` reason point at the documentation, so a future maintainer who removes the test sees the policy reference in the diff.

## Requirements

### Functional Requirements

- **FR-001**: The suite MUST run on a host with only `bash`, `python`, `git`, and a `tar`/POSIX shell. The user MUST NOT need any of Docker, kind, kwok, kubectl, or OpenSimulator to execute the suite end to end.
- **FR-002**: The suite MUST include a static check that runs `bash -n` on every script in the inventory and reports any parse error with the script path and the failing line.
- **FR-003**: The suite MUST include a static check that runs the scripts under `set -u` and `set -o pipefail` in a subshell to detect uninitialized variable use and unset pipeline failures for at least the runner scripts.
- **FR-004**: The suite MUST include behavioral tests for `kube-run.sh` argument parsing, missing-experiment-path error, and result-preservation default behavior using fixtures and PATH shims.
- **FR-005**: The suite MUST include behavioral tests for `kube-director.sh` module loading and simulator iteration using fixtures and PATH shims.
- **FR-006**: The suite MUST include behavioral tests for `entrypoint.sh` image-pull failure reporting using PATH shims that simulate `docker image pull` exit codes.
- **FR-007**: The suite MUST include behavioral tests for each module script under `modules/*/module.sh` covering module loading, log message presence, and the simulator-specific behavior described in the inventory (`SIM_MODULES.md`).
- **FR-008**: The suite MUST skip tests that require an external tool that is not installed and MUST report the missing tool in the skip reason.
- **FR-009**: The suite MUST support a `--with-mocks` flag that prepends the repository's mock binary directory to `PATH` and re-runs the behavioral tests against the shim binaries.
- **FR-010**: The suite MUST produce TAP output so existing TAP consumers, editors, and CI systems can render the results.
- **FR-011**: The suite MUST be invokable through `utils/validate-checkpoint.sh` with a new `bash-tests` subcommand and MUST be included in the `all` subcommand sequence.
- **FR-012**: The suite MUST auto-discover the script inventory by globbing the expected paths (root `*.sh` excluding template/library files, `modules/*/module.sh`, `utils/*.sh`, `entrypoint.sh`) and MUST fail loudly if a script referenced by name from a behavior test is missing. Adding or removing a tracked shell script under the expected globs requires no test changes.
- **FR-013**: The suite MUST provide at least one path-with-spaces test for the runner and dataset generator paths because path quoting regressions are a known failure mode in this repository.
- **FR-014**: The suite MUST be runnable in the local environment on this Windows/Git-Bash host without privileged execution and MUST NOT require network access for the test code itself (test fixtures are local; mocks are local).
- **FR-015**: The suite MUST write a per-run summary under `tests/bash/.reports/` (gitignored) with pass, fail, skip counts and the per-test duration so the existing checkpoint log can reference the latest run by report path.
- **FR-016**: The suite MUST bootstrap a pinned version of `bats` into the gitignored `tests/bash/.bats/` directory on first run if `bats` is not on `PATH`, and MUST use that local copy for subsequent runs. The bootstrap step MUST be a no-op when `bats` is already on `PATH` and MUST NOT require network access once the local copy exists.

### Key Entities

- **Test Suite Run**: A single execution of the suite, identified by the timestamp and the active branch, with a summary of pass/fail/skip counts and a list of per-test results.
- **Script Inventory**: The list of shell scripts the suite is responsible for, with metadata about whether the script needs external tools, what the skip reason would be, and which mock binaries replace which real tools.
- **Mock Binary**: A small shell script under `tests/mocks/bin/` that emulates an external tool (e.g., `kwokctl`, `kubectl`, `kind`, `docker`, `cgexec`) by writing a controlled response to stdout and exiting with a known status.
- **Test Fixture**: A small, versioned file (e.g., a YAML, an empty CSV, a spaced path) under `tests/fixtures/` that the suite uses to drive a behavioral test.
- **Skip Reason**: The textual reason a test is skipped, always beginning with the missing tool name when the cause is a missing binary.

## Success Criteria

- **SC-001**: A maintainer can run a single command that completes the bash correctness test suite in under 60 seconds on the current Windows/Git-Bash host when simulator tools are not installed.
- **SC-002**: 100% of scripts in the script inventory have at least one static test and at least one behavioral test (or a documented skip when only static is feasible).
- **SC-003**: When a script regresses on a previously passing behavior (e.g., stops emitting the result preservation warning), the corresponding test fails on the next suite run and the failure message names the regression.
- **SC-004**: The suite is integrated into `utils/validate-checkpoint.sh` so existing maintainers do not need to learn a new command, and the helper's `bash-tests` subcommand returns the suite's overall pass/fail status as its own exit code.
- **SC-005**: A user on a host with no simulator tools can run `--with-mocks` to execute the behavioral tests in a deterministic mock environment, and the suite reports a result for every test rather than skipping the entire behavioral layer.

## Assumptions

- The maintainer is the primary user; CI usage is a secondary concern that the suite is also designed to support, but local execution is the priority.
- The existing scripts use POSIX-ish bash features and are expected to remain compatible with the `bash` that ships with Git-Bash on Windows. A newer bash-only feature is allowed only if the test harness documents the minimum required version.
- The existing `utils/validate-checkpoint.sh` helper is the single integration point for ad-hoc validation commands. The new suite does not introduce a parallel runner.
- The mock binaries under `tests/mocks/bin/` are intentionally limited to test behavior; they are not a substitute for the real tools, and the suite documents this in the `SECURITY.md` and `SIM_MODULES.md` style as needed.
- The existing fixtures under `tests/fixtures/results/` continue to be valid for both plotting validation and the new bash behavioral tests, but the new suite introduces its own fixtures under `tests/bash/fixtures/` and `tests/mocks/` so the two suites do not share mutable state.
- The suite is a developer tool, not a user-facing command, and is therefore exempt from the `result preservation` and `privilege` policies that apply to the actual benchmark runner. The suite is still runnable on the local machine without elevated permissions.
- The first version of the suite targets only the shell scripts in the repository root, the `modules/*/module.sh` adapters, the `utils/*.sh` helpers, and `entrypoint.sh`. Python utilities are out of scope for this feature; their existing `py_compile` and fixture-based checks remain the source of truth.
