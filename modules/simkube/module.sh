#!/bin/bash
readonly LOCAL_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLUSTER_NAME="simkube"
NAMESPACE="virtual-paib-gpu"
SIMULATION_SPEED="4"
CONTAINERS_TO_WATCH="$CLUSTER_NAME"

create_cluster(){
    if kind get clusters | grep -q "$CLUSTER_NAME"; then
        log INFO "$CLUSTER_NAME already exists. Deleting..."
        kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
    fi
    log INFO "Creating cluster $CLUSTER_NAME..."
    cd "${LOCAL_PATH}"
    kind create cluster \
        --config="${LOCAL_PATH}/kind-config.yaml" \
        --name "$CLUSTER_NAME" \
        --image=kindest/node:v1.29.0
}

cluster_setup(){
    local SIM_CONTEXT="kind-$CLUSTER_NAME"
    cd "${LOCAL_PATH}"
    kubectl config use-context "$SIM_CONTEXT"
    kubectl apply -f "https://github.com/kubernetes-sigs/kwok/releases/download/v0.7.0/kwok.yaml"
    kubectl apply -f "https://github.com/kubernetes-sigs/kwok/releases/download/v0.7.0/stage-fast.yaml"

    if [ ! -d "kube-prometheus" ]; then
        git clone https://github.com/prometheus-operator/kube-prometheus.git
    fi

    cd "kube-prometheus"

    kubectl create -f manifests/setup
    until kubectl get servicemonitors --all-namespaces ; do
        date
        sleep 1
        echo ""
    done
    kubectl create -f manifests/
    cd ..

    kubectl apply -f "${LOCAL_PATH}/cert-manager.yaml"
    log INFO "cert-manager.yaml applied"
    kubectl wait --for=condition=Ready -n cert-manager pod -l app=cert-manager --timeout=60s
    kubectl wait --for=condition=Ready -n cert-manager pod -l app=webhook --timeout=60s
    kubectl wait --for=condition=Ready -n cert-manager pod -l app=cainjector --timeout=60s
    sleep 5
    kubectl apply -f "${LOCAL_PATH}/self-signed.yml"
    log INFO "self-signed.yaml applied"

    if [ ! -d "simkube-src" ]; then
        git clone https://github.com/acrlabs/simkube.git simkube-src
        cd simkube-src
        git checkout v2.3.0
        cd ..
    fi

    cd "simkube-src/"
    kubectl create ns simkube
    kubectl apply -k k8s/kustomize/sim
}

cleanup_cluster(){
    kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
}

deploy_objects(){
    local NODE_FILE="$1"
    local TRACE_FILE="$2"
    rm -f "$LOCAL_PATH/data/trace.out"
    kubectl create secret generic simkube --namespace=simkube
    cp "$TRACE_FILE" "$LOCAL_PATH/data/trace.out"
    kubectl create -f "$NODE_FILE"
    cd "$LOCAL_PATH/simkube-src/"
    skctl run test-sim \
    --trace-path file:///data/trace.out \
    --hooks config/hooks/default.yml \
    --disable-metrics \
    --duration +5m \
    --speed "$SIMULATION_SPEED" \
    --driver-verbosity debug \
    --driver-image quay.io/appliedcomputing/sk-driver:v2.3.0
}

# generate_traces: generate .sktrace files directly via kube-gen.py (no cluster needed)
# Usage: generate_traces <output_dir> <node_count> <increment>
generate_traces(){
    local OUTPUT_DIR="${1:-output/simkube-traces}"
    local NODE_COUNT="${2:-100}"
    local INCREMENT="${3:-25}"
    python "${LOCAL_PATH}/../../utils/kube-gen.py" \
        --simkube --tracer \
        -c "$NODE_COUNT" -i "$INCREMENT" \
        -o "$OUTPUT_DIR"
}

wait_for_simulator_state(){
    local WANTED_STATE="$1"
    local MAX_WAIT_TIME=180
    local WAIT_START_TIME=$(date +%s)
    local ELAPSED_TIME=0
    local LAST_STATE=""
    local DRIVER_POD=""
    local TICK=0
    until kubectl get simulations | grep -q "$WANTED_STATE"; do
        ELAPSED_TIME=$(($(date +%s)-$WAIT_START_TIME))
        if [ "$ELAPSED_TIME" -ge "$MAX_WAIT_TIME" ]; then
            log ERROR "Timeout waiting for simulation to reach state $WANTED_STATE"
            TIMEOUT_REACHED="1"
            RUN_CONDITION="false"
            break
        fi
        check_max_time

        # Fetch current simulation state
        local SIM_LINE
        SIM_LINE=$(kubectl get simulations --no-headers 2>/dev/null | head -1)
        local CUR_STATE
        CUR_STATE=$(echo "$SIM_LINE" | awk '{print $NF}')

        # Every 10 seconds, print a detailed status line (avoid log spam)
        if [ $((TICK % 10)) -eq 0 ]; then
            local DIAG="state=${CUR_STATE:-unknown}"

            # Check driver pod status
            if [ -z "$DRIVER_POD" ]; then
                DRIVER_POD=$(kubectl get pods -n simkube -l app=sk-driver --no-headers -o custom-columns=NAME:.metadata.name,STATUS:.status.phase 2>/dev/null | head -1)
            fi
            if [ -n "$DRIVER_POD" ]; then
                local POD_STATUS
                POD_STATUS=$(kubectl get pod -n simkube "$DRIVER_POD" --no-headers -o custom-columns=STATUS:.status.phase 2>/dev/null)
                DIAG="$DIAG driver=$POD_STATUS"
                # If driver is Error or Failed, grab last log line
                if [ "$POD_STATUS" = "Error" ] || [ "$POD_STATUS" = "Failed" ]; then
                    local LAST_LOG
                    LAST_LOG=$(kubectl logs -n simkube "$DRIVER_POD" --tail=1 2>/dev/null)
                    DIAG="$DIAG err=$LAST_LOG"
                fi
            fi

            log INFO "Waiting for simulation ($WANTED_STATE) elapsed=${ELAPSED_TIME}s $DIAG"
        fi

        TICK=$((TICK + 1))
        LAST_STATE="$CUR_STATE"
        sleep 1;
    done

    # Print final state on success
    if [ "$TIMEOUT_REACHED" != "1" ]; then
        local FINAL_LINE
        FINAL_LINE=$(kubectl get simulations --no-headers 2>/dev/null | head -1)
        log INFO "Simulation reached $WANTED_STATE after ${ELAPSED_TIME}s: $FINAL_LINE"
    fi
}

log INFO "SimKube module loaded!"
