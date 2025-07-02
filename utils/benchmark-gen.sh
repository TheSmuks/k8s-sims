#!/bin/bash
NODE_COUNT=4
POD_COUNT=400
OUTPUT_FOLDER="data/benchmark/vanilla"
cat <<EOF > "${OUTPUT_FOLDER}/cluster-${NODE_COUNT}.yaml"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
EOF
> "${OUTPUT_FOLDER}/nodes-${NODE_COUNT}.yaml"
> "${OUTPUT_FOLDER}/pods-${NODE_COUNT}.yaml"
for i in $(seq 1 $NODE_COUNT)
do
    cat <<EOF >> "${OUTPUT_FOLDER}/cluster-${NODE_COUNT}.yaml"
- role: worker
EOF
cat <<EOF >> "${OUTPUT_FOLDER}/nodes-${NODE_COUNT}.yaml"
apiVersion: v1
kind: Node
metadata:
  labels:
    beta.kubernetes.io/os: linux
    kubernetes.io/hostname: node-${i}
    kubernetes.io/os: linux
  name: node-${i}
status:
  allocatable:
    cpu: 1000m
    memory: 81920Mi
    pods: '1001'
  capacity:
    cpu: 1000m
    memory: 81920Mi
    pods: '1001'
---
EOF
done 

for i in $(seq 1 $POD_COUNT)
do
cat <<EOF >> "${OUTPUT_FOLDER}/pods-${NODE_COUNT}.yaml"
apiVersion: v1
kind: Pod
metadata:
  name: pod-${i}
spec:
  containers:
  - image: busybox
    command:
      - sleep
      - "3600"
    imagePullPolicy: IfNotPresent
    name: busybox
    resources:
        requests:
            memory: 100Mi
            cpu: 10m
  restartPolicy: Always
---
EOF
done