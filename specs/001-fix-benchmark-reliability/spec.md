# Feature Specification: Benchmark Reliability Stabilization

**Feature Branch**: `001-fix-benchmark-reliability`

**Created**: 2026-06-09

**Status**: Draft

**Input**: User description: "Address the identified benchmark toolkit weaknesses: repair plotting failures, correct data validation, make simulator setup and timeout behavior reliable, remove unsafe command construction, improve path handling, document privileged execution risks, improve reproducibility, handle result edge cases, manage generated data and environment-file risks, clarify supported simulator modes, strengthen error handling, make memory-limit cancellation reliable, and make CSV backup behavior explicit. Commit and verify after each part is solved."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generate benchmark plots reliably (Priority: P1)

A benchmark user can turn completed simulator result files into plots and summaries without the plotting workflow failing on startup, malformed input, constant-value metrics, or unfamiliar result file names.

**Why this priority**: Result visualization is the final user-facing output of the benchmark workflow. If it fails, users cannot compare simulators or validate experiment outcomes.

**Independent Test**: Can be fully tested by running the plotting and summary workflows against representative valid, invalid, constant-value, and custom-named result files and confirming that successful cases produce outputs while invalid cases report clear corrective messages.

**Acceptance Scenarios**:

1. **Given** valid benchmark result files, **When** the user requests line charts, summary bars, and correlation summaries, **Then** all requested outputs are generated with readable labels and no startup errors.
2. **Given** a missing or invalid result directory, **When** the user requests plots, **Then** the workflow stops with a clear message that identifies the missing input location.
3. **Given** a result file with constant metric values, **When** summary comparisons are generated, **Then** normalization completes without undefined or infinite values.
4. **Given** a result file whose simulator name is not preconfigured, **When** plots are generated, **Then** the file is still included using a safe default presentation instead of failing.

---

### User Story 2 - Run simulator experiments predictably (Priority: P1)

A benchmark operator can run simulator experiments from the project root, a different working directory, or the container entrypoint and receive consistent setup, timeout, output, and cleanup behavior.

**Why this priority**: The benchmark exists to compare simulator behavior. Unreliable setup, timeout handling, or output creation makes results untrustworthy.

**Independent Test**: Can be tested by starting representative simulator runs with default output settings, explicit time limits, paths containing spaces, and interrupted or resource-limited scenarios, then confirming that each run either completes with metrics or exits with a clear reason and cleanup evidence.

**Acceptance Scenarios**:

1. **Given** the user starts a simulator run without specifying an output file, **When** the run records results, **Then** the default output location is created automatically and the result file is written.
2. **Given** the user starts a run from outside the project root, **When** the simulator module is loaded, **Then** the correct module is found without depending on the current working directory.
3. **Given** a maximum run duration is configured, **When** scheduling makes no progress or exceeds the allowed duration, **Then** the run stops with an explicit timeout result and records the timeout in the output.
4. **Given** a memory threshold is exceeded, **When** monitoring detects the threshold breach, **Then** the active run stops promptly, records the memory-limit result, and performs cleanup.
5. **Given** experiment input or output paths contain spaces, **When** supported workflows use those paths, **Then** the workflows complete or fail for domain reasons, not because the path was split or misread.

---

### User Story 3 - Trust simulator setup and reproducibility (Priority: P2)

A maintainer can understand and reproduce the simulator environment, including which simulator modes are supported, which runtime dependencies are expected, and what privileged execution risks are accepted.

**Why this priority**: Benchmark comparisons are only useful when users can reproduce the environment and understand operational risk.

**Independent Test**: Can be tested by reviewing the supported-mode registry and safety/reproducibility documentation, then performing a clean setup dry run that reports pinned or intentionally variable dependencies.

**Acceptance Scenarios**:

1. **Given** a maintainer reviews supported simulators, **When** they compare configured modes with available modules and data requirements, **Then** every advertised mode has a clear status, data source, and run requirement.
2. **Given** a user evaluates containerized execution, **When** they read the project safety guidance, **Then** they can identify privileged host access requirements and decide whether to run in an isolated environment.
3. **Given** a maintainer needs reproducible benchmark results, **When** they review setup dependencies, **Then** pinned dependencies, intentionally floating dependencies, and runtime downloads are clearly distinguished.

---

### User Story 4 - Preserve results safely and review changes in checkpoints (Priority: P2)

A maintainer can apply reliability improvements in independently verifiable parts, preserve existing result files intentionally, and review each part with validation evidence before moving to the next.

**Why this priority**: The requested changes affect multiple workflows. Independent checkpoints reduce regression risk and make review easier.

**Independent Test**: Can be tested by completing each improvement group as a separate checkpoint with its own validation record and confirming that existing results are either preserved by an explicit policy or replaced only when requested.

**Acceptance Scenarios**:

1. **Given** an output file already exists, **When** a new run targets the same location, **Then** the system follows a documented policy that is visible to the user before or during result creation.
2. **Given** a reliability improvement group is completed, **When** the maintainer reviews the project history, **Then** the group has a distinct checkpoint and includes the verification performed for that group.
3. **Given** a validation step cannot be run in the local environment, **When** the checkpoint is created, **Then** the limitation and the closest completed alternative verification are recorded.

### Edge Cases

