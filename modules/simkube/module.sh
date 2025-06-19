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
        --name "$CLUSTER_NAME"
}

cluster_setup(){
    local SIM_CONTEXT="kind-$CLUSTER_NAME"
    cd "${LOCAL_PATH}"
    kubectl config use-context $SIM_CONTEXT
    kubectl apply -f "https://github.com/kubernetes-sigs/kwok/releases/download/v0.7.0/kwok.yaml"
    kubectl apply -f "https://github.com/kubernetes-sigs/kwok/releases/download/v0.7.0/stage-fast.yaml"

    if [ ! -d "kube-prometheus" ]; then
        git clone https://github.com/prometheus-operator/kube-prometheus.git
    fi

    cd kube-prometheus

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

    cd simkube-src/
    kubectl create ns simkube
    kubectl apply -k k8s/kustomize/sim
}

cleanup_cluster(){
    kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
}

deploy_objects(){
    local NODE_FILE="$1"
    local TRACE_FILE="$2"
    # rm "$LOCAL_PATH/data/trace.out"
    kubectl create secret generic simkube --namespace=simkube
    cp -r "$TRACE_FILE" "$LOCAL_PATH/data/trace.out"
    kubectl create -f "$NODE_FILE"
    cd "$LOCAL_PATH/simkube-src/"
    skctl run test-sim \
    --trace-path file:///data/trace.out \
    --hooks config/hooks/default.yml \
    --disable-metrics \
    --duration +5m \
    --speed $SIMULATION_SPEED \
    --driver-verbosity debug
}

wait_for_simulator_state(){
    local WANTED_STATE="$1"
    local MAX_WAIT_TIME=180
    local WAIT_START_TIME=$(date +%s)
    until kubectl get simulations | grep -q "$WANTED_STATE"; do
        ELAPSED_TIME=$(($(date +%s)-$WAIT_START_TIME))
        if [ "$ELAPSED_TIME" -ge "$MAX_WAIT_TIME" ]; then
            log ERROR "Timeout waiting for simulation to reach state $WANTED_STATE"
            TIMEOUT_REACHED="true"
            break
        fi
        echo -ne "Waiting for simulation to reach state $WANTED_STATE. Elapsed: $ELAPSED_TIME seconds.\r";
        sleep 1;
    done
}

log INFO "SimKube module loaded!"
