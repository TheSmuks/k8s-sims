# k8s-sims Constitution

## Core Principles

### I. Shell Safety

All shell scripts must pass `bash -n` syntax checking, use `set -u` for unbound variable detection, and quote all variable expansions. The bash correctness test suite (`tests/bash/run.sh`) enforces this on every inventory entry.

### II. Conventional Commits (NON-NEGOTIABLE)

All commits MUST follow the [Conventional Commits](https://www.conventionalcommits.org/) v1.0.0 specification. Format:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Allowed types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`, `build`, `perf`, `revert`.

**Scopes**: `runner`, `director`, `modules`, `entrypoint`, `utils`, `tests`, `deps`, `docker`, `spec`, `infra`, or omitted for repo-wide changes.

Examples:
- `feat(runner): add --with-mocks flag for shim-based testing`
- `fix(director): quote experiment path in module invocation`
- `docs: update ARCHITECTURE.md with test suite layer`
- `test(modules): add behavioral tests for kwok and simkube`
- `chore(deps): pin bats-core to 1.11.0`

Non-conforming commit messages must be amended before merge.

### III. Conventional Branches (NON-NEGOTIABLE)

All non-trunk branches MUST follow the [Conventional Branch](https://conventionalbranch.org/) specification. Format:

```
<type>/<description>
```

**Allowed types**: `feature` (or `feat`), `bugfix` (or `fix`), `hotfix`, `release`, `chore`.

**Trunk branches**: `main`, `develop` (no prefix).

**Rules**:
- Lowercase alphanumerics and hyphens only (no underscores, no spaces, no uppercase).
- No consecutive, leading, or trailing hyphens.
- Descriptions must be concise and descriptive.
- Include ticket numbers where applicable (e.g., `feat/issue-12-bash-test-suite`).

Examples:
- `feature/bash-test-suite`
- `fix/quote-paths-in-director`
- `hotfix/entrypoint-image-pull`
- `release/v1.2.0`
- `chore/pin-bats-version`

Non-conforming branch names must be renamed before merge.

### IV. Test-First for Shell Changes

Any change to a shell script in the inventory must be accompanied by a corresponding test in the bats suite. Red-Green-Refactor: write or update the test, confirm it fails, then make the change, confirm it passes.

### V. No Silent Overwrites

Result files (`results/*.csv`) are never silently overwritten. The runner preserves existing files as `*.preserved-YYYYmmdd-HHMMSS.csv`. Plotting tools ignore preserved backups by default.

### VI. Privileged Execution Awareness

Full simulator execution requires Docker-in-Docker, host cgroup access, or network pulls. Non-privileged validation paths (syntax checks, Python compilation, fixture plotting, bash test suite) must always remain available and passing.

## Development Constraints

- **Platform**: Scripts must work on POSIX sh (bash 5+) and be validated on both Linux and Windows/Git-Bash (MSYS2).
- **Line endings**: CRLF is the repo default; all tools must handle it.
- **Python**: 3.12+; dependencies listed in `requirements.txt`.
- **External tools**: kwokctl, kubectl, kind, docker, cgexec are runtime-only dependencies. Tests skip gracefully when these are absent; `--with-mocks` provides PATH shims for forced execution.

## Workflow

1. Create a feature branch from `main` using the Spec Kit workflow or manually with conventional commit prefix.
2. Implement changes with tests.
3. Validate: `bash tests/bash/run.sh` and `utils/validate-checkpoint.sh all`.
4. Commit with conventional commit format.
5. Push and open a PR for review.

## Governance

This constitution supersedes ad-hoc practices. Amendments require documentation in this file, a conventional commit of type `docs(spec)`, and verification that existing tests still pass.

**Version**: 1.1.0 | **Ratified**: 2026-06-09 | **Last Amended**: 2026-06-09
