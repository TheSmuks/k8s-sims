# Feature Specification: Overhaul SimKube Trace Generation

**Feature Branch**: `003-trace-gen-overhaul`

**Created**: 2026-06-09

**Status**: Draft

**Input**: User description: "Overhaul the SimKube trace generation pipeline: modularize bin-packing with greedy approximation, generate .sktrace files directly in Python (eliminating simkube-tracer.sh cluster spin-up), add kustomize overlays for simulator-specific manifest patching, and integrate validation."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Direct .sktrace Generation (Priority: P1)

A researcher generates SimKube trace files from Alibaba cluster manifests without needing kwokctl, Docker, or any cluster runtime. Running `kube-gen.py --simkube` produces valid `.sktrace` files directly via Python msgpack serialization, with the same structure that `skctl snapshot` would produce but without spinning up ephemeral KWOK clusters.

**Why this priority**: This eliminates the entire `simkube-tracer.sh` overhead (cluster create/destroy per node-count increment) and removes the kwokctl hard dependency from dataset generation. It unblocks trace generation on machines without Docker/kind.

**Independent Test**: Can be fully tested by running `kube-gen.py --simkube -t` with test fixtures, then verifying the output `.sktrace` is valid msgpack with correct schema (version, config, events, index, pod_lifecycles) using `skctl validate`.

**Acceptance Scenarios**:

1. **Given** Alibaba node/pod manifests in `base/`, **When** user runs `kube-gen.py --simkube -t -o output/`, **Then** `output/trace-{N}.sktrace` files are generated for each node-count increment, each containing valid SimKube v2 trace format with a single timestamp event containing all placed pods.
2. **Given** a generated `.sktrace` file, **When** user runs `skctl validate` against it, **Then** no errors are reported.
3. **Given** a machine without kwokctl or Docker, **When** user runs `kube-gen.py --simkube -t -o output/`, **Then** trace files are generated successfully (no cluster tooling required).

---

### User Story 2 - Modular Bin-Packing (Priority: P2)

A researcher can select different greedy placement strategies when generating datasets. The bin-packing logic is extracted from `kube-gen.py` into a standalone, testable module that handles CPU/memory constraints, taints/tolerations, and node affinity as placement filters. Pods that cannot be placed are tracked and reported rather than silently dropped.

**Why this priority**: The current first-fit bin-pack is embedded in the generation loop with global mutable state. Extracting it enables testing, swapping strategies, and properly handling affinity constraints that real workloads carry.

**Independent Test**: Can be tested by importing the bin-packing module directly, feeding it known node/pod inventories, and asserting placement counts and rejection reasons.

**Acceptance Scenarios**:

1. **Given** 5 nodes (4 CPU, 8Gi each) and 20 pods (1 CPU, 2Gi each), **When** first-fit placement runs, **Then** 20 pods are placed (4 per node), 0 rejected.
2. **Given** pods with node affinity `requiredDuringSchedulingIgnoredDuringExecution` targeting a label that only half the nodes carry, **When** placement runs, **Then** pods are only placed on matching nodes, excess pods are rejected with reason "affinity constraint".
3. **Given** more pod CPU demand than node capacity, **When** placement runs, **Then** excess pods are rejected with reason "insufficient resources" and the count is reported.

---

### User Story 3 - Kustomize Overlays for Simulator Patches (Priority: P3)

A researcher can inspect and customize simulator-specific manifest transformations via kustomize overlay directories instead of embedded Python patch functions. The overlays live under `overlays/{simkube,kubemark,opensim}/` and are applied by `kube-gen.py` during generation, replacing the current `patch_kwok_node`, `patch_kwok_pod`, `patch_hollow_node`, `patch_hollow_pod` callback functions.

**Why this priority**: Declarative overlays are easier to audit, extend, and version than procedural Python patches. New simulators only need a new overlay directory. However, the Python patch functions currently work and this is an improvement in maintainability, not correctness.

