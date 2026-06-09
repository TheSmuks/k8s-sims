# Research: Bash Correctness Test Suite

## Decision: Adopt bats (bats-core) as the test framework

**Rationale**: bats is the de facto TAP-based testing framework for bash. It produces TAP output that integrates with the spec's FR-010 and with existing TAP consumers, runs on any host with `bash`, requires no compilation, and has minimal dependencies. It is the framework the user selected for this feature.

**Alternatives considered**:
- shunit2: xUnit-style and reasonable, but its TAP output requires extra glue and its test layout is more verbose for our small suite.
- Plain bash assertions: zero dependency, but the maintainer has to build a runner, a TAP emitter, and a skip mechanism; this is a poor fit when an off-the-shelf runner already meets the requirements.

## Decision: Auto-discover the script inventory by globbing

**Rationale**: The maintainer wants to add and rename scripts without having to also edit a manifest. The repository's shell script layout is already conventional (`*.sh` at the root, `modules/*/module.sh`, `utils/*.sh`, plus `entrypoint.sh`). A glob-based inventory with allowlist for legitimate exclusions (e.g., `modules/template/module.sh` is a copy/paste template, not a runnable module) keeps the maintenance cost at zero for the common case.

**Alternatives considered**:
- A hand-maintained `tests/bash/script-inventory.bash` list: explicit, but every rename and addition requires an edit in two places.
- A pure allowlist with no glob: explicit, but the maintainer has to remember every new script.

## Decision: Bootstrap a pinned bats into a gitignored directory

**Rationale**: The user asked for "no external tooling required beyond bash, python, git". A pinned, self-installed `bats` under `tests/bash/.bats/` (gitignored) makes the suite portable across hosts and CI without requiring `apt install`, `brew install`, or a system-wide bats. The bootstrap is a one-time, no-network-afterward process; it downloads bats-core 1.11.0 from GitHub, extracts it, and uses it for all subsequent runs.

**Alternatives considered**:
- Fail loudly if bats is missing: this is the strictest option, but it forces every maintainer to install bats, which the user explicitly said they want to avoid.
- Skip the suite if bats is missing: the safest option, but the user wants the suite to be the regression detector, so silently skipping defeats the purpose.

## Decision: PATH-shim mock binaries for external tools

**Rationale**: bats tests run in a subshell. Prepending a directory of small shell scripts (e.g., `mock-kwokctl`, `mock-kind`, `mock-docker`) to `PATH` for the duration of the test lets the suite exercise real script behavior without the real tools. This is cheaper and more deterministic than container-based mocking, works on Windows/Git-Bash, and supports the user's "no privileged execution" requirement.

**Alternatives considered**:
- Container-based isolation (e.g., a Docker harness): realistic but heavyweight, requires Docker, and the user already records Docker as an environment blocker.
- Pure unit testing with stubs injected at function boundaries: would require refactoring the scripts to expose test seams, which the user did not ask for.

## Decision: Integrate the suite through `utils/validate-checkpoint.sh`

**Rationale**: The maintainer already has one validation entry point. Adding a `bash-tests` subcommand and folding it into the `all` sequence keeps the mental model simple and the runbook short. The new suite reuses the helper's logging, fail-fast, and exit-code semantics.

**Alternatives considered**:
- A standalone `tests/bash/run.sh`: simpler to write, but the maintainer would need to remember a second command and CI would need two paths.
- Make: standard, but a second build tool is unnecessary for a single-purpose test runner.

## Decision: TAP output, no JUnit XML

**Rationale**: bats emits TAP by default. JUnit XML is only required by some CI systems; if a downstream consumer needs it, `tap2junit` or a one-line `bats --formatter junit` wrapper can be added later. Adding both at the start duplicates the output and complicates the contract.

## Decision: Reports are gitignored, not committed

**Rationale**: A per-run report (TAP log + summary) is useful for the checkpoint log and for retrospective debugging, but committing one report per run pollutes the diff. The reports are written under `tests/bash/.reports/` and are excluded from the repo via `.gitignore`.

## Decision: Pinned bats version is 1.11.0

**Rationale**: bats-core 1.11.0 is the latest release as of 2024 and is widely available on GitHub. Pinning the version in the bootstrap script gives deterministic behavior across hosts and prevents surprise breaking changes from `main`. The bootstrap also writes the resolved version into `tests/bash/.bats/VERSION` so the user can confirm what was installed.

## Decision: Out of scope: Python tests

**Rationale**: The spec explicitly excludes Python utilities (Assumptions). `py_compile` and the existing fixture-based plotting/summary validation in `utils/validate-checkpoint.sh` continue to be the source of truth for Python correctness. If a future feature wants pytest, it can be a separate suite with its own scope and conventions.
