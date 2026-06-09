"""Tests for bin-packing module (User Story 2).

Tests cover:
- T023: First-fit placement with sufficient capacity
- T024: Affinity constraint rejection
- T025: Insufficient resources rejection
- T026: Zero-cost pods always placed
- T027: Heterogeneous node capacities
- T028: nodeSelector + nodeAffinity both must be satisfied
"""

import os
import sys

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "utils"))

from binpack import (
    NodeSpec,
    PodSpec,
    NodeAffinity,
    NodeSelectorTerm,
    MatchExpression,
    place,
    check_affinity,
    check_resources,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _node(name: str, cpu: int = 4000, mem: int = 8192, labels: dict | None = None) -> NodeSpec:
    return NodeSpec(name=name, cpu_capacity=cpu, memory_capacity=mem, labels=labels or {})


def _pod(name: str, cpu: int = 1000, mem: int = 2048, **kwargs) -> PodSpec:
    return PodSpec(name=name, cpu_request=cpu, memory_request=mem, **kwargs)


def _affinity_pod(name: str, key: str, operator: str, values: list[str], **kw) -> PodSpec:
    return _pod(
        name,
        node_affinity=NodeAffinity(
            node_selector_terms=[
                NodeSelectorTerm(
                    match_expressions=[
                        MatchExpression(key=key, operator=operator, values=values)
                    ]
                )
            ]
        ),
        **kw,
    )


# ---------------------------------------------------------------------------
# T023: First-fit placement
# ---------------------------------------------------------------------------


class TestFirstFit:
    def test_basic_placement(self):
        """5 nodes (4000m CPU, 8192Mi mem) + 20 pods (1000m, 2048Mi) = all placed."""
        nodes = [_node(f"n{i}", cpu=4000, mem=8192) for i in range(5)]
        pods = [_pod(f"p{i}", cpu=1000, mem=2048) for i in range(20)]
        result = place(nodes, pods)
        assert len(result.assignments) == 20
        assert len(result.rejections) == 0

    def test_fills_nodes_sequentially(self):
        """First-fit should fill node-0 before moving to node-1."""
        nodes = [_node("n0", cpu=4000, mem=8192), _node("n1", cpu=4000, mem=8192)]
        pods = [_pod(f"p{i}", cpu=2000, mem=4096) for i in range(3)]
        result = place(nodes, pods)
        assert len(result.assignments) == 3
        # n0 gets 2 pods (4000m total), n1 gets 1 pod
        n0_count = sum(1 for p, n in result.assignments if n.name == "n0")
        n1_count = sum(1 for p, n in result.assignments if n.name == "n1")
        assert n0_count == 2
        assert n1_count == 1


# ---------------------------------------------------------------------------
# T024: Affinity constraint rejection
# ---------------------------------------------------------------------------


class TestAffinityConstraint:
    def test_affinity_targets_half_nodes(self):
        """Pod targets label on half the nodes; excess rejected with affinity_constraint."""
        nodes = [
            _node("n0", labels={"zone": "a"}),
            _node("n1", labels={"zone": "b"}),
            _node("n2", labels={"zone": "a"}),
            _node("n3", labels={"zone": "b"}),
        ]
        # Pods that require zone=a, each needing 2000m CPU / 4096Mi mem
        # n0 and n2 each have 4000m -> can fit 2 pods each = 4 total
        pods = [_affinity_pod(f"p{i}", "zone", "In", ["a"], cpu=2000, mem=4096) for i in range(6)]
        result = place(nodes, pods)
        placed = len(result.assignments)
        rejected = len(result.rejections)
        assert placed == 4  # 2 per zone=a node
        assert rejected == 2
        assert all(r.reason == "insufficient_resources" for r in result.rejections)

    def test_affinity_no_matching_nodes(self):
        """Pod targets label that no node has -> affinity_constraint."""
        nodes = [_node("n0"), _node("n1")]
        pods = [_affinity_pod("p0", "nonexistent", "In", ["yes"])]
        result = place(nodes, pods)
        assert len(result.assignments) == 0
        assert len(result.rejections) == 1
        assert result.rejections[0].reason == "affinity_constraint"


# ---------------------------------------------------------------------------
# T025: Insufficient resources rejection
# ---------------------------------------------------------------------------


class TestInsufficientResources:
    def test_more_demand_than_capacity(self):
        """More pod demand than total capacity -> rejected with insufficient_resources."""
        nodes = [_node("n0", cpu=4000, mem=8192)]
        pods = [_pod(f"p{i}", cpu=3000, mem=6000) for i in range(3)]
        result = place(nodes, pods)
        assert len(result.assignments) == 1
        assert len(result.rejections) == 2
        assert all(r.reason == "insufficient_resources" for r in result.rejections)

    def test_single_oversized_pod(self):
        """Pod that exceeds any single node capacity."""
        nodes = [_node("n0", cpu=4000, mem=8192)]
        pods = [_pod("big", cpu=5000, mem=10000)]
        result = place(nodes, pods)
        assert len(result.assignments) == 0
        assert len(result.rejections) == 1
        assert result.rejections[0].reason == "insufficient_resources"


# ---------------------------------------------------------------------------
# T026: Zero-cost pods always placed
# ---------------------------------------------------------------------------


class TestZeroCostPods:
    def test_no_resource_requests_always_placed(self):
        """Pods with no resource requests are always placed regardless of remaining capacity."""
        nodes = [_node("n0", cpu=100, mem=100)]  # Tiny capacity
        # Exhaust the capacity
        pods = [_pod("p0", cpu=100, mem=100)]
        # Add zero-cost pods
        pods += [_pod(f"zero-{i}", cpu=0, mem=0) for i in range(10)]
        result = place(nodes, pods)
        assert len(result.assignments) == 11  # 1 regular + 10 zero-cost
        assert len(result.rejections) == 0

    def test_zero_cost_pod_on_full_node(self):
        """Zero-cost pod fits on a node with zero remaining resources."""
        nodes = [_node("n0", cpu=1000, mem=1000)]
        pods = [_pod("full", cpu=1000, mem=1000), _pod("zero", cpu=0, mem=0)]
        result = place(nodes, pods)
        assert len(result.assignments) == 2
        assert len(result.rejections) == 0


# ---------------------------------------------------------------------------
# T027: Heterogeneous node capacities
# ---------------------------------------------------------------------------


class TestHeterogeneousNodes:
    def test_mixed_capacities(self):
        """Nodes with different capacities are handled correctly."""
        nodes = [
            _node("small", cpu=1000, mem=2048),
            _node("medium", cpu=4000, mem=8192),
            _node("large", cpu=8000, mem=16384),
        ]
        # Pods that need 3000m/6000Mi - only medium and large can host them
        pods = [_pod(f"p{i}", cpu=3000, mem=6000) for i in range(4)]
        result = place(nodes, pods)
        # small can't fit any, medium fits 1, large fits 2, remaining 1 rejected
        assert len(result.assignments) == 3
        assert len(result.rejections) == 1

    def test_node_remaining_tracks_correctly(self):
        """Remaining resources are tracked correctly per node."""
        nodes = [_node("n0", cpu=4000, mem=8192), _node("n1", cpu=2000, mem=4096)]
        pods = [_pod("p0", cpu=1000, mem=2048), _pod("p1", cpu=500, mem=1024)]
        result = place(nodes, pods)
        # First-fit: both pods go to n0 (1000+500 cpu, 2048+1024 mem)
        assert result.node_remaining["n0"] == (4000 - 1500, 8192 - 3072)
        assert result.node_remaining["n1"] == (2000, 4096)  # untouched


# ---------------------------------------------------------------------------
# T028: nodeSelector + nodeAffinity both must be satisfied
# ---------------------------------------------------------------------------


class TestNodeSelectorPlusAffinity:
    def test_both_must_match(self):
        """Pod with nodeSelector AND nodeAffinity: both must be satisfied."""
        nodes = [
            _node("n0", labels={"zone": "a", "tier": "frontend"}),
            _node("n1", labels={"zone": "a", "tier": "backend"}),
            _node("n2", labels={"zone": "b", "tier": "frontend"}),
        ]
        # Pod requires zone=a (selector) AND tier=frontend (affinity)
        pod = _pod(
            "p0",
            node_selector={"zone": "a"},
            node_affinity=NodeAffinity(
                node_selector_terms=[
                    NodeSelectorTerm(
                        match_expressions=[MatchExpression(key="tier", operator="In", values=["frontend"])]
                    )
                ]
            ),
        )
        result = place(nodes, [pod])
        assert len(result.assignments) == 1
        assert result.assignments[0][1].name == "n0"  # Only n0 matches both

    def test_selector_match_affinity_miss(self):
        """Pod matches nodeSelector but not nodeAffinity -> not placed on that node."""
        nodes = [
            _node("n0", labels={"zone": "a", "tier": "backend"}),
            _node("n1", labels={"zone": "b", "tier": "frontend"}),
        ]
        pod = _pod(
            "p0",
            node_selector={"zone": "a"},
            node_affinity=NodeAffinity(
                node_selector_terms=[
                    NodeSelectorTerm(
                        match_expressions=[MatchExpression(key="tier", operator="In", values=["frontend"])]
                    )
                ]
            ),
        )
        result = place(nodes, [pod])
        assert len(result.assignments) == 0
        assert len(result.rejections) == 1

    def test_affinity_match_selector_miss(self):
        """Pod matches nodeAffinity but not nodeSelector -> not placed on that node."""
        nodes = [
            _node("n0", labels={"zone": "b", "tier": "frontend"}),
            _node("n1", labels={"zone": "a", "tier": "backend"}),
        ]
        pod = _pod(
            "p0",
            node_selector={"zone": "a"},
            node_affinity=NodeAffinity(
                node_selector_terms=[
                    NodeSelectorTerm(
                        match_expressions=[MatchExpression(key="tier", operator="In", values=["frontend"])]
                    )
                ]
            ),
        )
        result = place(nodes, [pod])
        assert len(result.assignments) == 0
        assert len(result.rejections) == 1
