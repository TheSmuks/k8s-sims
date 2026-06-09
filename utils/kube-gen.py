"""Kubernetes resource generator for k8s-sims benchmarking toolkit.

Generates node and pod YAML manifests from Alibaba cluster trace data.
Supports SimKube (KWOK), Kubemark, and OpenSim simulators via kustomize
overlays and direct .sktrace trace generation.

Usage:
    python utils/kube-gen.py --simkube -c 100 -i 25 -o output/test/
"""

import os
import sys
import yaml
import copy
import argparse
import itertools
import time
import shutil
import subprocess
import shlex
import tempfile
import logging
from datetime import datetime
from typing import List, Dict, Tuple, Optional, Any

# Import new modules
script_dir = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, script_dir)

from binpack import (
    parse_node as bp_parse_node,
    parse_pod as bp_parse_pod,
    place as bp_place,
    NodeSpec,
    PodSpec,
    PlacementResult,
)
from sktrace import (
    build_trace,
    write_sktrace,
    validate_traces_in_dir,
)

logger = logging.getLogger(__name__)

# Root project directory (one level up from utils/)
ROOT_DIR = os.path.dirname(script_dir)


def create_folder(path: str) -> None:
    """Create a directory if it doesn't exist."""
    if not os.path.exists(path):
        os.makedirs(path, exist_ok=True)


def get_yaml_file(yaml_path: str, single: bool = True, limit: int = -1) -> Any:
    """Load YAML file(s) and return the parsed content."""
    try:
        with open(yaml_path) as yaml_file:
            if single:
                return yaml.safe_load(yaml_file)
            else:
                data = yaml.safe_load_all(yaml_file)
                res_list = [val for val in data if val is not None]
                limit = limit if 0 < limit < len(res_list) else len(res_list)
                return res_list[:limit]
    except Exception as e:
        print(f'\rError opening file: {yaml_path}')
        print(e)
        sys.exit(-1)


def print_msg(msg: str, cr: bool = False) -> None:
    """Print timestamped message with optional carriage return."""
    current_time = datetime.now().strftime("[%H:%M:%S]")
    cr_str = "\r" if cr else ""
    print(f"{cr_str}{current_time} - {msg}")


# ---------------------------------------------------------------------------
# Kustomize overlay integration (T041)
# ---------------------------------------------------------------------------


def apply_overlay(manifests: list[dict], overlay_dir: str) -> list[dict]:
    """Apply a kustomize overlay to a list of Kubernetes manifests.

    Tries `kubectl kustomize` first. If kubectl is not found, falls back
    to Python-based strategic merge patching using the overlay patch files.

    Args:
        manifests: List of Kubernetes manifest dicts (nodes or pods).
        overlay_dir: Path to the kustomize overlay directory containing patches.

    Returns:
        List of patched manifest dicts.
    """
    if not overlay_dir or not os.path.isdir(overlay_dir):
        return manifests

    # Try kubectl kustomize first
    try:
        return _apply_overlay_kubectl(manifests, overlay_dir)
    except (FileNotFoundError, RuntimeError):
        logger.info("kubectl not found; using Python-based patch fallback")
        return _apply_overlay_python(manifests, overlay_dir)


