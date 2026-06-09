# Data Model: Overhaul SimKube Trace Generation

**Branch**: `003-trace-gen-overhaul` | **Date**: 2026-06-09

## Entities

### NodeSpec

Represents a Kubernetes node with capacity, taints, and labels for bin-packing.

| Field | Type | Source | Validation |
|-------|------|--------|------------|
| `name` | `str` | `metadata.name` | Required, non-empty |
| `cpu_capacity` | `int` | `status.capacity.cpu` | > 0, parsed from `m` suffix or bare integer |
| `memory_capacity` | `int` | `status.capacity.memory` | > 0, parsed from `Mi` suffix or bare integer |
| `labels` | `dict[str, str]` | `metadata.labels` | May be empty |
| `taints` | `list[Taint]` | `spec.taints` | May be empty |
| `raw_manifest` | `dict` | Full YAML object | Preserved for kustomize output |

### PodSpec

Represents a Kubernetes pod with resource requests, tolerations, and affinity.

| Field | Type | Source | Validation |
|-------|------|--------|------------|
| `name` | `str` | `metadata.name` | Required, non-empty |
| `namespace` | `str` | `metadata.namespace` | Default `"default"` |
| `cpu_request` | `int` | `spec.containers[0].resources.requests.cpu` | >= 0, defaults to 0 if missing |
| `memory_request` | `int` | `spec.containers[0].resources.requests.memory` | >= 0, defaults to 0 if missing |
| `tolerations` | `list[Toleration]` | `spec.tolerations` | May be empty |
| `node_affinity` | `NodeAffinity \| None` | `spec.affinity.nodeAffinity` | May be None |
| `node_selector` | `dict[str, str]` | `spec.nodeSelector` | May be empty |
| `raw_manifest` | `dict` | Full YAML object | Preserved for kustomize output |

### Taint

| Field | Type | Validation |
|-------|------|------------|
| `key` | `str` | Required |
| `value` | `str` | May be empty |
| `effect` | `str` | One of: `NoSchedule`, `PreferNoSchedule`, `NoExecute` |

### Toleration

| Field | Type | Validation |
|-------|------|------------|
| `key` | `str` | Required (or empty for catch-all) |
| `value` | `str` | May be empty |
| `effect` | `str` | One of: `NoSchedule`, `PreferNoSchedule`, `NoExecute`, or empty (matches all) |
| `operator` | `str` | One of: `Equal` (default), `Exists` |

### NodeAffinity

Represents `requiredDuringSchedulingIgnoredDuringExecution`.

| Field | Type | Validation |
|-------|------|------------|
| `node_selector_terms` | `list[NodeSelectorTerm]` | At least one term required |

### NodeSelectorTerm

| Field | Type | Validation |
|-------|------|------------|
| `match_expressions` | `list[MatchExpression]` | May be empty |
| `match_labels` | `dict[str, str]` | May be empty |

### MatchExpression

| Field | Type | Validation |
|-------|------|------------|
| `key` | `str` | Required |
| `operator` | `str` | One of: `In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt`, `Lt` |
| `values` | `list[str]` | Required for `In`, `NotIn`, `Gt`, `Lt` |

### PlacementResult

Output of the bin-packing operation.

| Field | Type | Description |
|-------|------|-------------|
| `assignments` | `list[tuple[PodSpec, NodeSpec]]` | Successfully placed pods with their assigned node |
| `rejections` | `list[Rejection]` | Pods that could not be placed, with reasons |
| `node_remaining` | `dict[str, tuple[int, int]]` | Per-node remaining (cpu, memory) after placement |

### Rejection

| Field | Type | Validation |
|-------|------|------------|
| `pod` | `PodSpec` | The rejected pod |
| `reason` | `str` | One of: `"insufficient_resources"`, `"taint_mismatch"`, `"affinity_constraint"` |
| `details` | `str` | Human-readable explanation |

### SktraceFile

Represents the SimKube v2 msgpack trace file structure.

| Field | Type | Msgpack Key | Description |
|-------|------|-------------|-------------|
| `version` | `int` | `"version"` | Always `2` |
| `config` | `TracerConfig` | `"config"` | Tracked objects configuration |
| `events` | `list[TraceEvent]` | `"events"` | Single snapshot event |
| `index` | `TraceIndex` | `"index"` | GVK -> name -> spec_hash |
| `pod_lifecycles` | `dict` | `"pod_lifecycles"` | Empty `{}` for static snapshots |

### TracerConfig

| Field | Type | Msgpack Key | Description |
|-------|------|-------------|-------------|
| `tracked_objects` | `dict[str, dict]` | `"trackedObjects"` | `{"v1.Pod": {}}` |

### TraceEvent

| Field | Type | Msgpack Key | Description |
|-------|------|-------------|-------------|
| `timestamp` | `int` | `"ts"` | Unix seconds (snapshot time) |
| `applied_objs` | `list[dict]` | `"applied_objs"` | All placed pod manifests (full YAML as dict) |
| `deleted_objs` | `list[dict]` | `"deleted_objs"` | Empty `[]` for snapshots |

### TraceIndex

| Field | Type | Msgpack Key | Description |
|-------|------|-------------|-------------|
| `entries` | `dict[str, dict[str, int]]` | Flattened | `{"v1.Pod": {"ns/name": hash}}` |

Note: `TraceIndex` uses `#[serde(flatten)]` in Rust, so GVK strings become top-level map keys in the msgpack map. There is no wrapping `"entries"` key.

## Relationships

```
NodeSpec 1---* PodSpec (via PlacementResult.assignments)
PodSpec *---0..1 Rejection (via PlacementResult.rejections)
PlacementResult ---> SktraceFile.events[0].applied_objs
NodeSpec.raw_manifest ---> kustomize overlay ---> patched manifest
PodSpec.raw_manifest ---> kustomize overlay ---> patched manifest
```

## State Transitions

### Bin-Packing Flow

```
[Load YAML] -> [Parse NodeSpec list] -> [Parse PodSpec list]
    -> [BinPacker.place(nodes, pods)] -> PlacementResult
        -> [SktraceGenerator.generate(PlacementResult)] -> .sktrace file
        -> [Write patched node/pod YAML files]
```

### Filter Chain (per pod, per candidate node)

```
1. Affinity check: pod.node_affinity vs node.labels -> REJECT "affinity_constraint"
2. NodeSelector check: pod.node_selector vs node.labels -> REJECT "affinity_constraint"
3. Resource check: pod.cpu/memory_request vs node remaining -> REJECT "insufficient_resources"
4. PASS -> assign pod to node, decrement remaining capacity
```

Note: Taint/toleration filtering is NOT in the bin-packer. Kustomize overlays apply taints and tolerations uniformly (every node gets the taint, every pod gets the matching toleration), so taints never block placement.

### Trace Generation Flow

```
[PlacementResult] -> [Build TracerConfig] -> [Build TraceEvent from assignments]
    -> [Build TraceIndex from assignments] -> [Empty pod_lifecycles]
    -> [msgpack.packb(SktraceFile)] -> write to .sktrace
```
