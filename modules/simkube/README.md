


# SimKube
In this file we are going to see an step by step of how to run the simuator.
## Obtaining the simulator
The first step is to obtain the simulator source code to make sure that the simulation run the same way and there are no conflicts we are going to use a specific version of the simulator.
```bash
pwd # k8s-sims/
git clone https://github.com/acrlabs/simkube.git simkube-src
cd simkube-src
git checkout v2.3.0
```
Once we have acquired the source code the next step is to configure a simulation cluster.
## Configuring the simulation environment
First we need to have [kind](https://kind.sigs.k8s.io/) installed and working, Docker should be running too.
Next, we need to create a kind cluster where the simulation is going to be replayed.
```bash
pwd # k8s-sims/
kind create cluster --name simkube --config modules/simkube/kind-config.yaml
```
Next step is to configure KWOK to run in the kind cluster we just deployed.
```bash
SIM_CONTEXT=kind-simkube
kubectl config use-context $SIM_CONTEXT
kubectl apply -f "https://github.com/kubernetes-sigs/kwok/releases/download/v0.7.0/kwok.yaml"
    kubectl apply -f "https://github.com/kubernetes-sigs/kwok/releases/download/v0.7.0/stage-fast.yaml"
```
Now need to setup the Prometheus Operator to recollect data of the simulation.
```bash
pwd # k8s-sim/modules/simkube
git clone https://github.com/prometheus-operator/kube-prometheus.git
cd kube-prometheus
kubectl create -f manifests/setup
until kubectl get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done
# No resources found this message is expected
kubectl create -f manifests/
```
Now we need to setup self-signed certificates.
```bash
pwd # k8s-sim/modules/simkube
kubectl apply -f cert-manager.yaml
kubectl wait --for=condition=Ready -l app=webhook -n cert-manager pod --timeout=60s
kubectl apply -f modules/simkube/self-signed.yml
```
Finally we need to install sk-ctrl in the simulation environment.
```bash
pwd # k8s-sim/simkube/
cd simkube-src/
kubectl apply -k k8s/kustomize/sim
```
Now we need to create a namespace for the simkube objects.
```bash
kkubectl create secret generic simkube --namespace=simkube
```
<!---
```bash
# Expose Prometheus WebUI to port 9090
kubectl --namespace monitoring port-forward svc/prometheus-k8s 9090
```
--->
## Configuring the production environment
The production environment is from where we are collecting the traces to be replayed later.
In this case we are going to use a `kind` cluster as a production cluster.
```bash
pwd # k8s-sim/simkube
PROD_CONTEXT=kind-prod
kind create cluster --name prod
kubectl config use-context $PROD_CONTEXT
cd simkube-src
kubectl apply -k k8s/kustomize/prod
PROD_TRACER_POD=$(kubectl --context ${PROD_CONTEXT} get pods -n simkube --no-headers -o custom-columns=":metadata.name")
```

## Collecting cluster traces
The first step is to port-forward the cluster tracer in order to be able to extract data from it.
```
kubectl port-forward -n simkube pod/$PROD_TRACER_POD 7777:7777
```
Now that the tracer is ready, we proceed to create a simple nginx deployment for the sk-tracer to capture it.
```bash
pwd # k8s-sim/simkube
kubectl create ns testing
kubectl create -f experiments/nginx-deployment.yaml --namespace=testing
```
After the deployment has been successful we proceed to export the traces generated.
```bash
pwd # k8s-sim/simkube
skctl export -o experiments/data/trace.out
```
## Running a simulation
In this case the `data` volume is mapped to the [experiments/data](experiments/data) folder in the kind node we created previously.
First, we proceed to deploy the nodes.
```bash
pwd # k8s-sim/
kubectl apply -f data/big/simkube/nodes-1200.yaml
```
Next step is to deploy the SimKube simulation traces.
```bash
pwd # k8s-sim/modules/simkube
cp ../../data/big/simkube/trace-1200.sktrace ./data/trace.out
cd simkube-src/
skctl run test-sim --trace-path file:///data/trace.out --hooks config/hooks/default.yml --disable-metrics --duration +5m
```
To check the status of the simulation we can use kubectl.
```bash
kubectl get simulation test-sim --context kind-simkube
```
