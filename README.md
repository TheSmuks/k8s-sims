

# K8s-sims
K8sims is a repository containing a guide on how to run a selected number of Kubernetes simulators.
Specs of the computer where the simulations were run.
```
OS: Alpine Linux v3.22
CPU: 2 x Intel(R) Xeon(R) Silver 4210R (40) @ 3.20 Gz
Memory: 128GB DDR4
```
## Required Dependencies
This project requires several tools and languages to be installed on your system. Ensure all dependencies below are properly installed before proceeding.

1. [Go](https://go.dev/doc/install)
2. [Docker](https://docs.docker.com/engine/install/)
	2.1 [Docker Compose](https://docs.docker.com/compose/install/)
3. [make](https://www.gnu.org/software/make/)
4. [Python3.12.3](https://www.python.org/downloads/release/python-3123/) and [requirements.txt](requirements.txt)
5. [Rust 1.86.0](https://www.rust-lang.org/tools/install)
6. skctl: `cargo install skctl`
7. [Alibaba Cluster Traces](https://github.com/alibaba/clusterdata.git)
## Obtain traces
The first step is to clone the clusterdata repository containing Alibaba's production traces.
```sh
git clone https://github.com/alibaba/clusterdata.git
```
Next we are going to use the 2023 dataset.
```sh
cd ./clusterdata/cluster-trace-gpu-v2023
```
Once we are in the proper directory, the csv data needs to be transformed into yaml pod manifest files. For this we execute the `prepare_input` script. But first we need to install the dependencies to execute the script.
```sh
./prepare_input.sh
```
After the script finishes there should be 23 folders, one per each csv file containing the traces.
### Modifying traces
[kube-gen.py](utils/kube-gen.py) is a script that can be used to modify the traces to generate new traces that fit the supported simulators (Vanilla Kubernetes, OpenSimulator, SimKube, Kubemark). For more detail refer to the [README.md](utils/README.md).
## Running simulations
Simulations can be run by setting up the environment step by step or spin up a docker compose for an easy and fast setup.
### Docker Compose
To reproduce the default experiments just deploy the [docker-compose.yaml](docker-compose.yaml) provided. This will pull the proper image and run all the experiments using the [big dataset](data/big).
[.env](.env) cotains variable that can be changed and loaded on the compose.
```sh
docker compose up
```
### Experiment Script
If all the dependencies are installed, the user can opt to run the experiments on the host machine.
This can be done by executing the file [kube-director.sh](kube-director.sh).
```bash
./kube-director.sh
```
Alternatively, to run a single experiment, the user can execute the file [kube-run.sh](kube-run.sh).
```bash
./kube-run.sh -m module_name -d data_path
```
### Manual Approach
- In order to run Alibaba's OpenSimulator refer to [README-OpenSim](modules/opensim/README.md)
- In order to run Kubernetes Scheduler Simulator refer to [README-kube-sched-sim](modules/kube-sched/README.md)
- In order to run SimKube refer to [README-SimKube](modules/simkube/README.md)
- In order to run Kubemark refer to [README-Kubemark](modules/kubemark/README.md)
