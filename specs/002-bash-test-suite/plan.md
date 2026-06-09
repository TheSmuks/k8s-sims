# Implementation Plan: Bash Correctness Test Suite

**Branch**: `002-bash-test-suite` | **Date**: 2026-06-09 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-bash-test-suite/spec.md`

## Summary

Add a bats-based regression test suite for the project's shell scripts. The suite is auto-discovered from the existing script inventory, bootstraps a pinned `bats` into a gitignored directory on first run, supports `PATH`-shim mocks for simulator tools, emits TAP output, writes per-run reports, and is invokable through the existing `utils/validate-checkpoint.sh` helper as a new `bash-tests` subcommand. The suite is the regression detector for argument parsing, error paths, path-with-spaces handling, result preservation, cleanup, and image-pull reporting across `kube-run.sh`, `kube-director.sh`, `entrypoint.sh`, every `modules/*/module.sh`, and the `utils/*.sh` helpers.

## Technical Context

**Language/Version**: Bash 4+ (Git-Bash 5.x on Windows is sufficient; no bash 5-only features are required). bats-core 1.11.0 (bootstrapped locally).

**Primary Dependencies**: bats-core 1.11.0 (locally bootstrapped), `bash`, `git`, `tar`, POSIX `sh` for the shim binaries. Python is not required for the bash suite.

**Storage**: Local filesystem only. The bootstrapped bats tree lives under `tests/bash/.bats/` (gitignored). Per-run TAP and summary files live under `tests/bash/.reports/` (gitignored). Mock binaries live under `tests/mocks/bin/`. Fixtures live under `tests/bash/fixtures/` and `tests/mocks/fixtures/` and ARE committed.

**Testing**: bats-core 1.11.0. The suite tests other shell scripts and Python utilities are out of scope.

**Target Platform**: POSIX shell environment. Validated on Windows/Git-Bash 5.x and on Linux. No privileged execution required.

**Project Type**: Bash-based test suite inside an existing script-based benchmark automation toolkit.

**Performance Goals**: Local suite run completes in under 60 seconds (SC-001) on the current Windows/Git-Bash host with no external tools. With `--with-mocks` the same budget applies.

**Constraints**:
- Bootstrap downloads bats-core 1.11.0 once; subsequent runs are offline.
- External tools (Docker, kind, kwok, kubectl, cgexec, etc.) are absent on most contributor hosts; behavioral tests for those flows either skip with a clear reason or run against shims under `--with-mocks`.
- No changes to benchmark methodology, scheduler scoring, or simulator internals.
- Must respect the existing fixture conventions in `tests/fixtures/results/` and not introduce cross-suite coupling.

**Scale/Scope**: 1 bats runner script, 1 bootstrap script, 1 inventory allowlist, 1 fixtures root, ~6 mock shims, ~6 `*.bats` files (one per concern area: static-syntax, static-strict, behavioral-runner, behavioral-director, behavioral-entrypoint, behavioral-modules), one integration into `utils/validate-checkpoint.sh`, and the `.gitignore` updates.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The current constitution file is the generated placeholder with no ratified principles. Practical quality gates derived from the feature specification and the previous feature's planning notes:

- Reliability changes must include verification evidence or a recorded blocker.
- Risky runtime behavior must be documented for users.
- Each improvement group must be independently reviewable and committable.
- The bash test suite must run end to end without privileged execution.

Pre-design gate result: PASS. The research, data model, contracts, and quickstart preserve these gates and include validation expectations for each new test group.

Post-design gate result: PASS. The generated design artifacts (research.md, data-model.md, contracts/cli-contracts.md, quickstart.md) cover static checks, behavioral checks, the bootstrap, the mock layer, the inventory auto-discovery, the report contract, and the helper integration. Validation expectations are encoded in `quickstart.md` and `contracts/cli-contracts.md`.

## Project Structure

### Documentation (this feature)

```text
specs/002-bash-test-suite/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── cli-contracts.md # Phase 1 output
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
tests/
├── bash/
│   ├── run.sh                       # bats runner and bootstrap entry point
│   ├── bootstrap-bats.sh            # downloads and unpacks bats-core 1.11.0
│   ├── excluded-scripts.bash        # allowlist for non-runnable scripts
│   ├── fixtures/                    # versioned fixtures for behavioral tests
│   │   ├── experiment-empty/        # experiment dir that exercises the missing path
│   │   ├── spaced-path/             # intentionally spaced path components
│   │   └── result-csv/              # example result CSV files
│   ├── helpers/
│   │   ├── inventory.bash           # glob + allowlist -> inventory
│   │   ├── bats.bash                # resolve bats path, run with timeout
│   │   └── skip.bash                # skip-with-reason helper
│   ├── tests/
│   │   ├── static-syntax.bats       # bash -n on every inventory entry
│   │   ├── static-strict.bats       # set -u/pipefail smoke for runner scripts
│   │   ├── behavioral-runner.bats   # kube-run.sh argument and behavior
│   │   ├── behavioral-director.bats # kube-director.sh module loading and iteration
│   │   ├── behavioral-entrypoint.bats # entrypoint.sh image-pull failure reporting
│   │   ├── behavioral-modules.bats  # module loading and log presence
│   │   └── behavioral-path-spaces.bats # path-with-spaces coverage
│   └── .reports/                    # gitignored, per-run reports
└── mocks/
    ├── bin/                         # PATH-shim binaries
    │   ├── kwokctl
    │   ├── kubectl
    │   ├── kind
    │   ├── docker
    │   ├── cgexec
    │   └── cgdelete
    └── conf/                        # shim configuration
        ├── kwokctl.conf
        ├── kubectl.conf
        ├── kind.conf
        ├── docker.conf
        ├── cgexec.conf
        └── cgdelete.conf
```

**Structure Decision**: Add the bash test suite under `tests/bash/` and the mock layer under `tests/mocks/`. Reuse the existing `utils/validate-checkpoint.sh` helper for the integration entry point. No changes to the existing benchmark scripts beyond the helper's new subcommand.

## Complexity Tracking

No constitution violations identified. The feature touches multiple small files but each file is self-contained, the auto-discovered inventory means there is no manual cross-reference, and the bootstrap is a one-line addition. The only intentional coupling is the integration into `utils/validate-checkpoint.sh`, which is required by FR-011.