**Independent Test**: Can be tested by running `kubectl kustomize overlays/simkube/` and verifying the output matches the expected patched manifests (KWOK annotations, taints, tolerations).

**Acceptance Scenarios**:

1. **Given** a base node manifest, **When** `kubectl kustomize overlays/simkube/` is applied, **Then** the output node has `kwok.x-k8s.io/node: fake` annotation and `openb-only` taint.
2. **Given** a base pod manifest, **When** `kubectl kustomize overlays/simkube/` is applied, **Then** the output pod has matching toleration for `openb-only`.
3. **Given** a base node manifest, **When** `kubectl kustomize overlays/kubemark/` is applied, **Then** the output is a hollow-node ConfigMap/manifest matching the current `patch_hollow_node` behavior.

---

### User Story 4 - Trace Validation Step (Priority: P4)

After generating `.sktrace` files, the pipeline automatically validates them using `skctl validate`. Invalid traces are reported with actionable errors rather than failing silently at simulation replay time.

**Why this priority**: Prevents downstream failures. Currently invalid traces are only discovered during `kube-run.sh -m simkube`, wasting experiment time.

**Independent Test**: Generate a trace with known defects and verify that validation catches them.

**Acceptance Scenarios**:

1. **Given** a freshly generated `.sktrace`, **When** the validation step runs, **Then** the trace passes with zero errors.
2. **Given** a corrupted or incomplete `.sktrace`, **When** validation runs, **Then** specific errors are reported with field-level detail.

---

### Edge Cases

- What happens when a pod manifest has no resource requests (CPU/memory zero or missing)? The bin-packer should treat it as zero-cost and always place it.
- What happens when nodes have heterogeneous capacities (mixed machine types from Alibaba traces)? The greedy algorithm must handle variable per-node limits.
- What happens when the `.sktrace` format version changes in a future SimKube release (currently v2)? The generator should pin the format version and document the SimKube compatibility range (currently v2.3.0).
- What happens when `skctl` is not available for the validation step? The step should be skipped with a warning, not block generation.
- What happens when a pod spec contains both nodeSelector and nodeAffinity? Both constraints must be satisfied simultaneously.
- What happens with overlapping increment boundaries (e.g., `--node_count 400 --increment 75`)? Remainder handling must not produce duplicate or missing node counts.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST generate `.sktrace` files in SimKube v2 msgpack format directly in Python, without requiring cluster tooling (kwokctl, kind, Docker).
- **FR-002**: The `.sktrace` files MUST conform to the SimKube trace schema: version (int), config (map), events (array of {ts, applied_objs, deleted_objs}), index (map of GVK to namespaced-name/hash), and pod_lifecycles (map).
- **FR-003**: The bin-packing logic MUST be extracted from `kube-gen.py` into a standalone, importable Python module with no global mutable state.
- **FR-004**: The bin-packing module MUST support greedy first-fit placement with CPU and memory constraints.
- **FR-005**: Taint/toleration handling is delegated to kustomize overlays (applied uniformly: every node gets the taint, every pod gets the matching toleration). The bin-packer does not need to filter on taints.
- **FR-006**: The bin-packing module MUST respect `requiredDuringSchedulingIgnoredDuringExecution` node affinity as a placement filter.
- **FR-007**: The bin-packing module MUST track and report pods that cannot be placed, with rejection reasons (insufficient resources, affinity constraint).
- **FR-008**: The system MUST support kustomize overlay directories for simulator-specific manifest patching, replacing the current Python callback patch functions.
- **FR-009**: The system MUST pin the SimKube trace format to version 2, compatible with SimKube v2.3.0.
- **FR-010**: The system MUST optionally validate generated `.sktrace` files using `skctl validate` when `skctl` is available.
- **FR-011**: The system MUST skip validation with a warning when `skctl` is not available, without blocking generation.
- **FR-012**: The `simkube-tracer.sh` script MUST be removed from the codebase in this feature cycle once the new Python `.sktrace` generator passes all tests. The removal must also update any references in `ARCHITECTURE.md`, `SIM_MODULES.md`, `README.md`, and `kube-gen.py` (`run_simkube_tracer` function).
- **FR-013**: The `utils/base/config.yml` tracked objects MUST be expanded to include `v1.Pod` and document why higher-level objects (Deployments, etc.) are not tracked in static snapshot mode.
- **FR-014**: Kustomize overlay application MUST use `kubectl kustomize` via subprocess (client-side only, no running cluster required). The `kubectl` binary must be on PATH.
- **FR-015**: The generation pipeline MUST produce semantically equivalent output files (node YAML, pod YAML, trace) as the current pipeline for the same inputs, ensuring backward compatibility. Exact byte-identity is not required; same parsed API objects is sufficient.

