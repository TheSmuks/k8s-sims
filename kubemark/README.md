

# SimKube
In this file we are going to see an step by step of how to run the simuator.
## Obtain the simulator source code
The first step is to obtain the simulator source code to make sure that the simulation run the same way and there are no conflicts we are going to use a specific version of the simulator.
```sh
git clone https://github.com/acrlabs/simkube.git simkube-src
cd simkube-src
git reset --hard 9a3e671
```
The controller expects a secrets provider that is not used, in order to avoid any issues when running simulations we need to edit the file [k8s/kustomize/sim/sk-ctrl.yml](k8s/kustomize/sim/sk-ctrl.yml).
```sh
# Comment the line related to the driver secret
sed -i "s|- --driver-secrets|#- --driver-secrets|" k8s/kustomize/sim/sk-ctrl.yml 
sed -i "s|- simkube|#- simkube|" k8s/kustomize/sim/sk-ctrl.yml 
```
Once we have acquired the source code the next step is to configure a simulation cluster.
## Configuring the simulation environment
First we need to have [kind](https://kind.sigs.k8s.io/) installed and working, Docker should be running too.
First we need to create a kind cluster where the simulation is going to be replayed.
```sh
pwd # k8s-sims/simkube
kind create cluster --name simkube --config experiment/kind.yml
```
Next step is to configure KWOK to run in the kind cluster we just deployed.
```sh
SIM_CONTEXT=kind-simkube
KWOK_REPO=kubernetes-sigs/kwok
KWOK_LATEST_RELEASE=$(curl "https://api.github.com/repos/${KWOK_REPO}/releases/latest" | jq -r '.tag_name')
kubectl config use-context $SIM_CONTEXT
kubectl apply -f "https://github.com/${KWOK_REPO}/releases/download/${KWOK_LATEST_RELEASE}/kwok.yaml"
kubectl apply -f "https://github.com/${KWOK_REPO}/releases/download/${KWOK_LATEST_RELEASE}/stage-fast.yaml"
```
Now need to setup the Prometheus Operator to recollect data of the simulation.
```sh
pwd # k8s-sim/simkube
git clone https://github.com/prometheus-operator/kube-prometheus.git
cd kube-prometheus
kubectl create -f manifests/setup
until kubectl get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done
# No resources found this message is expected
kubectl create -f manifests/
``` 
Now we need to setup self-signed certificates.
```sh
pwd # k8s-sim/simkube
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.yaml
kubectl wait --for=condition=Ready -l app=webhook -n cert-manager pod --timeout=60s
kubectl apply -f experiment/self-signed.yml
```
Finally we need to install sk-ctrl in the simulation environment.
```sh
pwd # k8s-sim/simkube
cd simkube-src/
kubectl apply -k k8s/kustomize/sim
```
Now we proceed to create some virtual node to deploy pods that will be managed by KWOK.
```sh
pwd # k8s-sim/simkube
kubectl apply -f experiment/node.yml
```
<!---
```sh
# Expose Prometheus WebUI to port 9090
kubectl --namespace monitoring port-forward svc/prometheus-k8s 9090
```
```sh
kubectl create secret docker-registry simkube -n simkube
```
--->
## Configuring the production environment
The production environment is from where we are collecting the traces to be replayed later.
In this case we are going to use a `kind` cluster as a production cluster.
```sh
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
```sh
pwd # k8s-sim/simkube
kubectl create ns testing
kubectl create -f experiment/nginx-deployment.yaml --namespace=testing
```
After the deployment has been successful we proceed to export the traces generated.
```sh
pwd # k8s-sim/simkube
skctl export -o experiment/data/trace.out
```
## Running a simulation
In this case the `data` volume is mapped to the [experiment/data](experiment/data) folder in the kind node we created previously.
```
pwd # k8s-sim/simkube
cd simkube-src/
skctl run test-sim --trace-path file:///data/trace.out --hooks config/hooks/default.yml --disable-metrics
```
To check the status of the simulation we can use kubectl.
```sh
kubectl get simulation test-sim --context kind-simkube
```

