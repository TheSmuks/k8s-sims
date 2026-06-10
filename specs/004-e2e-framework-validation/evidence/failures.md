# Failure Log: E2E Framework Validation

Every failed command, mismatch, or unexpected behavior observed during validation.

## F001: Missing test fixture directories for kube-plot and min-max-avg

- **Discovered**: During `validate-checkpoint.sh all` execution
- **Command**: `python utils/kube-plot.py -d tests/fixtures/results/valid ...`
- **Error**: `Error: Data directory does not exist or is not a directory.`
- **Scope**: project-scope (missing test fixtures)
- **Resolution**: FIX-001 (created fixture directories with minimal CSVs)
- **Verified**: kube-plot.py generates 14 plots; min-max-avg.py generates summary.json

## F002: skctl validate uses wrong subcommand syntax

- **Discovered**: During simkube workload generation
- **Command**: `skctl validate <path>` (as called from `utils/sktrace.py:160`)
- **Error**: `error: unrecognized subcommand`
- **Scope**: project-scope (code defect in sktrace.py)
- **Resolution**: FIX-002 (added "check" subcommand)
- **Verified**: New pytest test passes

## F003: Dockerfile references non-existent simkube-tracer.sh

- **Discovered**: During `docker build` for docker-compose run
- **Error**: `failed to calculate checksum: "/utils/simkube-tracer.sh": not found`
- **Scope**: project-scope (Dockerfile out of sync after 003 spec rename)
- **Resolution**: FIX-003 (changed COPY to reference utils/sktrace.py)
- **Verified**: Docker image builds successfully

## F004: CRLF line endings in SIM_MODULES and shell scripts

- **Discovered**: During docker-compose run
- **Error**: `exec /entrypoint.sh: no such file or directory` (first run); `Unsupported simulator 'opensim\r'` (after entrypoint fix)
- **Root cause**: Windows host commits files with CRLF terminators
- **Scope**: project-scope (line-ending issue)
- **Resolution**: FIX-004 (sed -i 's/\r$//' on all shell scripts and SIM_MODULES)
- **Verified**: Docker image boots and all module names resolve correctly

## F005: SimKube version mismatch (skctl v2.3.0 vs driver v2.6.1)

- **Discovered**: During docker-compose run, simkube simulation phase
- **Error**: Driver pod crashes: `unexpected argument '--virtual-ns-prefix' found`
- **Root cause**: module.sh clones simkube-src at v2.3.0 and skctl is built from v2.3.0, but the driver image deployed is v2.6.1 which has incompatible CLI flags
- **Scope**: project-scope (version pinning issue in modules/simkube/module.sh)
- **Resolution**: NOT YET FIXED -- needs either upgrading skctl to v2.6.1 or pinning driver image to v2.3.0
- **Impact**: SimKube simulations cannot run in Docker; blocks kubemark from running (kubemark is after simkube in SIM_MODULES order)

## F006: kube-sched pods cannot be scheduled

- **Discovered**: During docker-compose run
- **Error**: `All pending pods can not be scheduled` (1 pod with 1 node)
- **Root cause**: Single-node kube-sched simulator cluster has insufficient resources for the pod spec
- **Scope**: expected behavior (data/test has only nodes-1.yaml with 1 node)
- **Resolution**: Not a defect -- small test dataset, pods with resource requests exceeding single-node capacity
- **Impact**: Framework correctly records unscheduled pods in results CSV
