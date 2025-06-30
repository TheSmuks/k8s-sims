


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
