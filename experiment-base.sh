#!/bin/bash

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DEFAULT_CLUSTER_NAME="kwok"
readonly DEFAULT_RUNS=1
readonly DEFAULT_MEMORY_THRESHOLD=95
readonly POLL_TIMEOUT=1
readonly LOG_FILE="$SCRIPT_DIR/experiment.log"
readonly MAIN_SCRIPT_PID=$$
readonly DEFAULT_START=0
readonly DEAFULT_SIMULATION_MODE="kwok"
readonly CGROUP_BASE="/sys/fs/cgroup/system.slice"
readonly DEFAULT_MAX_SIMULATION_TIME=3600
readonly TIMEOUT_FLAG_FILE="${SCRIPT_DIR}/timeout.flag"

CLUSTER_NAME=""
NAMESPACE="paib-gpu"
CONTAINERS_TO_WATCH=""
FILE_PATTERN="nodes-*.yaml"
START=0
RUN_CONDITION="true"
UNSCHEDULED_PODS=0
TIMEOUT_REACHED="false"
usage() {
    cat << EOF
Usage: $(basename "$0") -e EXPERIMENT_PATH -m SIMULATION_MODE [options]

Required arguments:
  -e EXPERIMENT_PATH   Path to experiment files directory
  -m SIMULATION_MODE   Simulator: simkube, kube-sched, kubemark, kwok, opensim

Optional arguments:
  -n RUNS              Number of runs per experiment (default: $DEFAULT_RUNS)
  -s START             Resume from a specific node count (default: $DEFAULT_START)
  -o OUT_FILE          Output file for experiment results
  -t MEMORY_THRESHOLD  Memory threshold percentage (default: $DEFAULT_MEMORY_THRESHOLD)
  -x MAX_SIMULATION_TIME  Max allowed duration for a simulation (default: $DEFAULT_MAX_SIMULATION_TIME)
  -h                   Show this help message

Example:
  $(basename "$0") -e ./experiments -m simkube -n 5 -o results.csv -c my-cluster
EOF
}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    local color_reset="\033[0m"
    local color_info="\033[1;34m"
    local color_warn="\033[1;33m"
    local color_error="\033[1;31m"
    local color_debug="\033[0;37m"
    local color_sim="\033[0;33m"

    local color=""
    case "$level" in
        INFO)  color="$color_info" ;;
        WARN)  color="$color_warn" ;;
        ERROR) color="$color_error" ;;
        DEBUG) color="$color_debug" ;;
        *)     level="INFO"; color="$color_info" ;;
    esac

    local simulator_info=""

    if [[ ! -z "${SIMULATION_MODE}" ]]; then
        if [[ -t 1 ]]; then
            simulator_info=" ${color_sim}${SIMULATION_MODE}${color_reset}:"
        else
            simulator_info=" ${SIMULATION_MODE}:"
        fi
    fi

    if [[ -t 1 ]]; then
        echo -e "${color}[${timestamp}] [${level}]${color_reset}${simulator_info} ${message}"
    else
        echo "[${timestamp}] [${level}]${simulator_info} ${message}"
    fi
}

parse_args() {
    RUNS=$DEFAULT_RUNS
    MEMORY_THRESHOLD=$DEFAULT_MEMORY_THRESHOLD
    START=$DEFAULT_START
    MAX_SIMULATION_TIME=$DEFAULT_MAX_SIMULATION_TIME

    local OPTIND
    while getopts 'he:m:c:n:s:o:p:t:x:' opt; do
        case "$opt" in
            e) EXPERIMENT_FILES_PATH=$(realpath "$OPTARG") ;;
            m) SIMULATION_MODE="$OPTARG" ;;
            n) RUNS="$OPTARG" ;;
            s) START="$OPTARG" ;;
            o) OUT_FILE=$(realpath "$OPTARG") ;;
            t) MEMORY_THRESHOLD="$OPTARG" ;;
            x) MAX_SIMULATION_TIME="$OPTARG" ;;
            h) usage; exit 0 ;;
            :) log ERROR "Option -$OPTARG requires an argument." >&2; usage; exit 1 ;;
            ?) log ERROR "Invalid option -$OPTARG" >&2; usage; exit 1 ;;
        esac
    done

    if [[ -z "$EXPERIMENT_FILES_PATH" || -z "$SIMULATION_MODE" ]]; then
        log ERROR "Missing required arguments -e and -m." >&2
        usage
        exit 1
    fi

    if [[ ! "$SIMULATION_MODE" =~ ^(simkube|kube-sched|kubemark|kwok|opensim)$ ]]; then
        log ERROR "Unsupported simulator '$SIMULATION_MODE'" >&2
        usage
        exit 1
    fi

    if [[ ! -d "$EXPERIMENT_FILES_PATH" ]]; then
        log ERROR "Experiment files path does not exist: $EXPERIMENT_FILES_PATH" >&2
        exit 1
    fi

    if [[ -z $OUT_FILE ]]; then
        OUT_FILE="${SCRIPT_DIR}/results/${SIMULATION_MODE}.csv"
    fi
}

