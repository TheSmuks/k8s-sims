# OpenSim Validation Status

## Documentation Evidence
- Module path: modules/opensim/
- SIM_MODULES.md classification: opensim (active)

## Prerequisites from Documentation
- | `opensim` | `modules/opensim/module.sh` | `simon-config-*.yaml` | OpenSimulator binary, sudo/cgroup access | local `modules/opensim/cmd`; host cgroup tools | cgroup process termination and `cgdelete` | syntax; full run requires Linux cgroups |

## Classification

OpenSim (OpenSimulator) requires:
1. Linux cgroups access for container resource control
2. A running Kubernetes cluster with proper cgroup configuration
3. The OpenSim binary built from source (Go)

## Host Prerequisites Status
- Platform: Windows 10 / Git-Bash -- Linux cgroups NOT available
- Docker: AVAILABLE but cgroup passthrough not functional on Windows
- OpenSim binary: Not found on PATH

## Validation Approach
1. Generation check: kube-gen.py --open_sim generates manifests and simon-config files (PASSED)
2. Runtime smoke: Cannot run on Windows due to cgroup dependency
3. Fallback: Verify generated artifacts exist and are structurally valid

## Artifact Validation
- nodes-10.yaml: PRESENT
- pods-10.yaml: PRESENT  
- new-node.yaml: PRESENT
- simon-config-10.yaml: PRESENT

## Final Status
skipped-documented-constraint (Linux cgroups required; validated generation path only)
