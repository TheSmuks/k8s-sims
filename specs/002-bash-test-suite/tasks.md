# Tasks: Bash Correctness Test Suite

**Input**: Design documents from `specs/002-bash-test-suite/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/cli-contracts.md, quickstart.md
**Tests**: The feature IS a test suite. Every user story phase begins with a Tests section so the suite's own behavior is verified before more functionality is added. The implementation tasks for the new suite are sequenced after the tests for that story to keep the contract-first rhythm.

**Organization**: Tasks are grouped by user story. Each story's tests, then its implementation, then its validation, then a checkpoint commit.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1, US2, US3
- Every task includes an exact file path

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the suite's own scaffolding so the rest of the work has a home.

- [ ] T001 Create the suite directory tree under `tests/bash/` and `tests/mocks/` per `specs/002-bash-test-suite/plan.md`
- [ ] T002 Add `tests/bash/.bats/`, `tests/bash/.reports/`, and `tests/bash/.cache/` to `.gitignore` so bootstrapped bats and per-run reports are not committed
- [ ] T003 Create the empty allowlist `tests/bash/excluded-scripts.bash` with the documented format
- [ ] T004 Create `tests/bash/helpers/inventory.bash` with the glob + allowlist enumeration
- [ ] T005 [P] Create `tests/bash/helpers/skip.bash` with the `batslib_skip` and missing-tool helpers
- [ ] T006 [P] Create `tests/bash/helpers/bats.bash` with the bats resolution and report-writing helpers
- [ ] T007 Create `tests/bash/fixtures/.keep` so the fixtures directory is tracked
- [ ] T008 [P] Create `tests/mocks/conf/.keep` and `tests/mocks/bin/.keep` placeholders

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build the runner and bootstrap so the user story tests have something to run.

**Critical**: US1 tests cannot run without these.

- [ ] T009 Implement `tests/bash/bootstrap-bats.sh` that downloads bats-core 1.11.0 into `tests/bash/.bats/` on first run and is a no-op thereafter
- [ ] T010 Implement `tests/bash/run.sh` that bootstraps bats, enumerates the inventory, runs every test under `tests/bash/tests/`, writes the TAP and summary reports, and exits with the suite's overall result
- [ ] T011 Smoke-run `tests/bash/run.sh` on a host with no `.bats` directory to confirm the bootstrap and TAP output, and record the run in `specs/002-bash-test-suite/checkpoints.md`
- [ ] T012 Add `bash-tests` subcommand and fold it into the `all` sequence in `utils/validate-checkpoint.sh`
- [ ] T013 Run `utils/validate-checkpoint.sh bash-tests` and record the result in `specs/002-bash-test-suite/checkpoints.md`
- [ ] T014 Commit the foundational checkpoint and record the commit reference in `specs/002-bash-test-suite/checkpoints.md`

**Checkpoint**: Foundation ready. The runner exists, the bootstrap works, and `utils/validate-checkpoint.sh` can invoke the suite. No tests yet.

---

## Phase 3: User Story 1 - Detect script regressions before commit (Priority: P1) MVP

**Goal**: A maintainer can run a single command and see whether a script regressed on argument parsing, error handling, or result preservation. Static checks cover every inventory entry; behavioral checks cover the runner with mocks.

**Independent Test**: Run the suite once. Every test passes (or is skipped with a clear reason). Intentionally introducing a regression on `kube-run.sh` (e.g., removing the preserve warning) causes the specific behavioral test to fail and the suite to exit non-zero.

### Tests for User Story 1

- [ ] T015 [P] [US1] Author `tests/bash/tests/static-syntax.bats` that iterates the inventory and runs `bash -n` on every entry, failing with the script path and parse error
- [ ] T016 [P] [US1] Author `tests/bash/tests/static-strict.bats` that runs the runner scripts under `set -u` and `set -o pipefail` in a subshell and fails on unbound variable or pipeline errors
- [ ] T017 [P] [US1] Author `tests/bash/tests/behavioral-runner.bats` covering `kube-run.sh` argument parsing, missing-experiment-path error, and result preservation default behavior using fixtures and PATH shims
- [ ] T018 [US1] Run the new tests on the unmodified scripts and confirm they all pass (US1 tests-first checkpoint) in `specs/002-bash-test-suite/checkpoints.md`

### Implementation for User Story 1

- [ ] T019 [P] [US1] Implement shim binaries for `kwokctl`, `kubectl`, `kind`, and `docker` under `tests/mocks/bin/` plus a small shared shell helper at `tests/mocks/bin/_shim.sh` and a per-shim `<name>.conf` at `tests/mocks/conf/`
- [ ] T020 [P] [US1] Add behavioral fixtures under `tests/bash/fixtures/experiment-missing/`, `tests/bash/fixtures/experiment-spaced/`, and `tests/bash/fixtures/result-csv/` so the runner tests have deterministic inputs
- [ ] T021 [US1] Wire the inventory and the `--with-mocks` path into `tests/bash/run.sh` so US1's behavioral tests pick up the shims and the inventory size appears in the summary
- [ ] T022 [US1] Run `tests/bash/run.sh` and confirm pass counts, fail counts, and inventory size match expectations; record the run in `specs/002-bash-test-suite/checkpoints.md`
- [ ] T023 [US1] Commit US1 checkpoint and record the commit reference in `specs/002-bash-test-suite/checkpoints.md`

**Checkpoint**: User Story 1 is independently functional when a maintainer can run `./tests/bash/run.sh`, see a TAP summary, and rely on a regression in `kube-run.sh` to fail a specific named test.

---

## Phase 4: User Story 2 - Run behavioral checks on hosts without simulator tooling (Priority: P1)

**Goal**: A maintainer on a host without Docker, kind, kwok, kubectl, or OpenSimulator can still run the behavioral tests. The default behavior is to skip with a clear reason; `--with-mocks` forces the shim layer.

**Independent Test**: Run the suite on a host without simulator tools. Every test that needs only `bash` and the repo files passes or skips. Run with `--with-mocks` to force behavioral tests through shims. No test fails because a tool is missing.

### Tests for User Story 2

- [ ] T024 [P] [US2] Author `tests/bash/tests/skip-reason.bats` that asserts every behavioral test file emits a `skip` TAP line with `missing tool: <name>` when its external dependency is absent
- [ ] T025 [P] [US2] Author `tests/bash/tests/with-mocks.bats` that asserts `--with-mocks` results in PASS for at least one behavioral test per script category
- [ ] T026 [US2] Run the new tests on the current host (no simulator tools) and confirm skip behavior is correct in `specs/002-bash-test-suite/checkpoints.md`

### Implementation for User Story 2

- [ ] T027 [P] [US2] Extend the shim layer with `cgexec`, `cgdelete`, and the `cgcreate` companion if the modules under test reference them, including per-shim `.conf` rules
- [ ] T028 [P] [US2] Add the missing-tool detection helper to `tests/bash/helpers/skip.bash` so each behavioral test can declare its dependencies once
- [ ] T029 [US2] Add the `--with-mocks` flag to `tests/bash/run.sh` and ensure the shim layer is prepended to `PATH` only when requested
- [ ] T030 [US2] Run `tests/bash/run.sh` and `tests/bash/run.sh --with-mocks` and record both results in `specs/002-bash-test-suite/checkpoints.md`
- [ ] T031 [US2] Commit US2 checkpoint and record the commit reference in `specs/002-bash-test-suite/checkpoints.md`

**Checkpoint**: User Story 2 is independently functional when a maintainer on a bare host sees a TAP summary with every behavioral test either passing or skipped with a clear reason, and `--with-mocks` produces a non-skipping summary.

---

## Phase 5: User Story 3 - Integrate the suite into the existing validation helper (Priority: P2)

**Goal**: The maintainer does not need a second command. `utils/validate-checkpoint.sh bash-tests` invokes the bats runner, and `utils/validate-checkpoint.sh all` includes the bash-tests step in its sequence.

**Independent Test**: Running `utils/validate-checkpoint.sh bash-tests` produces the same output as `./tests/bash/run.sh` and propagates the exit code. Running `utils/validate-checkpoint.sh all` interleaves the bash-tests step with the existing validation steps and ends with a non-zero exit code if any test failed.

### Tests for User Story 3

- [ ] T032 [US3] Author `tests/bash/tests/helper-integration.bats` that asserts `utils/validate-checkpoint.sh bash-tests` exits 0 when the suite passes and non-zero when a synthetic test fails (using a temp copy of the runner and a deliberately failing bats file)

### Implementation for User Story 3

- [ ] T033 [P] [US3] Add the `bash-tests` subcommand handler to `utils/validate-checkpoint.sh` and append it to the `all` subcommand sequence
- [ ] T034 [US3] Print the latest report path at the end of the `bash-tests` step so the checkpoint log can reference it
- [ ] T035 [US3] Run `utils/validate-checkpoint.sh all` on the local host and record the result in `specs/002-bash-test-suite/checkpoints.md`
- [ ] T036 [US3] Commit US3 checkpoint and record the commit reference in `specs/002-bash-test-suite/checkpoints.md`

**Checkpoint**: User Story 3 is independently functional when a maintainer who already knows `utils/validate-checkpoint.sh` can run `bash-tests` and `all` without learning a new command, and the helper's exit code reflects the suite's overall result.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final consistency checks and any cleanup across all user stories.

- [ ] T037 [P] Update `specs/002-bash-test-suite/quickstart.md` with the actual run command outputs once all stories are merged
- [ ] T038 [P] Update `specs/002-bash-test-suite/tasks.md` final notes with the actual commit references
- [ ] T039 [P] Update `specs/002-bash-test-suite/checkpoints.md` with the final consolidated report and a short summary of pass/fail/skip counts
- [ ] T040 Run the full local validation suite (`utils/validate-checkpoint.sh all`) and record the output in `specs/002-bash-test-suite/checkpoints.md`
- [ ] T041 Run `git status --short` and record clean/expected state in `specs/002-bash-test-suite/checkpoints.md`
- [ ] T042 Commit the final polish checkpoint and record the commit reference in `specs/002-bash-test-suite/checkpoints.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies; can start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1; blocks all user stories.
- **User Story 1 (Phase 3, P1)**: Depends on Foundational; MVP and complete without other stories.
- **User Story 2 (Phase 4, P1)**: Depends on Foundational and on US1's shim layer (T019). Builds on US1's runner behavior.
- **User Story 3 (Phase 5, P2)**: Depends on Foundational and on the runner and tests from US1 and US2.
- **Polish (Phase 6)**: Depends on all selected user stories being complete.

