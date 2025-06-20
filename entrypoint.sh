#!/bin/bash
if [ ! -S /var/run/docker.sock ]; then
    echo "Starting Docker daemon..."
    dockerd &
    for i in {1..30}; do
        [ -S /var/run/docker.sock ] && break
        echo "Waiting for dockerd..."
        sleep 1
    done
else
    echo "Docker already running."
fi
sleep 5
docker image pull registry.k8s.io/scheduler-simulator/debuggable-scheduler:v0.4.0
docker image pull registry.k8s.io/scheduler-simulator/simulator-backend:v0.4.0
# docker image pull registry.k8s.io/scheduler-simulator/simulator-frontend:v0.4.0
docker image pull registry.k8s.io/etcd:3.5.21-0
docker image pull registry.k8s.io/kube-apiserver:v1.33.0
docker image pull registry.k8s.io/kube-controller-manager:v1.33.0
docker image pull registry.k8s.io/kube-scheduler:v1.33.0
docker image pull registry.k8s.io/kwok/kwok:v0.7.0
docker image pull docker.io/kindest/node:v1.33.1
docker image pull docker.io/kindest/node:v1.29.0

export CONTAINERIZED="true"
#Pre-run to ensure proper working
echo "$@"
/run-all-experiments.sh -n 1 -o /tmp -e /data/tiny
/run-all-experiments.sh "$@"
