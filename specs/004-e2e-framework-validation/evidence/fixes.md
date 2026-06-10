# Fix Log: E2E Framework Validation

Every project change made to resolve a failure.

## FIX-001: Create missing test fixture directories

- **Failure**: F001
- **Changes**:
  - Created `tests/fixtures/results/valid/results-kwok.csv` (2-row valid result CSV)
  - Created `tests/fixtures/results/edge-cases/results-empty.csv` (1-row edge case)
- **Verified**: kube-plot.py 14 plots; min-max-avg.py summary.json

## FIX-002: Fix skctl validate subcommand in sktrace.py

- **Failure**: F002
- **Changes**: `utils/sktrace.py` line 160: `["skctl", "validate", path]` -> `["skctl", "validate", "check", path]`
- **New files**: `tests/test_e2e_validation.py` (2 TDD tests)
- **Verified**: 36/36 pytest pass

## FIX-003: Update Dockerfile for renamed simkube-tracer.sh -> sktrace.py

- **Failure**: F003
- **Changes**: `Dockerfile` line 64: `COPY utils/simkube-tracer.sh` -> `COPY utils/sktrace.py`
- **Verified**: Docker image builds successfully

## FIX-004: Fix CRLF line endings

- **Failure**: F004
- **Changes**: `sed -i 's/\r$//'` on entrypoint.sh, kube-director.sh, kube-run.sh, modules/*/module.sh, SIM_MODULES
- **Verified**: Docker image boots, all module names resolve, opensim+kwok+kube-sched+simkube all start correctly

## UNRESOLVED: F005 - SimKube version mismatch

- **Failure**: F005
- **Status**: Not fixed. skctl v2.3.0 is incompatible with driver v2.6.1.
- **Required fix**: Either upgrade `cargo install skctl` in Dockerfile to v2.6.1, or pin driver image to v2.3.0 in module.sh
