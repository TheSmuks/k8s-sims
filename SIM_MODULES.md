# Simulator Modules Inventory

`SIM_MODULES` remains the active runtime list consumed by `kube-director.sh`. This document is the maintainer-facing inventory for status, dependencies, and expectations.

## Active simulator modes

| Mode | Module | Data path rule | Requirements | Runtime dependencies | Cleanup | Verification |
|---|---|---|---|---|---|---|
| `kwok` | `modules/kwok/module.sh` | `vanilla/` datasets from director, or direct `nodes-*.yaml`/`pods-*.yaml` | `kwokctl`, `kubectl` | kind node image pinned to `kindest/node:v1.29.0`; KWOK installed externally or in container | `kwokctl delete cluster --name kwok` | syntax, path, best-effort run |
| `kube-sched` | `modules/kube-sched/module.sh` | `vanilla/` datasets | Docker Compose, scheduler simulator, `kubectl` | scheduler simulator repository checked out at `v0.4.0`; KWOK cluster image pinned to `registry.k8s.io/kwok/cluster:v0.5.1-k8s.v1.29.0` | `docker compose down` | syntax and documented runtime blocker when Docker unavailable |
| `simkube` | `modules/simkube/module.sh` | `simkube/` datasets with `trace-*.sktrace` | kind, KWOK manifests, Prometheus, SimKube | KWOK manifests pinned to v0.7.0 URLs; SimKube repository checked out at `v2.3.0`; kube-prometheus currently follows upstream default branch and is intentionally variable | kind cluster deletion | syntax and documented runtime blocker when tooling unavailable |
| `kubemark` | `modules/kubemark/module.sh` | `kubemark/` datasets | kind, kubemark hollow nodes, `kubectl` | kind node image pinned to `kindest/node:v1.29.0` | kind cluster deletion and temporary kubeconfig removal | syntax and best-effort run |
| `opensim` | `modules/opensim/module.sh` | `simon-config-*.yaml` | OpenSimulator binary, sudo/cgroup access | local `modules/opensim/cmd`; host cgroup tools | cgroup process termination and `cgdelete` | syntax; full run requires Linux cgroups |

## Experimental and legacy modes

| Mode | Status | Notes |
|---|---|---|
| `vanilla` | Experimental | Module exists for real kind/Kubernetes runs, but it is not listed in `SIM_MODULES` by default. It requires stronger host isolation and manual verification. |
| `k8s` | Legacy naming | `kube-director.sh` still recognizes a `k8s` data-path branch for compatibility, but it is not an active module name. |

## Result preservation policy

Runner entry points never silently overwrite an existing result file. If a target CSV already exists, it is moved to a visible sibling backup named `<base>.preserved-YYYYmmdd-HHMMSS.csv` before the new header is written. Plotting ignores `*.preserved-*.csv` by default so backups are not misclassified as additional simulator results.

## Generated data and reproducibility

Runtime dependencies are categorized as pinned, intentionally variable, or unavailable above. Generated datasets should be reproducible through `utils/kube-gen.py` and should not be treated as authoritative benchmark results unless the exact generator command and simulator mode are recorded in a checkpoint.
