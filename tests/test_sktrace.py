"""Tests for SimKube v2 .sktrace generation (User Story 1).

Tests cover:
- T011: Correct top-level keys (version, config, events, index, pod_lifecycles)
- T012: Version field is 2
- T013: Config has trackedObjects (camelCase) with v1.Pod
- T014: Events[0] has ts, applied_objs, deleted_objs (snake_case)
- T015: pod_lifecycles is empty dict
- T016: msgpack roundtrip (pack then unpack produces same structure)
- T017: Index has correct GVK key format and namespace/name entries
"""

import os
import sys
import tempfile

import msgpack
import pytest

# Add utils/ to path so we can import modules directly
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "utils"))

from binpack import (
    NodeSpec,
    PodSpec,
    PlacementResult,
    place,
    parse_node,
    parse_pod,
)
from sktrace import build_trace, write_sktrace, compute_spec_hash


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


def _make_node(name: str, cpu: int = 4000, mem: int = 8192, labels: dict | None = None) -> NodeSpec:
    return NodeSpec(
        name=name,
        cpu_capacity=cpu,
        memory_capacity=mem,
        labels=labels or {},
        raw_manifest={"metadata": {"name": name}, "spec": {}, "status": {"capacity": {"cpu": f"{cpu}m", "memory": f"{mem}Mi"}}},
    )


def _make_pod(name: str, ns: str = "default", cpu: int = 1000, mem: int = 2048) -> PodSpec:
    return PodSpec(
        name=name,
        namespace=ns,
        cpu_request=cpu,
        memory_request=mem,
        raw_manifest={
            "metadata": {"name": name, "namespace": ns},
            "spec": {"containers": [{"name": "app", "resources": {"requests": {"cpu": f"{cpu}m", "memory": f"{mem}Mi"}}}]},
        },
    )


@pytest.fixture
def simple_placement() -> PlacementResult:
    """5 nodes, 5 pods -> all placed."""
    nodes = [_make_node(f"node-{i}") for i in range(5)]
    pods = [_make_pod(f"pod-{i}", ns="testns") for i in range(5)]
    return place(nodes, pods)


@pytest.fixture
def sample_trace(simple_placement) -> dict:
    config = {"trackedObjects": {"v1.Pod": {}}}
    return build_trace(simple_placement, config, timestamp=1700000000)


# ---------------------------------------------------------------------------
# T011: Correct top-level keys
# ---------------------------------------------------------------------------


class TestTopLevelKeys:
    def test_trace_has_required_keys(self, sample_trace):
        expected = {"version", "config", "events", "index", "pod_lifecycles"}
        assert set(sample_trace.keys()) == expected

    def test_trace_has_exactly_five_keys(self, sample_trace):
        assert len(sample_trace) == 5


# ---------------------------------------------------------------------------
# T012: Version field is 2
# ---------------------------------------------------------------------------


class TestVersion:
    def test_version_is_2(self, sample_trace):
        assert sample_trace["version"] == 2

    def test_version_is_int(self, sample_trace):
        assert isinstance(sample_trace["version"], int)


# ---------------------------------------------------------------------------
# T013: Config has trackedObjects (camelCase) with v1.Pod
# ---------------------------------------------------------------------------


class TestConfig:
    def test_config_has_tracked_objects_camel_case(self, sample_trace):
        assert "trackedObjects" in sample_trace["config"]

    def test_config_tracks_v1_pod(self, sample_trace):
        assert "v1.Pod" in sample_trace["config"]["trackedObjects"]

    def test_tracked_objects_key_is_camel_case(self, sample_trace):
        # Ensure it's NOT snake_case
        assert "tracked_objects" not in sample_trace["config"]


# ---------------------------------------------------------------------------
# T014: Events[0] has ts, applied_objs, deleted_objs (snake_case)
# ---------------------------------------------------------------------------


class TestEvent:
    def test_event_has_ts(self, sample_trace):
        events = sample_trace["events"]
        assert len(events) > 0
        assert "ts" in events[0]

    def test_event_has_applied_objs(self, sample_trace):
        assert "applied_objs" in sample_trace["events"][0]

    def test_event_has_deleted_objs(self, sample_trace):
        assert "deleted_objs" in sample_trace["events"][0]

    def test_deleted_objs_is_empty_for_snapshot(self, sample_trace):
        assert sample_trace["events"][0]["deleted_objs"] == []

    def test_ts_is_int(self, sample_trace):
        assert isinstance(sample_trace["events"][0]["ts"], int)

    def test_applied_objs_is_list(self, sample_trace):
        assert isinstance(sample_trace["events"][0]["applied_objs"], list)


# ---------------------------------------------------------------------------
# T015: pod_lifecycles is empty dict
# ---------------------------------------------------------------------------


class TestPodLifecycles:
    def test_pod_lifecycles_is_empty_dict(self, sample_trace):
        assert sample_trace["pod_lifecycles"] == {}

    def test_pod_lifecycles_is_dict(self, sample_trace):
        assert isinstance(sample_trace["pod_lifecycles"], dict)


# ---------------------------------------------------------------------------
# T016: msgpack roundtrip
# ---------------------------------------------------------------------------


class TestMsgpackRoundtrip:
    def test_roundtrip_preserves_structure(self, sample_trace):
        packed = msgpack.packb(sample_trace, use_bin_type=True)
        unpacked = msgpack.unpackb(packed, raw=False, strict_map_key=False)
        # Keys come back as strings with raw=False
        assert set(unpacked.keys()) == {"version", "config", "events", "index", "pod_lifecycles"}
        assert unpacked["version"] == 2
        assert unpacked["pod_lifecycles"] == {}

    def test_roundtrip_file_write_read(self, sample_trace):
        with tempfile.NamedTemporaryFile(suffix=".sktrace", delete=False) as f:
            path = f.name
        try:
            write_sktrace(sample_trace, path)
            with open(path, "rb") as f:
                unpacked = msgpack.unpackb(f.read(), raw=False, strict_map_key=False)
            assert unpacked["version"] == 2
            assert "events" in unpacked
        finally:
            os.unlink(path)


# ---------------------------------------------------------------------------
# T017: Index has correct GVK key format
# ---------------------------------------------------------------------------


class TestIndex:
    def test_index_has_gvk_key(self, sample_trace):
        index = sample_trace["index"]
        assert "v1.Pod" in index

    def test_index_has_namespace_name_entries(self, sample_trace):
        index = sample_trace["index"]
        pod_index = index["v1.Pod"]
        # Our fixture pods are in "testns" namespace
        assert "testns/pod-0" in pod_index
        assert "testns/pod-4" in pod_index

    def test_index_values_are_int_hashes(self, sample_trace):
        index = sample_trace["index"]
        for gvk, entries in index.items():
            for name, hash_val in entries.items():
                assert isinstance(hash_val, int), f"Hash for {gvk}/{name} should be int, got {type(hash_val)}"

    def test_index_covers_all_placed_pods(self, sample_trace, simple_placement):
        index = sample_trace["index"]
        pod_index = index["v1.Pod"]
        for pod, node in simple_placement.assignments:
            key = f"{pod.namespace}/{pod.name}"
            assert key in pod_index, f"Missing index entry for {key}"
