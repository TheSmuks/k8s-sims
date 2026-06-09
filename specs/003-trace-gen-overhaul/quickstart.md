# Quickstart: Overhaul SimKube Trace Generation

**Branch**: `003-trace-gen-overhaul` | **Date**: 2026-06-09

## Prerequisites

- Python 3.12+ with `msgpack`, `PyYAML` installed
- `kubectl` on PATH (for kustomize overlay application)
- (Optional) `skctl` on PATH for trace validation

## Validation Scenarios

### V1: Direct .sktrace Generation (no cluster tooling)

Generate traces from base manifests without Docker/kind/kwokctl:

```bash
cd /path/to/k8s-sims
python utils/kube-gen.py --simkube -c 100 -i 25 -o output/test-v1/
```

**Expected outcome**:
- `output/test-v1/nodes-25.yaml`, `nodes-50.yaml`, `nodes-75.yaml`, `nodes-100.yaml` generated
- `output/test-v1/pods-25.yaml`, `pods-50.yaml`, `pods-75.yaml`, `pods-100.yaml` generated
- `output/test-v1/trace-25.sktrace`, `trace-50.sktrace`, `trace-75.sktrace`, `trace-100.sktrace` generated
- No `kwokctl`, `docker`, or `kind` process spawned
- Trace files are valid msgpack: `python -c "import msgpack; print(msgpack.unpackb(open('output/test-v1/trace-100.sktrace','rb').read(), raw=False, strict_map_key=False).keys())"`

### V2: Bin-Packing with Taints and Affinity

Run the bin-packing unit tests:

```bash
python -m pytest tests/test_binpack.py -v
```

**Expected outcome**:
- All test cases pass: first-fit, taint mismatch rejection, affinity constraint rejection, insufficient resources rejection
- Zero-cost pods (no resource requests) are always placed
- Heterogeneous node capacities handled correctly

### V3: Kustomize Overlay Semantic Equivalence

Verify kustomize overlays produce semantically equivalent output to current Python patches:

```bash
# Generate with new kustomize-based flow
python utils/kube-gen.py --simkube -c 50 -o output/test-v3/

# Apply kustomize directly and compare
kubectl kustomize overlays/simkube/ > /tmp/kustomized.yaml
python -c "
import yaml
with open('output/test-v3/nodes-50.yaml') as f:
    new_nodes = list(yaml.safe_load_all(f))
# Check first node has KWOK annotation and taint
n = new_nodes[0]
assert n['metadata']['annotations']['kwok.x-k8s.io/node'] == 'fake'
assert any(t['key'] == 'openb-only' for t in n['spec']['taints'])
print('PASS: node has KWOK annotation and openb-only taint')
"
```

### V4: Trace Validation with skctl

If `skctl` is available:

```bash
python utils/kube-gen.py --simkube -c 100 -i 50 -o output/test-v4/
skctl validate output/test-v4/trace-50.sktrace
skctl validate output/test-v4/trace-100.sktrace
```

**Expected outcome**: Zero errors from `skctl validate` on all generated traces.

If `skctl` is not available, generation completes with a warning message but does not fail.

### V5: simkube-tracer.sh Removal Verification

Verify the old tracer is gone:

```bash
test -f utils/simkube-tracer.sh && echo "FAIL: tracer still exists" || echo "PASS: tracer removed"
grep -r "run_simkube_tracer" utils/kube-gen.py && echo "FAIL: function reference remains" || echo "PASS: no references"
```

## Performance Benchmark

```bash
time python utils/kube-gen.py --simkube -c 1200 -i 200 -o output/test-perf/
```

**Expected**: Completes in under 5 seconds (vs. current 2-6 minutes with cluster spin-up).
