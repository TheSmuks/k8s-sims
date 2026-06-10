# Tasks: End-to-End Framework Validation

**Input**: Design documents from `/specs/004-e2e-framework-validation/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included because the feature explicitly requires end-to-end testing, every failure solved and verified, and the constitution requires test-first workflow for shell changes.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel with other tasks in the same phase when dependencies are satisfied
- **[Story]**: User story label for traceability
- Every task includes an exact repository file path or evidence artifact path

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish a clean validation workspace, preserve evidence directories, and prepare report artifacts.

- [X] T001 Verify active feature pointer in `.specify/feature.json` references `specs/004-e2e-framework-validation`
- [X] T002 Verify branch name from `git rev-parse --abbrev-ref HEAD` is constitution-compliant and record result in `specs/004-e2e-framework-validation/validation-report.md`
- [X] T003 Create the initial validation report from `specs/004-e2e-framework-validation/contracts/validation-report.md` at `specs/004-e2e-framework-validation/validation-report.md`
- [X] T004 [P] Create evidence directory `specs/004-e2e-framework-validation/evidence/`
- [X] T005 [P] Create command log file `specs/004-e2e-framework-validation/evidence/commands.log`
- [X] T006 [P] Create failure log file `specs/004-e2e-framework-validation/evidence/failures.md`
- [X] T007 [P] Create fix log file `specs/004-e2e-framework-validation/evidence/fixes.md`
- [X] T008 Create isolated validation output directory `output/e2e-validation/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Collect shared evidence, install dependencies if needed, and make validation repeatable before user story work begins.

**CRITICAL**: No user story validation can begin until this phase is complete.

- [X] T009 Record remote URL, branch, revision, and working-tree status commands in `specs/004-e2e-framework-validation/evidence/baseline.txt`
- [X] T010 Record original dirty working-tree isolation rationale in `specs/004-e2e-framework-validation/validation-report.md`
- [X] T011 [P] Record `python --version`, `uv --version`, and dependency installation outcome in `specs/004-e2e-framework-validation/evidence/python-tools.txt`
- [X] T012 [P] Record `git --version`, `docker --version`, `kubectl version --client=true --output=yaml`, `kind --version`, and `kwokctl --help` in `specs/004-e2e-framework-validation/evidence/runtime-tools.txt`
- [X] T013 [P] Extract evidence from `README.md` and `SIM_MODULES.md` into `specs/004-e2e-framework-validation/evidence/project-docs.md`
- [X] T014 [P] Extract evidence from `modules/kwok/README.md`, `modules/kube-sched/README.md`, `modules/simkube/README.md`, `modules/kubemark/README.md`, and `modules/opensim/README.md` into `specs/004-e2e-framework-validation/evidence/module-docs.md`
- [X] T015 [P] Extract governance evidence from `.specify/memory/constitution.md`, `utils/validate-checkpoint.sh`, and `tests/bash/run.sh` into `specs/004-e2e-framework-validation/evidence/governance-and-validation.md`
- [X] T016 Verify Python dependencies from `requirements.txt` are importable or install them, then record outcome in `specs/004-e2e-framework-validation/evidence/python-dependencies.txt`
- [X] T017 Create the simulator coverage matrix skeleton in `specs/004-e2e-framework-validation/validation-report.md`
- [X] T018 Create the failure-record template section in `specs/004-e2e-framework-validation/validation-report.md`
- [X] T019 Create the reproduction-steps section in `specs/004-e2e-framework-validation/validation-report.md`

**Checkpoint**: Baseline, tool, documentation, and report structures are ready for story-level validation.

---

## Phase 3: User Story 1 - Establish Verified Baseline (Priority: P1) MVP

**Goal**: Prove validation starts from a clean remote-derived baseline and every early fact has evidence.

**Independent Test**: Review `specs/004-e2e-framework-validation/validation-report.md` and `specs/004-e2e-framework-validation/evidence/baseline.txt` to confirm remote URL, branch, revision, clean status, and local isolation are recorded before validation results.

### Tests for User Story 1

- [X] T020 [P] [US1] Add baseline completeness checklist to `specs/004-e2e-framework-validation/evidence/baseline-check.md`
- [X] T021 [P] [US1] Add tool-evidence completeness checklist to `specs/004-e2e-framework-validation/evidence/tool-evidence-check.md`

### Implementation for User Story 1

