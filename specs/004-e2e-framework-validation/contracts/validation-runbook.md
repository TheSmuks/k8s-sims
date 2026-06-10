# Contract: Validation Runbook

This contract defines the required workflow for the implementation phase. Exact commands may be adjusted when evidence proves a better project-supported command is required, but every adjustment must be recorded in the validation report.

## Baseline contract

The run must start by recording:

```bash
git remote -v
git fetch origin --prune
git rev-parse --abbrev-ref HEAD
git rev-parse HEAD
git status --short --branch
```

Acceptance criteria:
- Working tree is clean before validation work starts, except planned feature artifacts.
- If the original project working tree is dirty, a separate clean clone is used.

## Documentation and version evidence contract

Before using a tool or simulator, record evidence from the best available source:

```bash
python --version
uv --version
git --version
docker --version
kubectl version --client=true --output=yaml
kind --version
kwokctl --help
```

Also inspect repository documentation:

```bash
# Use repository files, not memory, as evidence
README.md
SIM_MODULES.md
modules/*/README.md
.specify/memory/constitution.md
requirements.txt
utils/validate-checkpoint.sh
tests/bash/run.sh
```

Acceptance criteria:
- Each factual claim in the final report maps to command output or a file path.
- If command help and repository documentation disagree, create a failure record or documentation mismatch record.

## Non-privileged validation contract

Run before full simulator smoke tests:

```bash
python -m pytest tests/ -v
bash tests/bash/run.sh
bash tests/bash/run.sh --with-mocks
bash utils/validate-checkpoint.sh all
```

Acceptance criteria:
- All checks either pass or create failure records.
- Project-scope failures are fixed and re-run.
- Shell changes follow test-first discipline.

## Workload generation contract

Generate small reproducible workloads in isolated output directories:

```bash
rm -rf output/e2e-validation
python utils/kube-gen.py -o output/e2e-validation/vanilla -c 10 -i 10
python utils/kube-gen.py --simkube -t -o output/e2e-validation/simkube -c 10 -i 10
python utils/kube-gen.py --kubemark -o output/e2e-validation/kubemark -c 10 -i 10
python utils/kube-gen.py --open_sim -o output/e2e-validation/opensim -c 10 -i 10
```

Acceptance criteria:
- Expected node, pod, trace, or simulator-specific artifacts exist.
- SimKube traces are structurally validated before use.
- Missing optional validators become evidence-backed warnings only if project documentation allows graceful degradation.

## Simulator smoke contract

For each active simulator mode:

1. Read its module README and `SIM_MODULES.md` row.
2. Check host prerequisites.
3. If prerequisites are satisfied, run through `kube-run.sh` with a small dataset and a bounded timeout.
4. If prerequisites are not satisfied, record a documented skip or external blocker and run available fallback checks.
5. Confirm cleanup or record cleanup failure.

Required command shape:

```bash
bash kube-run.sh -m <mode> -e <dataset-path> -n 1 -x <timeout>
```

Acceptance criteria:
- Every active mode has one final outcome.
- Runtime-created clusters or resources are cleaned up or documented as cleanup failures.
- Host/platform blockers are supported by documentation evidence.

## Failure handling contract

When any command fails:

1. Capture the command, exit status, and relevant output.
2. Determine expected behavior from spec, constitution, or docs.
3. Diagnose root cause.
4. Classify scope.
5. If project-scope, fix it.
6. Re-run the failing check.
7. Re-run broader regression checks.
8. Update the validation report.

Acceptance criteria:
- No failed action is silently ignored.
- Project defects are not left unresolved.
- External blockers have fallback validation.

## Artifact preservation contract

Validation must avoid silent overwrites.

Acceptance criteria:
- Use isolated output paths for validation-generated files.
- Explicitly test existing result preservation behavior.
- Do not delete unrelated local outputs or simulator source directories.
