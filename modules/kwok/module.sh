#!/bin/bash
readonly LOCAL_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLUSTER_NAME="kwok"
NAMESPACE="paib-gpu"
CONTAINERS_TO_WATCH="$CLUSTER_NAME"

create_cluster(){
    if kwokctl get clusters | grep -q "$CLUSTER_NAME"; then
        log INFO "$CLUSTER_NAME already exists. Deleting..."
        kwokctl delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
    fi
    kwokctl create cluster --name $CLUSTER_NAME \
    --timeout 60s
}

cluster_setup(){
    kubectl config use-context kwok-${CLUSTER_NAME}
    kubectl create namespace ${NAMESPACE}
}

cleanup_cluster(){
    kwokctl delete cluster --name $CLUSTER_NAME
}

deploy_objects(){
    local NODE_FILE="$1"
    local POD_FILE="$2"
    kubectl create ns paib-gpu
    kubectl create -f $NODE_FILE
    kubectl create -f $POD_FILE -n paib-gpu
}

wait_for_simulator_state(){
    # Dummy function
    :;
}

log INFO "KWOK module loaded!"