- [X] T022 [US1] Execute baseline verification commands from `specs/004-e2e-framework-validation/contracts/validation-runbook.md` and save output to `specs/004-e2e-framework-validation/evidence/baseline.txt`
- [X] T023 [US1] Verify the primary user working tree isolation decision and document it in `specs/004-e2e-framework-validation/validation-report.md`
- [X] T024 [US1] Execute tool version and help commands from `specs/004-e2e-framework-validation/contracts/validation-runbook.md` and save output to `specs/004-e2e-framework-validation/evidence/runtime-tools.txt`
- [X] T025 [US1] Cross-check all baseline and tool claims against evidence and mark `specs/004-e2e-framework-validation/evidence/baseline-check.md` complete
- [X] T026 [US1] Update the Baseline and Environment sections in `specs/004-e2e-framework-validation/validation-report.md`

**Checkpoint**: User Story 1 is complete when the baseline and tool facts can be audited without terminal scrollback.

---

## Phase 4: User Story 2 - Exercise the Framework End to End (Priority: P2)

**Goal**: Run non-privileged checks, generate workloads, and exercise every active simulator mode through framework-supported paths or documented fallbacks.

**Independent Test**: Review the coverage matrix in `specs/004-e2e-framework-validation/validation-report.md` and confirm every active mode and validation layer has command evidence and a final status.

### Tests for User Story 2

- [X] T027 [P] [US2] Run `python -m pytest tests/ -v` and save output to `specs/004-e2e-framework-validation/evidence/pytest.txt`
- [X] T028 [P] [US2] Run `bash tests/bash/run.sh` and save output plus report path to `specs/004-e2e-framework-validation/evidence/bats.txt`
- [X] T029 [US2] Run `bash tests/bash/run.sh --with-mocks` and save output plus report path to `specs/004-e2e-framework-validation/evidence/bats-with-mocks.txt`
- [X] T030 [US2] Run `bash utils/validate-checkpoint.sh all` and save output to `specs/004-e2e-framework-validation/evidence/validate-checkpoint.txt`

### Implementation for User Story 2

- [X] T031 [US2] Generate vanilla smoke workload with `utils/kube-gen.py` into `output/e2e-validation/vanilla/`
- [X] T032 [P] [US2] Generate SimKube smoke workload with `utils/kube-gen.py` into `output/e2e-validation/simkube/`
- [X] T033 [P] [US2] Generate Kubemark smoke workload with `utils/kube-gen.py` into `output/e2e-validation/kubemark/`
- [X] T034 [P] [US2] Generate OpenSim smoke workload with `utils/kube-gen.py` into `output/e2e-validation/opensim/`
- [X] T035 [US2] Verify generated manifests and traces from `output/e2e-validation/` and save artifact inventory to `specs/004-e2e-framework-validation/evidence/workload-artifacts.txt`
- [X] T036 [US2] Validate SimKube trace structure from `output/e2e-validation/simkube/` and save output to `specs/004-e2e-framework-validation/evidence/simkube-traces.txt`
- [X] T037 [US2] Run KWOK smoke validation through `kube-run.sh` when prerequisites pass and save output to `specs/004-e2e-framework-validation/evidence/kwok-smoke.txt`
- [X] T038 [US2] Run Kubemark smoke validation through `kube-run.sh` when prerequisites pass and save output to `specs/004-e2e-framework-validation/evidence/kubemark-smoke.txt`
- [X] T039 [US2] Run SimKube smoke validation through `kube-run.sh` when prerequisites pass and save output to `specs/004-e2e-framework-validation/evidence/simkube-smoke.txt`
- [X] T040 [US2] Classify kube-sched validation from documentation and available fallback checks in `specs/004-e2e-framework-validation/evidence/kube-sched-status.md`
- [X] T041 [US2] Classify OpenSim validation from documentation and available fallback checks in `specs/004-e2e-framework-validation/evidence/opensim-status.md`
- [X] T042 [US2] Verify cleanup state for runtime-created clusters and save output to `specs/004-e2e-framework-validation/evidence/cleanup.txt`
- [X] T043 [US2] Update the coverage matrix in `specs/004-e2e-framework-validation/validation-report.md` for all validation layers and simulator modes

**Checkpoint**: User Story 2 is complete when every active simulator mode has a pass, fixed, skipped-documented-constraint, or blocked-external status with evidence.

---

## Phase 5: User Story 3 - Document and Resolve Every Failure (Priority: P3)

**Goal**: Convert every failed command or mismatch into a failure record, fix project-scope defects, and re-run relevant checks.

**Independent Test**: Inspect `specs/004-e2e-framework-validation/evidence/failures.md`, `specs/004-e2e-framework-validation/evidence/fixes.md`, and `specs/004-e2e-framework-validation/validation-report.md` to confirm no project-scope failure remains unresolved.

### Tests for User Story 3

- [X] T044 [US3] For each shell failure, add or update a failing bats test in `tests/bash/tests/` before changing shell implementation files
- [X] T045 [P] [US3] For each Python utility failure, add or update a failing pytest test in `tests/test_e2e_validation.py` before changing Python implementation files
- [X] T046 [P] [US3] For each documentation mismatch, add the mismatch evidence to `specs/004-e2e-framework-validation/evidence/failures.md`

