# Research: Overhaul SimKube Trace Generation

**Branch**: `003-trace-gen-overhaul` | **Date**: 2026-06-09

## R1: SimKube v2.3.0 Trace Format (ExportedTrace)

**Decision**: Generate static snapshot traces in Python using `msgpack` library with all-string map keys.

**Rationale**: Source code analysis of SimKube v2.3.0 confirms the `ExportedTrace` struct:

```rust
// sk-store/src/lib.rs
const CURRENT_TRACE_FORMAT_VERSION: u16 = 2;

struct ExportedTrace {
    version: u16,                                           // always 2
    config: TracerConfig,                                   // tracked objects config
    events: Vec<TraceEvent>,                                // snapshot events
    index: TraceIndex,                                      // GVK -> {namespace/name: spec_hash}
    pod_lifecycles: HashMap<(GVK, String), PodLifecyclesMap> // owner -> lifecycle data
}
```

For **static snapshots** (our use case), `pod_lifecycles` is **empty** because:
- PodLifecyclesMap is keyed by `(owner_gvk, "namespace/owner_name")`
- Only pods whose *owners* are tracked with `track_lifecycle: true` get lifecycle entries
- Our config tracks only `v1.Pod` with no `track_lifecycle` flag
- Therefore no tuple map keys are needed -- the field is an empty `{}`

Field name casing verified:
- `TracerConfig` uses `#[serde(rename_all = "camelCase")]` -> `trackedObjects`
- `TraceEvent` uses no rename -> `ts`, `applied_objs`, `deleted_objs` (snake_case)
- `TraceIndex` uses `#[serde(flatten)]` -> GVK strings become top-level map keys

The snapshot command creates `start_ts = now()`, `end_ts = now() + 1`, with all existing objects as `applied_objs` in a single event.

**Alternatives considered**:
- Using `ormsgpack` (faster) -- rejected; `msgpack` is sufficient and already available
- Producing temporal traces with event ordering -- rejected; out of scope, static snapshots suffice for benchmarking

## R2: Python msgpack Compatibility

**Decision**: Use `msgpack` (msgpack-python) with `use_bin_type=True` for packing.

**Rationale**: Verified via live testing:
- Python `msgpack.packb()` produces valid msgpack binary that SimKube's Rust `rmp_serde` can deserialize
- String map keys, integer map keys (for index spec hashes), nested maps all serialize correctly
- `strict_map_key=False` needed only for *unpacking* (reading traces), not for writing
- Tuple map keys (not needed for our case) roundtrip as arrays, not compatible with Rust tuple deserialization -- but since `pod_lifecycles` is empty for static snapshots, this is moot

**Alternatives considered**:
- `ormsgpack` -- faster but adds a dependency; `msgpack` is sufficient for our scale (<5s for 1200 nodes)
- Raw `struct.pack()` -- too low-level, error-prone

## R3: Kustomize Integration Strategy

**Decision**: Use `kubectl kustomize <overlay_dir>` via subprocess.

**Rationale**: Per spec clarification Q1, `kubectl kustomize` is purely client-side (no cluster needed), reuses the existing `kubectl` dependency already required for experiment execution, and avoids adding a Python kustomize library.

The overlay directory structure will be:
```
overlays/
├── simkube/
│   └── kustomization.yaml   # Inline patches with target.kind selectors
├── kubemark/
│   └── kustomization.yaml   # Inline patches with target.kind selectors
└── opensim/
    └── kustomization.yaml   # Placeholder (no patches)
```

Each `kustomization.yaml` uses inline `patches` with `target.kind` selectors instead of separate patch files. This keeps overlays self-contained (single file per simulator) while remaining standard kustomize consumable by `kubectl kustomize`.

`kube-gen.py` calls `kubectl kustomize` with a temporary directory containing base resources + overlay patches. Falls back to Python-based strategic merge when kubectl is not on PATH.

**Alternatives considered**:
- Standalone `kustomize` binary -- extra install step, `kubectl` already has it built-in
- Python kustomize library -- lags behind upstream, less maintainable
- Keeping Python patch functions -- works but not declarative, harder to audit/extend

## R4: Bin-Packing Module Design

**Decision**: Stateless functional API with a `BinPacker` class that takes node/pod inventories and returns a `PlacementResult`.

**Rationale**: Current `generate_n_nodes()` mixes bin-packing with file I/O, global state mutation, and callback invocation. Extracting into a pure function with explicit inputs/outputs enables:
- Unit testing with deterministic fixtures
- Swapping placement strategies (first-fit, best-fit, worst-fit)
- No global mutable state

Filter chain for placement eligibility:
1. Taint/toleration check (node taints vs pod tolerations)
2. Node affinity check (pod `requiredDuringSchedulingIgnoredDuringExecution`)
3. Resource check (CPU + memory remaining on node)

Pods with missing resource requests default to zero-cost (always placeable).

**Alternatives considered**:
- Exact scheduling (scoring, priorities, preemption) -- rejected; greedy first-fit is sufficient for benchmarking
- Keeping bin-packing inline -- rejected; untestable, global state, can't swap strategies

## R5: simkube-tracer.sh Removal Scope

**Decision**: Remove in this feature cycle once tests pass, with documentation updates.

**Rationale**: Per spec clarification Q3, the tracer is fully replaced by the Python generator. References to update:
- `utils/simkube-tracer.sh` (delete)
- `utils/kube-gen.py` `run_simkube_tracer()` function (delete)
- `ARCHITECTURE.md` tracer references (update)
- `SIM_MODULES.md` tracer references (update, if exists)
- `README.md` tracer usage (update)
- `modules/simkube/module.sh` tracer invocation (update)

## R6: Spec Hash Computation

**Decision**: Use Python `hashlib.sha256` on JSON-serialized `spec` field, take first 8 bytes as u64.

**Rationale**: SimKube's `jsonutils::hash_option(obj.data.get("spec"))` computes a hash of the pod's spec field for the index. The Rust implementation uses `DefaultHasher` (SipHash 1-3) which produces a `u64`. However, since this hash is only used for pod lifecycle deduplication (which we don't need for static snapshots), the exact hash algorithm doesn't matter as long as it's deterministic. We'll use a stable hash for reproducibility.

For static snapshots, the index maps `namespace/name -> spec_hash` but the hash value is only consumed by the lifecycle tracking code. Since `pod_lifecycles` is empty, the hash values in the index are inert. We'll still compute them for structural correctness.

**Alternatives considered**:
- Skip index entirely -- risky; `skctl validate` may require it
- Match Rust's SipHash exactly -- unnecessary; hash values are not cross-compared with Rust output
