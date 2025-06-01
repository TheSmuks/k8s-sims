#!/bin/bash

CGROUP_BASE="/sys/fs/cgroup/system.slice"
RUNS=3
EXPERIMENT_FILES_PATH=""
OUT_FILE="$(pwd)/run-kube-sched.csv"

if [ $# -eq 0 ]; then
    echo "Usage: $(basename $0) [-r runs]"
    exit 1
fi

while getopts 'h?e:r:' opt; do
	case "$opt" in
    e)
        EXPERIMENT_FILES_PATH="$OPTARG"
        ;;
	r)
		RUNS="$OPTARG"
		;;

	h)
		echo "Usage: $(basename $0) <-c cluster-name> [-r runs]"
		exit 0
		;;

	:)
		echo -e "option requires an argument.\nUsage: $(basename $0) <-c cluster-name> [-r runs]"
		exit 1
		;;

	?)
		echo -e "Invalid command option.\nUsage: $(basename $0) <-c cluster-name> [-r runs]"
		exit 1
		;;
	esac
done
shift "$(($OPTIND - 1))"

function track_containers(){
    START_TIME=$1
    CONTAINERS_TO_WATCH=$2
    CONTAINER_IDS=()
    for ((i=0; i<${#CONTAINERS_TO_WATCH[@]}; i++)); do
        CONTAINER_IDS[i]=$(docker ps --no-trunc -aqf "name=${CONTAINERS_TO_WATCH[i]}")
    done
    POLL_TIMEOUT=0.1
    MAX_MEMORY_MEASUREMENTS=()
    for ((i=0; i<${#CONTAINER_IDS[@]}; i++)); do
        MAX_MEMORY_MEASUREMENTS[i]=-1
    done
	RUN_CONDITION="true"
	trap 'RUN_CONDITION=false' SIGINT
	while [ $RUN_CONDITION = "true" ]; do
        for ((i=0; i<${#CONTAINER_IDS[@]}; i++)); do
            if [ -d "$CGROUP_BASE/docker-${CONTAINER_IDS[i]}.scope" ]; then
                CURRENT_MEMORY_MEASUREMENT=$(cat "$CGROUP_BASE/docker-${CONTAINER_IDS[i]}.scope/memory.current")
		        if [ $CURRENT_MEMORY_MEASUREMENT -gt ${MAX_MEMORY_MEASUREMENTS[i]} ]; then
			        MAX_MEMORY_MEASUREMENTS[i]=$CURRENT_MEMORY_MEASUREMENT
		        fi
                CPU_TIMES=($(awk 'NR<=3 {printf "%.2f ", $2/1000000}' "$CGROUP_BASE/docker-${CONTAINER_IDS[i]}.scope/cpu.stat"))
                CPU_MEASUREMENTS=()                
                for ((j=0; j<${#CONTAINER_IDS[@]}; j++)); do
                    CPU_MEASUREMENTS[j]+=${CPU_TIMES[j]}
                done
            else
                RUN_CONDITION="false"
                break
            fi
        done
		sleep $POLL_TIMEOUT
	done
    END_TIME=$(date +%s)
    TOTAL_MEM=0
    for ((i=0; i<${#CONTAINER_IDS[@]}; i++)); do
        TOTAL_MEM=$(($TOTAL_MEM + ${MAX_MEMORY_MEASUREMENTS[i]}))
    done
    printf "%d" $(($END_TIME - $START_TIME)) >>$OUT_FILE
    for ((i=0; i<3; i++)); do
        printf "|%.2f" ${CPU_MEASUREMENTS[i]} >> $OUT_FILE
    done
	printf "|%.2f\n" $(($TOTAL_MEM / 1024 / 1024 / 1024)) >> $OUT_FILE
	exit 0
}
# Download repo
if [ -d "simulator-src" ]; then
    cd simulator-src
else
    git clone https://github.com/kubernetes-sigs/kube-scheduler-simulator.git simulator-src
    cd simulator-src
    git reset --hard 2084fc1
fi
if [[ ! -f "kubeconfig.yaml" ]]; then
    cp simulator/kubeconfig.yaml kubeconfig.yaml
    LOCAL_IP=$(ip route get 1 | awk '{print $7; exit}')
    sed -i "s|server: http://fake-source-cluster:3132|server: http://$LOCAL_IP:3131|" kubeconfig.yaml 
fi
KUBE_FILE="kubeconfig.yaml"
CURRENT_RUNS=0

CONTAINERS_TO_WATCH=(simulator-scheduler simulator-server simulator-cluster)
echo "node_count|run_time|total_cpu_seconds|user_cpu_seconds|system_cpu_seconds|memory_peak_gb" > "$OUT_FILE"
for node_file in $(ls -1 "$EXPERIMENT_FILES_PATH"/nodes-*.yaml | xargs realpath | sort -V); do
    NODE_COUNT=$(echo "$node_file" | rev | cut -d '-' -f 1 | rev | cut -d '.' -f 1 )
    while [ $CURRENT_RUNS -lt $RUNS ]; do
        START_TIME=$(date +%s)
        docker compose up -d "${CONTAINERS_TO_WATCH[@]}"
        while ! docker logs "${CONTAINERS_TO_WATCH[-1]}" 2>&1 | grep -q "Starting to serve"; do
            sleep 0.5
        done
        track_containers $START_TIME ${CONTAINERS_TO_WATCH} &
        kubectl --kubeconfig kubeconfig.yaml create ns paib-gpu
        kubectl --kubeconfig kubeconfig.yaml create -f $node_file
        kubectl --kubeconfig kubeconfig.yaml create -f "$EXPERIMENT_FILES_PATH"/pods-"$NODE_COUNT".yaml
        FAILURE_FOUND="false"
        PENDING_PODS_COUNT=$(kubectl --kubeconfig kubeconfig.yaml get pods --field-selector=status.phase=Pending -n paib-gpu --no-headers | wc -l)
        while [ $PENDING_PODS_COUNT -gt 0 ]
        do
            if [ $FAILURE_FOUND = "true" ]; then
                break    
            fi
            PENDING_PODS=$(kubectl --kubeconfig kubeconfig.yaml get pods --field-selector=status.phase=Pending -n paib-gpu -o jsonpath='{.items[*].metadata.name}')
            FAILURE_COUNT=0    
            for pod_name in $PENDING_PODS; do
                FAILURE_CHECK=$(kubectl --kubeconfig kubeconfig.yaml get events -n paib-gpu --field-selector involvedObject.name="$pod_name" | \
                               grep "FailedScheduling" | \
                               grep -E "(Insufficient cpu|Insufficient memory|No preemption victims found)")
                
                if [ -n "$FAILURE_CHECK" ]; then
                    FAILURE_COUNT=$((FAILURE_COUNT+1))
                    if [ $FAILURE_COUNT -ge $PENDING_PODS_COUNT ]; then
                        FAILURE_FOUND="true"  
                        break          
                    fi
                fi
            done
            echo -ne "Pending pods: $PENDING_PODS_COUNT\r"
            sleep 1
            PENDING_PODS_COUNT=$(kubectl --kubeconfig kubeconfig.yaml get pods --field-selector=status.phase=Pending -n paib-gpu --no-headers | wc -l)
        done;
        docker compose down
        START_TIME=$(date +%s)
        kill -s SIGINT $POLL_PID > /dev/null 2>&1;
        CURRENT_RUNS=$(($CURRENT_RUNS + 1))
    done
done
