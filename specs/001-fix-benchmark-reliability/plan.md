# Implementation Plan: Benchmark Reliability Stabilization

**Branch**: `001-fix-benchmark-reliability` | **Date**: 2026-06-09 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-fix-benchmark-reliability/spec.md`

## Summary

Stabilize the Kubernetes simulator benchmarking toolkit by first preserving the pre-implementation state as the `sarteco-2026` release, then fixing broken result plotting, hardening run orchestration, documenting privileged/reproducibility risks, clarifying simulator/data policies, and adding validation paths that make each improvement independently verifiable and committable. The implementation will be split into review checkpoints so each part can be tested and committed before the next part begins.

## Technical Context

**Language/Version**: Bash shell scripts; Python 3.11-compatible utility scripts; Dockerfile and Compose configuration for containerized execution

**Primary Dependencies**: Python data stack listed in `requirements.txt`; Kubernetes/kind/KWOK/Kubemark/SimKube/OpenSimulator tooling; Docker-in-Docker runtime for full simulator execution

**Storage**: File-based inputs and outputs: YAML/trace experiment datasets, pipe-delimited CSV result files, generated PNG plots, JSON summaries, Markdown policy and design documents

**Testing**: Bash syntax checks, Python bytecode compilation, Python utility smoke tests with fixture data, path-with-spaces smoke tests, documentation/policy checks, and best-effort simulator dry runs where local Docker/Kubernetes tooling is available

**Target Platform**: Linux-like shell environment, including Git-Bash on Windows for development and Linux container runtime for full simulator execution

**Project Type**: CLI/script-based benchmark automation toolkit

**Performance Goals**: Plotting and summary commands complete on representative result fixtures in under 30 seconds; timeout and memory-limit runs stop within 10 seconds of the configured boundary when the environment permits; validation checkpoints remain fast enough for local maintainer use

**Constraints**: Full simulator verification may require privileged Docker, host cgroup access, and network access; local Windows/Git-Bash development may lack Docker Compose, python3 alias, or Linux cgroup behavior; implementation must avoid accidental secret exposure from local environment files

**Scale/Scope**: Covers existing benchmark scripts, Python utilities, container configuration, simulator modules, result preservation behavior, generated data policy, and documentation. Does not redesign benchmark methodology, scheduler scoring, or simulator internals.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Current constitution file is still the generated placeholder and contains no ratified project-specific principles. No enforceable constitution gates are available.

Pre-design gate result: PASS with note. Planning will apply practical quality gates derived from the feature specification:

- Reliability changes must include verification evidence or a recorded blocker.
- Risky runtime behavior must be documented for users.
- Each improvement group must be independently reviewable and committable.
- Full simulator tests may be replaced by syntax, fixture, dry-run, or documented-blocker validation when local prerequisites are unavailable.

Post-design gate result: PASS. The generated research, data model, contracts, and quickstart preserve these gates and include validation expectations for each improvement group.

## Project Structure

### Documentation (this feature)

```text
specs/001-fix-benchmark-reliability/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── cli-contracts.md
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
.
├── kube-director.sh              # multi-simulator experiment coordinator
├── kube-run.sh                   # per-simulator run orchestration and metrics
├── entrypoint.sh                 # container startup and pre-run path
├── docker-compose.yaml           # containerized execution configuration
├── Dockerfile                    # benchmark runtime image
├── SIM_MODULES                   # active simulator list
├── requirements.txt              # Python plotting/summary dependencies
├── modules/
│   ├── kube-sched/module.sh      # Kubernetes scheduler simulator adapter
│   ├── kubemark/module.sh        # Kubemark adapter
│   ├── kwok/module.sh            # KWOK adapter
│   ├── opensim/module.sh         # OpenSimulator adapter
│   ├── simkube/module.sh         # SimKube adapter
│   ├── vanilla/module.sh         # real kind/Kubernetes adapter candidate
│   └── template/module.sh        # adapter template
├── utils/
│   ├── kube-gen.py               # dataset generator and optional runner launcher
│   ├── kube-plot.py              # plotting workflow
│   ├── min-max-avg.py            # summary workflow
│   ├── simkube-tracer.sh         # SimKube trace generation
│   └── benchmark-gen.sh          # benchmark fixture generator
├── data/
│   ├── test/                     # smoke-test fixtures
│   ├── benchmark/                # benchmark fixtures
│   ├── small/                    # generated datasets
│   ├── medium/                   # generated datasets
│   └── big/                      # generated datasets
└── docs or SECURITY.md           # new/updated policy and safety documentation
```

**Structure Decision**: Keep the existing script-oriented repository layout. Add feature documentation under `specs/001-fix-benchmark-reliability/`, add one CLI contract document under `contracts/`, and implement source changes in the existing script, utility, module, container, and policy files listed above. Add tests or fixture validation helpers only where needed to verify the existing CLI workflows.

## Complexity Tracking

No constitution violations identified. The feature is broad, but complexity is justified by the spec's requirement to stabilize multiple independent failure areas in a benchmark toolkit. Work must be decomposed into checkpointed groups during task generation.
