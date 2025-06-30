
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
