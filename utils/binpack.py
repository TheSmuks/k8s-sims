"""Stateless bin-packing module for Kubernetes node/pod placement.

Provides pure functions for parsing Kubernetes manifests and performing
first-fit greedy bin-packing with affinity and resource constraint checks.
No global state; all functions are pure.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Optional


# ---------------------------------------------------------------------------
# Data structures (T004)
# ---------------------------------------------------------------------------


@dataclass
class MatchExpression:
    """A single match expression from a nodeSelectorTerm."""

    key: str
    operator: str  # In, NotIn, Exists, DoesNotExist, Gt, Lt
    values: list[str] = field(default_factory=list)


@dataclass
class NodeSelectorTerm:
    """A node selector term with match expressions and match labels."""

    match_expressions: list[MatchExpression] = field(default_factory=list)
    match_labels: dict[str, str] = field(default_factory=dict)


@dataclass
class NodeAffinity:
    """Represents requiredDuringSchedulingIgnoredDuringExecution."""

    node_selector_terms: list[NodeSelectorTerm] = field(default_factory=list)


@dataclass
class Taint:
    """A Kubernetes node taint."""

    key: str
    value: str = ""
    effect: str = "NoSchedule"


@dataclass
class Toleration:
    """A Kubernetes pod toleration."""

    key: str = ""
    value: str = ""
    effect: str = ""
    operator: str = "Equal"


@dataclass
class NodeSpec:
    """Represents a Kubernetes node with capacity and labels for bin-packing."""

    name: str
    cpu_capacity: int
    memory_capacity: int
    labels: dict[str, str] = field(default_factory=dict)
    taints: list[Taint] = field(default_factory=list)
    raw_manifest: dict[str, Any] = field(default_factory=dict)


@dataclass
class PodSpec:
    """Represents a Kubernetes pod with resource requests and scheduling constraints."""

    name: str
    namespace: str = "default"
    cpu_request: int = 0
    memory_request: int = 0
    tolerations: list[Toleration] = field(default_factory=list)
    node_affinity: Optional[NodeAffinity] = None
    node_selector: dict[str, str] = field(default_factory=dict)
    raw_manifest: dict[str, Any] = field(default_factory=dict)


@dataclass
class Rejection:
    """A pod that could not be placed, with reason."""

    pod: PodSpec
    reason: str  # "insufficient_resources", "affinity_constraint"
    details: str = ""


@dataclass
class PlacementResult:
    """Output of the bin-packing operation."""

    assignments: list[tuple[PodSpec, NodeSpec]] = field(default_factory=list)
    rejections: list[Rejection] = field(default_factory=list)
    node_remaining: dict[str, tuple[int, int]] = field(default_factory=dict)


# ---------------------------------------------------------------------------
# Resource parsing helpers (T007)
# ---------------------------------------------------------------------------


def parse_cpu(cpu_str: str | int) -> int:
    """Parse a Kubernetes CPU resource string to integer millicores.

    Handles:
      - "64000m" -> 64000
      - "4"      -> 4000
      - int 4    -> 4000
    """
    if isinstance(cpu_str, int):
        return cpu_str * 1000
    s = str(cpu_str).strip()
    if s.endswith("m"):
        return int(s[:-1])
    # Bare integer means whole cores, convert to millicores
    return int(s) * 1000


def parse_memory(mem_str: str | int) -> int:
    """Parse a Kubernetes memory resource string to integer MiB.

    Handles:
      - "262144Mi" -> 262144
      - "8Gi"      -> 8192
      - int 8192   -> 8192
    """
    if isinstance(mem_str, int):
        return mem_str
    s = str(mem_str).strip()
    if s.endswith("Mi"):
        return int(s[:-2])
    if s.endswith("Gi"):
        return int(s[:-2]) * 1024
    if s.endswith("Ki"):
        return int(s[:-2]) // 1024
    return int(s)


# ---------------------------------------------------------------------------
# Manifest parsers (T005, T006)
# ---------------------------------------------------------------------------


def parse_node(raw_manifest: dict[str, Any]) -> NodeSpec:
    """Parse a raw Kubernetes node manifest into a NodeSpec."""
    meta = raw_manifest.get("metadata", {})
    status = raw_manifest.get("status", {})
    spec = raw_manifest.get("spec", {})

    cpu_raw = status.get("capacity", {}).get("cpu", "0")
    mem_raw = status.get("capacity", {}).get("memory", "0Mi")
    labels = dict(meta.get("labels", {}))

    taints = []
    for t in spec.get("taints", []):
        taints.append(
            Taint(
                key=t.get("key", ""),
                value=t.get("value", ""),
                effect=t.get("effect", "NoSchedule"),
            )
        )

    return NodeSpec(
        name=meta.get("name", ""),
        cpu_capacity=parse_cpu(cpu_raw),
        memory_capacity=parse_memory(mem_raw),
        labels=labels,
        taints=taints,
        raw_manifest=raw_manifest,
    )


def parse_pod(raw_manifest: dict[str, Any]) -> PodSpec:
    """Parse a raw Kubernetes pod manifest into a PodSpec."""
    meta = raw_manifest.get("metadata", {})
    spec = raw_manifest.get("spec", {})

    # Extract resource requests from first container
    containers = spec.get("containers", [])
    if containers:
        resources = containers[0].get("resources", {})
        requests = resources.get("requests", {})
        cpu_raw = requests.get("cpu", "0")
        mem_raw = requests.get("memory", "0Mi")
    else:
        cpu_raw = "0"
        mem_raw = "0Mi"

    # Parse tolerations
    tolerations = []
    for t in spec.get("tolerations", []):
        tolerations.append(
            Toleration(
                key=t.get("key", ""),
                value=t.get("value", ""),
                effect=t.get("effect", ""),
                operator=t.get("operator", "Equal"),
            )
        )

    # Parse node affinity
    node_affinity = None
    affinity = spec.get("affinity", {})
    if affinity:
        na = affinity.get("nodeAffinity", {})
        required = na.get("requiredDuringSchedulingIgnoredDuringExecution", {})
        terms_raw = required.get("nodeSelectorTerms", [])
        if terms_raw:
            terms = []
            for term in terms_raw:
                match_exprs = []
                for expr in term.get("matchExpressions", []):
                    match_exprs.append(
                        MatchExpression(
                            key=expr.get("key", ""),
                            operator=expr.get("operator", "In"),
                            values=expr.get("values", []),
                        )
                    )
                terms.append(
                    NodeSelectorTerm(
                        match_expressions=match_exprs,
                        match_labels=dict(term.get("matchLabels", {})),
                    )
                )
            node_affinity = NodeAffinity(node_selector_terms=terms)

    node_selector = dict(spec.get("nodeSelector", {}))

    return PodSpec(
        name=meta.get("name", ""),
        namespace=meta.get("namespace", "default"),
        cpu_request=parse_cpu(cpu_raw),
        memory_request=parse_memory(mem_raw),
        tolerations=tolerations,
        node_affinity=node_affinity,
        node_selector=node_selector,
        raw_manifest=raw_manifest,
    )


# ---------------------------------------------------------------------------
# Constraint checks (T008, T009)
# ---------------------------------------------------------------------------


def _match_expression_satisfied(expr: MatchExpression, labels: dict[str, str]) -> bool:
    """Check if a single MatchExpression is satisfied by node labels."""
    val = labels.get(expr.key)
    op = expr.operator

    if op == "In":
        return val is not None and val in expr.values
    elif op == "NotIn":
        return val is None or val not in expr.values
    elif op == "Exists":
        return val is not None
    elif op == "DoesNotExist":
        return val is None
    elif op in ("Gt", "Lt"):
        if val is None:
            return False
        try:
            label_int = int(val)
            for v in expr.values:
                cmp_int = int(v)
                if op == "Gt" and label_int > cmp_int:
                    return True
                if op == "Lt" and label_int < cmp_int:
                    return True
            return False
        except (ValueError, TypeError):
            return False
    return False


def check_affinity(node: NodeSpec, pod: PodSpec) -> bool:
    """Check if pod's affinity constraints are satisfied by the node.

    Checks both nodeAffinity (requiredDuringSchedulingIgnoredDuringExecution)
    and nodeSelector against node labels.
    """
    # Check nodeSelector: all key=value pairs must match
    if pod.node_selector:
        for key, value in pod.node_selector.items():
            if node.labels.get(key) != value:
                return False

    # Check nodeAffinity
    if pod.node_affinity is None:
        return True

    # At least one term must be fully satisfied (OR of terms)
    for term in pod.node_affinity.node_selector_terms:
        term_satisfied = True

        # Check matchLabels (all must match)
        for key, value in term.match_labels.items():
            if node.labels.get(key) != value:
                term_satisfied = False
                break

        if not term_satisfied:
            continue

        # Check matchExpressions (all must be satisfied)
        for expr in term.match_expressions:
            if not _match_expression_satisfied(expr, node.labels):
                term_satisfied = False
                break

        if term_satisfied:
            return True

    # No term was satisfied
    return False if pod.node_affinity.node_selector_terms else True


def check_resources(remaining_cpu: int, remaining_mem: int, pod: PodSpec) -> bool:
    """Check if node has sufficient remaining resources for the pod."""
    return (remaining_cpu - pod.cpu_request) >= 0 and (remaining_mem - pod.memory_request) >= 0


# ---------------------------------------------------------------------------
# Placement engine (T010)
# ---------------------------------------------------------------------------


def place(nodes: list[NodeSpec], pods: list[PodSpec]) -> PlacementResult:
    """First-fit greedy bin-packing with filter chain.

    For each pod, iterate nodes and apply:
      1. Affinity check -> reject with "affinity_constraint"
      2. Resource check -> reject with "insufficient_resources"
    Assign to first passing node, decrement remaining capacity.
    """
    assignments: list[tuple[PodSpec, NodeSpec]] = []
    rejections: list[Rejection] = []

    # Track remaining resources per node
    remaining: dict[str, tuple[int, int]] = {
        n.name: (n.cpu_capacity, n.memory_capacity) for n in nodes
    }

    for pod in pods:
        placed = False
        for node in nodes:
            # Filter chain: affinity first, then resources
            if not check_affinity(node, pod):
                continue
            rem_cpu, rem_mem = remaining[node.name]
            if not check_resources(rem_cpu, rem_mem, pod):
                continue

            # Place pod on this node
            assignments.append((pod, node))
            remaining[node.name] = (
                rem_cpu - pod.cpu_request,
                rem_mem - pod.memory_request,
            )
            placed = True
            break

        if not placed:
            # Determine rejection reason by checking what failed
            affinity_passable = any(check_affinity(n, pod) for n in nodes)
            if not affinity_passable:
                rejections.append(
                    Rejection(
                        pod=pod,
                        reason="affinity_constraint",
                        details=f"No node satisfies affinity/selector for pod {pod.name}",
                    )
                )
            else:
                rejections.append(
                    Rejection(
                        pod=pod,
                        reason="insufficient_resources",
                        details=f"No node with sufficient resources for pod {pod.name}",
                    )
                )

    return PlacementResult(
        assignments=assignments,
        rejections=rejections,
        node_remaining=remaining,
    )