load_simulator_code() {
    local SCRIPT_FILE="./modules/${SIMULATION_MODE}/module.sh"

    if [[ -f "$SCRIPT_FILE" ]]; then
        source "$SCRIPT_FILE"
    else
        log ERROR "Script for simulator '$SIMULATION_MODE' not found at $SCRIPT_FILE" >&2
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
    for name in "${CONTAINERS_TO_WATCH[@]}"; do
        docker ps --no-trunc -aqf "name=$name" 2>/dev/null || true
    done
}

get_cgroup_base(){
    local IS_CONTAINER="$1"
    local PROGRAM_INFO="$2"
    echo "Container: $IS_CONTAINER, container mode: $CONTAINERIZED" >> /test.temp
    if [[ $IS_CONTAINER = "true" ]]; then
        if [[ ! -z $CONTAINERIZED ]]; then
            echo "/sys/fs/cgroup/docker/${PROGRAM_INFO}"
            echo "/sys/fs/cgroup/docker/${PROGRAM_INFO}" >> /test.temp
        else
            echo "${CGROUP_BASE}/docker-${PROGRAM_INFO}.scope"
        fi
    else
        echo "/sys/fs/cgroup/$PROGRAM_INFO"
    fi

}

get_memory_usage(){
    local IS_CONTAINER="$1"
    local PROGRAM_INFO="$2"
    local APP_CGROUP_BASE="$(get_cgroup_base "$IS_CONTAINER" "$PROGRAM_INFO")"
    local CGROUP_MEM_PATH

    CGROUP_MEM_PATH="${APP_CGROUP_BASE}/memory.current"

    if [[ -f "$CGROUP_MEM_PATH" ]]; then
        MEM_USAGE=$(cat "$CGROUP_MEM_PATH" 2>/dev/null || echo "0")
        echo "$MEM_USAGE"
    else
        echo "0"
    fi
}

get_cpu_usage(){
    local IS_CONTAINER="$1"
    local PROGRAM_INFO="$2"
    local APP_CGROUP_BASE="$(get_cgroup_base "$IS_CONTAINER" "$PROGRAM_INFO")"
    local CGROUP_CPU_PATH

    CGROUP_CPU_PATH="${APP_CGROUP_BASE}/cpu.stat"

    if [[ -f "$CGROUP_CPU_PATH" ]]; then
        CPU_USAGE=$(awk '/usage_usec/ {usage=$2/1000000} /user_usec/ {user=$2/1000000} /system_usec/ {sys=$2/1000000} END {printf "%.0f %.0f %.0f", usage, user, sys}' "$CGROUP_CPU_PATH" 2>/dev/null || echo "0 0 0")
        echo "$CPU_USAGE"
    else
        echo "0 0 0"
    fi
}

