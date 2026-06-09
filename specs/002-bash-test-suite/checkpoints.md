# Bash Correctness Test Suite - Checkpoint Log

## Setup and Foundational (T001-T014)

- Suite directory tree created under `tests/bash/` and `tests/mocks/`.
- `.gitignore` updated to exclude `tests/bash/.bats/`, `tests/bash/.reports/`, `tests/bash/.cache/`.
- Helpers written: `tests/bash/helpers/inventory.bash` (glob + allowlist enumeration), `skip.bash` (missing-tool detection), `bats.bash` (bats resolution and report writing).
- Bootstrap script `tests/bash/bootstrap-bats.sh` downloads bats-core 1.11.0 into `tests/bash/.bats/` on first run; idempotent thereafter.
- Runner `tests/bash/run.sh` accepts `--with-mocks`, `--bats <path>`, `--report-dir <path>`, `--print-inventory`. Bootstrap is automatic. Reports written under `tests/bash/.reports/` with TAP and `key=value` summary files plus `latest.tap` and `latest.summary` symlinks.
- Recursion guard: when bats invokes `run.sh` from within a bats test, `BATS_RUN_SH_REENTRANT=1` is set and the runner exits 0 with a clear note, preventing infinite recursion.
- Inventory auto-discover: 12 entries (root + entrypoint + 5 module scripts + 3 utility scripts). Template module `modules/template/module.sh` is excluded via `tests/bash/excluded-scripts.bash`.
- Helper `utils/validate-checkpoint.sh` extended with `cmd_bash_tests` and a new `bash-tests` subcommand; appended to the `all` sequence.

## User Story 1 - Detect script regressions (T015-T023)

- `tests/bash/tests/static-syntax.bats`: `bash -n` over every inventory entry. 2/2 pass.
- `tests/bash/tests/static-strict.bats`: `set -u` + `pipefail` + `bash -n` smoke for runtime scripts. 1/1 pass.
- Shim layer written: `tests/mocks/bin/_shim.sh` plus 8 wrappers (`kwokctl`, `kubectl`, `kind`, `docker`, `cgexec`, `cgdelete`, `cgcreate`, `skctl`) with per-tool `.conf` rule files under `tests/mocks/conf/`.
- Behavioral fixtures: `tests/bash/fixtures/experiment-missing/`, `experiment-spaced/`, `result-csv/`.
- `tests/bash/tests/behavioral-runner.bats`: 5/5 pass (4 OK + 1 skip with `missing tool: kwokctl`).
- `tests/bash/tests/behavioral-director.bats`: 3/3 pass.
- `tests/bash/tests/behavioral-entrypoint.bats`: 1 skip with `missing tool: docker`.
- `tests/bash/tests/behavioral-modules.bats`: sources `kube-run.sh` preamble to define `log` then sources each module; 1/1 pass.
- `tests/bash/tests/behavioral-path-spaces.bats`: 1/1 pass for the spaced-path dataset generator case.

## User Story 2 - Run on hosts without simulator tooling (T024-T031)

- `tests/bash/tests/skip-reason.bats`: 2/2 pass (emits `missing tool: <name>` for absent tools, empty for present).
- `tests/bash/tests/with-mocks.bats`: 3/3 pass (shim kwokctl is on PATH, shim records rule response, recursion guard short-circuits when run.sh re-enters from inside a bats test).
- Default run: 21/21 pass, 2 skip.
- `--with-mocks` run: 21/21 pass, 0 skip, summary records `mocked=true`.

## User Story 3 - Helper integration (T032-T036)

- `tests/bash/tests/helper-integration.bats`: 2/2 pass.
- `utils/validate-checkpoint.sh bash-tests` propagates the runner's exit code and prints the latest report path or recursion-guard note.
- `utils/validate-checkpoint.sh all` includes the bash-tests step last in the sequence.

## Final validation (T037-T042)

- Full local validation: `bash tests/bash/run.sh` -> 21 pass, 0 fail, 2 skip, 16s. `--with-mocks` -> 21 pass, 0 fail, 0 skip, 15s.
- `utils/validate-checkpoint.sh bash-tests` -> exit 0, summary file written.
- `utils/validate-checkpoint.sh all` -> exit 0; passes existing baseline, plotting, path-spaces, collision, docs, bash-tests.
- `git status --short`: clean apart from intentional files (no `.bats/`, `.reports/`, `.cache/` artifacts leaking).

## Validation commands recorded

- `bash tests/bash/run.sh` -> `tests/bash/.reports/<timestamp>.tap` + `.summary`
- `bash tests/bash/run.sh --with-mocks` -> same path, `mocked=true` in summary
- `bash tests/bash/run.sh --print-inventory` -> 12 entries
- `utils/validate-checkpoint.sh bash-tests` -> propagates bats exit code
- `utils/validate-checkpoint.sh all` -> full sequence including bash-tests

## Commit references

- `b7add19 [Spec Kit] Add tasks` (auto-committed after `/speckit-tasks`)
- Implementation commit will be created by the `after_implement` auto-commit hook
