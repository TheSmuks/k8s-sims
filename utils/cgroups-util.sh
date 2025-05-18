#!/bin/bash

was_last_command_success(){
	if [ $? -ne 0 ]; then
		echo "$1"
		exit 1
	fi
}

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <group_name> <program> [runs]"
    exit 1
fi

RUNS=3
CURRENT_RUNS=0
CGROUP_BASE="/sys/fs/cgroup/"
RUN_OUT="./run.csv"
was_last_command_success "Failed to create cgroup"
echo "run_start_time,run_finish_time,memory_bytes,cpu_time" > "$RUN_OUT" 
while [ $CURRENT_RUNS -lt $RUNS ]
do
	CGROUP_NAME="$1-$CURRENT_RUNS"
	sudo cgcreate -g memory,cpu:/$CGROUP_NAME
	echo "$CGROUP_NAME cgroup created"
	printf "%s" "$(date +%s)" >> "$RUN_OUT"
	sudo cgexec -g memory,cpu:/$CGROUP_NAME $2
	was_last_command_success "Failed to run program"
	printf ",%s" "$(date +%s)" >> "$RUN_OUT"
	echo "cgroup $CGROUP_NAME created"
	awk '{printf ",%s",$1}' "$CGROUP_BASE$CGROUP_NAME/memory.current" >> "$RUN_OUT"
	awk 'NR==1 {print ","$2}' "$CGROUP_BASE$CGROUP_NAME/cpu.stat" >> "$RUN_OUT"
	sudo cgdelete memory,cpu:/$CGROUP_NAME
	was_last_command_success "Failed to delete cgroup $CGROUP_NAME"
	echo "cgroup $CGROUP_NAME deleted"
	CURRENT_RUNS=$(($CURRENT_RUNS+1))
	echo -e -n "$CURRENT_RUNS/$RUNS completed runs...\r"
done