### Key Entities

- **BinPacker**: Stateless placement engine. Takes a list of nodes (with capacities, taints, labels) and a list of pods (with requests, tolerations, affinity), returns placement assignments and rejections.
- **SktraceGenerator**: Converts placement results into SimKube v2 msgpack trace files. Knows the schema: version, config, events, index, pod_lifecycles.
- **SimulatorOverlay**: Kustomize overlay directory that transforms base manifests into simulator-specific variants (KWOK patches, kubemark patches, opensim patches).
- **PlacementResult**: Output of bin-packing: list of (pod, node) assignments, list of rejected pods with reasons, per-node remaining capacity.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Trace generation completes in under 5 seconds for 1200 nodes without any cluster tooling (vs. current 2-6 minutes with cluster spin-up per increment).
- **SC-002**: 100% of generated `.sktrace` files pass `skctl validate` with zero errors.
- **SC-003**: Bin-packing module has unit test coverage for all constraint types (CPU, memory, taints, affinity) with deterministic assertions.
- **SC-004**: Generated manifests from kustomize overlays are semantically equivalent to the current Python patch function outputs (same parsed API objects after `yaml.safe_load_all`, formatting may differ).
- **SC-005**: A researcher can generate complete experiment datasets (nodes, pods, traces) on a machine with only Python 3.11+ and PyYAML, with no Docker/kind/kwokctl required.

## Clarifications

### Session 2026-06-09

- Q: How should kustomize overlays be applied -- subprocess or Python library? → A: Subprocess via `kubectl kustomize` (client-side, no cluster needed, reuses existing kubectl dependency).

- Q: Should kustomize overlay output be byte-identical or semantically equivalent to current Python patch functions? → A: Semantic equivalence -- same parsed API objects, allow formatting differences.

- Q: When should `simkube-tracer.sh` be removed? → A: Remove in this feature cycle once the new Python generator passes all tests.
- Q: Should the bin-packer filter on taints? → A: No. Taints/tolerations are applied uniformly by kustomize overlays (every node gets taint, every pod gets toleration). Bin-packer only needs resource + affinity checks.

## Assumptions

- The SimKube trace format version 2 is stable and unchanged between v2.3.0 and the current upstream release.
- The msgpack Python library (`msgpack` or `ormsgpack`) can produce output compatible with SimKube's Rust msgpack deserializer, including tuple map keys for pod_lifecycles.
- Static snapshot traces (single timestamp, all pods as applied_objs, empty deleted_objs) are sufficient for the benchmarking use case. Real temporal traces with event ordering remain out of scope for this feature.
- Kustomize is applied via `kubectl kustomize` subprocess (client-side, no cluster needed). On Windows/Git-Bash, kubectl is already a runtime dependency for experiment execution.
- The greedy first-fit algorithm provides sufficient placement fidelity for benchmarking purposes. Exact scheduler emulation (scoring, priorities, preemption) is explicitly out of scope.
- The Alibaba cluster trace format (node capacities, pod requests) does not change. The existing `base/nodes.yaml` and `base/pods.yaml` formats remain the input.
- `skctl` is available in the Docker container image (installed via `cargo install skctl`) but may not be available on the host. Validation must degrade gracefully.
