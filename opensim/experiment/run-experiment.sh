#!/bin/bash

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DEFAULT_CLUSTER_NAME="testing"
readonly DEFAULT_RUNS=1
readonly DEFAULT_MEMORY_THRESHOLD=95
readonly CGROUP_BASE="/sys/fs/cgroup/system.slice"
readonly POLL_TIMEOUT=1
readonly LOG_FILE="$SCRIPT_DIR/experiment.log"
readonly SIMON_LOG_FILE="$SCRIPT_DIR/simon.log"
readonly MAIN_SCRIPT_PID=$$
readonly CGROUP_NAME="opensim"
readonly CGROUP_PATH="/sys/fs/cgroup/$CGROUP_NAME"
readonly UNSCHEDULED_FILE="$SCRIPT_DIR/unscheduled.out"

POLL_PID=-1
EXPERIMENT_PID=-1
RUN_CONDITION="true"

usage() {
    cat << EOF
Usage: $(basename "$0") -e EXPERIMENT_PATH [-r RUNS] [-t MEMORY_THRESHOLD]

Required arguments:
    -e EXPERIMENT_PATH   Path to experiment files directory

Optional arguments:
    -r RUNS             Number of runs per experiment (default: $DEFAULT_RUNS)
    -t MEMORY_THRESHOLD Memory threshold percentage (default: $DEFAULT_MEMORY_THRESHOLD)
    -h                  Show this help message

Example:
    $(basename "$0") -e ./experiments -r 5
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
            e) EXPERIMENT_FILES_PATH="$OPTARG" ;;
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

    OUT_FILE="$SCRIPT_DIR/run-opensim.csv"
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

get_memory_usage(){
    local CGROUP_MEM_PATH="$CGROUP_PATH/memory.current"
    if [[ -f "$CGROUP_MEM_PATH" ]]; then
        cat "$CGROUP_MEM_PATH" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

get_cpu_usage(){
    local CGROUP_CPU_PATH="$CGROUP_PATH/cpu.stat"
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

    trap 'RUN_CONDITION=false' SIGINT SIGTERM

    while [[ $RUN_CONDITION = "true" ]]; do

        local CPU_MEASUREMENTS=($(get_cpu_usage))
        local TOTAL_MEM=$(get_memory_usage)

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

create_cgroup(){
    echo "Superuser needed to create cgroup."
    sudo cgcreate -g memory,cpu:/$CGROUP_NAME
}

run_experiment(){
    local SIMON_FILE="$1"
    echo "" >> $UNSCHEDULED_FILE
    echo "Superuser needed to run experiment under a cgroup."
    sudo cgexec -g memory,cpu:/$CGROUP_NAME "$SCRIPT_DIR/cmd" apply -f $SIMON_FILE > $SIMON_LOG_FILE 2>&1 &  #/dev/null
    EXPERIMENT_PID=$!
    while kill -0 "$EXPERIMENT_PID" 2>/dev/null; do
        if [[ $RUN_CONDITION = "false" ]]; then
            echo "Terminating experiment process..."
            sudo kill -TERM "$EXPERIMENT_PID" 2>/dev/null || true
            sleep 2
            # Force kill if still running
            if kill -0 "$EXPERIMENT_PID" 2>/dev/null; then
                sudo kill -KILL "$MAIN_SCRIPT_PID" 2>/dev/null || true
            fi
            break
        fi
        sleep 1
    done
    wait "$EXPERIMENT_PID" 2>/dev/null || true
    EXPERIMENT_PID=-1
}

cleanup(){
    echo "Superuser needed to delete cgroup."
    sudo cgdelete memory,cpu:/$CGROUP_NAME || true
}

parse_args "$@"

echo "Starting Kubemark experiments"
echo "Cluster: $CLUSTER_NAME"
echo "Runs per experiment: $RUNS"
echo "Results file: $OUT_FILE"

echo "node_count|pod_count|run_time|total_cpu_seconds|user_cpu_seconds|system_cpu_seconds|memory_peak_gb|unscheduled_pods" > "$OUT_FILE"
trap 'RUN_CONDITION=false; cleanup; exit 130' SIGINT SIGTERM

for simon_file in $(find "$EXPERIMENT_FILES_PATH" -name "simon-config-*.yaml" -type f | sort -V); do
    if [[ $RUN_CONDITION = "false" ]]; then
        echo "Experiment interrupted"
        break
    fi

    NODE_COUNT=$(basename "$simon_file" | grep -o '[0-9]\+' | tail -1)
    POD_FILE="$EXPERIMENT_FILES_PATH/applications/pods-$NODE_COUNT/opensim-pods-$NODE_COUNT.yaml"
    POD_COUNT=$(cat "$POD_FILE" | grep -c 'kind: Pod')

    for CURRENT_RUN in $(seq 1 $RUNS); do
        if [[ $RUN_CONDITION = "false" ]]; then
            echo "Experiment interrupted"
            break
        fi

        echo "Starting run $CURRENT_RUN for $NODE_COUNT nodes..."

        echo -n "$NODE_COUNT|" >> "$OUT_FILE"
        echo -n "$POD_COUNT|" >> "$OUT_FILE"
        START_TIME=$(date +%s)

        SETUP_OK="false"
        if create_cgroup $CGROUP_NAME; then
            track_containers $START_TIME > "$LOG_FILE" 2>&1 &
            POLL_PID=$!
            SETUP_OK="true"
        fi
        # set -euxo pipefail

        UNSCHEDULED_PODS=0
        if [[ $SETUP_OK = "true" ]]; then
            run_experiment "$simon_file"
            if [[ -f "$UNSCHEDULED_FILE" ]]; then
                UNSCHEDULED_PODS=$(cat "$UNSCHEDULED_FILE")
            fi
        fi

        kill -SIGINT "$POLL_PID" 2>/dev/null || true
        wait "$POLL_PID" 2>/dev/null || true
        echo "|$UNSCHEDULED_PODS" >> "$OUT_FILE"
        cleanup
    done
done

echo "All experiments completed. Results written to: $OUT_FILE"
