#!/bin/bash
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DEFAULT_RUNS=1
readonly DEFAULT_MEMORY_THRESHOLD=95
readonly CGROUP_BASE="/sys/fs/cgroup/system.slice"
readonly POLL_TIMEOUT=1
readonly LOG_FILE="$SCRIPT_DIR/experiment.log"
readonly MAIN_SCRIPT_PID=$$
RUN_CONDITION="true"
KUBE_FILE="$SCRIPT_DIR/kubeconfig.yaml"
CONTAINERS_TO_WATCH=(simulator-scheduler simulator-server simulator-cluster)
UNSCHEDULED_PODS=0

usage() {
    cat << EOF
Usage: $(basename "$0") -e EXPERIMENT_PATH [-c CLUSTER_NAME] [-r RUNS] [-t MEMORY_THRESHOLD]

Required arguments:
    -e EXPERIMENT_PATH   Path to experiment files directory

Optional arguments:
    -r RUNS             Number of runs per experiment (default: $DEFAULT_RUNS)
    -t MEMORY_THRESHOLD Memory threshold percentage (default: $DEFAULT_MEMORY_THRESHOLD)
    -h                  Show this help message

Example:
    $(basename "$0") -c my-cluster -e ./experiments -r 5
EOF
}

parse_args() {
    CLUSTER_NAME=$DEFAULT_CLUSTER_NAME
    RUNS=$DEFAULT_RUNS
    MEMORY_THRESHOLD=$DEFAULT_MEMORY_THRESHOLD

    local OPTIND
    while getopts 'hc:r:e:t:' opt; do
        case "$opt" in
            c) CLUSTER_NAME="$OPTARG" ;;
            r) RUNS="$OPTARG" ;;
            e) EXPERIMENT_FILES_PATH=$(realpath "$OPTARG") ;;
            t) MEMORY_THRESHOLD="$OPTARG" ;;
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

    OUT_FILE="$SCRIPT_DIR/run-kube-sched.csv"
}

get_max_alloted_memory(){
    local CURRENT_FREE_MEMORY
    CURRENT_FREE_MEMORY=$(awk '/MemFree/ {free=$2} /^Cached:/ {cached=$2} END { print (free + cached) * 1024 }' /proc/meminfo)
    local MAX_MEM_ALLOTED=$(($CURRENT_FREE_MEMORY*$MEMORY_THRESHOLD/100))
    echo $MAX_MEM_ALLOTED
}

get_container_ids(){
    for name in "${CONTAINERS_TO_WATCH[@]}"; do
        docker ps --no-trunc -aqf "name=$name"
    done
}

get_cgroup_base(){
    local PROGRAM_INFO="$1"
    local CGROUP_BASE_PATH="$CGROUP_BASE/docker-$PROGRAM_INFO"
    echo "$CGROUP_BASE_PATH"
}

get_memory_usage(){
    local CGROUP_MEM_PATH="$(get_cgroup_base "$1").scope/memory.current"
    if [[ -f "$CGROUP_MEM_PATH" ]]; then
        cat "$CGROUP_MEM_PATH" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

get_cpu_usage(){
    local CGROUP_CPU_PATH="$(get_cgroup_base "$1").scope/cpu.stat"
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

            local CURRENT_MEMORY_MEASUREMENT=$(get_memory_usage "${CONTAINER_IDS[i]}")
            TOTAL_MEM=$((TOTAL_MEM + CURRENT_MEMORY_MEASUREMENT))

            local CONTAINER_CPU_MEASUREMENT=($(get_cpu_usage "${CONTAINER_IDS[i]}"))
            for j in {0..2}; do
                CPU_MEASUREMENTS[j]=$(( ${CPU_MEASUREMENTS[j]:-0} + ${CONTAINER_CPU_MEASUREMENT[j]:-0} ))
            done
        done

        if [[ $TOTAL_MEM -gt $MAX_MEMORY_MEASUREMENT ]]; then
            MAX_MEMORY_MEASUREMENT=$TOTAL_MEM
        fi

        if [[ $TOTAL_MEM -gt $MAX_MEM_ALLOTED ]]; then
            RUN_CONDITION="false"
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
    cd $SCRIPT_DIR
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
    cd "$SCRIPT_DIR/simulator-src"
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

watch_pod_scheduling(){
    while [ $(kubectl get pods -n paib-gpu --no-headers | wc -l) -eq 0 ]; do
      sleep 1
    done
    while true; do
        local PENDING_PODS_COUNT
        PENDING_PODS_COUNT=$(kubectl get pods --field-selector=status.phase=Pending -n paib-gpu --no-headers 2>/dev/null | wc -l)

        if [[ $PENDING_PODS_COUNT -eq 0 ]]; then
            echo "All pods scheduled successfully"
            break
        fi

        local PENDING_PODS
        PENDING_PODS=$(kubectl get pods --field-selector=status.phase=Pending -n paib-gpu -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)

        local FAILURE_COUNT=0
        for pod_name in $PENDING_PODS; do
            local FAILURE_DETECTED
            FAILURE_DETECTED=$(kubectl get events -n paib-gpu \
                --field-selector "involvedObject.name=$pod_name" 2>/dev/null | \
                grep -E "(FailedScheduling|Insufficient cpu|Insufficient memory|No preemption victims found)" || true)

            if [[ -n "$FAILURE_DETECTED" ]]; then
                FAILURE_COUNT=$((FAILURE_COUNT + 1))
            fi
        done

        if [[ $FAILURE_COUNT -ge $PENDING_PODS_COUNT && $PENDING_PODS_COUNT -gt 0 ]]; then
            echo "All pending pods can not be scheduled." >&2
            break
        fi

        echo "Pending pods: $PENDING_PODS_COUNT"
        sleep 1
    done
    UNSCHEDULED_PODS=${PENDING_PODS_COUNT:-0}
}

parse_args "$@"

echo "Starting Kube-Scheduler-Simulator experiments"
echo "Cluster: $CLUSTER_NAME"
echo "Runs per experiment: $RUNS"
echo "Results file: $OUT_FILE"

echo "node_count|pod_count|run_time|total_cpu_seconds|user_cpu_seconds|system_cpu_seconds|memory_peak_gb|unscheduled_pods" > "$OUT_FILE"
trap 'RUN_CONDITION=false; cleanup_cluster; exit 130' SIGINT SIGTERM

for node_file in $(find "$EXPERIMENT_FILES_PATH" -name "nodes-*.yaml" -type f | sort -V); do
    NODE_COUNT=$(basename "$node_file" | grep -o '[0-9]\+' | tail -1)
    POD_FILE="$EXPERIMENT_FILES_PATH/pods-$NODE_COUNT.yaml"
    POD_COUNT=$(cat "$POD_FILE" | grep -c 'kind: Pod')
    for CURRENT_RUN in $(seq 1 $RUNS); do
        echo "Starting run $CURRENT_RUN for $NODE_COUNT nodes..."
        if [[ $RUN_CONDITION = "false" ]]; then
            echo "Experiment interrupted"
            break
        fi

        echo -n "$NODE_COUNT|" >> "$OUT_FILE"
        echo -n "$POD_COUNT|" >> "$OUT_FILE"
        START_TIME=$(date +%s)

        # set -euxo pipefail
        POLL_PID=-1
        SETUP_OK="false"
        if create_cluster && cluster_setup; then
            echo "Cluster setup successful"
            track_containers "$START_TIME" &
            POLL_PID=$!
            SETUP_OK="true"
        fi

        UNSCHEDULED_PODS=0
        if [[ $SETUP_OK = "true" ]] && deploy_objects "$node_file" "$POD_FILE"; then
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
