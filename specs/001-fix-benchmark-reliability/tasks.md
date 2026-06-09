# Tasks: Benchmark Reliability Stabilization

**Input**: Design documents from `specs/001-fix-benchmark-reliability/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/cli-contracts.md, quickstart.md

**Tests**: The feature explicitly requires verification after each part. Tasks below include validation commands/fixtures and checkpoint recording; implementation should commit after each checkpoint group.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Every task includes an exact file path or validation artifact path

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm the pre-change release exists and prepare reusable local validation fixtures/scripts.

- [ ] T001 Verify Git tag and GitHub release `sarteco-2026` exist and record the release URL/status in `specs/001-fix-benchmark-reliability/quickstart.md`
- [ ] T002 [P] Create valid plotting result fixtures in `tests/fixtures/results/valid/`
- [ ] T003 [P] Create malformed, empty, constant-metric, zero-pod, and unknown-simulator result fixtures in `tests/fixtures/results/edge-cases/`
- [ ] T004 [P] Create a checkpoint verification log template in `specs/001-fix-benchmark-reliability/checkpoints.md`
- [ ] T005 [P] Create a lightweight validation helper script in `utils/validate-checkpoint.sh`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish common validation and policy scaffolding that all user stories depend on.

**Critical**: No user story implementation should begin until this phase is complete.

- [ ] T006 Add baseline shell/Python validation commands to `utils/validate-checkpoint.sh`
- [ ] T007 Add fixture-based plotting/summary validation commands to `utils/validate-checkpoint.sh`
- [ ] T008 Add path-with-spaces validation commands to `utils/validate-checkpoint.sh`
- [ ] T009 [P] Add generated-output directories and validation artifacts to `.gitignore`
- [ ] T010 [P] Add project safety and reproducibility documentation skeleton in `SECURITY.md`
- [ ] T011 [P] Add simulator support inventory skeleton in `SIM_MODULES.md`
- [ ] T012 [P] Add generated data maintenance policy skeleton in `DATASETS.md`
- [ ] T013 Run baseline validation from `specs/001-fix-benchmark-reliability/quickstart.md` and record current known failures in `specs/001-fix-benchmark-reliability/checkpoints.md`
- [ ] T014 Commit setup/foundational checkpoint and record the commit reference in `specs/001-fix-benchmark-reliability/checkpoints.md`

**Checkpoint**: Foundation ready. Validation fixtures, policy skeletons, and checkpoint recording exist.

---

## Phase 3: User Story 1 - Generate benchmark plots reliably (Priority: P1) MVP

**Goal**: Benchmark users can generate plots and summaries from valid result files, and invalid plotting inputs fail with clear messages instead of crashes.

**Independent Test**: Run plotting and summary workflows against `tests/fixtures/results/valid/` and `tests/fixtures/results/edge-cases/`, then confirm generated artifacts and clear error handling.

### Implementation for User Story 1

- [ ] T015 [US1] Fix the plotting startup syntax error in `utils/kube-plot.py`
- [ ] T016 [US1] Replace the invalid data-directory check with a clear directory validation path in `utils/kube-plot.py`
- [ ] T017 [US1] Align result numeric parsing with emitted benchmark CSV decimals in `utils/kube-plot.py`
- [ ] T018 [US1] Handle constant metric normalization without undefined values in `utils/kube-plot.py`
- [ ] T019 [US1] Add safe default style handling for unknown simulator result names in `utils/kube-plot.py`
- [ ] T020 [US1] Add empty-directory and malformed-file user messages in `utils/kube-plot.py`
- [ ] T021 [US1] Harden summary input validation and empty-result behavior in `utils/min-max-avg.py`
- [ ] T022 [P] [US1] Document plotting and summary result-file expectations in `specs/001-fix-benchmark-reliability/contracts/cli-contracts.md`
- [ ] T023 [US1] Run `python -m py_compile utils/kube-plot.py utils/min-max-avg.py` and record output in `specs/001-fix-benchmark-reliability/checkpoints.md`
- [ ] T024 [US1] Run plotting validation against `tests/fixtures/results/valid/` and record generated artifact paths in `specs/001-fix-benchmark-reliability/checkpoints.md`
- [ ] T025 [US1] Run plotting validation against `tests/fixtures/results/edge-cases/` and record expected error/default-style behavior in `specs/001-fix-benchmark-reliability/checkpoints.md`
- [ ] T026 [US1] Commit User Story 1 checkpoint and record the commit reference in `specs/001-fix-benchmark-reliability/checkpoints.md`

**Checkpoint**: User Story 1 is independently functional when plotting and summary validation passes for valid and edge-case fixtures.

---

## Phase 4: User Story 2 - Run simulator experiments predictably (Priority: P1)

**Goal**: Benchmark operators can run simulator experiments from supported entry points with reliable module loading, output creation, timeout behavior, memory-limit cancellation, cleanup, and path handling.

**Independent Test**: Run shell syntax validation, path-with-spaces generation, runner invocation from outside the repo root, and best-effort lightweight simulator validation or documented local blocker.

### Implementation for User Story 2

- [ ] T027 [US2] Make simulator module loading use the repository script directory in `kube-run.sh`
- [ ] T028 [US2] Create default result output directories before writing in `kube-run.sh`
- [ ] T029 [US2] Make stalled-scheduling timeout calculation always initialized and bounded in `kube-run.sh`
- [ ] T030 [US2] Make memory-limit cancellation visible to the active scheduling loop in `kube-run.sh`
- [ ] T031 [US2] Strengthen interrupted-run and failed-run cleanup status handling in `kube-run.sh`
- [ ] T032 [US2] Quote path-like shell variables in `kube-run.sh`
- [ ] T033 [P] [US2] Quote path-like shell variables in `kube-director.sh`
- [ ] T034 [P] [US2] Quote path-like shell variables in `modules/kwok/module.sh`
- [ ] T035 [P] [US2] Quote path-like shell variables in `modules/kubemark/module.sh`
- [ ] T036 [P] [US2] Quote path-like shell variables in `modules/opensim/module.sh`
- [ ] T037 [P] [US2] Quote path-like shell variables in `modules/simkube/module.sh`
- [ ] T038 [P] [US2] Quote path-like shell variables in `modules/kube-sched/module.sh`
- [ ] T039 [P] [US2] Quote path-like shell variables in `modules/vanilla/module.sh`
- [ ] T040 [P] [US2] Quote path-like shell variables in `utils/simkube-tracer.sh`
- [ ] T041 [US2] Replace unsafe shell command construction for follow-on workflows in `utils/kube-gen.py`
- [ ] T042 [US2] Add or update path-with-spaces validation coverage in `utils/validate-checkpoint.sh`
- [ ] T043 [US2] Run `bash -n kube-director.sh kube-run.sh entrypoint.sh modules/*/module.sh utils/*.sh` and record output in `specs/001-fix-benchmark-reliability/checkpoints.md`
- [ ] T044 [US2] Run `python utils/kube-gen.py -o "/tmp/k8s sims path test" -c 1 -i 1` and record output in `specs/001-fix-benchmark-reliability/checkpoints.md`
- [ ] T045 [US2] Run best-effort runner validation from outside the repo root or record the Docker/Kubernetes blocker in `specs/001-fix-benchmark-reliability/checkpoints.md`
- [ ] T046 [US2] Commit User Story 2 checkpoint and record the commit reference in `specs/001-fix-benchmark-reliability/checkpoints.md`

**Checkpoint**: User Story 2 is independently functional when script syntax, path-with-spaces behavior, cwd-independent module loading, output creation, and timeout/memory behavior are validated or environment blockers are recorded.

---

## Phase 5: User Story 3 - Trust simulator setup and reproducibility (Priority: P2)

**Goal**: Maintainers can understand supported simulator modes, setup dependencies, privileged execution risks, and reproducibility gaps before running benchmarks.

**Independent Test**: Review `SIM_MODULES.md`, `SECURITY.md`, `DATASETS.md`, container files, and module setup scripts, then confirm every active mode has documented status, requirements, dependencies, and cleanup expectations.

### Implementation for User Story 3

- [ ] T047 [US3] Make the scheduler simulator image pinning edit persistent in `modules/kube-sched/module.sh`
- [ ] T048 [US3] Align or document Kubernetes tooling version choices in `Dockerfile`
- [ ] T049 [US3] Pin or explicitly categorize runtime repository/manifests dependencies in `modules/simkube/module.sh`
- [ ] T050 [US3] Pin or explicitly categorize runtime repository/image dependencies in `modules/kube-sched/module.sh`
- [ ] T051 [US3] Make image pulling failures explicit in `entrypoint.sh`
- [ ] T052 [US3] Document privileged Docker, host cgroup, and Docker-in-Docker risks in `SECURITY.md`
- [ ] T053 [US3] Document isolated execution recommendations and non-privileged limitations in `SECURITY.md`
- [ ] T054 [US3] Document active, experimental, unavailable, and legacy simulator modes in `SIM_MODULES.md`
- [ ] T055 [US3] Reconcile `SIM_MODULES` with documented active simulator modes in `SIM_MODULES`
- [ ] T056 [US3] Document runtime dependency reproducibility status in `SIM_MODULES.md`
- [ ] T057 [US3] Document generated dataset categories, retention policy, and regeneration commands in `DATASETS.md`
- [ ] T058 [US3] Update source-control ignore policy for generated large outputs in `.gitignore`
- [ ] T059 [US3] Run documentation discovery checks from `specs/001-fix-benchmark-reliability/quickstart.md` and record output in `specs/001-fix-benchmark-reliability/checkpoints.md`
- [ ] T060 [US3] Commit User Story 3 checkpoint and record the commit reference in `specs/001-fix-benchmark-reliability/checkpoints.md`

**Checkpoint**: User Story 3 is independently functional when a maintainer can identify active modes, dependencies, privileged risks, and dataset policy from project documentation.

---

## Phase 6: User Story 4 - Preserve results safely and review changes in checkpoints (Priority: P2)

**Goal**: Maintainers can preserve existing result files intentionally, review each improvement checkpoint, and avoid silent or confusing result backup behavior.

**Independent Test**: Run an output-collision scenario and confirm the selected policy is visible, predictable, and does not pollute plotting inputs; review checkpoint log for commit and validation coverage.

### Implementation for User Story 4

- [ ] T061 [US4] Define explicit result preservation defaults and user-facing messages in `kube-run.sh`
- [ ] T062 [US4] Apply the same result preservation policy to multi-simulator output paths in `kube-director.sh`
- [ ] T063 [US4] Ensure preserved result files are excluded or clearly handled by plotting workflows in `utils/kube-plot.py`
- [ ] T064 [US4] Document result preservation policy in `SIM_MODULES.md`
- [ ] T065 [US4] Add output-collision validation commands to `utils/validate-checkpoint.sh`
- [ ] T066 [US4] Run output-collision validation from `specs/001-fix-benchmark-reliability/quickstart.md` and record output in `specs/001-fix-benchmark-reliability/checkpoints.md`
- [ ] T067 [US4] Review every checkpoint entry for verification output, blocker notes, and commit references in `specs/001-fix-benchmark-reliability/checkpoints.md`
- [ ] T068 [US4] Commit User Story 4 checkpoint and record the commit reference in `specs/001-fix-benchmark-reliability/checkpoints.md`

**Checkpoint**: User Story 4 is independently functional when result collision behavior is predictable and every checkpoint has validation evidence or a documented blocker.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final consistency checks and cleanup across all user stories.

- [ ] T069 [P] Update validation examples and expected outcomes in `specs/001-fix-benchmark-reliability/quickstart.md`
- [ ] T070 [P] Update final task completion notes in `specs/001-fix-benchmark-reliability/tasks.md`
- [ ] T071 Run final shell syntax validation and record output in `specs/001-fix-benchmark-reliability/checkpoints.md`
- [ ] T072 Run final Python compile validation and record output in `specs/001-fix-benchmark-reliability/checkpoints.md`
- [ ] T073 Run final fixture plotting and summary validation and record output in `specs/001-fix-benchmark-reliability/checkpoints.md`
- [ ] T074 Run final dataset generator smoke validation and record output in `specs/001-fix-benchmark-reliability/checkpoints.md`
- [ ] T075 Run `git status --short` and record clean/expected state in `specs/001-fix-benchmark-reliability/checkpoints.md`
- [ ] T076 Commit final polish checkpoint and record the commit reference in `specs/001-fix-benchmark-reliability/checkpoints.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies; can start immediately.
- **Foundational (Phase 2)**: Depends on Setup completion; blocks all user stories.
- **User Story 1 (Phase 3, P1)**: Depends on Foundational; MVP and can complete without other stories.
- **User Story 2 (Phase 4, P1)**: Depends on Foundational; can run after or in parallel with US1, but final validation benefits from US1 plotting fixes.
- **User Story 3 (Phase 5, P2)**: Depends on Foundational; can run after or in parallel with US1/US2 if policy/documentation files are not being edited by another worker.
- **User Story 4 (Phase 6, P2)**: Depends on Foundational and benefits from US1 plotting behavior and US2 output behavior.
- **Polish (Phase 7)**: Depends on all selected user stories being complete.

### User Story Dependencies

- **User Story 1 (P1)**: No dependency on other stories after Foundational; recommended MVP.
- **User Story 2 (P1)**: No hard dependency on US1, but shares validation helper and checkpoint log.
- **User Story 3 (P2)**: No hard dependency on US1/US2, but may need to reference final simulator behavior after US2.
- **User Story 4 (P2)**: Depends conceptually on the chosen output behavior from US2 and plotting inclusion behavior from US1.

### Within Each User Story

- Implement source behavior first.
- Update relevant contract/policy documentation where the behavior changes.
- Run the story-specific validation from `utils/validate-checkpoint.sh` or `quickstart.md`.
- Record verification in `specs/001-fix-benchmark-reliability/checkpoints.md`.
- Commit the completed checkpoint before moving to the next logical group.

### Parallel Opportunities

- Setup fixture/document skeleton tasks T002-T005 can run in parallel.
- Foundational skeleton docs T009-T012 can run in parallel.
- US2 module quoting tasks T033-T040 can run in parallel because they touch different files.
- US3 documentation tasks T052-T057 can run in parallel if file ownership is coordinated.
- Final documentation updates T069-T070 can run in parallel.

---

## Parallel Example: User Story 1

```bash
# Independent tasks after T015-T021 are planned:
Task: "T022 [P] [US1] Document plotting and summary result-file expectations in specs/001-fix-benchmark-reliability/contracts/cli-contracts.md"
Task: "T023 [US1] Run python compile validation and record output in specs/001-fix-benchmark-reliability/checkpoints.md"
```

## Parallel Example: User Story 2

```bash
# Module quoting tasks can be split safely across workers:
Task: "T034 [P] [US2] Quote path-like shell variables in modules/kwok/module.sh"
Task: "T035 [P] [US2] Quote path-like shell variables in modules/kubemark/module.sh"
Task: "T036 [P] [US2] Quote path-like shell variables in modules/opensim/module.sh"
Task: "T037 [P] [US2] Quote path-like shell variables in modules/simkube/module.sh"
Task: "T038 [P] [US2] Quote path-like shell variables in modules/kube-sched/module.sh"
Task: "T039 [P] [US2] Quote path-like shell variables in modules/vanilla/module.sh"
```

## Parallel Example: User Story 3

```bash
# Documentation tasks can proceed after simulator behavior decisions are known:
Task: "T052 [US3] Document privileged Docker, host cgroup, and Docker-in-Docker risks in SECURITY.md"
Task: "T054 [US3] Document active, experimental, unavailable, and legacy simulator modes in SIM_MODULES.md"
Task: "T057 [US3] Document generated dataset categories, retention policy, and regeneration commands in DATASETS.md"
```

## Parallel Example: User Story 4

```bash
# After result policy behavior is implemented:
Task: "T064 [US4] Document result preservation policy in SIM_MODULES.md"
Task: "T065 [US4] Add output-collision validation commands to utils/validate-checkpoint.sh"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 Setup.
2. Complete Phase 2 Foundational validation scaffolding.
3. Complete Phase 3 User Story 1 plotting and summary reliability.
4. Stop and validate US1 independently with fixture results.
5. Commit the US1 checkpoint before starting broader runner or documentation changes.

### Incremental Delivery

1. Setup + Foundational: release verified, fixtures and checkpoint log ready.
2. US1: plotting and summary workflows work with valid and edge-case fixtures.
3. US2: runner behavior is hardened and verified or blockers recorded.
4. US3: simulator support, safety, reproducibility, and dataset policies are documented and aligned.
5. US4: result preservation behavior and checkpoint review flow are complete.
6. Polish: final validation suite and clean repository state.

### Checkpoint Commit Strategy

- Commit after Phase 2 and after each user story phase.
- Every checkpoint commit must have matching validation evidence in `specs/001-fix-benchmark-reliability/checkpoints.md`.
- If a validation command cannot run on the current host, record the blocker and the closest completed validation before committing.

## Notes

- The `sarteco-2026` release was created before implementation changes and should remain the pre-implementation recovery point.
- Avoid changing benchmark methodology, scheduling metrics, or simulator scoring in this feature.
- Avoid reading or exposing `.env` contents; treat local environment files as sensitive unless the user explicitly says otherwise.
- Use `python`, not `python3`, in local Windows/Git-Bash validation commands unless the environment adds a `python3` alias.
