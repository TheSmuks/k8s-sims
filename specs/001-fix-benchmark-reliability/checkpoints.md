# Benchmark Reliability Stabilization Checkpoints

Each checkpoint records scope, commands, outcome, blockers, and commit/reference.

## Setup and Foundational

- Scope: release verification, fixtures, validation helper, policy skeletons.
- Release: https://github.com/TheSmuks/k8s-sims/releases/tag/sarteco-2026
  - Local tag `sarteco-2026` exists.
  - GitHub release is visible (not draft, not prerelease).
- Fixtures created:
  - `tests/fixtures/results/valid/kwok.csv`, `tests/fixtures/results/valid/kube-sched.csv`
  - `tests/fixtures/results/edge-cases/constant-metric.csv`, `zero-pod.csv`, `unknown-simulator.csv`, `malformed.csv`, `empty.csv`
- Validation helper created: `utils/validate-checkpoint.sh` (baseline, plotting, path-spaces, collision, docs, all).
- Policy skeletons created: `SECURITY.md`, `SIM_MODULES.md`, `DATASETS.md`.
- Ignore files updated: `.gitignore`, `.dockerignore`.
- Validation commands run from repo root:
  - `bash -n kube-director.sh kube-run.sh entrypoint.sh modules/*/module.sh utils/*.sh` -> exit 0
  - `python -m py_compile utils/*.py` -> exit 0 (after `.venv` install of `requirements.txt`)
  - `python utils/kube-gen.py -o /tmp/k8s-sims-validation/gen -c 1 -i 1` -> produced `nodes-1.yaml` and `pods-1.yaml`
- Local environment blocker recorded: `kwokctl`, `kubectl`, `kind`, and Docker are not installed in this Git-Bash environment, so full simulator execution cannot be performed; baseline is therefore limited to syntax checks, Python compile, dataset generator smoke, and fixture-based plotting.
- Commit/reference: 481856a "[Spec Kit] Implementation progress"; verified tree clean apart from intentional files.

## User Story 1 - Plotting and summary reliability

- `utils/kube-plot.py` rewritten to fix the startup import-order problem, replace the `os.path.isdit` typo with a clear `is_dir()` validation, parse comma decimals explicitly, normalize constant-metric case to `0.0`, provide default style/color for unknown simulator names, and skip empty/malformed files without crashing.
- `utils/min-max-avg.py` rewritten to validate input directory, parse decimal-aware columns, skip empty/malformed files, and emit a clear error when no valid result files remain.
- Contracts updated in `specs/001-fix-benchmark-reliability/contracts/cli-contracts.md` to record pipe-delimited CSV format with comma decimals and the `*.preserved-*.csv` ignore rule.
- Validations run via `utils/validate-checkpoint.sh plotting`:
  - Valid fixtures: produced line, bar, correlation, and CPU ratio artifacts under `/tmp/k8s-sims-validation/plots/`; `summary.json` written.
  - Edge fixtures: constant-metric, zero-pod, unknown-simulator, malformed, and empty files processed without traceback; empty file skipped, malformed file skipped, unknown simulator accepted with default style, zero-pod handled.
  - Missing directory: clear error `Error: Data directory '...' does not exist or is not a directory.` and exit code 1.
- Commit/reference: 481856a "[Spec Kit] Implementation progress".

## User Story 2 - Runner predictability

- `kube-run.sh`:
  - `load_simulator_code` now uses `${SCRIPT_DIR}/modules/<mode>/module.sh` so module loading is independent of the caller's working directory.
  - Default output directory is created with `mkdir -p "$(dirname "$OUT_FILE")"` before writing.
  - `SCHEDULE_TIMEOUT` is always initialized; the `if [[ $MAX_SIMULATION_TIME -eq -1 ]]` branch no longer leaves it unset.
  - Memory-limit cancellation sets `RUN_CONDITION="false"` and `touch "$MAX_MEM_FLAG_FILE"`; the watch loop checks `RUN_CONDITION` each iteration, allowing the active scheduling loop to react to the max-memory signal.
  - Cleanup paths explicitly clear the timeout/max-mem flag files and `trap` cleanup on `SIGINT/SIGTERM` is installed before the run loop.
  - Iteration over node files uses `while read` with `< <(find ...)` and path-like variables are quoted.
  - The preserve-existing-output block now emits a visible `log WARN` and renames to `*.preserved-YYYYmmdd-HHMMSS.csv` so backup files are excluded from plotting by default.
  - Cluster setup failure now writes a `0|0|0|0|0|0|0` failed-run row and runs cleanup so the result file is never silently left half-written.
- `kube-director.sh`:
  - `mapfile -t SIMULATORS < "$LOCAL_PATH/SIM_MODULES"` replaces `read -a ... -d EOF`; the missing-output-folder error is removed (the folder is auto-created), and all per-simulator invocations are quoted.
  - Plotting call uses `python` and quotes `$OUT_FOLDER`/output path.
- `utils/kube-gen.py`:
  - `run_simkube_tracer` and `invoke_kube_run` use `subprocess.check_call` with argument lists and `shlex.split` for the user arguments; no shell interpolation.
  - `script_dir` is `utils/`, so `root_dir` is the repo root, matching the prior layout.
