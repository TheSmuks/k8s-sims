#!/bin/bash
dockerd &
sleep 5
docker ps
docker image pull registry.k8s.io/scheduler-simulator/debuggable-scheduler:v0.4.0
docker image pull registry.k8s.io/scheduler-simulator/simulator-backend:v0.4.0
# docker image pull registry.k8s.io/scheduler-simulator/simulator-frontend:v0.4.0
export CONTAINERIZED="true"
#Pre-run to ensure proper working
/run-all-experiments.sh "$@ -n 1 -o /tmp -e /data/tiny"
/run-all-experiments.sh "$@"
