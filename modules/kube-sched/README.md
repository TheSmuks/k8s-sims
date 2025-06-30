

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