- Module quoting: `modules/kwok/module.sh`, `modules/kubemark/module.sh`, `modules/opensim/module.sh`, `modules/simkube/module.sh`, `modules/vanilla/module.sh`, `modules/kube-sched/module.sh`, `utils/simkube-tracer.sh` now quote `kubectl`, `kind`, `cgexec`, `cd`, and the trace/cluster variables. The kube-sched `sed` is now `sed -i` so the image-pin edit persists in `compose.yml`.
- Validations:
  - `bash -n kube-director.sh kube-run.sh entrypoint.sh modules/*/module.sh utils/*.sh` -> exit 0.
  - `python utils/kube-gen.py -o "/tmp/k8s-sims-validation/path with spaces" -c 1 -i 1` -> produced `nodes-1.yaml` and `pods-1.yaml` in the spaced path.
  - `(cd /tmp && bash <repo>/kube-run.sh -e "<spaced path>" -m kwok -n 1 -x 1)` -> runner invoked from outside the repo root, accepted the spaced path, preserved the existing `kwok.csv` as `kwok.preserved-20260609-*.csv` with a visible WARN, then recorded a failed-run row because `kwokctl`/`kubectl` are not installed in this environment.
- Local environment blocker recorded: full simulator execution requires Docker, kind, KWOK, and kubectl, which are not present in this Git-Bash environment. The closest completed validation is fixture generation, runner invocation from outside the repo root, and the visible preservation behavior.
- Commit/reference: 481856a "[Spec Kit] Implementation progress".

## User Story 3 - Simulator setup, mode inventory, and reproducibility

- `modules/kube-sched/module.sh`: image pinning now uses `sed -i` so the KWOK cluster image reference is persisted in `compose.yml` for the lifetime of the cloned simulator repository; `v0.4.0` checkout is preserved.
- `Dockerfile`: documented in `SIM_MODULES.md` and `SECURITY.md` so users know that `kind`, `kwok`, `skctl`, `kubectl`, and the scheduler simulator images are bundled versions and the runtime pulls scheduler-simulator images in `entrypoint.sh`.
- `modules/simkube/module.sh` and `modules/kube-sched/module.sh`: runtime dependencies are categorized in `SIM_MODULES.md` as pinned (KWOK manifests v0.7.0, scheduler simulator v0.4.0, kind image v1.29.0), intentionally variable (kube-prometheus follows upstream default), and unavailable (none for these modules at the moment).
- `entrypoint.sh`: each required image is pulled individually with explicit `WARNING` reporting on failure instead of failing the whole step.
- `SECURITY.md`: documents privileged Docker, Docker-in-Docker, host cgroup access, and local environment file risks; recommends disposable VMs and reviews of module scripts.
- `SIM_MODULES.md`: authoritative inventory of active, experimental, unavailable, and legacy modes plus result preservation policy.
- Validation: `git grep -n "sarteco-2026\|privileged\|simulator mode\|reproduc" -- . ':!data/**'` returns matches in `quickstart.md`, `plan.md`, `research.md`, `contracts/cli-contracts.md`, and `SIM_MODULES.md`.
- Commit/reference: 481856a "[Spec Kit] Implementation progress".

## User Story 4 - Result preservation

- `kube-run.sh` now emits a visible `log WARN` whenever an existing result file is preserved, names the preserved copy with a timestamp suffix `*.preserved-YYYYmmdd-HHMMSS.csv`, and excludes those copies from plotting via the `*.preserved-*.csv` filter in `utils/kube-plot.py` and `utils/min-max-avg.py`.
- `kube-director.sh` uses the same per-simulator output path naming, so the preservation policy is consistent across both runner entry points.
- `SIM_MODULES.md` documents the policy.
- Validation:
  - `mkdir -p /tmp/k8s-sims-validation/results; printf 'existing\n' > example.csv` and rerunning the runner preserved the original contents and left the backup under a `*.preserved-*.csv` name.
  - The plotting workflow now explicitly filters `*.preserved-*.csv` files (see `candidate_result_files` and `min-max-avg.py`).
  - All earlier checkpoints have validation evidence recorded in this document.
- Commit/reference: 481856a "[Spec Kit] Implementation progress".

## Final validation

- `bash -n kube-director.sh kube-run.sh entrypoint.sh modules/*/module.sh utils/*.sh` -> exit 0.
- `python -m py_compile utils/*.py` -> exit 0.
- `python utils/kube-gen.py -o /tmp/k8s-sims-validation/gen -c 1 -i 1` -> produced `nodes-1.yaml` and `pods-1.yaml`.
- `python utils/kube-plot.py -d tests/fixtures/results/valid -o <plot-output> -l -b` -> produces plot artifacts.
- `python utils/min-max-avg.py -d tests/fixtures/results/valid -o <summary-output>` -> produces `summary.json`.
- Local environment blocker: full simulator execution requires Docker, kind, KWOK, kubectl, and OpenSimulator tooling; the closest available validation is fixture-based plotting, dataset generation, runner invocation, and visible preservation behavior.
- `git status --short` after the implementation changes shows the expected modified and new files described above and no unrelated untracked files (apart from `.venv/` which is gitignored).
- Commit/reference: 481856a "[Spec Kit] Implementation progress" (final).
