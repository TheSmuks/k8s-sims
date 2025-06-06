#!/bin/bash
#
cleanup() {
    echo "Interrupted. Cleaning up..."
    # Kill any remaining child processes
    jobs -p | xargs -r kill
    exit 1
}

SIMULATORS=(simkube kube-scheduler-simulator kubemark opensim)
# SIMULATORS=(kubemark simkube)
# SIMULATORS_ARGS=("-e ./out/simkube -r 1 -o ./results/simkube.csv" "-e ./out/opensim -r 1 -o ./results/opensim.csv" "-e ./out/kube-sched -r 1 -o ./results/kube-sched.csv" "-e ./out/kubemark -r 1 -o ./results/kubemark.csv")
SIMULATORS_ARGS=("-e ./out/simkube -r 3 -o ./results2/simkube.csv" "-e ./out/opensim -r 3 -o ./results2/opensim.csv" "-e ./out/kube-sched -r 3 -o ./results2/kube-sched.csv" "-e ./out/kubemark -r 3 -s 400 -o ./results2/kubemark.csv")
trap cleanup SIGINT

for i in ${!SIMULATORS[@]}; do
    echo "Starting experiments for ${SIMULATORS[i]}"
    ../${SIMULATORS[i]}/experiments/run-experiment.sh ${SIMULATORS_ARGS[i]}
done
