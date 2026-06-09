# Research: Benchmark Reliability Stabilization

## Decision: Split implementation into independently verified checkpoints

**Rationale**: The requested work spans plotting, run orchestration, path safety, simulator setup, documentation, data policy, and result handling. Independent checkpoints let each group be verified and committed before the next group begins, matching the user's instruction and reducing regression risk.

**Alternatives considered**:
- Single large cleanup commit: rejected because failures would be harder to isolate.
- One commit per individual line item: rejected as too noisy and likely to fragment related fixes.

## Decision: Treat local fixture and syntax validation as the baseline verification layer

**Rationale**: Full simulator execution requires Docker-in-Docker, privileged host access, Linux cgroups, and network access. The planning workflow must remain usable on Windows/Git-Bash and machines without Docker Compose. Syntax checks, Python compilation, generated fixture runs, path-with-spaces checks, and small result fixtures provide reliable baseline validation. Full simulator validation remains a higher-confidence check when prerequisites exist.

**Alternatives considered**:
- Require full simulator runs for every checkpoint: rejected because local prerequisites are not guaranteed and would block maintainers.
- Skip runtime validation entirely: rejected because plotting and orchestration regressions can be caught with lightweight fixtures.

## Decision: Preserve existing CLI entry points while tightening their contracts

**Rationale**: Users already interact with `kube-director.sh`, `kube-run.sh`, and utilities under `utils/`. Preserving commands avoids needless workflow churn. The plan will harden validation, output handling, path behavior, and failure messages without changing the core user model.

**Alternatives considered**:
- Replace scripts with a new unified command: rejected as out of scope for reliability stabilization.
- Add a wrapper-only layer: rejected because several defects are inside existing workflows and must be fixed at the source.

## Decision: Use result fixtures to validate plotting and summary behavior

**Rationale**: Plotting failures can be verified without live Kubernetes. Representative CSV fixtures can cover valid inputs, missing directories, malformed rows, constant metrics, zero pod counts, and unknown simulator names.

**Alternatives considered**:
- Validate plotting only against historical benchmark outputs: rejected because historical data may not include edge cases.
- Validate by visual inspection only: rejected because errors such as undefined normalization and unknown style failures need repeatable checks.

## Decision: Make result preservation explicit rather than silently renaming files

**Rationale**: Silent backup names can surprise users and can later be misread as additional simulator results. A visible policy improves trust and makes plotting behavior predictable.

**Alternatives considered**:
- Always overwrite existing output: rejected because it risks data loss.
- Always auto-rename without messaging: rejected because current behavior is surprising and can pollute plotting inputs.

## Decision: Document privileged execution as accepted risk, not a defect to remove immediately

**Rationale**: Full benchmark runs appear to require Docker-in-Docker, host cgroup access, kind/KWOK/Kubemark behavior, and privileged containers. Removing that would likely change the benchmark architecture. The reliability feature should make risks visible and recommend isolated execution.

**Alternatives considered**:
- Remove all privileged execution: rejected as likely incompatible with existing simulator requirements.
- Leave risk undocumented: rejected because users need to understand host impact before running.

## Decision: Categorize runtime dependencies by reproducibility status

**Rationale**: Some dependencies are version-pinned, some are pulled or cloned dynamically, and some are constrained by simulator ecosystems. A dependency inventory that marks pinned, intentionally variable, or unavailable makes reproducibility gaps visible and actionable.

**Alternatives considered**:
- Pin every dependency immediately: rejected because it may require upstream compatibility investigation beyond this stabilization feature.
- Leave dynamic downloads implicit: rejected because benchmark results need reproducible setup context.

## Decision: Treat `.env` as sensitive local configuration unless proven otherwise

**Rationale**: The repository currently contains a tracked environment file name. Even without reading its contents, the safe policy is to prevent accidental reliance on committed secrets and move shared defaults to a non-secret example file.

**Alternatives considered**:
- Inspect and classify the tracked file contents: rejected because secret-bearing files should not be read unless explicitly required.
- Ignore the file because contents are unknown: rejected because the existence of a tracked `.env` is itself a repository hygiene risk.

## Decision: Clarify simulator support through a single authoritative mode inventory

**Rationale**: The current source has active modules, candidate modules, and special data-path handling that can diverge. A single inventory avoids confusion around active, experimental, unavailable, and legacy modes.

**Alternatives considered**:
- Keep simulator status implicit in script conditionals: rejected because users and maintainers cannot easily reason about available modes.
- Delete inactive modes immediately: rejected until the project owner confirms whether candidates such as the vanilla mode should remain.

## Decision: Do not change benchmark methodology in this feature

**Rationale**: The requested feature targets reliability, safety, and reproducibility. Changing scheduling workload composition, simulator scoring, or metric definitions would make results incomparable with prior runs and expand scope.

**Alternatives considered**:
- Redesign benchmark metrics while touching plotting: rejected as out of scope.
- Replace generated datasets wholesale: rejected unless later tasks explicitly define a generated-data migration policy.
