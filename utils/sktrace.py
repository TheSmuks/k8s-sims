"""SimKube v2 trace generator.

Generates valid .sktrace files in Python msgpack format without requiring
any cluster tooling. Produces static snapshot traces compatible with
SimKube v2.3.0.

Trace format (ExportedTrace):
  - version: 2
  - config: {trackedObjects: {"v1.Pod": {}}}
  - events: [{ts, applied_objs, deleted_objs}]
  - index: {GVK: {namespace/name: spec_hash}}
  - pod_lifecycles: {} (empty for static snapshots)
"""

from __future__ import annotations

import hashlib
import json
import logging
import os
import subprocess
from typing import Any

import msgpack

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Trace schema constants (T018)
# ---------------------------------------------------------------------------

TRACE_VERSION: int = 2

# Field name constants (matching SimKube Rust serde naming)
KEY_VERSION = "version"
KEY_CONFIG = "config"
KEY_EVENTS = "events"
KEY_INDEX = "index"
KEY_POD_LIFECYCLES = "pod_lifecycles"
KEY_TRACKED_OBJECTS = "trackedObjects"  # camelCase (serde rename_all)
KEY_TS = "ts"
KEY_APPLIED_OBJS = "applied_objs"  # snake_case (no rename)
KEY_DELETED_OBJS = "deleted_objs"  # snake_case (no rename)


# ---------------------------------------------------------------------------
# Spec hash computation (T019)
# ---------------------------------------------------------------------------


def compute_spec_hash(spec: dict) -> int:
    """Compute a deterministic hash of a pod spec for the trace index.

    Uses SHA-256 of JSON-serialized spec, takes first 8 bytes as u64.
    The hash value is only used for pod lifecycle deduplication (which
    we don't need for static snapshots), but is included for structural
    correctness.
    """
    spec_json = json.dumps(spec, sort_keys=True, separators=(",", ":"))
    digest = hashlib.sha256(spec_json.encode()).digest()
    return int.from_bytes(digest[:8], byteorder="big", signed=False)


# ---------------------------------------------------------------------------
# Trace builder (T020)
# ---------------------------------------------------------------------------


def build_trace(
    placement,  # PlacementResult from binpack
    config: dict[str, Any] | None = None,
    timestamp: int = 0,
) -> dict:
    """Build a full ExportedTrace dict from a PlacementResult.

    Args:
        placement: PlacementResult with assignments list.
        config: Optional config dict. Defaults to tracking v1.Pod only.
        timestamp: Unix timestamp for the snapshot event.

    Returns:
        dict matching SimKube v2 ExportedTrace structure.
    """
    if config is None:
        config = {KEY_TRACKED_OBJECTS: {"v1.Pod": {}}}

    # Build applied_objs: list of pod raw manifests
    applied_objs = []
    index_entries: dict[str, dict[str, int]] = {}

    for pod, node in placement.assignments:
        # applied_objs gets the full pod manifest
        applied_objs.append(pod.raw_manifest)

        # Build index: GVK -> namespace/name -> spec_hash
        gvk = "v1.Pod"
        key = f"{pod.namespace}/{pod.name}"

        if gvk not in index_entries:
            index_entries[gvk] = {}

        # Hash the spec field from raw manifest
        spec = pod.raw_manifest.get("spec", {})
        index_entries[gvk][key] = compute_spec_hash(spec)

    trace = {
        KEY_VERSION: TRACE_VERSION,
        KEY_CONFIG: config,
        KEY_EVENTS: [
            {
                KEY_TS: timestamp,
                KEY_APPLIED_OBJS: applied_objs,
                KEY_DELETED_OBJS: [],
            }
        ],
        KEY_INDEX: index_entries,
        KEY_POD_LIFECYCLES: {},
    }

    return trace


# ---------------------------------------------------------------------------
# Trace writer (T021)
# ---------------------------------------------------------------------------


def write_sktrace(trace: dict, path: str) -> None:
    """Write a trace dict to a .sktrace file using msgpack serialization.

    Args:
        trace: Trace dict from build_trace().
        path: Output file path.
    """
    packed = msgpack.packb(trace, use_bin_type=True)
    with open(path, "wb") as f:
        f.write(packed)


# ---------------------------------------------------------------------------
# Trace validation (T022)
# ---------------------------------------------------------------------------


def validate_sktrace(path: str) -> bool:
    """Validate a .sktrace file using skctl validate.

    If skctl is not found on PATH, logs a warning and returns True
    (graceful degradation per FR-011).

    Args:
        path: Path to the .sktrace file.

    Returns:
        True if validation passes or skctl is unavailable.
        False if validation fails.
    """
    try:
        result = subprocess.run(
            ["skctl", "validate", "check", path],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            logger.error("skctl validate failed for %s: %s", path, result.stderr)
            return False
        return True
    except FileNotFoundError:
        logger.warning("skctl not found on PATH; skipping validation for %s", path)
        return True
    except subprocess.TimeoutExpired:
        logger.error("skctl validate timed out for %s", path)
        return False


def validate_traces_in_dir(dir_path: str) -> bool:
    """Validate all .sktrace files in a directory.

    Args:
        dir_path: Directory containing .sktrace files.

    Returns:
        True if all validations pass (or skctl is absent).
    """
    all_valid = True
    sktrace_files = sorted(
        f for f in os.listdir(dir_path) if f.endswith(".sktrace")
    )
    if not sktrace_files:
        logger.info("No .sktrace files found in %s", dir_path)
        return True

    for fname in sktrace_files:
        fpath = os.path.join(dir_path, fname)
        if not validate_sktrace(fpath):
            all_valid = False

    return all_valid
