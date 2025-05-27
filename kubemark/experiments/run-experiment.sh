#!/bin/bash

CLUSTER_NAME="testing"
CGROUP_BASE="/sys/fs/cgroup/system.slice"
RUNS=3

if [ $# -eq 0 ]; then
    echo "Usage: $(basename $0) <-c cluster-name> [-r runs]"
    exit 1
fi

while getopts 'h?c:r:' opt; do
	case "$opt" in
	r)
		RUNS="$OPTARG"
		;;

	c)
		CLUSTER_NAME="$OPTARG"
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
    NODE_IDS=($(docker ps --no-trunc -aqf "name=$CLUSTER_NAME"))
    POLL_TIMEOUT=0.1
    MAX_MEMORY_MEASUREMENTS=()
    for ((i=0; i<${#NODE_IDS[@]}; i++)); do
        MAX_MEMORY_MEASUREMENTS[i]=-1
    done
	RUN_CONDITION="true"
	trap 'RUN_CONDITION=false' SIGINT
	while [ $RUN_CONDITION = "true" ]; do
        for ((i=0; i<${#NODE_IDS[@]}; i++)); do
            if [ -d "$CGROUP_BASE/docker-${NODE_IDS[i]}.scope" ]; then
                CURRENT_MEMORY_MEASUREMENT=$(cat "$CGROUP_BASE/docker-${NODE_IDS[i]}.scope/memory.current")
		        if [ $CURRENT_MEMORY_MEASUREMENT -gt ${MAX_MEMORY_MEASUREMENTS[i]} ]; then
			        MAX_MEMORY_MEASUREMENTS[i]=$CURRENT_MEMORY_MEASUREMENT
		        fi
                CPU_TIMES=($(awk 'NR<=3 {printf "%.2f ", $2/1000000}' "$CGROUP_BASE/docker-${NODE_IDS[i]}.scope/cpu.stat"))
                CPU_MEASUREMENTS=()                
                for ((j=0; j<3; j++)); do
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
    for ((i=0; i<${#NODE_IDS[@]}; i++)); do
        TOTAL_MEM=$(($TOTAL_MEM + ${MAX_MEMORY_MEASUREMENTS[i]}))
    done
    printf "%d" $(($END_TIME - $2)) >>$1
    for ((i=0; i<3; i++)); do
        printf "|%.2f" ${CPU_MEASUREMENTS[i]} >> $1
    done
	printf "|%.2f\n" $(($TOTAL_MEM / 1024 / 1024 / 1024)) >> $1
	exit 0
}
CURRENT_RUNS=0
echo "run_time|total_cpu_seconds|user_cpu_seconds|system_cpu_seconds|memory_peak_gb" > "$1"
while [ $CURRENT_RUNS -lt $RUNS ]; do
    START_TIME=$(date +%s)
    kind create cluster --config=kind-config.yaml --name $CLUSTER_NAME --image kindest/node:v1.29.0
    track_containers $1 $START_TIME &
    POLL_PID=$!
    kind get kubeconfig --name $CLUSTER_NAME > ./config
    sed -i 's|server: https://127.0.0.1:[0-9]\+|server: https://kubernetes.default.svc:443|' ./config
    kubectl config use-context kind-$CLUSTER_NAME
    kubectl create ns kubemark
    kubectl create secret generic kubeconfig \
    --type=Opaque --namespace=kubemark \
    --from-file=kubelet.kubeconfig=config \
    --from-file=kubeproxy.kubeconfig=config
    kubectl create -f hollow-nodes.yml
    echo "Creating pods"
    kubectl create -f pods.yaml -n kubemark
    FAILURE_FOUND="false"
    PENDING_PODS_COUNT=$(kubectl get pods --field-selector=status.phase=Pending -n kubemark --no-headers | wc -l)
    while [ $PENDING_PODS_COUNT -gt 0 ]
    do
        if [ $FAILURE_FOUND = "true" ]; then
            break    
        fi
        PENDING_PODS=$(kubectl get pods --field-selector=status.phase=Pending -n kubemark -o jsonpath='{.items[*].metadata.name}')
        FAILURE_COUNT=0    
        for pod_name in $PENDING_PODS; do
            FAILURE_CHECK=$(kubectl get events -n kubemark --field-selector involvedObject.name="$pod_name" | \
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
        PENDING_PODS_COUNT=$(kubectl get pods --field-selector=status.phase=Pending -n kubemark --no-headers | wc -l)
    done;
    #kubectl get pods -A
    kind delete cluster --name $CLUSTER_NAME
    kill -s SIGINT $POLL_PID > /dev/null 2>&1;
    CURRENT_RUNS=$(($CURRENT_RUNS + 1))
done
