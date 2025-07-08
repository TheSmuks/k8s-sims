#!/bin/bash
echo "Starting Docker daemon..."
pkill dockerd || dockerd &
for i in {1..30}; do
    [[ -S /var/run/docker.sock ]] && break
    echo "Waiting for dockerd..."
    sleep 1
done
sleep 5
docker image pull registry.k8s.io/scheduler-simulator/debuggable-scheduler:v0.4.0
docker image pull registry.k8s.io/scheduler-simulator/simulator-backend:v0.4.0
# docker image pull registry.k8s.io/scheduler-simulator/simulator-frontend:v0.4.0
docker image pull registry.k8s.io/etcd:3.5.21-0
docker image pull registry.k8s.io/kube-apiserver:v1.29.0
docker image pull registry.k8s.io/kube-controller-manager:v1.29.0
docker image pull registry.k8s.io/kube-scheduler:v1.29.0
docker image pull registry.k8s.io/kwok/cluster:v0.5.1-k8s.v1.29.0
docker image pull docker.io/kindest/node:v1.29.0

export CONTAINERIZED="true"
#Pre-run to ensure proper working
/kube-director.sh -n 1 -o /tmp -e /data/test
/kube-director.sh $@
