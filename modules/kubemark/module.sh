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
    local CONFIG_PATH="$LOCAL_PATH/config"
    kind get kubeconfig --name "$CLUSTER_NAME" > "$CONFIG_PATH"
    #sed -i 's|server: https://127.0.0.1:[0-9]\+|server: https://kubernetes.default.svc:443|' "$LOCAL_PATH/config"
    kubectl config use-context "kind-$CLUSTER_NAME"
    kubectl create ns "$NAMESPACE"
    kubectl create ns "kubemark"
    wait_for_namespace "kubemark"
    wait_for_namespace "$NAMESPACE"

    kubectl create secret generic kubeconfig \
        --type=Opaque --namespace="kubemark" \
        --from-file=kubelet.kubeconfig="$CONFIG_PATH" \
        --from-file=kubeproxy.kubeconfig="$CONFIG_PATH"
}

cleanup_cluster(){
    kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
    rm -f "$LOCAL_PATH/config"
}

deploy_objects(){
    local NODE_FILE="$1"
    local POD_FILE="$2"
    kubectl create -f "$NODE_FILE" --namespace="kubemark"
    kubectl create -f "$POD_FILE" --namespace="$NAMESPACE"
}

log INFO "Kubemark module loaded!"
