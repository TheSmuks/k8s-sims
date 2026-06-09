# Quickstart: Bash Correctness Test Suite Validation

This guide defines the validation path for the bash correctness test suite. Run commands from the repository root unless noted.

## Prerequisites

- `bash` on `PATH`. The suite is exercised on this Windows/Git-Bash host.
- `git` for branch and inventory context.
- `python` is not required for the bash suite itself; the existing Python utilities keep their `py_compile`-based validation in `utils/validate-checkpoint.sh`.
- Optional network access only on the first run to bootstrap `bats` into `tests/bash/.bats/`. After that, the suite runs offline.
- External tools such as Docker, kind, kwok, kubectl, or OpenSimulator are NOT required. Tests that depend on them are skipped with a clear reason unless `--with-mocks` is used.

## First-run setup

The suite bootstraps itself. Run:

```bash
./tests/bash/run.sh
```

Expected outcome:
- The runner creates `tests/bash/.bats/` and downloads bats-core 1.11.0 into it.
- The bootstrap is a no-op on subsequent runs.
- The first run may take a few seconds longer than the 60-second target in SC-001 because of the download.

## Run the suite

```bash
./tests/bash/run.sh
```

Run with mocks to force behavioral tests through shim binaries:

```bash
./tests/bash/run.sh --with-mocks
```

Expected outcome:
- TAP output is printed to stdout.
- A per-run TAP file and summary are written under `tests/bash/.reports/`.
- Exit code is 0 when every test passes or is skipped; non-zero when any test fails.

## Run the suite through the existing helper

```bash
./utils/validate-checkpoint.sh bash-tests
```

Or include it in the full sequence:

```bash
./utils/validate-checkpoint.sh all
```

Expected outcome:
- The `bash-tests` step runs the bats runner and propagates its exit code.
- The `all` sequence ends with the bash-tests step and prints the latest report path so it can be referenced from `specs/002-bash-test-suite/checkpoints.md`.

## Validate individual concerns

```bash
# Static syntax check across the inventory
bats tests/bash/tests/static-syntax.bats

# set -u / pipefail smoke for the runner scripts
bats tests/bash/tests/static-strict.bats

# Behavioral tests with mocks
bats --with-mocks tests/bash/tests/behavioral
```

Expected outcome:
- Each concern has its own `.bats` file under `tests/bash/tests/`, and each file can be invoked directly with the locally bootstrapped `bats`.
- Behavioral tests run in a subshell with `tests/mocks/bin/` on `PATH`; the shim logs are under `tests/bash/.reports/mock-*.log`.

## Confirm inventory auto-discovery

```bash
# Show the auto-discovered inventory
./tests/bash/run.sh --print-inventory
```

Expected outcome:
- The list includes the project root `*.sh`, `entrypoint.sh`, every `modules/*/module.sh` (with the template excluded), and every `utils/*.sh`.
- Excluded scripts listed in `tests/bash/excluded-scripts.bash` are not present.

## Local environment blockers

If the local host lacks network access entirely, the bootstrap step will fail. In that case the suite falls back to skipping the bootstrap and reporting `missing tool: bats` for every test, which is the documented behavior in the spec and contracts. To work around the network restriction, mirror bats-core 1.11.0 onto the host, unpack it into `tests/bash/.bats/`, and re-run the suite. No code changes are required.

## Reference paths

- Test runner: `tests/bash/run.sh`
- Bootstrap script: `tests/bash/bootstrap-bats.sh`
- Inventory exclusion list: `tests/bash/excluded-scripts.bash`
- Mock binaries: `tests/mocks/bin/<name>` and `<name>.conf`
- Fixtures: `tests/bash/fixtures/`
- Per-run reports: `tests/bash/.reports/` (gitignored)
- Checkpoint log: `specs/002-bash-test-suite/checkpoints.md`
