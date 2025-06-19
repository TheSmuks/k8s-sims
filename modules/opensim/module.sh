#!/bin/bash
readonly LOCAL_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CGROUP_NAME="opensim"
readonly TEMP_OUT="${LOCAL_PATH}/temp.out"
FILE_PATTERN="simon-config-*.yaml"
BINARY_PATH="${LOCAL_PATH}/cmd"

echo $BINARY_PATH >> /test.tmp
metric_collector(){
    local TYPE="$1"
    if [[ "$TYPE" == "cpu" ]]; then
        CPU_USAGE=$(get_cpu_usage "false" "$CGROUP_NAME")
        echo "$CPU_USAGE"
    elif [[ "$TYPE" == "memory" ]]; then
        MEM_USAGE=$(get_memory_usage "false" "$CGROUP_NAME")
        echo "$MEM_USAGE"
    fi
}

create_cluster(){
    echo "Superuser needed to create cgroup."

    if [[ -d "/sys/fs/cgroup/$CGROUP_NAME" ]]; then
        log WARN "Cgroup already exists: $CGROUP_NAME"
        sudo cgdelete -g memory,cpu:/$CGROUP_NAME
    fi

    sudo cgcreate -g memory,cpu:/$CGROUP_NAME

    if [[ ! -d "/sys/fs/cgroup/$CGROUP_NAME" ]]; then
        log ERROR "Failed to create cgroup: $CGROUP_NAME"
        return 1
    fi

    log INFO "Created cgroup: $CGROUP_NAME"
}

cluster_setup(){
    local MEMORY_PATH="/sys/fs/cgroup/$CGROUP_NAME/memory.current"
    local CPU_PATH="/sys/fs/cgroup/$CGROUP_NAME/cpu.stat"

    if [[ ! -f "$MEMORY_PATH" ]]; then
        log WARN "Memory monitoring file not found: $MEMORY_PATH"
    fi

    if [[ ! -f "$CPU_PATH" ]]; then
        log WARN "CPU monitoring file not found: $CPU_PATH"
    fi

    log INFO "Cgroup setup completed"
}

cleanup_cluster(){
    echo "Superuser needed to delete cgroup."
    if [[ -f "/sys/fs/cgroup/$CGROUP_NAME/cgroup.procs" ]]; then
        local PIDS
        PIDS=$(sudo cat "/sys/fs/cgroup/$CGROUP_NAME/cgroup.procs" 2>/dev/null || true)
        if [[ -n "$PIDS" ]]; then
            echo "Terminating processes in cgroup: $PIDS"
            echo "$PIDS" | xargs -r sudo kill -TERM 2>/dev/null || true
            sleep 2
            # Force kill if still running
            PIDS=$(sudo cat "/sys/fs/cgroup/$CGROUP_NAME/cgroup.procs" 2>/dev/null || true)
            if [[ -n "$PIDS" ]]; then
                echo "$PIDS" | xargs -r sudo kill -KILL 2>/dev/null || true
            fi
        fi
    fi

    sudo cgdelete memory,cpu:/$CGROUP_NAME 2>/dev/null || true
    log INFO "Cleaned up cgroup: $CGROUP_NAME"
}

deploy_objects(){
    local SIMON_FILE="$1"
    local EXPERIMENT_PATH="$(cd "$(dirname "$1")" && pwd)"
    echo $SIMON_FILE
    echo "Superuser needed to run experiment under a cgroup."
    LAST_PATH=$(pwd)
    cd $EXPERIMENT_PATH
    sudo cgexec -g memory,cpu:/$CGROUP_NAME ${BINARY_PATH} apply -f $SIMON_FILE > ${TEMP_OUT} &
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
    cd $LAST_PATH
    wait "$EXPERIMENT_PID" 2>/dev/null || true
    until [[ -f ${TEMP_OUT} ]]; do
        sleep 1
    done
    UNSCHEDULED_PODS=$(awk '/Unscheduled:/ {printf "%d", $2}' ${TEMP_OUT})
    rm ${TEMP_OUT}
    EXPERIMENT_PID=-1
}

watch_pod_scheduling(){
    #Dummy function
    :;
}

wait_for_simulator_state(){
    #Dummy function
    :;
}

log INFO "OpenSimulator module loaded!"
