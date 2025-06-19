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
		echo "Usage: $(basename $0) <-e EXPERIMENT_FILES_PATH>"
		exit 0
		;;

	:)
		echo -e "option requires an argument.\nUsage: $(basename $0) <-e EXPERIMENT_FILES_PATH>"
		exit 1
		;;

	?)
		echo -e "Invalid command option.\nUsage: $(basename $0) <-e EXPERIMENT_FILES_PATH>"
		exit 1
		;;
	esac
done
shift "$(($OPTIND - 1))"

install_kwok
for pod_file in $(find "$EXPERIMENT_FILES_PATH" -name "pods-*.yaml" -type f | sort -V); do
    kwokctl create cluster --name tracer
    kubectl create ns paib-gpu
    kubectl config use-context kwok-tracer
    NODE_COUNT=$(echo $pod_file | rev | cut -d '-' -f 1 | rev | cut -d '.' -f 1)
    echo "Generating pod trace of file with $NODE_COUNT nodes"
    kubectl apply -f $pod_file --namespace paib-gpu
    skctl snapshot -c base/config.yml -o "$EXPERIMENT_FILES_PATH/trace-$NODE_COUNT.sktrace"
    kwokctl delete cluster --name tracer
done
