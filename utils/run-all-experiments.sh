#!/bin/bash

SIMULATORS=(kubemark kube-scheduler-simulator opensim)
SIMULATORS_ARGS=("-c testing -e ./out/kubemark -r 1" "-e ./out/kube-sched -r 1" "-e ./out/opensim -r 1" "-e ./out/simkube -r 1")
for i in ${!SIMULATORS[@]}; do
    echo "Starting experiments for $simulator"
    ../${SIMULATORS[i]}/experiments/run-experiment.sh ${SIMULATORS_ARGS[i]}
done
