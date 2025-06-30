


# Kubernetes WithOut Kubelet
In this file we are going to see an step by step of how to run the simulator.
## Obtain the simulator source code
The first step is to obtain the KWOK binaries, which enables to create fake clusters to deploy the workload on them.
```bash
pwd # k8s-sims/modules/kwok
go install sigs.k8s.io/kwok/cmd/kwok@v0.7.0 && \
go install sigs.k8s.io/kwok/cmd/kwokctl@v0.7.0
```
## Running a simulation
First we create a KWOK cluster.
```bash
kwokctl create cluster --name kwok \
    --timeout 60s \
    --kind-node-image kindest/node:v1.29.0
```
After that we can switch the Kubernetes context to use the newly created cluster.
```bash
kubectl config use-context kwok-kwok
kubectl get pods # Empty
```
Next step is to create a namespace to be able to deploy Alibaba's cluster traces Pods into our cluster.
```bash
kubectl create ns paib-gpu
```
Once the namespace is created we can proceed to instantiate the nodes and pods. This process takes a while as there are over 1k nodes and over 7k pods.
```bash
# Create nodes
kubectl create -f ../data/big/vanilla/nodes-1200.yaml
# Create pods
kubectl create -f ../data/big/vanilla/pods-1200.yaml
# Unset kubeconfig
unset KUBECONFIG
```
This process will first create the nodes and then schedule in each one the pods if the requirements are met.
