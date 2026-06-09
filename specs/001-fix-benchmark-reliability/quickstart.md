# Quickstart: Benchmark Reliability Stabilization Validation

This guide defines the validation path for the implementation. Run commands from the repository root unless noted.

## Prerequisites

- Shell environment compatible with the project scripts.
- Python available as `python` for local utility validation.
- Dependencies from `requirements.txt` installed in the active environment when validating plotting or summary behavior.
- Docker, privileged container support, and Linux cgroup access only for full simulator validation.
- GitHub CLI authentication only when publishing release checkpoints.

## Pre-implementation release gate

Before implementation changes are made, preserve the current project state with a release tag:

```bash
git tag -a sarteco-2026 -m "sarteco-2026 pre-implementation release"
git push origin sarteco-2026
gh release create sarteco-2026 --title "sarteco-2026" --notes "Pre-implementation release before benchmark reliability stabilization changes."
```

Expected outcome:
- Tag `sarteco-2026` exists locally and on the remote.
- GitHub release `sarteco-2026` is visible.
- The release points to a commit before implementation code changes for this feature.

Current planning run status:
- Release created: https://github.com/TheSmuks/k8s-sims/releases/tag/sarteco-2026
- Tag target commit: `ba9d2d7140d7cdbe2d67873f5b877c5de5d68c63`

## Baseline validation before code changes

Run baseline checks to confirm known failures and available local prerequisites:

```bash
bash -n kube-director.sh kube-run.sh entrypoint.sh modules/*/module.sh utils/*.sh
python -m py_compile utils/kube-gen.py utils/kube-plot.py utils/min-max-avg.py
python utils/kube-gen.py -o /tmp/k8s-sims-gen-test -c 1 -i 1
```

Expected outcome before implementation:
- Shell syntax check passes.
- Python compile shows the existing plotting syntax failure until the plotting checkpoint is implemented.
- Dataset generator smoke test creates `nodes-1.yaml` and `pods-1.yaml`.

## Checkpoint 1: Plotting and summary reliability

Validate after fixing plotting and summary behavior:

```bash
python -m py_compile utils/kube-plot.py utils/min-max-avg.py
python utils/kube-plot.py -d <valid-result-fixtures> -o <plot-output> -l -b
python utils/min-max-avg.py -d <valid-result-fixtures> -o <summary-output>
python utils/kube-plot.py -d <missing-directory> -o <plot-output> -l
```

Expected outcome:
- Compilation succeeds.
- Valid fixtures create plot artifacts and summary output.
- Missing directory produces a clear user-facing error.
- Constant metrics and unknown simulator names do not crash plotting.

Commit expectation:
- Commit this checkpoint with the verification output in the commit message body or adjacent notes.

## Checkpoint 2: Runner path, timeout, output, and memory behavior

Validate after runner hardening:

```bash
bash -n kube-director.sh kube-run.sh modules/*/module.sh
mkdir -p "/tmp/k8s sims path test"
python utils/kube-gen.py -o "/tmp/k8s sims path test" -c 1 -i 1
(cd /tmp && <repo-root>/kube-run.sh -e "/tmp/k8s sims path test" -m <lightweight-mode> -n 1 -x 1)
```

Expected outcome:
- Shell syntax remains valid.
- Paths containing spaces are preserved.
- Simulator module loading does not depend on current working directory.
- Default result output directories are created before writing.
- Timeout or prerequisite failures are explicit and recorded.

If full simulator execution is unavailable locally, record the blocker and run the closest available dry-run or syntax validation.

Commit expectation:
- Commit this checkpoint after validation or documented blocker.

## Checkpoint 3: Simulator setup, mode inventory, and reproducibility

Validate after setup and documentation changes:

```bash
bash -n modules/*/module.sh entrypoint.sh kube-director.sh kube-run.sh
git grep -n "sarteco-2026\|privileged\|simulator mode\|reproduc" -- . ':!data/**'
```

Expected outcome:
- Simulator setup scripts remain syntactically valid.
- The scheduler simulator setup applies intended configuration changes persistently.
- Active, experimental, unavailable, and legacy modes are documented in one authoritative place.
- Runtime dependencies are categorized as pinned, intentionally variable, or unavailable.
- Privileged execution and host access requirements are discoverable.

Commit expectation:
- Commit this checkpoint after validation.

## Checkpoint 4: Environment-file and generated-data policy

Validate after repository hygiene policy changes:

```bash
git status --short
git check-ignore .env || true
git grep -n "generated data\|\.env\|secret\|environment" -- . ':!data/**'
```

Expected outcome:
- Sensitive local environment files are not required as committed project inputs.
- A non-secret example or documented configuration path exists if users need environment defaults.
- Generated data policy states which datasets remain versioned and how larger datasets are regenerated or stored.

Commit expectation:
- Commit this checkpoint after validation.

## Checkpoint 5: Result preservation policy

Validate after output collision behavior is updated:

```bash
mkdir -p /tmp/k8s-sims-results
printf 'existing\n' > /tmp/k8s-sims-results/example.csv
# Run the selected lightweight result-writing workflow against the same output target.
```

Expected outcome:
- Existing output is not silently overwritten.
- The user sees whether output was preserved, rejected, renamed, or written to a timestamped location.
- Preserved files are not unintentionally treated as simulator result files by plotting workflows.

Commit expectation:
- Commit this checkpoint after validation.

## Final validation

Run the full local validation suite available in the environment:

```bash
bash -n kube-director.sh kube-run.sh entrypoint.sh modules/*/module.sh utils/*.sh
python -m py_compile utils/*.py
python utils/kube-gen.py -o /tmp/k8s-sims-gen-test -c 1 -i 1
python utils/kube-plot.py -d <valid-result-fixtures> -o /tmp/k8s-sims-plots -l -b
python utils/min-max-avg.py -d <valid-result-fixtures> -o /tmp/k8s-sims-summary
```

Expected outcome:
- All local checks pass or have documented environment blockers.
- Every feature success criterion has a corresponding verification result or blocker note.
- Git history shows the pre-implementation release and the checkpoint commits.
