# Architecture Overview

This document provides a rapid and comprehensive understanding of the k8s-sims codebase architecture. Update it as the codebase evolves.

## 1. Project Structure

```
[Project Root]/
├── kube-run.sh           # Single-experiment runner (CLI entry point)
├── kube-director.sh      # Multi-experiment orchestrator (batch runner)
├── entrypoint.sh         # Docker container entrypoint
├── docker-compose.yaml   # One-command reproducible benchmark environment
├── Dockerfile            # Multi-stage build: builder (Go, Rust, Python) + runtime
├── modules/              # Simulator backend modules (one per mode)
│   ├── kwok/             # KWOK lightweight pod simulation
│   │   └── module.sh
│   ├── kubemark/         # Kubemark hollow-node simulation
│   │   ├── module.sh
│   │   └── kind-config.yaml
│   ├── kube-sched/       # Kubernetes Scheduler Simulator
│   │   └── module.sh
│   ├── simkube/          # SimKube trace-based simulation
│   │   ├── module.sh
│   │   ├── kind-config.yaml
│   │   ├── cert-manager.yaml
│   │   └── self-signed.yml
│   ├── opensim/          # OpenSimulator (Alibaba)
│   │   ├── module.sh
│   │   └── cmd           # Pre-built OpenSim binary
│   ├── vanilla/          # Real Kubernetes (experimental)
│   │   └── module.sh
│   └── template/         # Copy-paste template for new modules
│       └── module.sh
├── utils/                # Shared utilities
│   ├── kube-gen.py       # Dataset generator (Alibaba traces → YAML manifests)
│   ├── kube-plot.py      # Result plotter (CSV → matplotlib charts)
│   ├── min-max-avg.py    # Aggregate statistics across runs
│   ├── benchmark-gen.sh  # Benchmark dataset generation helper
│   ├── simkube-tracer.sh # SimKube trace collection wrapper
│   ├── validate-checkpoint.sh  # Multi-stage validation harness
│   └── base/             # Static manifests (hollow-node YAML, etc.)
├── data/                 # Input datasets (test, small, medium, big)
├── results/              # Output CSV files (gitignored by default)
├── tests/
│   ├── fixtures/         # Small result CSV fixtures for plotting validation
│   └── bash/             # Bats-based bash correctness test suite
│       ├── run.sh        # Suite runner
│       ├── bootstrap-bats.sh  # Auto-download bats-core
│       ├── helpers/      # inventory.bash, skip.bash, bats.bash
│       └── tests/        # .bats test files (static, behavioral, mocks)
├── tests/mocks/          # PATH-shim mock binaries for external tools
│   ├── bin/              # kwokctl, kubectl, kind, docker, cgexec, etc.
│   └── conf/             # Per-tool response rules
├── specs/                # Spec Kit feature specifications and plans
├── .specify/             # Spec Kit configuration and governance
├── requirements.txt      # Python dependencies
├── SECURITY.md           # Privileged execution and safety guidance
├── SIM_MODULES.md        # Simulator inventory and dependency status
├── DATASETS.md           # Dataset categories and retention policy
├── .gitignore
├── .dockerignore
└── ARCHITECTURE.md       # This document
```

## 2. High-Level System Diagram

```
[User] ──► [docker compose up] ──► [Container (entrypoint.sh)]
                │                          │
                │                          ├── kube-director.sh (batch)
                │                          │      ├── kube-run.sh -m kwok ...
                │                          │      ├── kube-run.sh -m kubemark ...
                │                          │      └── kube-run.sh -m simkube ...
                │                          │
                │                          └── Each kube-run.sh:
                │                                 ├── parse_args()
                │                                 ├── module.sh setup/run/cleanup
                │                                 ├── kube-gen.py (dataset)
                │                                 └── results → CSV
                │
[User] ──► [kube-director.sh] ──► (same flow, host-native)
[User] ──► [kube-run.sh -m ...] ──► (single experiment)
[User] ──► [kube-plot.py] ──► PNG charts
[User] ──► [utils/validate-checkpoint.sh] ──► validation report
```

