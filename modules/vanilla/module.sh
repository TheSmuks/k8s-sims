CLUSTER_NAME="kube-bench"
NAMESPACE="kube-bench"
CONTAINERS_TO_WATCH="${NAMESPACE}"

create_cluster(){
    if kind get clusters | grep -q "$CLUSTER_NAME"; then
        log INFO "$CLUSTER_NAME already exists. Deleting..."
        kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
    fi
    log INFO "Creating cluster $CLUSTER_NAME..."
    CONFIG_FILE="$1"
    kind create cluster \
        --config="$CONFIG_FILE" \
        --name="$CLUSTER_NAME" \
        --image=kindest/node:v1.29.0
}

cluster_setup(){
    kubectl create namespace "$NAMESPACE"
}

deploy_objects(){
    local NODE_FILE="$1" # In this case it is empty
    local POD_FILE="$2"
    kubectl create -f "$POD_FILE" --namespace="$NAMESPACE"
}

cleanup_cluster(){
    kind delete cluster --name "$CLUSTER_NAME"
    containers=$(docker ps -a --filter "name=kube-bench" -q)
    [ -n "$containers" ] && docker rm -f $containers
}