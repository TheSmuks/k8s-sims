

# Kubemark
In this file we are going to see an step by step of how to run the simuator.
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
pwd # k8s-sims/kubemark/kubernetes
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
pwd # k8s-sims/simkube
kind create cluster --config=experiments/kind-config.yaml --name testing --image kindest/node:v1.29.0
```
Once the hollow nodes are up and running we can deploy the workload into them.
## Running a simulation
