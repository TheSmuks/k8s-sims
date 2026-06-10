# Quickstart: End-to-End Framework Validation

This guide describes how to validate the feature from a clean checkout and how to prove the resulting implementation meets the specification.

## Prerequisites

- Git access to `git@github.com:TheSmuks/k8s-sims.git`.
- Windows/Git-Bash or Linux shell capable of running bash scripts.
- Python available as `python`.
- Project Python dependencies installable from `requirements.txt`.
- Docker, kubectl, kind, and kwokctl for simulator smoke tests where documented prerequisites are satisfied.
- Enough permission to create and delete temporary validation directories and local clusters.

If a runtime dependency is missing, do not assume the simulator failed. Record the missing dependency as evidence, run fallback checks, and classify the simulator according to the validation report contract.

## 1. Create a clean validation checkout

Use a separate path if the existing working tree has local changes.

```bash
BASE=/c/Users/chill/Syncthing/Projects/k8s-sims-e2e-run
rm -rf "$BASE"
git clone git@github.com:TheSmuks/k8s-sims.git "$BASE"
cd "$BASE"
git fetch origin --prune
git checkout main
git reset --hard origin/main
git clean -fdx
git status --short --branch
```

Expected outcome:
- `git status --short --branch` reports a clean `main...origin/main` baseline before feature work.

## 2. Record baseline and tool evidence

```bash
git remote -v
git rev-parse --abbrev-ref HEAD
git rev-parse HEAD
git status --short --branch
python --version
uv --version || true
git --version
docker --version || true
kubectl version --client=true --output=yaml || kubectl version --client || true
kind --version || true
kwokctl --help | head -20 || true
```

Expected outcome:
- Every installed tool has observed version or help output.
- Missing tools are recorded and later used to classify blocked or skipped runtime checks.

## 3. Inspect project documentation before selecting checks

Read and cite these files in the validation report:

```text
README.md
SIM_MODULES.md
modules/kwok/README.md
modules/kube-sched/README.md
modules/simkube/README.md
modules/kubemark/README.md
modules/opensim/README.md
.specify/memory/constitution.md
requirements.txt
utils/validate-checkpoint.sh
tests/bash/run.sh
```

Expected outcome:
- Active simulator modes and their prerequisites are known from repository documentation.
- Validation expectations are not based on memory.

## 4. Install or verify Python dependencies

Use the project-supported dependency set. On this host, `uv` is available and `pip` is not guaranteed to be on PATH.

```bash
uv pip install --system -r requirements.txt || python -m pip install -r requirements.txt
```

Expected outcome:
- Python validation commands can import required packages.
- If dependency installation fails, create a failure record with command output.

## 5. Run non-privileged validation checks

```bash
python -m pytest tests/ -v
bash tests/bash/run.sh
bash tests/bash/run.sh --with-mocks
bash utils/validate-checkpoint.sh all
```

Expected outcome:
- All non-privileged checks pass, or every failure is recorded, fixed if project-scope, and re-run.
- For shell failures, add/update bats coverage first, confirm the failing behavior, then apply the fix.

## 6. Generate small reproducible workloads

```bash
rm -rf output/e2e-validation
python utils/kube-gen.py -o output/e2e-validation/vanilla -c 10 -i 10
python utils/kube-gen.py --simkube -t -o output/e2e-validation/simkube -c 10 -i 10
python utils/kube-gen.py --kubemark -o output/e2e-validation/kubemark -c 10 -i 10
python utils/kube-gen.py --open_sim -o output/e2e-validation/opensim -c 10 -i 10
find output/e2e-validation -maxdepth 3 -type f | sort
```

Expected outcome:
- Required manifests and traces exist for each generated mode.
- SimKube `.sktrace` artifacts are structurally validated before runtime use.

## 7. Run simulator smoke checks where prerequisites are satisfied

Follow the module README and `SIM_MODULES.md` for each mode before running it.

Command pattern:

```bash
bash kube-run.sh -m <mode> -e <dataset-path> -n 1 -x <timeout>
```

Suggested starting checks:

```bash
bash kube-run.sh -m kwok -e output/e2e-validation/vanilla -n 1 -x 180
bash kube-run.sh -m kubemark -e output/e2e-validation/kubemark -n 1 -x 300
bash kube-run.sh -m simkube -e output/e2e-validation/simkube -n 1 -x 900
```

Expected outcome:
- Modes whose documented prerequisites are satisfied complete a smoke run or produce failure records.
- Modes whose prerequisites are not satisfied receive documented skip or external blocker records plus fallback validation.
- Cleanup behavior is verified or recorded as a failure.

## 8. Validate preservation behavior

```bash
bash utils/validate-checkpoint.sh collision
```

Expected outcome:
- Existing result artifacts are not silently overwritten.

## 9. Produce the validation report

Create or update:

```text
specs/004-e2e-framework-validation/validation-report.md
```

The report must follow:

```text
specs/004-e2e-framework-validation/contracts/validation-report.md
```

Expected outcome:
- Every active simulator mode has a final status.
- Every failed command has a failure record.
- Project-scope failures are fixed and re-verified.
- External blockers are documented with fallback checks.
- Reproduction steps are complete.

## 10. Final regression check

After applying fixes, rerun the affected failing checks and then run the broader non-privileged suite again:

```bash
python -m pytest tests/ -v
bash tests/bash/run.sh
bash tests/bash/run.sh --with-mocks
bash utils/validate-checkpoint.sh all
```

Expected outcome:
- All non-privileged checks pass on the validation host.
- Any remaining non-pass simulator outcomes are documented as external blockers or platform constraints, not unexplained failures.
