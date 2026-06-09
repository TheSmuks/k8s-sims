# Implementation Plan: Overhaul SimKube Trace Generation

**Branch**: `003-trace-gen-overhaul` | **Date**: 2026-06-09 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-trace-gen-overhaul/spec.md`

## Summary

Replace the `simkube-tracer.sh` cluster-per-increment approach with direct `.sktrace` generation in Python. Extract bin-packing into a stateless module with taint/affinity filtering. Replace Python patch callbacks with kustomize overlays. Remove the old tracer and all references.

## Technical Context

**Language/Version**: Python 3.12+ (per constitution)

**Primary Dependencies**: PyYAML (existing), msgpack (new), kubectl (existing, for kustomize)

**Storage**: Filesystem only (YAML manifests, msgpack binary traces)

**Testing**: pytest for Python unit tests (bin-packing module, trace generator), bats for shell integration (if module.sh changes)

**Target Platform**: Windows/Git-Bash (MSYS2) and Linux

**Project Type**: CLI toolkit / shell+Python hybrid

**Performance Goals**: <5s for 1200 nodes (SC-001)

**Constraints**: No Docker/kind/kwokctl required for generation (SC-005), semantic equivalence with current output (FR-015)

**Scale/Scope**: Up to 1200 nodes, ~10000 pods per trace file

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status | Notes |
|------|--------|-------|
| Shell Safety | PASS | No shell script changes in this feature (tracer is removed, not modified) |
| Conventional Commits | PASS | All commits will use `feat(utils)`, `refactor(utils)`, etc. |
| Conventional Branches | PASS | Branch `003-trace-gen-overhaul` follows spec-kit numbering |
| Test-First for Shell | N/A | No shell changes |
| No Silent Overwrites | PASS | Trace files use new names (`.sktrace`), existing YAML output preserved |
| Privileged Execution | PASS | No Docker/kind required for generation |
| Platform compat | PASS | Python + kubectl subprocess works on both Linux and Git-Bash |

**Post-design re-check**: All gates still pass. No new shell scripts. Python module is pure computation + file I/O.

## Project Structure

### Documentation (this feature)

```
specs/003-trace-gen-overhaul/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```
utils/
├── kube-gen.py              # Refactored: remove globals, use binpack module + sktrace generator
├── binpack.py               # NEW: Stateless bin-packing module
├── sktrace.py               # NEW: SimKube v2 trace generator (msgpack writer)
├── simkube-tracer.sh        # DELETED (replaced by sktrace.py)
└── base/
    └── config.yml           # Updated: document why only v1.Pod tracked

overlays/                    # NEW: Kustomize overlay directories
├── simkube/
│   └── kustomization.yaml   # Inline patches with target selectors (Node, Pod)
├── kubemark/
│   └── kustomization.yaml   # Inline patches with target selectors (Node, Pod)
└── opensim/
    └── kustomization.yaml   # Placeholder (no patches)

tests/
├── test_binpack.py          # NEW: Bin-packing unit tests
├── test_sktrace.py          # NEW: Trace generator unit tests
└── fixtures/                # NEW: Test manifests (small node/pod sets)
    ├── nodes-small.yaml
    └── pods-small.yaml
```

**Structure Decision**: Extend existing `utils/` with new Python modules. Add `overlays/` at repo root as a new top-level directory for kustomize configs. Add `tests/` for Python unit tests (existing bats tests remain at `tests/bash/`).

## Implementation Tasks

### Task 1: Create `utils/binpack.py` -- Stateless Bin-Packing Module

**Scope**: Extract and refactor bin-packing from `kube-gen.py` into a standalone module.

- Define `NodeSpec`, `PodSpec`, `NodeAffinity`, `MatchExpression`, `PlacementResult`, `Rejection` dataclasses per data-model.md
- Implement `parse_node(raw_manifest: dict) -> NodeSpec` -- extracts name, cpu, memory, labels
- Implement `parse_pod(raw_manifest: dict) -> PodSpec` -- extracts name, namespace, cpu, memory, affinity, node_selector
- Implement `check_affinity(node: NodeSpec, pod: PodSpec) -> bool` -- checks nodeAffinity + nodeSelector against node labels
- Implement `check_resources(remaining_cpu: int, remaining_mem: int, pod: PodSpec) -> bool`
- Implement `place(nodes: list[NodeSpec], pods: list[PodSpec]) -> PlacementResult` -- first-fit greedy with filter chain (affinity + resources only)
- No global state; all functions are pure
- Taint/toleration filtering is NOT in the bin-packer (handled by kustomize overlays uniformly)

**Commit**: `feat(utils): add stateless bin-packing module`

### Task 2: Create `utils/sktrace.py` -- SimKube v2 Trace Generator

**Scope**: Generate valid `.sktrace` files in Python msgpack format.

- Define `SktraceFile`, `TracerConfig`, `TraceEvent`, `TraceIndex` data structures per data-model.md
- Implement `compute_spec_hash(spec: dict) -> int` -- deterministic hash of pod spec for index
- Implement `build_trace(placement: PlacementResult, config: dict, timestamp: int) -> dict` -- builds the full trace dict
- Implement `write_sktrace(trace: dict, path: str) -> None` -- msgpack serialization to file
- Implement `validate_sktrace(path: str) -> bool` -- optional validation via `skctl validate` subprocess, returns True if skctl available and trace passes, logs warning and returns True if skctl absent
- Format version pinned to 2, compatible with SimKube v2.3.0

