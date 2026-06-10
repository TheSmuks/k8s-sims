# Module Documentation Evidence

## modules/kwok/README.md




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




## modules/kube-sched/README.md



# Kubernetes scheduler simulator
In this file we are going to see an step by step of how to run the simulator.
## Obtain the simulator source code
The first step is to obtain the simulator source code to make sure that the simulation run the same way and there are no conflicts we are going to use a specific version of the simulator.
```bash
pwd # k8s-sims/modules/kube-sched
git clone https://github.com/kubernetes-sigs/kube-scheduler-simulator.git simulator-src
cd simulator-src
git reset --hard 2084fc1
```
Once we have acquired the source code the next step is to start Docker-Compose stack.
```bash
make docker_up
```
You can access the simulator in http://localhost:3000.
## Running a simulation
Now we need to make a modification in the [kubeconfig.yaml](kubeconfig.yaml) file to be able to interact with the KWOK cluster.
```bash
pwd # k8s-sims/modules/kube-sched
cp simulator-src/simulator/kubeconfig.yaml kubeconfig.yaml
LOCAL_IP=$(ip route get 1 | awk '{print $7; exit}') # Get local ip
sed -i "s|server: http://fake-source-cluster:3132|server: http://$LOCAL_IP:3131|" kubeconfig.yaml # repalce the fake-source with the local ip and correct port
# Setup the kubeconfig file to be the default
export KUBECONFIG=kubeconfig.yaml
```
After that we can use the kubeconfig file to connect to our KWOK instance.
```bash
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




## modules/simkube/README.md




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

... (109 total lines, showing first 100)



## modules/kubemark/README.md




# Kubemark
In this file we are going to see an step by step of how to run the simulator.
## Obtain the simulator source code
The first step is to obtain Kubemark source code to make sure that the simulation run the same way and there are no conflicts we are going to use a specific version of the simulator.
```bash
git clone https://github.com/kubernetes/kubernetes.git
cd kubernetes
# Kubemark working version 1.29.0
git checkout v1.29.0
```
The next step is to build the Docker image to use Kubemark, or a prebuilt image can be used instead, in this case we are going to build the image from source. In case you prefer to skip and use an already built image you can use [thesmuks/kubemark:v1.29.0](https://hub.docker.com/r/thesmuks/kubemark/tags).
```bash
pwd # k8s-sims/modules/kubemark/kubernetes
make WHAT=cmd/kubemark KUBE_BUILD_PLATFORMS=linux/amd64
cp ./_output/local/bin/linux/amd64/kubemark cluster/images/kubemark
cd cluster/images/kubemark
docker build -t thesmuks/kubemark:v1.29.0 .
docker push thesmuks/kubemark:v1.29.0
```
Now that he image is built and uploaded to our repository we can use it on our Kubemark manifest file.
## Configuring the simulation environment
First we need to have [kind](https://kind.sigs.k8s.io/) installed and working, Docker should be running too.
First we need to create a kind cluster where the hollow nodes are going to be deployed. The configuration file creates a kind cluster `testing` with three worker nodes and patches the maxPods to allow it to run up to 1k hollow nodes.
```bash
pwd # k8s-sims/modules/kubemark
kind create cluster --config=kind-config.yaml \
--name testing \
--image kindest/node:v1.29.0
```
Once the hollow nodes are up and running we can deploy the workload into them.
## Running a simulation
Next step is to create a namespace to be able to deploy Alibaba's cluster traces Pods into our cluster, and a namespace for the hollow nodes.
```bash
kubectl create ns paib-gpu
kubectl create ns kubemark
```
Once the namespace is created we can proceed to instantiate the nodes and pods. This process takes a while as there are over 1k nodes and over 7k pods.
```bash
# Create nodes
kubectl create -f ../data/big/kubemark/nodes-1200.yaml
# Create pods
kubectl create -f ../data/big/kubemark/pods-1200.yaml
```




## modules/opensim/README.md


# Open Simulator
In this file we are going to see an step by step of how to run the simulator.
## Obtaining the simulator
Now that the data is ready to be used, the simulator is needed, for this we are going to clone the repository.
```bash
git clone https://github.com/alibaba/open-simulator.git
```
Once we have acquired the source code the next step is to build the simulation binary.
```bash
cd open-simulator
go build ./cmd #This will generate a binary called "cmd"
```
Now that be binary is ready to be used, we can run the simulation.
## Modifications needed
In this case there are no modifications needed for nodes/pods files. But the simulator takes a special file as input. There are examples ready to be used in the [data/opensim](data/opensim) folder. Alternatively  the [simon-config.yaml](utils/base/simon-config.yaml) file can be used as a template .
```bash
cd .. # cd to root folder
cat <<EOF > simon-config.yaml
apiVersion: simon/v1alpha1
kind: Config
metadata:
  name: simon-config
spec:
  cluster:
    # Cluster data location
    customConfig: #path to cluster folder/yaml
  appList:
    - name: simulation
      # Location to the Pods file
      path: #path to pods folder/yaml
  newNode: utils/base/new-node.yaml
EOF
```
## Running a simulation
To load the config file into the simulator and execute the simulation we run the following instruction.
```bash
pwd # k8s-sims/
modules/opensim/cmd apply -f data/big/opensim/simon-config-1200.yaml
```
Once the simulation has finished it will inform if the run was a success or if scaling is needed.



