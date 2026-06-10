# Contract: Validation Report

The final validation report is a durable Markdown artifact produced during implementation at:

`specs/004-e2e-framework-validation/validation-report.md`

It must be readable without access to terminal scrollback and must contain enough evidence to reproduce or audit the run.

## Required sections

### 1. Baseline

Must include:
- Remote URL
- Baseline branch
- Baseline revision
- Feature branch used for validation
- Clean working-tree evidence
- Whether the user's original working tree was dirty and how isolation was handled

### 2. Environment and tool evidence

Must include a table with one row per tool or document used in a factual claim.

Required columns:
- Fact
- Evidence source
- Observed value
- Impact on validation

Minimum entries:
- Git
- Python
- Dependency manager or package installation method
- Docker
- kubectl and kustomize
- kind
- kwokctl
- Project constitution
- Active simulator inventory
- Each module README used to decide runtime feasibility

### 3. Coverage matrix

Must include one row per validation layer and simulator mode.

Required columns:
- Area
- Command or check
- Expected outcome
- Actual outcome
- Final status: `pass`, `fixed`, `skipped-documented-constraint`, or `blocked-external`
- Evidence reference

Minimum areas:
- Clean baseline
- Python unit tests
- Bash/bats suite
- Checkpoint validation
- Workload generation
- Trace structure validation
- Plotting and summary generation
- Result preservation behavior
- `kwok`
- `kube-sched`
- `simkube`
- `kubemark`
- `opensim`

### 4. Failure records

Every failure must have a subsection using this shape:

```text
#### FAILURE-ID: Short title

- Phase:
- Command or action:
- Expected:
- Observed:
- Root cause:
- Scope: project-defect | external-dependency | platform-constraint | documentation-mismatch | test-environment
- Resolution:
- Post-resolution status:
- Verification evidence:
```

Rules:
- A failing command cannot be omitted because a later command passed.
- Original failure evidence and post-fix verification evidence must be separate.
- Project defects must not remain unresolved at completion.

### 5. Fix records

Every project change made to solve a failure must have a subsection using this shape:

```text
#### FIX-ID: Short title

- Related failures:
- Changed paths:
- Change summary:
- Test-first evidence:
- Verification commands:
- Documentation updates:
```

Rules:
- Shell fixes require test-first evidence.
- Documentation updates are required when verified behavior differs from existing docs.

### 6. External blockers and documented skips

Every skipped or blocked simulator/check must include:
- Blocking prerequisite or platform constraint
- Evidence source proving the constraint
- Fallback validation performed
- User impact
- What would be required to fully validate it

### 7. Reproduction steps

Must include a clean sequence that another maintainer can run from the remote repository.

Rules:
- Commands must not rely on hidden local paths except explicitly declared temporary directories.
- Commands must record expected high-level outcomes.
- Any known host-specific requirements must be listed before the commands.

### 8. Final verdict

Must include:
- Overall status
- Whether all project-scope failures are fixed
- Remaining external blockers, if any
- Regression checks completed after fixes

## Completion rules

The report is complete only when:
- 100% of active simulator modes have a final status.
- 100% of failed actions have failure records.
- 0 project-scope failures remain unresolved.
- 100% of factual claims have evidence references.
- All non-privileged checks pass after fixes on the validation host.
