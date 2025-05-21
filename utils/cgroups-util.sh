#!/bin/bash

was_last_command_success(){
	if [ $? -ne 0 ]; then
		echo "$1"
		exit 1
	fi
}

poll_memory_peak(){
	POLL_TIMEOUT=0.1
	MAX_MEMORY_MEASUREMENT=-1
	RUN_CONDITION=true
	trap 'RUN_CONDITION=false' SIGINT
	while [ $RUN_CONDITION = "true" ]; do
		CURRENT_MEMORY_MEASUREMENT=$(cat $1)
		if [ $CURRENT_MEMORY_MEASUREMENT -gt $MAX_MEMORY_MEASUREMENT ]; then
			MAX_MEMORY_MEASUREMENT=$CURRENT_MEMORY_MEASUREMENT
		fi
		sleep $POLL_TIMEOUT
	done
	printf "|%.2f\n" $(($MAX_MEMORY_MEASUREMENT/1024/1024/1024)) >> $2
	exit 0
}

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <group_name> <program> [runs]"
    exit 1
fi

RUNS=3

if [ "$#" -gt 2 ]; then
	RUNS=$3
fi

CURRENT_RUNS=0
CGROUP_BASE="/sys/fs/cgroup/"
RUN_OUT="./run.csv"
echo "run_time|cpu_seconds_time|memory_peak" > "$RUN_OUT" 
while [ $CURRENT_RUNS -lt $RUNS ]
do
	CGROUP_NAME="$1-$CURRENT_RUNS"
	sudo cgcreate -g memory,cpu:/$CGROUP_NAME
	was_last_command_success "Failed to create cgroup"
	echo "$CGROUP_NAME cgroup created"
	poll_memory_peak "$CGROUP_BASE$CGROUP_NAME/memory.current" $RUN_OUT &
	POLL_PID=$!
	echo "Poll process started: $POLL_PID"
	START_TIME=$(date +%s)
	sudo cgexec -g memory,cpu:/$CGROUP_NAME $2
	was_last_command_success "Failed to run program"
	END_TIME=$(date +%s)
	printf "%d" $(($END_TIME-$START_TIME)) >> "$RUN_OUT"
	awk 'NR==1 {printf "|%.2f", $2/1000000}' "$CGROUP_BASE$CGROUP_NAME/cpu.stat" >> "$RUN_OUT"
	kill -s SIGINT $POLL_PID
	sleep 1 
	sudo cgdelete memory,cpu:/$CGROUP_NAME
	was_last_command_success "Failed to delete cgroup $CGROUP_NAME"
	echo "cgroup $CGROUP_NAME deleted"
	CURRENT_RUNS=$(($CURRENT_RUNS+1))
	echo -e -n "$CURRENT_RUNS/$RUNS completed runs...\r"
done