**Commit**: `feat(utils): add SimKube v2 trace generator`

### Task 3: Create `tests/test_binpack.py` -- Bin-Packing Unit Tests

**Scope**: Test bin-packing constraint types from User Story 2 acceptance scenarios.

- Test first-fit placement: 5 nodes x (4 CPU, 8Gi) + 20 pods x (1 CPU, 2Gi) = 20 placed, 0 rejected
- Test affinity constraint: pod affinity targets label on only half the nodes = pods only on matching nodes, excess rejected "affinity_constraint"
- Test insufficient resources: more pod demand than capacity = rejected "insufficient_resources"
- Test zero-cost pods: pods with no resource requests always placed
- Test heterogeneous nodes: mixed capacities handled correctly
- Test nodeSelector: both nodeSelector and nodeAffinity must be satisfied

**Commit**: `test(utils): add bin-packing unit tests`

### Task 4: Create `tests/test_sktrace.py` -- Trace Generator Unit Tests

**Scope**: Test trace generation and validation.

- Test generated trace has correct top-level keys (version, config, events, index, pod_lifecycles)
- Test version field is 2
- Test config has `trackedObjects` (camelCase) with `v1.Pod`
- Test events[0] has ts, applied_objs, deleted_objs (snake_case)
- Test pod_lifecycles is empty dict
- Test index has correct GVK key format and namespace/name entries
- Test msgpack roundtrip: pack then unpack produces same structure
- Test validate_sktrace returns True when trace is structurally valid

**Commit**: `test(utils): add trace generator unit tests`

### Task 5: Create Kustomize Overlays

**Scope**: Replace Python patch callbacks with declarative overlays.

- Create `overlays/simkube/kustomization.yaml` with inline patches using `target.kind` selectors for Node and Pod
- Simkube Node patch: `kwok.x-k8s.io/node: fake` annotation + `openb-only` taint
- Simkube Pod patch: toleration for `openb-only`
- Create `overlays/kubemark/kustomization.yaml` with inline patches matching current `patch_hollow_node` / `patch_hollow_pod` behavior
- Create `overlays/opensim/kustomization.yaml` (placeholder)
- Verify with `kubectl kustomize` that output is semantically equivalent to current Python patch output

**Commit**: `feat(overlays): add kustomize overlays for simkube and kubemark`

### Task 6: Refactor `kube-gen.py` -- Integrate New Modules

**Scope**: Wire binpack.py, sktrace.py, and kustomize overlays into the generation pipeline.

- Remove all global mutable state (nodes, pods, total_node_resources, selected_nodes, selected_pods, etc.)
- Remove `patch_kwok_node`, `patch_kwok_pod`, `patch_hollow_node`, `patch_hollow_pod` functions
- Remove `run_simkube_tracer` function
- Add kustomize integration: `apply_overlay(manifests: list[dict], overlay_dir: str) -> list[dict]` calling `kubectl kustomize` via subprocess
- Refactor `generate_n_nodes` to use `binpack.place()` and return `PlacementResult`
- Add trace generation: after each increment, call `sktrace.write_sktrace()` to produce `trace-{N}.sktrace`
- Add overlay application: after bin-packing, apply kustomize overlay to node/pod manifests before writing YAML files
- Preserve CLI interface: same `-s`, `-k`, `-os`, `-t`, `-c`, `-i` flags
- `-t`/`--tracer` flag now generates `.sktrace` directly (no subprocess to simkube-tracer.sh)

**Commit**: `refactor(utils): integrate binpack module, sktrace generator, and kustomize overlays`

### Task 7: Remove `simkube-tracer.sh` and Update References

**Scope**: Delete the old tracer and clean up all references.

- Delete `utils/simkube-tracer.sh`
- Update `ARCHITECTURE.md`: remove tracer section, add sktrace.py and overlays documentation
- Update `README.md`: update SimKube usage instructions
- Update `modules/simkube/module.sh`: replace tracer invocation with trace generation via kube-gen.py
- Update `utils/base/config.yml`: expand tracked objects documentation
- Search for any other references to `simkube-tracer` or `run_simkube_tracer` and update

**Commit**: `refactor(utils): remove simkube-tracer.sh, update documentation`

### Task 8: Integration Testing and Performance Validation

**Scope**: End-to-end validation of the new pipeline.

- Run full generation with test fixtures: `python utils/kube-gen.py --simkube -c 100 -i 25 -o output/integration-test/`
- Verify all output files exist: nodes YAML, pods YAML, trace files
- Verify trace files are valid msgpack with correct schema
- Run performance benchmark: `time python utils/kube-gen.py --simkube -c 1200 -i 200 -o output/perf-test/`
- Verify <5s completion (SC-001)
- If skctl available, validate all traces pass `skctl validate` (SC-002)
- Run existing bats test suite to ensure no regressions: `bash tests/bash/run.sh`

**Commit**: `test(utils): add integration tests for trace generation pipeline`

## Complexity Tracking

No constitution violations to justify. All gates pass.