Data flow: **Alibaba traces** → `kube-gen.py` → YAML manifests → `kube-run.sh` + module → `results/*.csv` → `kube-plot.py` → charts.

## 3. Core Components

### 3.1. Experiment Runner

**Name**: kube-run.sh

**Description**: Single-experiment CLI runner. Parses arguments (mode, experiment path, node count, runs, timeouts), sources the appropriate module, and orchestrates the setup/run/cleanup lifecycle. Preserves existing result files as timestamped backups before writing.

**Technologies**: Bash 5+, POSIX-compatible

**Key interfaces**: `kube-run.sh -m <mode> -e <experiment_path> -n <nodes> -x <timeout> [-s start] [-o output] [-t mem_threshold] [-p]`

### 3.2. Batch Orchestrator

**Name**: kube-director.sh

**Description**: Iterates over simulator modes and dataset sizes, invoking `kube-run.sh` for each combination. Reads the active module list from `SIM_MODULES` file. Supports path-specific experiment overrides.

**Technologies**: Bash 5+

### 3.3. Container Entrypoint

**Name**: entrypoint.sh

**Description**: Docker container entrypoint that runs `kube-director.sh` with environment-variable arguments. Reports individual image-pull failures. Runs in privileged mode with host cgroup access.

**Technologies**: Bash, Docker-in-Docker

### 3.4. Simulator Modules

Each module (`modules/<name>/module.sh`) exposes a standard interface consumed by `kube-run.sh`:

| Module | Simulator | External tools required | Data format |
|---|---|---|---|
| kwok | KWOK (lightweight pods) | `kwokctl`, `kubectl` | `nodes-*.yaml`, `pods-*.yaml` |
| kubemark | Kubemark (hollow nodes) | `kind`, `kubectl` | `kubemark/` datasets |
| kube-sched | Scheduler Simulator | Docker Compose, `kubectl` | `vanilla/` datasets |
| simkube | SimKube (trace replay) | `kind`, `kubectl`, Prometheus | `trace-*.sktrace` |
| opensim | OpenSimulator | `cgexec`, host cgroups | `simon-config-*.yaml` |
| vanilla | Real Kubernetes | `kind`, `kubectl` | `vanilla/` datasets |

### 3.5. Dataset Generator

**Name**: utils/kube-gen.py

**Description**: Transforms Alibaba cluster traces into simulator-specific YAML pod/node manifests. Supports configurable node counts, iterations, and output paths (including paths with spaces).

**Technologies**: Python 3.12, PyYAML

### 3.6. Result Plotter

**Name**: utils/kube-plot.py

**Description**: Reads result CSVs and produces matplotlib comparison charts. Handles locale-aware decimal formatting and normalization across simulator runs.

**Technologies**: Python 3.12, pandas, matplotlib, seaborn

### 3.7. Validation Harness

**Name**: utils/validate-checkpoint.sh

**Description**: Multi-stage validation runner. Subcommands: `baseline` (syntax + compile), `datasets`, `plots`, `plots-edge`, `collision`, `path-spaces`, `docs`, `bash-tests`, `all`. Each stage is independently runnable.

**Technologies**: Bash, Python

### 3.8. Bash Test Suite

**Name**: tests/bash/

**Description**: bats-core regression suite covering static syntax checking (`bash -n`, `set -u` smoke), behavioral tests (arg parsing, error paths, cleanup, path-with-spaces), and mock-based execution via PATH shims. Auto-bootstraps bats 1.11.0 on first run.

**Technologies**: bats-core 1.11.0, Bash

## 4. Data Stores

### 4.1. Input Datasets

**Type**: Filesystem (YAML, CSV)

**Location**: `data/`

**Purpose**: Alibaba cluster trace data transformed into simulator-specific manifests. Categories: `test/` (curated, committed), `small/`, `medium/`, `big/` (generated, gitignored).

### 4.2. Result Files

**Type**: Filesystem (CSV)

**Location**: `results/`

**Purpose**: Per-simulator benchmark output. Each row represents one simulation run. Existing files are preserved as `*.preserved-YYYYmmdd-HHMMSS.csv` before overwrite.

