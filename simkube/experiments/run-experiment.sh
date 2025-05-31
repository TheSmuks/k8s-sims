#!/bin/bash

CLUSTER_NAME="simkube"
CGROUP_BASE="/sys/fs/cgroup/system.slice"
OUT_FILE="$(pwd)/run-simkube.csv"
RUNS=3

if [ $# -eq 0 ]; then
    echo "Usage: $(basename $0) <-c cluster-name> [-r runs]"
    exit 1
fi

while getopts ':c:r:h' opt; do
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
    printf "%d" $(($END_TIME - $2)) >> $OUT_FILE
    for ((i=0; i<3; i++)); do
        printf "|%.2f" ${CPU_MEASUREMENTS[i]} >> $OUT_FILE
    done
	printf "|%.2f\n" $(($TOTAL_MEM / 1024 / 1024 / 1024)) >> $OUT_FILE
	exit 0
}

CURRENT_RUNS=0
echo "node_count|run_time|total_cpu_seconds|user_cpu_seconds|system_cpu_seconds|memory_peak_gb" > "$OUT_FILE"
for node_file in "$EXPERIMENT_FILES_PATH"/"simkube-"nodes-*.yaml; do
    NODE_COUNT=$(echo "$node_file" | rev | cut -d '-' -f 1 | rev | cut -d '.' -f 1 )
    SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    while [ $CURRENT_RUNS -lt $RUNS ]; do
        cp "$EXPERIMENT_FILES_PATH"/"simkube-"pods-"$NODE_COUNT" $SCRIPT_DIR/experiments/data/trace.out
        START_TIME=$(date +%s)
        kind create cluster --name $CLUSTER_NAME --config experiments/kind.yml
        track_containers $OUT_FILE $START_TIME &
        POLL_PID=$!
        SIM_CONTEXT=kind-simkube
        KWOK_REPO=kubernetes-sigs/kwok
        KWOK_LATEST_RELEASE=$(curl "https://api.github.com/repos/${KWOK_REPO}/releases/latest" | jq -r '.tag_name')
        kubectl config use-context $SIM_CONTEXT
        kubectl apply -f "https://github.com/${KWOK_REPO}/releases/download/${KWOK_LATEST_RELEASE}/kwok.yaml"
        kubectl apply -f "https://github.com/${KWOK_REPO}/releases/download/${KWOK_LATEST_RELEASE}/stage-fast.yaml"

        if [ ! -d "kube-prometheus" ]; then
            git clone https://github.com/prometheus-operator/kube-prometheus.git
        fi
        cd kube-prometheus
        kubectl create -f manifests/setup
        until kubectl get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done
        # No resources found this message is expected
        kubectl create -f manifests/
        cd ..

        kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.yaml
        kubectl wait --for=condition=Ready -l app=webhook -n cert-manager pod --timeout=60s
        kubectl apply -f experiments/self-signed.yml

        if [ ! -d "simkube-src" ]; then
            git clone https://github.com/acrlabs/simkube.git simkube-src
            cd simkube-src
            git checkout v2.3.0
        #    sed -i "s|- --driver-secrets|#- --driver-secrets|" k8s/kustomize/sim/sk-ctrl.yml 
        #    sed -i "s|- simkube|#- simkube|" k8s/kustomize/sim/sk-ctrl.yml 
            cd ..
        fi

        cd simkube-src/

        kubectl create namespace $CLUSTER_NAME
        kubectl create secret generic simkube -n $CLUSTER_NAME
        kubectl apply -k k8s/kustomize/sim
        kubectl apply -f $node_file

        skctl run test-sim --trace-path file:///data/trace.out --hooks config/hooks/default.yml --disable-metrics --duration +5m --speed 1
        WAIT_START_TIME=$(date +%s)
        until kubectl get simulations | grep -q "Finished"; do 
            ELAPSED_TIME=$(($(date +%s)-$WAIT_START_TIME))
            echo -ne "Waiting for simulation to finish. Elapsed: $ELAPSED_TIME seconds.\r"; 
            sleep 1; 
        done
        SIM_ID=$(kubectl get pods -n $CLUSTER_NAME | grep "sk-test-sim-driver" | awk '{print $1}')
        kind delete cluster --name $CLUSTER_NAME
        kill -s SIGINT $POLL_PID > /dev/null 2>&1;
        CURRENT_RUNS=$(($CURRENT_RUNS+1))
    done
done
