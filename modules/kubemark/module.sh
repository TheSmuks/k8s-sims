#!/bin/bash
readonly LOCAL_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CLUSTER_NAME="kubemark"
CONTAINERS_TO_WATCH="${CLUSTER_NAME}"
NAMESPACE="paib-gpu"

create_cluster(){
    if kind get clusters | grep -q "$CLUSTER_NAME"; then
        echo "$CLUSTER_NAME already exists. Deleting..."
        kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
    fi
    echo "Creating cluster $CLUSTER_NAME..."
    kind create cluster \
        --config="$LOCAL_PATH/kind-config.yaml" \
        --name "$CLUSTER_NAME" \
        --image kindest/node:v1.29.0
}

cluster_setup(){
    kind get kubeconfig --name "$CLUSTER_NAME" > "$LOCAL_PATH/config"
    sed -i 's|server: https://127.0.0.1:[0-9]\+|server: https://kubernetes.default.svc:443|' "$LOCAL_PATH/config"
    kubectl config use-context "kind-$CLUSTER_NAME"
    kubectl create ns $NAMESPACE
    kubectl create secret generic kubeconfig \
        --type=Opaque --namespace=$NAMESPACE \
        --from-file=kubelet.kubeconfig="$LOCAL_PATH/config" \
        --from-file=kubeproxy.kubeconfig="$LOCAL_PATH/config"
}

cleanup_cluster(){
    kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
    rm -f "$LOCAL_PATH/config"
}

deploy_objects(){
    local NODE_FILE="$1"
    local POD_FILE="$2"
    kubectl create -f "$NODE_FILE"
    kubectl create -f "$POD_FILE"
}

wait_for_simulator_state(){
    # Dummy function
    :;
}

log INFO "Kubemark module loaded!"
