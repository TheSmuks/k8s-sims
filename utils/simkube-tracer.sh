#!/bin/bash
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check_kwok() {
    if ! command -v kwokctl &> /dev/null; then
        echo "kwokctl could not be found"
        exit 1
    fi
}

parse_args() {
    while getopts 'h?e:n:' opt; do
        case "$opt" in
        e)
            EXPERIMENT_FILES_PATH="$OPTARG"
            ;;
        n)
            NAMESPACE="$OPTARG"
            ;;
        h)
            echo "Usage: $(basename $0) <-e EXPERIMENT_FILES_PATH> <-n NAMESPACE>"
            exit 0
            ;;
        :)
            echo -e "option requires an argument.\nUsage: $(basename $0) <-e EXPERIMENT_FILES_PATH> <-n NAMESPACE>"
            exit 1
            ;;
        ?)
            echo -e "Invalid command option.\nUsage: $(basename $0) <-e EXPERIMENT_FILES_PATH> <-n NAMESPACE>"
            exit 1
            ;;
        esac
    done

    if [ -z "$EXPERIMENT_FILES_PATH" ]; then
        echo -e "Missing required argument.\nUsage: $(basename $0) <-e EXPERIMENT_FILES_PATH> <-n NAMESPACE>"
        exit 1
    fi

    if [ -z "$NAMESPACE" ]; then
        echo -e "Missing required argument.\nUsage: $(basename $0) <-e EXPERIMENT_FILES_PATH> <-n NAMESPACE>"
        exit 1
    fi
}

parse_args "$@"

check_kwok

for pod_file in $(find "$EXPERIMENT_FILES_PATH" -name "pods-*.yaml" -type f | sort -V); do
    echo "Processing file: $pod_file"
    kwokctl create cluster --name tracer
    kubectl create ns ${NAMESPACE}
    while ! kubectl get serviceaccount default -n ${NAMESPACE} >/dev/null 2>&1; do
      echo "Waiting for default service account in ${NAMESPACE}..."
      sleep 1
    done
    kubectl config use-context kwok-tracer
    NODE_COUNT=$(echo $pod_file | rev | cut -d '-' -f 1 | rev | cut -d '.' -f 1)
    echo "Generating pod trace of file with $NODE_COUNT nodes"
    kubectl apply -f $pod_file --namespace ${NAMESPACE}
    skctl snapshot -c ${SCRIPT_DIR}/base/config.yml -o "$EXPERIMENT_FILES_PATH/trace-$NODE_COUNT.sktrace"
    kwokctl delete cluster --name tracer
done
