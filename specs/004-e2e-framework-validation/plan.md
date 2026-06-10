# Implementation Plan: End-to-End Framework Validation

**Branch**: `feature/004-e2e-framework-validation` | **Date**: 2026-06-10 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-e2e-framework-validation/spec.md`

## Summary

Validate the k8s-sims framework end to end from a clean remote baseline, document every checked fact with evidence, exercise all active simulator modes through the normal framework paths where host prerequisites allow, fix every project-scope failure, and produce an auditable final validation report. The technical approach is evidence-first: establish a clean checkout, record tool and documentation facts, run non-privileged checks first, then run simulator smoke workflows with small reproducible workloads, escalating failures into structured records until they are fixed or proven externally blocked.

## Technical Context

**Language/Version**: Bash 5+ on Windows/Git-Bash and Linux; Python per project requirement 3.12+ with current validation host reporting Python 3.11.15, which must be treated as an environment fact and recorded if it affects results.

**Primary Dependencies**: Existing project dependencies in `requirements.txt` (PyYAML, msgpack, pandas, numpy, scipy, seaborn, matplotlib); runtime tools documented by the project (`docker`, `kubectl`, `kind`, `kwokctl`, and simulator-specific tools where applicable).

**Storage**: Filesystem artifacts only: generated manifests, traces, result CSVs, preserved result backups, test reports, and the feature validation report under `specs/004-e2e-framework-validation/`.

**Testing**: Existing Python tests, bash/bats suite, `utils/validate-checkpoint.sh`, static shell syntax checks, Python compile checks, workload generation checks, plotting checks, and simulator smoke runs through `kube-run.sh` when host prerequisites are satisfied.

**Target Platform**: Primary validation host is Windows 10 with Git-Bash/MSYS2; plan must preserve Linux compatibility and document Linux-only or privileged simulator constraints rather than misclassifying them as project defects.

**Project Type**: CLI toolkit and shell/Python simulation framework.

**Performance Goals**: Validation should prefer small smoke workloads that complete quickly; full benchmark-scale performance runs are out of scope unless required to prove or diagnose a failure. Existing feature 003 performance goals remain validated through their own tests and documentation.

**Constraints**: Start from a clean remote-derived checkout; do not delete unrelated local work; avoid silent overwrites; every fact must have evidence; every project-scope failure must be fixed and re-verified; external blockers must be documented with fallback checks.

**Scale/Scope**: All active simulator modes listed by project documentation (`kwok`, `kube-sched`, `simkube`, `kubemark`, `opensim`) plus non-privileged framework layers (generation, trace validation, plotting, runner, director, module sourcing, path handling, collision preservation, docs consistency).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status | Notes |
|------|--------|-------|
| Shell Safety | PASS | Any shell changes found necessary during implementation must pass `bash -n`, quote expansions, use `set -u` where applicable, and be covered by bats tests. Planning itself adds documentation only. |
| Conventional Commits | PASS | Future commits must use allowed Conventional Commit types and scopes. |
| Conventional Branches | PASS | The Spec Kit hook initially created `004-e2e-framework-validation`; branch was renamed to `feature/004-e2e-framework-validation` to satisfy the constitution while keeping `.specify/feature.json` pointed at `specs/004-e2e-framework-validation`. |
| Test-First for Shell Changes | PASS | If validation exposes shell defects, add or update bats coverage before applying shell fixes. |
| No Silent Overwrites | PASS | Validation scenarios explicitly include collision preservation and must use isolated output directories. |
| Privileged Execution Awareness | PASS | Full simulator execution is attempted only where documented prerequisites are satisfied; otherwise fallback non-privileged checks and blockers are recorded. |
| Platform Compatibility | PASS | Plan targets Windows/Git-Bash first and requires documentation of Linux-only constraints such as OpenSim cgroups. |

**Post-design re-check**: PASS. Phase 1 artifacts preserve all constitution gates. No shell or source implementation is introduced by planning. The design requires TDD for any later shell fix and keeps privileged simulator runs gated by documented prerequisites.

## Project Structure

### Documentation (this feature)

```text
specs/004-e2e-framework-validation/
├── plan.md                         # This file
├── research.md                     # Phase 0 decisions
├── data-model.md                   # Validation entities and state transitions
├── quickstart.md                   # Runnable validation guide
├── contracts/
│   ├── validation-report.md        # Required final report structure
│   └── validation-runbook.md       # Required command/evidence workflow contract
├── checklists/
│   └── requirements.md             # Specification quality checklist
└── tasks.md                        # Future /speckit-tasks output
```

### Source Code (repository root)

```text
# Existing framework paths to validate or update if failures require changes
kube-run.sh                         # Single experiment entry point
kube-director.sh                    # Experiment orchestration entry point
entrypoint.sh                       # Container entry point
SIM_MODULES.md                      # Active simulator inventory
README.md                           # User-facing setup and run documentation
ARCHITECTURE.md                     # Framework architecture documentation
DATASETS.md                         # Dataset documentation
requirements.txt                    # Python dependency list

modules/
├── kwok/module.sh                  # KWOK simulator module
├── kube-sched/module.sh            # Scheduler simulator module
├── simkube/module.sh               # SimKube module
├── kubemark/module.sh              # Kubemark module
├── opensim/module.sh               # OpenSimulator module
└── */README.md                     # Simulator-specific setup documentation

utils/
├── kube-gen.py                     # Workload and trace generator
├── kube-plot.py                    # Plot generation
├── min-max-avg.py                  # Summary generation
├── validate-checkpoint.sh          # Non-privileged validation entry point
├── binpack.py                      # Bin-packing support
└── sktrace.py                      # SimKube trace support

tests/
├── test_binpack.py                 # Python unit tests
├── test_sktrace.py                 # Python unit tests
├── fixtures/                       # Small validation fixtures
├── mocks/                          # Tool shims for forced module checks
└── bash/                           # Bats correctness suite
```

**Structure Decision**: This feature primarily produces validation documentation and may later modify existing framework files only when project-scope failures are observed. No new runtime subsystem is planned up front. The final validation report should live with the feature artifacts so it remains tied to the baseline, evidence, and future tasks.

## Phase 0: Research Summary

Research outputs are captured in [research.md](./research.md). All planning unknowns are resolved through project documentation, existing validation scripts, and observed tool help/version output.

## Phase 1: Design Summary

Design outputs are captured in [data-model.md](./data-model.md), [contracts/validation-report.md](./contracts/validation-report.md), [contracts/validation-runbook.md](./contracts/validation-runbook.md), and [quickstart.md](./quickstart.md).

## Complexity Tracking

No constitution violations require justification. The branch naming conflict introduced by the Spec Kit hook was resolved by renaming the branch to the constitution-compliant form.