def _apply_overlay_kubectl(manifests: list[dict], overlay_dir: str) -> list[dict]:
    """Apply overlay using kubectl kustomize subprocess.

    Writes manifests as a base resources.yaml, then creates a
    kustomization.yaml that imports the overlay's patches (inline or file)
    and applies them to the base resources.
    """
    subprocess.run(
        ["kubectl", "version", "--client"],
        capture_output=True,
        timeout=10,
    )

    with tempfile.TemporaryDirectory(prefix="k8s-sims-kust-") as tmpdir:
        # Write base manifests
        resources_path = os.path.join(tmpdir, "resources.yaml")
        with open(resources_path, "w") as f:
            yaml.dump_all(manifests, f, default_flow_style=False)

        # Read the overlay's kustomization.yaml to extract patches
        overlay_kust_path = os.path.join(overlay_dir, "kustomization.yaml")
        overlay_patches = []
        if os.path.exists(overlay_kust_path):
            with open(overlay_kust_path) as f:
                overlay_kust = yaml.safe_load(f) or {}
            overlay_patches = overlay_kust.get("patches", [])

        if not overlay_patches:
            return manifests

        # Build composite kustomization: base resources + overlay patches
        kust = {
            "apiVersion": "kustomize.config.k8s.io/v1beta1",
            "kind": "Kustomization",
            "resources": ["resources.yaml"],
            "patches": overlay_patches,
        }

        # Copy any referenced patch files into tmpdir
        for fname in sorted(os.listdir(overlay_dir)):
            if fname == "kustomization.yaml":
                continue
            if fname.endswith(".yaml") or fname.endswith(".yml"):
                shutil.copy2(
                    os.path.join(overlay_dir, fname),
                    os.path.join(tmpdir, fname),
                )

        kust_path = os.path.join(tmpdir, "kustomization.yaml")
        with open(kust_path, "w") as f:
            yaml.dump(kust, f, default_flow_style=False)

        result = subprocess.run(
            ["kubectl", "kustomize", tmpdir],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            logger.warning("kubectl kustomize failed: %s", result.stderr)
            return manifests

        patched = list(yaml.safe_load_all(result.stdout))
        return [m for m in patched if m is not None]


def _strategic_merge(base: dict, patch: dict) -> dict:
    """Apply a strategic merge patch to a base dict.

    For metadata: merge annotations and labels, preserve original name/namespace.
    For spec: replace taints/affinity/tolerations lists (not append).
    """
    result = copy.deepcopy(base)

    # Merge metadata
    if "metadata" in patch:
        meta = result.setdefault("metadata", {})
        if "annotations" in patch["metadata"]:
            ann = meta.setdefault("annotations", {})
            ann.update(patch["metadata"]["annotations"])
        if "labels" in patch["metadata"]:
            lab = meta.setdefault("labels", {})
            lab.update(patch["metadata"]["labels"])
        # Preserve original name and namespace from base manifest
        # (patch name/namespace are for kustomize resource matching only)

    # Merge spec (replace lists, merge dicts)
    if "spec" in patch:
        spec = result.setdefault("spec", {})
        for key, value in patch["spec"].items():
            if isinstance(value, list):
                spec[key] = value  # Replace lists (taints, tolerations, etc.)
            elif isinstance(value, dict):
                existing = spec.setdefault(key, {})
                existing.update(value)
            else:
                spec[key] = value

    return result


def _apply_overlay_python(manifests: list[dict], overlay_dir: str) -> list[dict]:
    """Apply overlay using Python-based strategic merge patching (fallback).

    Reads patches from the kustomization.yaml `patches` field, supporting
    both inline patches (with `target` selector and `patch` YAML string)
    and file-based patches.
    """
    kust_path = os.path.join(overlay_dir, "kustomization.yaml")
    if not os.path.exists(kust_path):
        return manifests

    with open(kust_path) as f:
        kust = yaml.safe_load(f) or {}

    raw_patches = kust.get("patches", [])
    if not raw_patches:
        return manifests

    # Parse patches into (target_kind, patch_dict) pairs
    patches_by_kind: dict[str, list[dict]] = {}
    for entry in raw_patches:
        patch_dict = None
        target_kind = None

        if isinstance(entry, dict):
            # Inline patch with target selector
            target = entry.get("target", {})
            target_kind = target.get("kind")
            patch_yaml = entry.get("patch", "")
            if patch_yaml:
                patch_dict = yaml.safe_load(patch_yaml)

        if patch_dict and target_kind:
            patches_by_kind.setdefault(target_kind, []).append(patch_dict)

        elif isinstance(entry, str):
            # File-based patch
            fpath = os.path.join(overlay_dir, entry)
            if os.path.exists(fpath):
                with open(fpath) as pf:
                    docs = list(yaml.safe_load_all(pf))
                    for doc in docs:
                        if doc and "kind" in doc:
                            patches_by_kind.setdefault(doc["kind"], []).append(doc)

    if not patches_by_kind:
        return manifests

    # Apply patches to matching manifests
    result = []
    for manifest in manifests:
        kind = manifest.get("kind", "")
        patched = copy.deepcopy(manifest)
        for patch in patches_by_kind.get(kind, []):
            patched = _strategic_merge(patched, patch)
        result.append(patched)

    return result


# ---------------------------------------------------------------------------
# Refactored generation functions (T042)
# ---------------------------------------------------------------------------


def load_resources(
    nodes_path: str, pods_path: str, node_count: int
) -> tuple[list[dict], list[dict]]:
    """Load raw node and pod manifests from YAML files.

    Args:
        nodes_path: Path to nodes YAML file.
        pods_path: Path to pods YAML file.
        node_count: Maximum number of nodes to load.

    Returns:
        Tuple of (nodes_list, pods_list) as raw manifest dicts.
    """
    nodes = get_yaml_file(nodes_path, False, node_count)
    pods = get_yaml_file(pods_path, False)
    return nodes, pods


def generate_increment(
    nodes_raw: list[dict],
    pods_raw: list[dict],
    start_pos: int,
    end_pos: int,
    output_folder: str,
    overlay_dir: str | None = None,
    trace_config: dict | None = None,
    timestamp: int = 0,
) -> tuple[list[dict], list[dict], PlacementResult]:
    """Generate node/pod manifests and optional trace for one increment.

    Uses the binpack module for placement and optionally applies kustomize
    overlays and generates .sktrace files.

    Args:
        nodes_raw: All raw node manifests.
        pods_raw: All raw pod manifests (will be pruned by bin-packing).
        start_pos: Start index in nodes_raw for this increment.
        end_pos: End index in nodes_raw for this increment.
        output_folder: Directory to write output files.
        overlay_dir: Kustomize overlay directory (or None for no patching).
        trace_config: Trace config dict (or None for no trace generation).
        timestamp: Unix timestamp for the trace event.

    Returns:
        Tuple of (selected_nodes, selected_pods, PlacementResult).
    """
    # Slice nodes for this increment
    increment_nodes_raw = nodes_raw[start_pos:end_pos]

    # Parse into binpack types
    node_specs = [bp_parse_node(n) for n in increment_nodes_raw]
    pod_specs = [bp_parse_pod(p) for p in pods_raw]

    # Run bin-packing
    result = bp_place(node_specs, pod_specs)

    # Collect raw manifests for placed pods
    selected_pods = [pod.raw_manifest for pod, _ in result.assignments]
    selected_nodes = increment_nodes_raw

    # Apply kustomize overlay if specified
    if overlay_dir:
        selected_nodes = apply_overlay(selected_nodes, overlay_dir)
        selected_pods = apply_overlay(selected_pods, overlay_dir)

    # Calculate node count for filenames
    node_count = end_pos

    # Write node YAML
    nodes_path = os.path.join(output_folder, f"nodes-{node_count}.yaml")
    with open(nodes_path, "w") as f:
        yaml.dump_all(selected_nodes, f, default_flow_style=False)

    # Write pod YAML
    pods_path = os.path.join(output_folder, f"pods-{node_count}.yaml")
    with open(pods_path, "w") as f:
        yaml.dump_all(selected_pods, f, default_flow_style=False)

    # Generate trace if configured
    if trace_config is not None:
        trace = build_trace(result, trace_config, timestamp=timestamp)
        trace_path = os.path.join(output_folder, f"trace-{node_count}.sktrace")
        write_sktrace(trace, trace_path)

    print_msg(f"Generated {node_count} nodes and {len(selected_pods)} pods.", True)

    return selected_nodes, selected_pods, result


def generate_simon_config(output_folder: str, count: int, simon_template: dict, new_node_path: str) -> None:
    """Generate Simon configuration file for OpenSim."""
    new_simon_file = copy.deepcopy(simon_template)
    new_simon_file["spec"]["cluster"]["customConfig"] = f"nodes-{count}.yaml"
    new_simon_file["spec"]["appList"][0]["name"] = f"simulation-{count}"
    new_simon_file["spec"]["appList"][0]["path"] = f"pods-{count}.yaml"
    new_simon_file["spec"]["newNode"] = "new-node.yaml"
    with open(os.path.join(output_folder, f"simon-config-{count}.yaml"), "w") as output_file:
        yaml.dump(new_simon_file, output_file, default_flow_style=False)


# ---------------------------------------------------------------------------
# Animation helper
# ---------------------------------------------------------------------------


class Spinner:
    """Simple spinner animation for long-running operations."""

    def __init__(self):
        self._done = False
        self._msg = ""
        self._thread = None

    def start(self, msg: str):
        import threading

        self._done = False
        self._msg = msg
        self._thread = threading.Thread(target=self._spin, daemon=True)
        self._thread.start()

    def _spin(self):
        for c in itertools.cycle(["|", "/", "-", "\\"]):
            if self._done:
                break
            print(f"\r{self._msg}... {c}", end="")
            time.sleep(0.1)

    def stop(self):
        self._done = True
        if self._thread:
            self._thread.join()


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------


def main(args: argparse.Namespace) -> None:
    """Main function that orchestrates the Kubernetes resource generation process."""
    output_folder = os.path.abspath(args.output_folder)
    create_folder(output_folder)

    increment: int = args.increment if args.increment > 0 else args.node_count

    spinner = Spinner()
    print_msg("Loading resources...")
    spinner.start("Loading")
    nodes_raw, pods_raw = load_resources(args.nodes_path, args.pods_path, args.node_count)
    loaded_nodes_qty = len(nodes_raw)
    spinner.stop()
    print_msg("Finished loading!                 ", True)

    # Determine simulator and overlay directory
    simulator = ""
    overlay_dir = None
    trace_config = None
    simon_template = None

    if args.kubemark:
        simulator = "Kubemark"
        overlay_dir = os.path.join(ROOT_DIR, "overlays", "kubemark")
    elif args.simkube:
        simulator = "SimKube"
        overlay_dir = os.path.join(ROOT_DIR, "overlays", "simkube")
        trace_config = {"trackedObjects": {"v1.Pod": {}}}
    elif args.open_sim:
        simulator = "OpenSim"
        overlay_dir = os.path.join(ROOT_DIR, "overlays", "opensim")
        new_node_path = os.path.abspath(args.new_node_path)
        shutil.copyfile(new_node_path, os.path.join(output_folder, "new-node.yaml"))
        simon_template = get_yaml_file(os.path.join(script_dir, "base", "simon-config.yaml"))

    if simulator:
        print_msg(f"{simulator} selected.")

    # Track all placed pods across increments for cumulative trace
    all_placed_pod_names: set[str] = set()

    stop_iteration = False
    steps = args.node_count // increment

    for i in range(steps):
        if stop_iteration:
            break

        start_pos = i * increment
        end_pos = start_pos + increment
        node_qty = (i + 1) * increment

        if abs(node_qty - loaded_nodes_qty) < increment:
            stop_iteration = True
            node_qty = loaded_nodes_qty
            end_pos = loaded_nodes_qty

        # Round node_qty to nearest increment
        val = (node_qty // increment)
        if val == 0:
            val = node_qty
        else:
            val *= increment
        rounded_qty = val

        print_msg(f"Generating {rounded_qty} nodes...")
        spinner.start("Generating")

        # OpenSim: generate simon config
        if args.open_sim and simon_template:
            generate_simon_config(output_folder, rounded_qty, simon_template, args.new_node_path)

        # Generate increment using binpack module
        _, selected_pods, placement = generate_increment(
            nodes_raw=nodes_raw,
            pods_raw=pods_raw,
            start_pos=start_pos,
            end_pos=end_pos,
            output_folder=output_folder,
            overlay_dir=overlay_dir,
            trace_config=trace_config if args.tracer else None,
            timestamp=int(time.time()),
        )

        # Track placed pods and prune from pool for next increment
        placed_names = {p["metadata"]["name"] for p in selected_pods if p and "metadata" in p}
        pods_raw = [p for p in pods_raw if p.get("metadata", {}).get("name") not in placed_names]

        spinner.stop()
        print_msg("Finished!                 ", True)

    print_msg(f"Files saved to output folder: {output_folder}")

    # Validate traces if generated
    if args.tracer and trace_config:
        print_msg("Validating generated traces...")
        valid = validate_traces_in_dir(output_folder)
        if valid:
            print_msg("All traces validated successfully.")
        else:
            print_msg("WARNING: Some traces failed validation. Check logs for details.")

    # Run experiments if requested
    if args.run_experiments:
        print_msg("Starting kube-run")
        result_path = os.path.abspath(output_folder)
        kube_director_path = os.path.join(ROOT_DIR, "kube-director.sh")
        subprocess.check_call([kube_director_path, "-e", result_path, *shlex.split(args.kube_director_arguments)])


def print_ascii() -> None:
    """Print ASCII art banner for the application."""
    print(r"""      _  __     _           _____
     | |/ /    | |         / ____|
     | ' /_   _| |__   ___| |  __  ___ _ __
     |  <| | | | '_ \ / _ \ | |_ |/ _ \ '__|
     | . \ |_| | |_) |  __/ |__| |  __/ | | |
     |_|\_\__,_|_.__/ \___|\_____|\___|_| |_|

-------------------------------------------------""")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog="kube-gen.py")
    parser.add_argument("-o", "--output_folder", type=str, required=True, help="Output folder where generated files are saved")
    parser.add_argument("-c", "--node_count", type=int, default=400, help="Quantity of nodes to generate")
    parser.add_argument("-i", "--increment", type=int, default=0, help="Used to generate multiple files with steps of size n")
    parser.add_argument("-k", "--kubemark", default=False, action="store_true", help="Applies the kubemark patches to the generated files")
    parser.add_argument("-s", "--simkube", default=False, action="store_true", help="Applies the simkube patches to the generated files")
    parser.add_argument("-os", "--open_sim", default=False, action="store_true", help="Generates files with the OpenSimulator format")
    parser.add_argument("-t", "--tracer", default=False, action="store_true", help="Generates SimKube .sktrace files directly (no cluster needed)")
    parser.add_argument("-e", "--run_experiments", default=False, action="store_true", help="Indicates whether to run experiments after generating the datasets.")
    parser.add_argument("-a", "--kube_director_arguments", type=str, default="-n 3 -p", help="Arguments to be passed to KubeDirector if run experiments is enabled.")
    parser.add_argument("-tn", "--tracer_namespace", type=str, default="paib-gpu", help="Specifies the namespace that will be used to generate SimKube traces")
    parser.add_argument("-hn", "--hollow_node_path", type=str, default=os.path.join(script_dir, "base", "hollow-node.yml"), help="Template hollow node file used for Kubemark")
    parser.add_argument("-nn", "--new_node_path", type=str, default=os.path.join(script_dir, "base", "new-node.yaml"), help="Path to the YAML file containing the new node template for opensim")
    parser.add_argument("-n", "--nodes_path", type=str, default=os.path.join(script_dir, "base", "nodes.yaml"), help="Path to the YAML file containing the base Kubernetes manifest for nodes")
    parser.add_argument("-p", "--pods_path", type=str, default=os.path.join(script_dir, "base", "pods.yaml"), help="Path to the YAML file containing the base Kubernetes manifest for pods")

    print_ascii()
    try:
        args = parser.parse_args()
        if args.kubemark and (args.node_count is None or args.hollow_node_path is None or args.nodes_path is None or args.pods_path is None):
            raise Exception("Required arguments not provided")
        elif args.output_folder is None:
            raise Exception("No output folder provided")
    except SystemExit:
        sys.exit(-1)
    except Exception:
        parser.print_help()
        sys.exit(-1)
    main(args)
