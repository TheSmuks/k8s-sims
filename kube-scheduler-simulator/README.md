
# Kubernetes scheduler simulator
In this file we are going to see an step by step of how to run the simuator.
## Obtain the simulator source code
The first step is to obtain the simulator source code to make sure that the simulation run the same way and there are no conflicts we are going to use a specific version of the simulator.
```sh
git clone https://github.com/kubernetes-sigs/kube-scheduler-simulator.git
cd kube-scheduler-simulator
git reset --hard 2084fc1
```
Once we have acquired the source code the next step is to start Docker-Compose stack.
```sh
make docker_up
```
You can access the simulator in http://localhost:3000.
## Running a simulation
Now we need to make a modification in the [kubeconfig.yml](./kube-scheduler-simulator/simulator/kubeconfig.yml) file to be able to interact with the KWOK cluster.
```sh
cp kube-scheduler-simulator/simulator/kubeconfig.yml kubeconfig.yml
LOCAL_IP=$(ip route get 1 | awk '{print $7; exit}') # Get local ip
sed -i "s|server: http://fake-source-cluster:3132|server: http://$LOCAL_IP:3131|" kubeconfig.yaml # repalce the fake-source with the local ip and correct port
```
After that we can use the kubeconfig file to connect to our KWOK instance.
```sh
kubectl --kubeconfig kubeconfig.yaml get pods # Empty
```
Next step is to create a namespace to be able to deploy Alibaba's cluster traces Pods into our cluster.
```sh
kubectl --kubeconfig kubeconfig.yaml create ns paib-gpu
```
Once the namespace is created we can proceed to instantiate the nodes and pods. This process takes a while as there are over 1k nodes and over 7k pods.
```sh
# Create nodes
kubectl --kubeconfig kubeconfig.yaml create -f ../example/cluster/nodes/nodes/nodes.yaml
# Create pods
kubectl --kubeconfig kubeconfig.yaml create -f ../example/applications/simulation/pods.yaml
```
This process will first create the nodes and then schedule in each one the pods if the requirements are met.