### 4.3. Test Fixtures

**Type**: Filesystem (CSV, directories)

**Location**: `tests/fixtures/`

**Purpose**: Small curated inputs and expected outputs for plotting, summary, and path-handling validation.

## 5. External Integrations / APIs

| Service | Purpose | Integration |
|---|---|---|
| kind | Local Kubernetes clusters | CLI (`kind create/delete cluster`) |
| kwokctl | KWOK cluster management | CLI (`kwokctl create/delete cluster`) |
| kubectl | Kubernetes API interaction | CLI (apply, get, delete) |
| Docker | Container runtime and Docker-in-Docker | CLI + socket mount |
| cgexec / cgcreate / cgdelete | Linux cgroup management | CLI (opensim only) |
| skctl | SimKube control plane | CLI (`cargo install skctl`) |
| Prometheus | Metrics collection (SimKube) | Deployed via kube-prometheus manifests |
| Alibaba Cluster Traces | Source workload data | Git clone + `prepare_input.sh` |

## 6. Deployment and Infrastructure

**Container Platform**: Docker (Docker-in-Docker for simulator isolation)

**Image**: `thesmuks/k8s-sims:latest` — multi-stage Alpine build with Go, Rust, Python toolchains

**Privilege Level**: `privileged: true`, `cgroup: host` — required for kind, KWOK, and cgroup access

**CI/CD**: GitHub (branch-based feature workflow, Spec Kit managed)

**Validation**: `utils/validate-checkpoint.sh all` — local, no CI pipeline configured

## 7. Security Considerations

**Authentication**: None (local tooling, no user-facing auth)

**Privileged Execution**: Container runs as privileged with host cgroup and Docker socket access. See `SECURITY.md` for isolation guidance.

**Data Encryption**: Not applicable (local benchmark data, no network transmission of results)

**Key Practices**:
- `.env*`, kubeconfigs, keys, and certificates are gitignored
- Runtime downloads from upstream repos are documented in `SIM_MODULES.md`
- Non-privileged validation path available for environments without Docker/cgroups

## 8. Development and Testing Environment

**Local Setup**: See `README.md` for dependency installation. Docker Compose provides the full environment. Alternatively, install Go, Rust, Python 3.12, and simulator tools natively.

**Testing Frameworks**:
- Bash: bats-core 1.11.0 (auto-bootstrapped into `tests/bash/.bats/`)
- Python: `python -m py_compile` for import/syntax checking; no formal pytest suite yet

**Test Runner**: `bash tests/bash/run.sh` (default), `bash tests/bash/run.sh --with-mocks` (forced execution via shims)

**Full Validation**: `bash utils/validate-checkpoint.sh all`

**Code Quality**: `bash -n` syntax checking, shellcheck (when available), Python compile checks

**Conventional Commits**: Mandatory. See constitution at `.specify/memory/constitution.md`.

## 9. Future Considerations / Roadmap

- Add Python pytest suite for `kube-gen.py`, `kube-plot.py`, `min-max-avg.py`
- CI pipeline (GitHub Actions) running the bats suite on PRs
- ShellCheck integration as a hard gate (currently best-effort)
- Explore rootless or less-privileged simulator execution modes
- Version-pin all runtime dependencies (currently some are intentionally variable)

## 10. Project Identification

**Project Name**: k8s-sims

**Repository URL**: https://github.com/TheSmuks/k8s-sims

**Primary Contact**: TheSmuks

**Date of Last Update**: 2026-06-09

## 11. Glossary / Acronyms

| Term | Definition |
|---|---|
| KWOK | Kubernetes WithOut Kubelet — lightweight pod simulator |
| kind | Kubernetes IN Docker — local cluster tool |
| SimKube | Trace-based Kubernetes simulator |
| Kubemark | Kubernetes hollow-node benchmarking tool |
| OpenSim | OpenSimulator (Alibaba) for cgroup-based scheduling simulation |
| bats | Bash Automated Testing System |
| TAP | Test Anything Protocol |
| CRLF | Carriage Return + Line Feed (Windows line endings) |
| Spec Kit | Specification-driven development workflow tooling |
