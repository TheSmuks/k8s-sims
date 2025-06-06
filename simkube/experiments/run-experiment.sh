#!/bin/bash

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DEFAULT_CLUSTER_NAME="simkube"
readonly DEFAULT_RUNS=1
readonly DEFAULT_MEMORY_THRESHOLD=95
readonly CGROUP_BASE="/sys/fs/cgroup/system.slice"
readonly POLL_TIMEOUT=1
readonly LOG_FILE="$SCRIPT_DIR/experiment.log"
readonly MAIN_SCRIPT_PID=$$
readonly DEFAULT_OUT_FILE="$SCRIPT_DIR/run-simkube.csv"
readonly NAMESPACE="virtual-paib-gpu"
readonly DEFAULT_START=0

START=0
RUN_CONDITION="true"
UNSCHEDULED_PODS=0
SIMULATION_SPEED=2
TIMEOUT_REACHED="false"

usage() {
    cat << EOF
Usage: $(basename "$0") -e EXPERIMENT_PATH [-o OUT_FILE] [-c CLUSTER_NAME] [-r RUNS] [-s START] [-t MEMORY_THRESHOLD]

Required arguments:
    -e EXPERIMENT_PATH   Path to experiment files directory

Optional arguments:
    -o OUT_FILE         Output file for experiment results
    -r RUNS             Number of runs per experiment (default: $DEFAULT_RUNS)
    -s START            Resume from a specific node count (default: $DEFAULT_START)
    -t MEMORY_THRESHOLD Memory threshold percentage (default: $DEFAULT_MEMORY_THRESHOLD)
    -h                  Show this help message

Example:
    $(basename "$0") -c my-cluster -e ./experiments -r 5 -o results.csv
EOF
}

parse_args() {
    CLUSTER_NAME=$DEFAULT_CLUSTER_NAME
    RUNS=$DEFAULT_RUNS
    MEMORY_THRESHOLD=$DEFAULT_MEMORY_THRESHOLD
    OUT_FILE=$DEFAULT_OUT_FILE
    START=$DEFAULT_START
    local OPTIND
    while getopts 'hc:r:e:t:o:s:' opt; do
        case "$opt" in
            c) CLUSTER_NAME="$OPTARG" ;;
            r) RUNS="$OPTARG" ;;
            e) EXPERIMENT_FILES_PATH=$(realpath "$OPTARG") ;;
            t) MEMORY_THRESHOLD="$OPTARG" ;;
            o) OUT_FILE=$(realpath "$OPTARG") ;;
            s) START="$OPTARG" ;;
            h) usage; exit 0 ;;
            :) echo "Error: Option requires an argument." >&2; usage; exit 1 ;;
            ?) echo "Error: Invalid option." >&2; usage; exit 1 ;;
        esac
    done

    if [[ -z "$EXPERIMENT_FILES_PATH" ]]; then
        echo "Error: Missing required arguments." >&2
        usage
        exit 1
    fi

    if [[ ! -d "$EXPERIMENT_FILES_PATH" ]]; then
        echo "Error: Experiment files path does not exist: $EXPERIMENT_FILES_PATH" >&2
        exit 1
    fi
}

get_max_alloted_memory(){
    local CURRENT_FREE_MEMORY
    CURRENT_FREE_MEMORY=$(awk '/MemFree/ {free=$2} /^Cached:/ {cached=$2} END { print (free + cached) * 1024 }' /proc/meminfo)
    local MAX_MEM_ALLOTED=$(($CURRENT_FREE_MEMORY*$MEMORY_THRESHOLD/100))
    echo $MAX_MEM_ALLOTED
}

get_container_ids(){
    docker ps --no-trunc -aqf "name=$CLUSTER_NAME" 2>/dev/null || true
}

get_cgroup_base(){
    local IS_CONTAINER="$1"
    local PROGRAM_INFO="$2"
    local CGROUP_BASE_PATH="$CGROUP_BASE/"

    if [[ $IS_CONTAINER == "true" ]]; then
        CGROUP_BASE_PATH+="docker-$PROGRAM_INFO"
    else
        CGROUP_BASE_PATH+="$PROGRAM_INFO"
    fi

    echo "$CGROUP_BASE_PATH"
}