### Implementation for User Story 3

- [X] T047 [US3] Create a failure record in `specs/004-e2e-framework-validation/evidence/failures.md` for every failed command, timeout, mismatch, or unexpected behavior
- [X] T048 [US3] Diagnose each failure and classify scope in `specs/004-e2e-framework-validation/evidence/failures.md`
- [X] T049 [US3] Apply project-scope shell fixes in `kube-run.sh`, `kube-director.sh`, `entrypoint.sh`, `modules/*/module.sh`, or `utils/validate-checkpoint.sh` only after task T044 is complete
- [X] T050 [US3] Apply project-scope Python fixes in `utils/kube-gen.py`, `utils/kube-plot.py`, `utils/min-max-avg.py`, `utils/binpack.py`, or `utils/sktrace.py` only after task T045 is complete
- [X] T051 [US3] Apply documentation fixes in `README.md`, `SIM_MODULES.md`, `ARCHITECTURE.md`, `DATASETS.md`, `modules/*/README.md`, or `specs/004-e2e-framework-validation/validation-report.md` when verified behavior differs from documentation
- [X] T052 [US3] Record every changed path and resolution in `specs/004-e2e-framework-validation/evidence/fixes.md`
- [X] T053 [US3] Re-run each failed check after its fix and save verification evidence under `specs/004-e2e-framework-validation/evidence/`
- [X] T054 [US3] Re-run broader regression commands and save final output to `specs/004-e2e-framework-validation/evidence/final-regression.txt`
- [X] T055 [US3] Update Failure Records and Fix Records sections in `specs/004-e2e-framework-validation/validation-report.md`

**Checkpoint**: User Story 3 is complete when every failure has a recorded outcome and all project-scope defects are fixed and re-verified.

---

## Phase 6: User Story 4 - Produce a Reproducible Validation Report (Priority: P4)

**Goal**: Finalize a concise, auditable report that another maintainer can reproduce from a clean checkout.

**Independent Test**: Follow the Reproduction Steps section in `specs/004-e2e-framework-validation/validation-report.md` from a clean checkout and confirm it names all prerequisites, commands, expected outcomes, and known blockers.

### Tests for User Story 4

- [X] T056 [P] [US4] Validate `specs/004-e2e-framework-validation/validation-report.md` against `specs/004-e2e-framework-validation/contracts/validation-report.md`
- [X] T057 [P] [US4] Validate command sequence in `specs/004-e2e-framework-validation/validation-report.md` against `specs/004-e2e-framework-validation/contracts/validation-runbook.md`

### Implementation for User Story 4

- [X] T058 [US4] Complete Baseline, Environment, Coverage Matrix, Failure Records, Fix Records, Blockers, Reproduction Steps, and Final Verdict sections in `specs/004-e2e-framework-validation/validation-report.md`
- [X] T059 [US4] Ensure every factual claim in `specs/004-e2e-framework-validation/validation-report.md` references a command output, repository file, or documentation source under `specs/004-e2e-framework-validation/evidence/`
- [X] T060 [US4] Ensure every active simulator mode from `SIM_MODULES.md` has exactly one final status in `specs/004-e2e-framework-validation/validation-report.md`
- [X] T061 [US4] Ensure external blockers and documented skips in `specs/004-e2e-framework-validation/validation-report.md` include fallback validation and user impact
- [X] T062 [US4] Ensure no project-scope unresolved failures remain in `specs/004-e2e-framework-validation/evidence/failures.md`
- [X] T063 [US4] Update `specs/004-e2e-framework-validation/quickstart.md` if implementation commands diverged from the planned validation runbook
- [X] T064 [US4] Update `specs/004-e2e-framework-validation/plan.md` if the verified validation structure diverged from the planned structure

**Checkpoint**: User Story 4 is complete when the report can be audited and reproduced without hidden local state.

---

## Final Phase: Polish & Cross-Cutting Concerns

**Purpose**: Final consistency checks, formatting, and governance completion.

