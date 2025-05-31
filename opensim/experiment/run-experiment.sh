#!/bin/bash

RUNS=3
OUT_FILE="$(pwd)/run-opensim.csv"
CGROUP_BASE="/sys/fs/cgroup/"
EXPERIMENT_FILES_PATH=""

while getopts 'h?r:e:' opt; do
	case "$opt" in
    e)
        EXPERIMENT_FILES_PATH="$OPTARG"
        ;;
	r)
		RUNS="$OPTARG"
		;;
	h)
		echo "Usage: $(basename $0) <-p program-name> <-s script-path> [-d]  [-r runs]"
		exit 0
		;;

	:)
		echo -e "option requires an argument.\nUsage: $(basename $0) <-p program-name> <-s script-path> [-d]  [-r runs]"
		exit 1
		;;

	?)
		echo -e "Invalid command option.\nUsage: $(basename $0) <-p program-name> <-s script-path> [-d] [-r runs]"
		exit 1
		;;
	esac
done
shift "$(($OPTIND - 1))"

was_last_command_success() {
	if [ $? -ne 0 ]; then
		echo "$1"
		exit 1
	fi
}

function track_metrics(){
    CGROUP_PATH=$1
    POLL_TIMEOUT=0.1
    MAX_MEMORY_MEASUREMENT=-1
	RUN_CONDITION="true"
	trap 'RUN_CONDITION=false' SIGINT
	while [ $RUN_CONDITION = "true" ]; do
        if [ -d "$CGROUP_PATH" ]; then
            CURRENT_MEMORY_MEASUREMENT=$(cat "${CGROUP_PATH}/memory.current")
	        if [ $CURRENT_MEMORY_MEASUREMENT -gt ${MAX_MEMORY_MEASUREMENT} ]; then
		        MAX_MEMORY_MEASUREMENT=$CURRENT_MEMORY_MEASUREMENT
	        fi
            CPU_TIMES=($(awk 'NR<=3 {printf "%.2f ", $2/1000000}' "${CGROUP_PATH}/cpu.stat"))
            CPU_MEASUREMENTS=()                
            for ((j=0; j<3; j++)); do
                CPU_MEASUREMENTS[j]+=${CPU_TIMES[j]}
            done
        else
            RUN_CONDITION="false"
            break
        fi
		sleep $POLL_TIMEOUT
	done
    END_TIME=$(date +%s)
    printf "%d" $(($END_TIME - $2)) >> $OUT_FILE
    for ((i=0; i<3; i++)); do
        printf "|%.2f" ${CPU_MEASUREMENTS[i]} >> $OUT_FILE
    done
	printf "|%.2f\n" $(($MAX_MEMORY_MEASUREMENT / 1024 / 1024 / 1024)) >> $OUT_FILE
	exit 0
}

CURRENT_RUNS=0

if [ ! -f $OUT_FILE ]; then
    echo "node_count|run_time|total_cpu_seconds|user_cpu_seconds|system_cpu_seconds|memory_peak_gb" > "$OUT_FILE"
fi
for simon_file in "$EXPERIMENT_FILES_PATH"/"opensim-"nodes*.yaml; do
    NODE_COUNT=$(echo "$simon_file" | rev | cut -d '-' -f 1 | rev | cut -d '.' -f 1 )
    while [ $CURRENT_RUNS -lt $RUNS ]; do
        echo "RUN $CURRENT_RUNS"
	    CGROUP_NAME="opensim"
        echo -ne "$NODE_COUNT|" >> "$OUT_FILE"
	    sudo cgcreate -g memory,cpu:/$CGROUP_NAME
	    was_last_command_success "Failed to create cgroup"
	    echo "$CGROUP_NAME cgroup created"
        START_TIME=$(date +%s)
	    track_metrics "$CGROUP_BASE$CGROUP_NAME" $START_TIME &
	    POLL_PID=$!
	    echo "Poll process started: $POLL_PID"
	    sudo cgexec -g memory,cpu:/$CGROUP_NAME ./cmd apply -f ${simon_file} --output-file /dev/null #opensim-out-${CURRENT_RUNS}.out
	    was_last_command_success "Failed to run program"
	    kill -s SIGINT $POLL_PID
	    sleep 1
	    sudo cgdelete memory,cpu:/$CGROUP_NAME
	    was_last_command_success "Failed to delete cgroup $CGROUP_NAME"
	    echo "cgroup $CGROUP_NAME deleted"
	    CURRENT_RUNS=$(($CURRENT_RUNS + 1))
	    echo -e -n "$CURRENT_RUNS/$RUNS completed runs...\r"
    done
done