- Plotting is requested for an empty result directory.
- Result files contain missing columns, non-numeric values, or zero pod counts.
- Metrics are identical across all simulators or all node counts.
- Result files are backups, custom names, or names that do not match known simulator labels.
- A run uses a path with spaces or special characters.
- A simulator dependency is unavailable, slow to download, or resolves to a different version than expected.
- A run is interrupted by the user during setup, scheduling, monitoring, or cleanup.
- A memory threshold is exceeded while the scheduling wait loop is still active.
- Existing output files already exist before a new run starts.
- Environment configuration files are present in the repository and may contain sensitive values.
- Large generated datasets are out of sync with the generation workflow.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The plotting workflow MUST start successfully and reject invalid input with user-readable messages instead of startup errors.
- **FR-002**: The plotting workflow MUST validate that the requested data directory exists before attempting to process result files.
- **FR-003**: The plotting workflow MUST parse result values using the same numeric format emitted by the benchmark result writer.
- **FR-004**: The plotting workflow MUST handle constant-value metrics without producing undefined, infinite, or misleading comparison values.
- **FR-005**: The plotting workflow MUST include result files with unknown or custom simulator names using a safe default presentation.
- **FR-006**: The benchmark result summarization workflow MUST report missing, malformed, or empty input clearly and must not create misleading summaries.
- **FR-007**: Simulator setup MUST apply intended configuration changes to the simulator environment and provide evidence when a required setup change cannot be applied.
- **FR-008**: Simulator runs MUST enforce configured maximum duration consistently for both total runtime and stalled scheduling progress.
- **FR-009**: Simulator runs MUST automatically create the default result output location before writing results.
- **FR-010**: Simulator module loading MUST work regardless of the user's current working directory.
- **FR-011**: Supported workflows MUST handle valid project paths containing spaces without path-splitting failures.
- **FR-012**: User-supplied workflow arguments MUST be processed in a way that preserves intended argument boundaries and prevents unintended command execution.
- **FR-013**: Resource monitoring MUST cause the active run to stop promptly when a configured memory threshold is exceeded.
- **FR-014**: Interrupted or failed runs MUST attempt cleanup and record a clear final status when cleanup cannot fully complete.
- **FR-015**: The containerized execution path MUST disclose privileged host access requirements and provide guidance for isolated use.
- **FR-016**: Setup dependencies MUST be either pinned to a reproducible version or explicitly documented as intentionally variable.
- **FR-017**: Supported simulator modes MUST be documented in one authoritative place, including whether each mode is active, experimental, or unavailable.
- **FR-018**: The project MUST prevent accidental reliance on sensitive local environment files as committed project inputs.
- **FR-019**: Generated benchmark datasets MUST have an explicit maintenance policy stating which datasets are kept in source control and how larger datasets are regenerated or stored.
- **FR-020**: Existing result file handling MUST follow an explicit policy that avoids silent, surprising backups or overwrites.
- **FR-021**: Each improvement group MUST be completed as an independently reviewable checkpoint with the verification evidence for that group recorded.
- **FR-022**: If a requested verification cannot be executed in the current environment, the checkpoint MUST record the blocker and the alternative validation performed.

### Key Entities *(include if feature involves data)*

- **Benchmark Result File**: A delimited result artifact containing node count, pod count, timeout status, memory-limit status, runtime, CPU usage, memory peak, and unscheduled-pod count.
- **Simulator Mode**: A supported or candidate benchmark backend with a name, setup requirements, data directory expectations, execution status, and cleanup behavior.
- **Experiment Dataset**: A generated or curated collection of node, pod, trace, and simulator-specific configuration files used as benchmark input.
- **Run Checkpoint**: A reviewable change group that includes scope, changed behavior, validation evidence, and any known verification limitations.
- **Safety Notice**: User-facing guidance that describes privileged execution requirements, host access, isolation expectations, and acceptable risk boundaries.
- **Result Preservation Policy**: The rule that determines whether existing result files are preserved, replaced, renamed, or rejected before a new run writes output.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of plotting and summary commands used for valid representative result files complete successfully and produce the requested artifacts.
- **SC-002**: 100% of invalid or missing plotting inputs tested produce a clear error message that identifies the corrective action.
- **SC-003**: Simulator runs with configured time limits stop within 10 seconds of the intended limit or record an explicit reason when the environment prevents timely shutdown.
- **SC-004**: Simulator runs that exceed the configured memory threshold record a memory-limit outcome in 100% of tested cases.
- **SC-005**: Supported benchmark workflows pass path-with-spaces tests for all user-facing input and output paths covered by the feature.
- **SC-006**: Every active simulator mode has documented status, data expectations, setup requirements, and cleanup expectations.
- **SC-007**: Every runtime dependency listed for benchmark setup is categorized as pinned, intentionally variable, or unavailable in the current environment.
- **SC-008**: Existing result file behavior is predictable for 100% of tested cases: no silent overwrite and no unexplained backup naming.
- **SC-009**: Each completed improvement group has a distinct review checkpoint with at least one verification result or a documented blocker.
- **SC-010**: A maintainer can identify privileged execution risks and safe-run expectations in under 2 minutes from project guidance.

## Assumptions

- The primary users are benchmark maintainers and operators who run simulator comparisons locally or in a dedicated containerized environment.
- The feature focuses on reliability, safety, reproducibility, and workflow clarity rather than changing benchmark methodology or simulator scoring.
- Existing generated test fixtures remain available for smoke validation unless replaced by an explicit generated-data policy.
- Privileged container execution may remain necessary for full simulator runs, but the requirement must be visible and isolated-use guidance must be provided.
- Some full simulator verifications may be unavailable on machines without container orchestration tooling; in those cases, syntax, dry-run, fixture, or unit-level validation is acceptable only when the limitation is recorded.
- The requested review checkpoints correspond to coherent improvement groups, not necessarily one checkpoint per individual file line item.