get_memory_usage(){
    local CGROUP_MEM_PATH="$(get_cgroup_base "$1" "$2").scope/memory.current"
    if [[ -f "$CGROUP_MEM_PATH" ]]; then
        cat "$CGROUP_MEM_PATH" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

get_cpu_usage(){
    local CGROUP_CPU_PATH="$(get_cgroup_base "$1" "$2").scope/cpu.stat"
    if [[ -f "$CGROUP_CPU_PATH" ]]; then
        awk 'NR<=3 {printf "%d ", $2/1000000}' "$CGROUP_CPU_PATH" 2>/dev/null || echo "0 0 0"
    else
        echo "0 0 0"
    fi
}

track_containers(){
    local MAX_MEM_ALLOTED=$(get_max_alloted_memory)
    local MAX_MEMORY_MEASUREMENT=0
    local START_TIME="$1"
    local LOCAL_RUN_CONDITION="true"
    local CONTAINER_IDS

    trap 'LOCAL_RUN_CONDITION=false' SIGINT SIGTERM

    while [[ $LOCAL_RUN_CONDITION = "true" ]]; do
        mapfile -t CONTAINER_IDS < <(get_container_ids)
        if [[ ${#CONTAINER_IDS[@]} -eq 0 ]]; then
            LOCAL_RUN_CONDITION="false"
            break
        fi

        local CPU_MEASUREMENTS=(0 0 0)
        local TOTAL_MEM=0
        for ((i=0; i<${#CONTAINER_IDS[@]}; i++)); do
            if [[ -z "${CONTAINER_IDS[i]}" ]]; then
                continue
            fi

            local CURRENT_MEMORY_MEASUREMENT=$(get_memory_usage "true" "${CONTAINER_IDS[i]}")
            TOTAL_MEM=$((TOTAL_MEM + CURRENT_MEMORY_MEASUREMENT))

            local CONTAINER_CPU_MEASUREMENT=($(get_cpu_usage "true" "${CONTAINER_IDS[i]}"))
            for j in {0..2}; do
                CPU_MEASUREMENTS[j]=$(( ${CPU_MEASUREMENTS[j]:-0} + ${CONTAINER_CPU_MEASUREMENT[j]:-0} ))
            done
        done

        if [[ $TOTAL_MEM -gt $MAX_MEMORY_MEASUREMENT ]]; then
            MAX_MEMORY_MEASUREMENT=$TOTAL_MEM
        fi

        if [[ $TOTAL_MEM -gt $MAX_MEM_ALLOTED ]]; then
            LOCAL_RUN_CONDITION="false"
            break
        fi

        sleep $POLL_TIMEOUT
    done

    local END_TIME=$(date +%s)
    local RUNTIME=$((END_TIME - START_TIME))

    local MEMORY_GB CPU_TOTAL_SEC CPU_USER_SEC CPU_SYS_SEC
    MEMORY_GB=$(awk "BEGIN {printf \"%.2f\", $MAX_MEMORY_MEASUREMENT / 1024 / 1024 / 1024}")
    CPU_TOTAL_SEC=$(awk "BEGIN {printf \"%.2f\", ${CPU_MEASUREMENTS[0]}}")
    CPU_USER_SEC=$(awk "BEGIN {printf \"%.2f\", ${CPU_MEASUREMENTS[1]}}")
    CPU_SYS_SEC=$(awk "BEGIN {printf \"%.2f\", ${CPU_MEASUREMENTS[2]}}")

    printf "%d|%s|%s|%s|%s" \
        "$RUNTIME" \
        "$CPU_TOTAL_SEC" \
        "$CPU_USER_SEC" \
        "$CPU_SYS_SEC" \
        "$MEMORY_GB" >> "$OUT_FILE"
    exit 0
}

create_cluster(){
    if kind get clusters | grep -q "$CLUSTER_NAME"; then
        echo "$CLUSTER_NAME already exists. Deleting..."
        kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
    fi
    echo "Creating cluster $CLUSTER_NAME..."
    kind create cluster \
        --config="$SCRIPT_DIR/kind-config.yaml" \
        --name "$CLUSTER_NAME"
}

cluster_setup(){
    local SIM_CONTEXT="kind-$CLUSTER_NAME"
    local KWOK_REPO="kubernetes-sigs/kwok"
    local KWOK_LATEST_RELEASE=$(curl "https://api.github.com/repos/${KWOK_REPO}/releases/latest" | jq -r '.tag_name')

    kubectl config use-context $SIM_CONTEXT
    kubectl apply -f "https://github.com/${KWOK_REPO}/releases/download/${KWOK_LATEST_RELEASE}/kwok.yaml"
    kubectl apply -f "https://github.com/${KWOK_REPO}/releases/download/${KWOK_LATEST_RELEASE}/stage-fast.yaml"

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

    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.yaml
    kubectl wait --for=condition=Ready -l app=webhook -n cert-manager pod --timeout=60s
    kubectl apply -f self-signed.yml

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
    # rm "$SCRIPT_DIR/data/trace.out"
    kubectl create secret generic simkube --namespace=simkube
    cp -r "$TRACE_FILE" "$SCRIPT_DIR/data/trace.out"
    kubectl create -f "$NODE_FILE"
    cd "$SCRIPT_DIR/simkube-src/"
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
            echo "Timeout waiting for simulation to reach state $WANTED_STATE"
            TIMEOUT_REACHED="true"
            break
        fi
        echo -ne "Waiting for simulation to reach state $WANTED_STATE. Elapsed: $ELAPSED_TIME seconds.\r";
        sleep 1;
    done
}

watch_pod_scheduling(){
    wait_for_simulator_state "Running"
    if [[ "$RUN_CONDITION" = "true" && "$TIMEOUT_REACHED" = "false" ]]; then
        echo ""
        while [ $(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l) -lt 2 ]; do
            sleep 1
        done
        echo "Waiting for the count of pending pods to stabilize..."

        local PREVIOUS_PENDING_COUNT=-1
        local CURRENT_PENDING_COUNT=0
        local PENDING_PODS

        mapfile -t PENDING_PODS < <(kubectl get pods --field-selector=status.phase=Pending -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' --no-headers 2>/dev/null || true)
        CURRENT_PENDING_COUNT="${#PENDING_PODS[@]}"

        while [[ "$CURRENT_PENDING_COUNT" -ne "$PREVIOUS_PENDING_COUNT" ]]; do
            PREVIOUS_PENDING_COUNT="$CURRENT_PENDING_COUNT"
            mapfile -t PENDING_PODS < <(kubectl get pods --field-selector=status.phase=Pending -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' --no-headers 2>/dev/null || true)
            CURRENT_PENDING_COUNT="${#PENDING_PODS[@]}"
            echo "Current pending count: $CURRENT_PENDING_COUNT, Previous: $PREVIOUS_PENDING_COUNT"
            sleep 1
        done

        echo ""
        local LOCAL_RUN_CONDITION="true"
        while [[ $LOCAL_RUN_CONDITION = "true" ]]; do
            mapfile -t PENDING_PODS < <(kubectl get pods --field-selector=status.phase=Pending -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' --no-headers 2>/dev/null || true)
            CURRENT_PENDING_COUNT="${#PENDING_PODS[@]}"

            if [[ $CURRENT_PENDING_COUNT -eq 0 ]]; then
                echo "All pods scheduled successfully"
                break
            fi
            local FAILURE_COUNT=0
            for pod_name in ${PENDING_PODS[@]}; do
                local FAILURE_DETECTED
                FAILURE_DETECTED=$(kubectl get events -n "$NAMESPACE" \
                    --field-selector "involvedObject.name=$pod_name" 2>/dev/null | \
                    grep -E "(FailedScheduling|Insufficient cpu|Insufficient memory|No preemption victims found)" || true)

                if [[ -n "$FAILURE_DETECTED" ]]; then
                    FAILURE_COUNT=$((FAILURE_COUNT + 1))
                fi
            done

            if [[ $CURRENT_PENDING_COUNT -gt 0 && $FAILURE_COUNT -eq $CURRENT_PENDING_COUNT ]]; then
                echo "All pending pods can not be scheduled." >&2
                echo "RUN: $CURRENT_RUN" >> "$SCRIPT_DIR/debug.log"
                echo "Reasons:" >> "$SCRIPT_DIR/debug.log"
                for pod in "${PENDING_PODS[@]}"; do
                    kubectl get events -n "$NAMESPACE" --no-headers --field-selector "involvedObject.name=${pod}" 2>/dev/null >> "$SCRIPT_DIR/debug.log"
                done
                echo "---------------------------------------------------------------------------------------" >> "$SCRIPT_DIR/debug.log"
                break
            fi

            echo "Pending pods: $CURRENT_PENDING_COUNT"
            sleep 1
        done
        UNSCHEDULED_PODS=${CURRENT_PENDING_COUNT:-0}
    else
        echo "Simulation failed"
    fi
}

parse_args "$@"

echo "Starting Simkube experiments"
echo "Cluster: $CLUSTER_NAME"
echo "Runs per experiment: $RUNS"
echo "Results file: $OUT_FILE"

if [[ ! -f "$OUT_FILE" ]]; then
    echo "node_count|pod_count|run_time|total_cpu_seconds|user_cpu_seconds|system_cpu_seconds|memory_peak_gb|unscheduled_pods" > "$OUT_FILE"
fi
trap 'RUN_CONDITION=false; cleanup_cluster; exit 130' SIGINT SIGTERM

for node_file in $(find "$EXPERIMENT_FILES_PATH" -name "simkube-nodes-*.yaml" -type f | sort -V); do
    NODE_COUNT=$(basename "$node_file" | grep -o '[0-9]\+' | tail -1)
    if [[ $NODE_COUNT -lt $START ]]; then
        echo "Skipping $NODE_COUNT nodes"
        continue
    fi
    POD_FILE="$EXPERIMENT_FILES_PATH/simkube-pods-$NODE_COUNT.yaml"
    POD_COUNT=$(cat "$POD_FILE" | grep -c 'kind: Pod')
    TRACE_FILE="$EXPERIMENT_FILES_PATH/simkube-$NODE_COUNT-trace.out"

    echo "Node file: $node_file"
    echo "Pod file: $POD_FILE"
    echo "Trace file: $TRACE_FILE"

    for CURRENT_RUN in $(seq 1 $RUNS); do
        cd $SCRIPT_DIR
        echo "Starting run $CURRENT_RUN for $NODE_COUNT nodes..."
        if [[ $RUN_CONDITION = "false" ]]; then
            echo "Experiment interrupted"
            break
        fi

        TIMEOUT_REACHED="false"

        echo -n "$NODE_COUNT|" >> "$OUT_FILE"
        echo -n "$POD_COUNT|" >> "$OUT_FILE"
        START_TIME=$(date +%s)

        POLL_PID=-1
        SETUP_OK="false"
        if create_cluster && cluster_setup; then
            track_containers $START_TIME > "$LOG_FILE" 2>&1 &
            POLL_PID=$!
            SETUP_OK="true"
        fi
        # set -euxo pipefail

        UNSCHEDULED_PODS=0
        if [[ $SETUP_OK = "true" ]] && deploy_objects "$node_file" "$TRACE_FILE"; then
            watch_pod_scheduling
        fi
        if [[ $POLL_PID -ne -1 ]]; then
            kill -SIGINT "$POLL_PID" 2>/dev/null || true
            wait "$POLL_PID" 2>/dev/null || true
        fi
        echo "|$UNSCHEDULED_PODS" >> "$OUT_FILE"
        cleanup_cluster
    done
done

echo "All experiments completed. Results written to: $OUT_FILE"
