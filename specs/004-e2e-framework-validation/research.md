# Research: End-to-End Framework Validation

## Decision: Use a separate clean clone as the validation baseline

**Rationale**: The user's primary working tree contained untracked local simulator source directories. A separate clone from the remote preserves local work while satisfying the requirement to start from remote state with no local changes.

**Alternatives considered**:
- Reset the existing working tree: rejected because it could delete unrelated local work.
- Continue from the dirty working tree: rejected because failures could be caused by untracked local state.

## Decision: Treat repository documents and built-in tool help/version output as first-class evidence

**Rationale**: The request requires every fact to be checked and verified before assumptions are made. Project documents such as `README.md`, `SIM_MODULES.md`, module READMEs, `.specify/memory/constitution.md`, and executable help/version output provide auditable evidence without relying on memory.

**Alternatives considered**:
- Rely on prior session memory: rejected because it is not sufficient evidence for a validation report.
- Use only online documentation: rejected because the project pins or documents local behavior in repository files and the run must reflect the checked-out revision.

## Decision: Validate non-privileged framework layers before full simulator smoke runs

**Rationale**: The constitution requires non-privileged validation paths to remain available. Running syntax, compile, generation, plotting, collision preservation, Python unit tests, and bats tests first quickly separates framework regressions from privileged runtime issues.

**Alternatives considered**:
- Start with full simulator execution: rejected because it mixes dependency, privilege, network, and framework failures too early.
- Run only unit tests: rejected because the feature requires end-to-end framework validation.

## Decision: Use the active simulator inventory as the coverage source

**Rationale**: `SIM_MODULES.md` lists active modes, data-path rules, dependencies, cleanup, and verification expectations. The validation scope should match that maintained inventory rather than hard-coded assumptions.

**Alternatives considered**:
- Discover modules only by folder names: rejected because experimental and legacy modes exist and not every folder is active by default.
- Use only `kube-director.sh` branches: rejected because documentation also captures runtime requirements and blockers.

## Decision: Use small reproducible workloads for smoke validation

**Rationale**: The goal is framework correctness, not benchmark reproduction. Small workloads reduce runtime, avoid overwhelming local clusters, and still verify generation, data compatibility, runner behavior, cleanup, and reporting.

**Alternatives considered**:
- Use the full benchmark dataset: rejected for routine validation because it requires large runtime and can obscure integration failures.
- Use static pre-generated artifacts only: rejected because workload generation itself is in scope.

## Decision: Classify outcomes as pass, fixed, skipped, or blocked

**Rationale**: The feature requires every failure to be documented and solved while acknowledging documented platform and external dependency constraints. Four statuses distinguish healthy checks, project defects that were repaired, intentional skips due to documented constraints, and unresolved external blockers.

**Alternatives considered**:
- Binary pass/fail only: rejected because platform-limited simulators and unavailable external services need precise treatment.
- Skip without evidence: rejected because it fails the verification requirement.

## Decision: Preserve result artifacts and isolate outputs under temporary validation directories

**Rationale**: The constitution forbids silent overwrites. Using isolated output directories plus explicit collision checks lets validation prove preservation behavior without damaging existing results.

**Alternatives considered**:
- Reuse repository `results/` paths directly: rejected because it risks overwriting or confusing historical outputs.
- Delete and recreate outputs globally: rejected because it violates the user's instruction to avoid local state assumptions.

## Decision: Fix project-scope failures with test-first discipline for shell changes

**Rationale**: The constitution mandates bats coverage before shell changes. Any shell defect found during validation must first receive a failing or updated bats test, then the fix, then the passing re-run.

**Alternatives considered**:
- Patch shell scripts directly after observing failures: rejected because it violates the constitution.
- Document shell failures without fixing them: rejected for project-scope defects because the feature requires failures to be solved.

## Decision: Keep the validation report in the feature specification directory

**Rationale**: The report is part of the feature outcome and should remain close to the plan, contracts, and data model. This keeps evidence and reproduction instructions tied to the exact validation effort.

**Alternatives considered**:
- Store only in terminal output: rejected because it is not durable or reviewable.
- Store under `results/`: rejected because that path is for simulator outputs, not governance evidence.
