#!/bin/bash
readonly LOCAL_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KUBE_FILE="$LOCAL_PATH/kubeconfig.yaml"

NAMESPACE="paib-gpu"
CONTAINERS_TO_WATCH=(simulator-scheduler simulator-server simulator-cluster)

create_cluster(){
    cd $LOCAL_PATH
    if [ -d "simulator-src" ]; then
        cd simulator-src
    else
        git clone https://github.com/kubernetes-sigs/kube-scheduler-simulator.git simulator-src
        cd simulator-src
        git checkout v0.4.0
    fi
    cp simulator/kubeconfig.yaml "$KUBE_FILE"
    LOCAL_IP=$(ip route get 1 | awk '{print $7; exit}')
    sed -i "s|server: http://fake-source-cluster:3132|server: http://$LOCAL_IP:3131|" "$KUBE_FILE"
}

cluster_setup(){
    docker compose up -d "${CONTAINERS_TO_WATCH[@]}"
    until docker logs "${CONTAINERS_TO_WATCH[-1]}" 2>&1 | grep -q "Starting to serve"; do
        sleep 0.5
    done
}

cleanup_cluster(){
    cd "$LOCAL_PATH/simulator-src"
    docker compose down
}

deploy_objects(){
    local NODE_FILE="$1"
    local POD_FILE="$2"
    export KUBECONFIG="$KUBE_FILE"
    kubectl create ns paib-gpu
    kubectl create -f $NODE_FILE
    kubectl create -f $POD_FILE -n paib-gpu
}

wait_for_simulator_state(){
    # Dummy function
    :;
}

log INFO "Kubernetes Scheduler Simulator module loaded!"