- [X] T065 [P] Check `specs/004-e2e-framework-validation/tasks.md` task completion state and evidence links for consistency
- [X] T066 [P] Check markdown formatting in `specs/004-e2e-framework-validation/validation-report.md`
- [X] T067 [P] Check Spec Kit artifacts `specs/004-e2e-framework-validation/spec.md`, `specs/004-e2e-framework-validation/plan.md`, and `specs/004-e2e-framework-validation/quickstart.md` for consistency with final implementation
- [X] T068 Run `git status --short --branch` and record final working-tree state in `specs/004-e2e-framework-validation/evidence/final-git-status.txt`
- [X] T069 Review changed files and ensure commits can use Conventional Commit format documented in `.specify/memory/constitution.md`
- [X] T070 Finalize `specs/004-e2e-framework-validation/validation-report.md` with overall verdict and remaining external blockers

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 Setup**: No dependencies.
- **Phase 2 Foundational**: Depends on Phase 1. Blocks all user-story work.
- **Phase 3 US1**: Depends on Phase 2. MVP scope.
- **Phase 4 US2**: Depends on Phase 2 and should use US1 evidence conventions.
- **Phase 5 US3**: Depends on failures discovered in Phase 4 but may begin as soon as the first failure appears.
- **Phase 6 US4**: Depends on US1 and US2 evidence, and on US3 for any failures.
- **Final Phase**: Depends on all selected user stories.

### User Story Dependencies

- **US1 Establish Verified Baseline**: No story dependency after foundational setup.
- **US2 Exercise the Framework End to End**: Can start after foundational setup, but final evidence should reference US1 baseline facts.
- **US3 Document and Resolve Every Failure**: Starts when any US2 or foundational command fails. Project-scope fixes depend on test-first tasks T044 or T045 where relevant.
- **US4 Produce a Reproducible Validation Report**: Depends on US1 baseline, US2 coverage, and US3 failure/fix records.

### Within Each User Story

- Test/checklist tasks precede implementation tasks.
- Evidence capture precedes report claims.
- Failure records precede fixes.
- Fixes precede re-runs.
- Re-runs precede final report status.

---

## Parallel Opportunities

- T004, T005, T006, and T007 can run in parallel after T003.
- T011, T012, T013, T014, and T015 can run in parallel after T009 and T010.
- T020 and T021 can run in parallel at the start of US1.
- T027 and T028 can run in parallel if separate terminals are available; T029 should wait if both bats runs would share report paths.
- T032, T033, and T034 can run in parallel after T031 establishes the output root.
- T040 and T041 can run in parallel with runtime smoke checks because they write distinct files.
- T045 and T046 can run in parallel with shell test preparation T044 when failures affect different files.
- T056 and T057 can run in parallel after the validation report is drafted.
- T065, T066, and T067 can run in parallel during final polish.

---

## Parallel Example: User Story 2

```bash
# Generate independent simulator workloads in parallel after the output root exists
Task: "T032 [US2] Generate SimKube smoke workload with utils/kube-gen.py into output/e2e-validation/simkube/"
Task: "T033 [US2] Generate Kubemark smoke workload with utils/kube-gen.py into output/e2e-validation/kubemark/"
Task: "T034 [US2] Generate OpenSim smoke workload with utils/kube-gen.py into output/e2e-validation/opensim/"

# Document platform-constrained modes while runtime smoke tests are running
Task: "T040 [US2] Classify kube-sched validation in specs/004-e2e-framework-validation/evidence/kube-sched-status.md"
Task: "T041 [US2] Classify OpenSim validation in specs/004-e2e-framework-validation/evidence/opensim-status.md"
```

## Parallel Example: User Story 3

```bash
# When failures touch different layers, prepare evidence in parallel
Task: "T044 [US3] Add or update failing bats test in tests/bash/tests/"
Task: "T045 [US3] Add or update failing pytest test in tests/"
Task: "T046 [US3] Add documentation mismatch evidence to specs/004-e2e-framework-validation/evidence/failures.md"
```

## Parallel Example: User Story 4

```bash
# Validate report and runbook contracts in parallel
Task: "T056 [US4] Validate validation-report.md against contracts/validation-report.md"
Task: "T057 [US4] Validate validation-report.md command sequence against contracts/validation-runbook.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 Setup.
2. Complete Phase 2 Foundational tasks.
3. Complete Phase 3 User Story 1.
4. Stop and validate that the clean baseline and tool facts are auditable.
5. Commit or checkpoint if desired using a Conventional Commit message.

### Incremental Delivery

1. Add US1 baseline evidence and report sections.
2. Add US2 framework and simulator coverage.
3. Add US3 failure records, fixes, and re-verification.
4. Add US4 final reproducible validation report.
5. Run final polish and governance checks.

### Parallel Team Strategy

With multiple agents or developers:

1. One worker owns baseline and tool evidence under `specs/004-e2e-framework-validation/evidence/`.
2. One worker owns non-privileged checks and workload generation.
3. One worker owns simulator smoke classification and runtime blockers.
4. One worker owns failure/fix records and report assembly.

---

## Notes

- Do not delete or reset the user's original dirty working tree.
- Every failure gets a failure record even if a later retry passes.
- Shell changes require test-first bats coverage.
- Use isolated output directories to avoid silent overwrites.
- Keep Spec Kit documents synchronized if implementation diverges from this plan.