metric_collector(){
    local TYPE="$1"
    mapfile -t CONTAINER_IDS < <(get_container_ids)
    if [[ ${#CONTAINER_IDS[@]} -eq 0 ]]; then
        RUN_CONDITION="false"
        if [[ "$TYPE" = "memory" ]]; then
            echo "0"
        elif [[ "$TYPE" = "cpu" ]]; then
            echo "0 0 0"
        fi
    else
        if [[ "$TYPE" = "memory" ]]; then
            local TOTAL_MEM=0
            for ID in "${CONTAINER_IDS[@]}"; do
                [[ -z "$ID" ]] && continue
                TOTAL_MEM=$(( TOTAL_MEM + $(get_memory_usage "true" "$ID") ))
            done
            echo "$TOTAL_MEM"

        elif [[ "$TYPE" = "cpu" ]]; then
            local CPU_TOTAL=(0 0 0)
            for ID in "${CONTAINER_IDS[@]}"; do
                [[ -z "$ID" ]] && continue
                local METRICS=($(get_cpu_usage "true" "$ID"))
                for j in {0..2}; do
                    CPU_TOTAL[j]=$(( ${CPU_TOTAL[j]:-0} + ${METRICS[j]:-0} ))
                done
            done
            echo "${CPU_TOTAL[@]}"
        fi
    fi

}

save_metrics() {
    local START_TIME="$1"
    local MAX_MEMORY_MEASUREMENT="$2"
    shift 2
    local CPU_MEASUREMENTS=("$@")
    local END_TIME=$(date +%s)
    local RUNTIME=$((END_TIME - START_TIME))

    local MEMORY_GB CPU_TOTAL_SEC CPU_USER_SEC CPU_SYS_SEC
    MEMORY_GB=$(awk "BEGIN {printf \"%.2f\", $MAX_MEMORY_MEASUREMENT / 1024 / 1024 / 1024}")
    CPU_TOTAL_SEC=$(awk "BEGIN {printf \"%.2f\", ${CPU_MEASUREMENTS[0]}}")
    CPU_USER_SEC=$(awk "BEGIN {printf \"%.2f\", ${CPU_MEASUREMENTS[1]}}")
    CPU_SYS_SEC=$(awk "BEGIN {printf \"%.2f\", ${CPU_MEASUREMENTS[2]}}")

    TIMEOUT_REACHED="0"
    if [[ -f $TIMEOUT_FLAG_FILE ]]; then
        rm $TIMEOUT_FLAG_FILE
        TIMEOUT_REACHED="1"
    fi

    printf "%s|%d|%s|%s|%s|%s" \
        "$TIMEOUT_REACHED" \
        "$RUNTIME" \
        "$CPU_TOTAL_SEC" \
        "$CPU_USER_SEC" \
        "$CPU_SYS_SEC" \
        "$MEMORY_GB"  >> "$OUT_FILE"
}

watch_pod_scheduling(){
    wait_for_simulator_state "Running"
    if [[ "$RUN_CONDITION" = "true" && "$TIMEOUT_REACHED" = "false" ]]; then
        echo ""
        while [[ $(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l) -lt 2  && $RUN_CONDITION = "true" ]]; do
            sleep 1
        done
        log INFO "Waiting for the count of pending pods to stabilize..."

        local PREVIOUS_PENDING_COUNT=-1
        local CURRENT_PENDING_COUNT=0
        local PENDING_PODS

        mapfile -t PENDING_PODS < <(kubectl get pods --field-selector=status.phase=Pending -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' --no-headers 2>/dev/null || true)
        CURRENT_PENDING_COUNT="${#PENDING_PODS[@]}"

        while [[ "$CURRENT_PENDING_COUNT" -ne "$PREVIOUS_PENDING_COUNT" ]]; do
            PREVIOUS_PENDING_COUNT="$CURRENT_PENDING_COUNT"
            mapfile -t PENDING_PODS < <(kubectl get pods --field-selector=status.phase=Pending -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' --no-headers 2>/dev/null || true)
            CURRENT_PENDING_COUNT="${#PENDING_PODS[@]}"
            log INFO "Current pending count: $CURRENT_PENDING_COUNT, Previous: $PREVIOUS_PENDING_COUNT"
            sleep 1
        done

        echo ""
        local LOCAL_RUN_CONDITION="true"
        while [[ $LOCAL_RUN_CONDITION = "true" ]]; do
            mapfile -t PENDING_PODS < <(kubectl get pods --field-selector=status.phase=Pending -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' --no-headers 2>/dev/null || true)
            CURRENT_PENDING_COUNT="${#PENDING_PODS[@]}"

            if [[ $CURRENT_PENDING_COUNT -eq 0 ]]; then
                log INFO "All pods scheduled successfully"
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
                log INFO "All pending pods can not be scheduled." >&2
                break
            fi

            log INFO "Pending pods: $CURRENT_PENDING_COUNT"
            sleep 1
        done
        UNSCHEDULED_PODS=${CURRENT_PENDING_COUNT:-0}
    else
        log ERROR "Simulation failed"
    fi
}

# Entry point
log INFO "Received arguments $@"
parse_args "$@"
# Functions are overwritten in this part
# It is done here to avoid overriding the function track_containers
load_simulator_code $SIMULATION_MODE

track_containers() {
    log INFO "Starting container tracking..."
    local MAX_MEM_ALLOTED=$(get_max_alloted_memory)
    local MAX_MEMORY_MEASUREMENT=0
    local START_TIME="$1"
    local RUN_CONDITION="true"
    trap 'RUN_CONDITION=false' SIGINT SIGTERM

    while [[ $RUN_CONDITION = "true" ]]; do
        local CPU_MEASUREMENTS TOTAL_MEM
        read -r -a CPU_MEASUREMENTS <<< "$(metric_collector cpu)"
        TOTAL_MEM=$(metric_collector memory)
        if [[ $TOTAL_MEM -gt $MAX_MEMORY_MEASUREMENT ]]; then
            MAX_MEMORY_MEASUREMENT=$TOTAL_MEM
        fi

        if [[ $TOTAL_MEM -gt $MAX_MEM_ALLOTED ]]; then
            break
        fi

        ELAPSED_TIME=$(( $(date +%s) - START_TIME ))

        if [[ $ELAPSED_TIME -gt $MAX_SIMULATION_TIME ]]; then
            RUN_CONDITION="false"
            log ERROR "Simulation time exceeded: $ELAPSED_TIME seconds."
            touch $TIMEOUT_FLAG_FILE
            break
        fi

        sleep "$POLL_TIMEOUT"
    done

    save_metrics "$START_TIME" "$MAX_MEMORY_MEASUREMENT" "${CPU_MEASUREMENTS[@]}"

}

log INFO "Simulation started with mode: $SIMULATION_MODE"
if [[ ! -z $CLUSTER_NAME ]]; then
    log INFO "Cluster: $CLUSTER_NAME"
fi
log INFO "Runs per experiment: $RUNS"
log INFO "Results file: $OUT_FILE"

if [[ -f "${OUT_FILE}" ]]; then
    BASE_NAME="${OUT_FILE%.*}"
    OLD_OUT_FILE="$OUT_FILE"
    i=1

    while [[ -e "${OLD_OUT_FILE}" ]]; do
        OLD_OUT_FILE="${BASE_NAME}-${i}.csv"
        ((i++))
    done

    mv "${OUT_FILE}" "${OLD_OUT_FILE}"
fi

echo "node_count|pod_count|timeout_reached|run_time|total_cpu_seconds|user_cpu_seconds|system_cpu_seconds|memory_peak_gb|unscheduled_pods" > "$OUT_FILE"

trap 'RUN_CONDITION=false; cleanup_cluster; exit 130' SIGINT SIGTERM

for node_file in $(find "$EXPERIMENT_FILES_PATH" -name $FILE_PATTERN -type f | sort -V); do
    NODE_COUNT=$(basename "$node_file" | grep -o '[0-9]\+' | tail -1)
    if [[ $NODE_COUNT -lt $START ]]; then
        log INFO "Skipping $NODE_COUNT nodes"
        continue
    fi

    POD_FILE="$EXPERIMENT_FILES_PATH/pods-$NODE_COUNT.yaml"
    POD_COUNT=$(cat "$POD_FILE" | grep -c 'kind: Pod')

    if [[ $SIMULATION_MODE = "simkube" ]]; then
        POD_FILE="$EXPERIMENT_FILES_PATH/trace-$NODE_COUNT.sktrace"
    fi

    log INFO "Node file: $node_file"
    log INFO "Pod file: $POD_FILE"

    for CURRENT_RUN in $(seq 1 $RUNS); do
        cd $SCRIPT_DIR
        log INFO "Starting run $CURRENT_RUN for $NODE_COUNT nodes..."
        if [[ $RUN_CONDITION = "false" ]]; then
            log INFO "Experiment interrupted"
            break
        fi

        TIMEOUT_REACHED="false"

        echo -n "$NODE_COUNT|" >> "$OUT_FILE"
        echo -n "$POD_COUNT|" >> "$OUT_FILE"
        START_TIME=$(date +%s)

        POLL_PID=-1
        SETUP_OK="false"
        log INFO "Starting cluster setup..."
        create_cluster
        CREATE_CLUSTER_STATUS=$?
        cluster_setup
        CREATE_CLUSTER_SETUP_STATUS=$?
        if [[ $CREATE_CLUSTER_STATUS -eq 0 && $CREATE_CLUSTER_SETUP_STATUS -eq 0 ]]; then
            log INFO "Cluster setup successful"
            track_containers $START_TIME &
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

log INFO "All experiments completed. Results written to: $OUT_FILE"
