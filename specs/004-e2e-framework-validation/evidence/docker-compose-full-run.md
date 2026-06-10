# Docker Compose Full Framework Run Evidence

## Run Configuration
- EXPERIMENT_FILES_PATH=/data/test
- RUNS=1
- MAX_SIMULATION_TIME=300
- Image: thesmuks/k8s-sims:latest (rebuilt with CRLF fixes and sktrace.py Dockerfile fix)

## Fixes Applied Before Run
1. sed -i 's/\r$//' on entrypoint.sh, kube-director.sh, kube-run.sh, modules/*/module.sh, SIM_MODULES
2. Dockerfile: COPY utils/simkube-tracer.sh -> COPY utils/sktrace.py (file was renamed in 003 spec)

## Execution Timeline

### 1. opensim
- Completed
- NOTE: opensim ran inside the privileged container with cgroup access

### 2. kwok
- Completed successfully
- Cluster created, pods scheduled, results written

### 3. kube-sched
- Completed
- Cluster setup successful (simulator-src containers started)
- Pods could not be scheduled (1 pod, resource constraints on single-node)
- Results written to /tmp/kube-sched.csv
- Cluster cleaned up

### 4. simkube
- Cluster setup: SUCCESS
  - kind cluster created
  - KWOK CRDs applied
  - Prometheus stack deployed
  - cert-manager deployed (1 pod timeout, 2/3 ready)
  - self-signed ClusterIssuer created
  - SimKube CRDs and controller deployed
  - simkube-src cloned from GitHub (v2.3.0 checkout)
- Simulation start: FAILED
  - skctl run test-sim started with config (duration +5m, speed 4.0, driver v2.6.1)
  - Driver pod entered Error state immediately
  - Driver error: "unexpected argument '--virtual-ns-prefix' found"
  - ROOT CAUSE: skctl binary built from v2.3.0 source passes --virtual-ns-prefix flag
    to driver, but the driver image is v2.6.1 which has different CLI args
  - Waited indefinitely for simulation to reach "Running" state (would never succeed)
  - Container was manually stopped after ~15 minutes

### 5. kubemark
- NOT REACHED (simkube hung before kubemark could start)

## Defects Found

### F003: Dockerfile references non-existent simkube-tracer.sh
- The 003 spec renamed utils/simkube-tracer.sh to utils/sktrace.py
- Dockerfile COPY step fails at build time
- Fix: Changed COPY line to reference utils/sktrace.py

### F004: CRLF line endings in SIM_MODULES and shell scripts
- Windows host commits files with CRLF
- SIM_MODULES with CRLF causes "opensim\r" to not match in kube-run.sh
- entrypoint.sh with CRLF causes "no such file or directory" in Docker
- Fix: sed -i 's/\r$//' on all affected files

### F005: SimKube version mismatch (skctl v2.3.0 vs driver v2.6.1)
- module.sh clones simkube-src at v2.3.0 tag
- skctl is built from v2.3.0 source
- But skctl run defaults to or uses driver image v2.6.1
- The v2.6.1 driver has different CLI flags (--virtual-ns-prefix removed)
- Driver pod crashes immediately on start
- Fix needed: either upgrade skctl to v2.6.1 or pin driver image to v2.3.0
