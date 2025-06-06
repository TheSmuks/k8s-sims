#!/bin/bash
#
cleanup() {
    echo "Interrupted. Cleaning up..."
    # Kill any remaining child processes
    jobs -p | xargs -r kill
    exit 1
}

SIMULATORS=(kube-scheduler-simulator opensim simkube kubemark)
SIMULATORS_ARGS=("-e ./out/kube-sched -r 5" "-e ./out/opensim -r 5" "-e ./out/simkube -r 5" "-e ./out/kubemark -r 5")
trap cleanup SIGINT

for i in ${!SIMULATORS[@]}; do
    echo "Starting experiments for ${SIMULATORS[i]}"
    ../${SIMULATORS[i]}/experiments/run-experiment.sh ${SIMULATORS_ARGS[i]}
done
