#!/bin/bash

function install_kwok(){
    GO_BIN_PATH='export PATH="$HOME/go/bin:$PATH"'
    grep -Fxq "$GO_BIN_PATH" "$HOME/.bashrc" || echo "$GO_BIN_PATH" >> "$HOME/.bashrc"
    if command -v go >/dev/null 2>&1; then
        :
    else
        go install sigs.k8s.io/kwok/cmd/{kwok,kwokctl}@"v0.7.0"
    fi
}

EXPERIMENT_FILES_PATH="./out/simkube"

while getopts 'h?r:e:' opt; do
	case "$opt" in
    e)
        EXPERIMENT_FILES_PATH="$OPTARG"
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

install_kwok
for pod_file in $EXPERIMENT_FILES_PATH/simkube-pods-*.yaml; do
    kwokctl create cluster --name tracer
    kubectl create ns paib-gpu
    kubectl config use-context kwok-tracer
    NODE_COUNT=$(echo $pod_file | rev | cut -d '-' -f 1 | rev | cut -d '.' -f 1)
#    CURRENT_PODS=$(kubectl get pods -n paib-gpu -o custom-columns=NAME:.metadata.name --no-headers | sort)
#    WANTED_PODS=$(grep -A1 'kind: Pod' "$pod_file" | grep 'name:' | awk '{print $2}' | sort)
#    PODS_TO_DELETE=$(comm -23 <(echo "$CURRENT_PODS") <(echo "$WANTED_PODS"))
#    for pod in $PODS_TO_DELETE; do
#        kubectl delete pod $pod --namespace paib-gpu
#    done
    echo "Generating pod trace of file with $NODE_COUNT nodes"
    kubectl apply -f $pod_file --namespace paib-gpu
    skctl snapshot -c config.yml -o "$EXPERIMENT_FILES_PATH/simkube-$NODE_COUNT-trace.out"
#    kubectl delete -f $pod_file
    kwokctl delete cluster --name tracer
done