### User Story Dependencies

- **US1 (P1)**: No dependency on other stories; recommended MVP.
- **US2 (P1)**: Depends on US1's shim layer; shares the runner.
- **US3 (P2)**: Depends conceptually on US1 (a passing suite is the input to integration) but the integration test itself is independent.

### Within Each User Story

- Tests first, then implementation, then a validation run, then a checkpoint commit.
- File-based coordination: tasks touching the same file are sequential; tasks touching different files are marked [P].

### Parallel Opportunities

- Phase 1 fixtures and helpers (T002, T003, T005, T006, T007, T008) can run in parallel.
- US1's static test files (T015, T016) and shim scripts (T019, T020) can run in parallel.
- US2's extended shims and helper extension (T027, T028) can run in parallel.
- US3's helper edit and report-path print (T033, T034) can run in parallel.
- Phase 6's documentation updates (T037, T038, T039) can run in parallel.

## Parallel Example: User Story 1

```bash
# Independent tasks after the foundational runner exists:
Task: "T015 [P] [US1] Author tests/bash/tests/static-syntax.bats"
Task: "T016 [P] [US1] Author tests/bash/tests/static-strict.bats"
Task: "T019 [P] [US1] Implement shim binaries under tests/mocks/bin/"
Task: "T020 [P] [US1] Add behavioral fixtures under tests/bash/fixtures/"
```

