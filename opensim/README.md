# Open Simulator
In this file we are going to see an step by step of how to run the simuator. Alternatively you can simply run the [run-experiment](./experiment/run-experiment.sh) file to run a simple simulation.
## Obtain traces
After obtaining the traces in the previous steps the next step ist to copy relevant files to run the simulator.
```sh
pwd # k8s-sims/opensim
mkdir demo
mkdir demo/nodes
cp ./clusterdata/cluster-trace-gpu-v2023/node_yaml/openb_node_list_gpu_node.yaml demo/nodes/
```
## Obtaining the simulator
Now that the data is ready to be used, the simulator is needed, for this we are going to clone the repository.
```sh
git clone https://github.com/alibaba/open-simulator.git
```
Once we have acquired the source code the next step is to build the simulation binary.
```sh
cd open-simulator
go build ./cmd #This will generate a binary called "cmd"
```
Now that be binary is ready to be used, we can run the simulation.
## Creating a configuration file
In this case there are already examples ready to be used in the project's source code, using the [simon-config.yaml](./experiment/simon-config.yaml) file as a template we obtain the following configuration file.
```sh
cd .. # cd to root folder
cat <<EOF > simon-config.yaml
apiVersion: simon/v1alpha1
kind: Config
metadata:
  name: simon-config 
spec:
  cluster:
    # Cluster data location
    customConfig: ./demo
  appList:
    - name: simulation
      # Location to the Pods file
      path: ./clusterdata/cluster-trace-gpu-v2023/open_pod_list_cpu0
  newNode: ./open-simulator/example/newnode/demo_1
EOF
```
## Running a simulation
To load the config file into the simulator and execute the simulation we run the following instruction.
```sh
./open-simulator/cmd apply -f simon-config.yaml
```
Once the simulation has finished it will inform if the run was a success or if scaling is needed.