## Parallel Example: User Story 2

```bash
# Independent tasks after US1's shim layer is in place:
Task: "T024 [P] [US2] Author tests/bash/tests/skip-reason.bats"
Task: "T025 [P] [US2] Author tests/bash/tests/with-mocks.bats"
Task: "T027 [P] [US2] Extend shim layer with cgexec/cgdelete/cgcreate"
Task: "T028 [P] [US2] Add missing-tool detection to tests/bash/helpers/skip.bash"
```

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 Setup.
2. Complete Phase 2 Foundational.
3. Complete Phase 3 US1.
4. Stop and validate US1 independently. Confirm `./tests/bash/run.sh` runs and a deliberate regression on `kube-run.sh` causes a specific test to fail.
5. Commit the US1 checkpoint before starting US2.

### Incremental Delivery

1. Setup + Foundational: runner, bootstrap, helper integration.
2. US1: static checks + behavioral checks for the runner.
3. US2: skip-with-reason and `--with-mocks` for the remaining behavioral tests.
4. US3: helper integration is a thin wrapper, so it lands last.
5. Polish: finalize the checkpoint log and quickstart.

### Checkpoint Commit Strategy

- Commit after Phase 2 and after each user story phase.
- Every checkpoint commit MUST have matching validation evidence in `specs/002-bash-test-suite/checkpoints.md`.
- If a test cannot run on the local host (e.g., a behavioral test that needs Docker), the skip reason is recorded as the validation evidence.

## Notes

- The suite reuses the existing `utils/validate-checkpoint.sh` helper as its single integration point; no parallel runner.
- The bats bootstrap is a no-op once `tests/bash/.bats/` exists.
- Mock binaries are local-only and are not a substitute for real simulator tools.
- Python tests are out of scope and continue to be covered by the existing `py_compile` and plotting validations.
- Avoid reading or exposing `.env` contents; treat local environment files as sensitive.
