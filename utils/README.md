# Utils
This folder is comprised by a set of utilities that help the simulation process or data preprocessing.
## KubeGen
[kube-gen.py](kube-gen.py) is a script that can be used to modify the traces to generate new traces that fit the supported simulators.
```text
_  __     _           _____
| |/ /    | |         / ____|
| ' /_   _| |__   ___| |  __  ___ _ __
|  <| | | | '_ \ / _ \ | |_ |/ _ \ '_ \
| . \ |_| | |_) |  __/ |__| |  __/ | | |
|_|\_\__,_|_.__/ \___|\_____|\___|_| |_|

-------------------------------------------------
usage: kube-gen.py [-h] -o OUTPUT_FOLDER [-c NODE_COUNT] [-i INCREMENT] [-k] [-s] [-os] [-hn HOLLOW_NODE_PATH]
             [-nn NEW_NODE_PATH] [-n NODES_PATH] [-p PODS_PATH]
kube-gen.py: error: the following arguments are required: -o/--output_folder
usage: kube-gen.py [-h] -o OUTPUT_FOLDER [-c NODE_COUNT] [-i INCREMENT] [-k] [-s] [-os] [-hn HOLLOW_NODE_PATH]
             [-nn NEW_NODE_PATH] [-n NODES_PATH] [-p PODS_PATH]

options:
-h, --help            show this help message and exit
-o OUTPUT_FOLDER, --output_folder OUTPUT_FOLDER
                  Output folder where generated files are saved
-c NODE_COUNT, --node_count NODE_COUNT
                  Quantity of nodes to generate
-i INCREMENT, --increment INCREMENT
                  Used to generate multiple files with steps of size n
-k, --kubemark        Applies the kubemark patches to the generated files
-s, --simkube         Applies the simkube patches to the generated files
-os, --open_sim       Generates files with the opensim folder structure
-hn HOLLOW_NODE_PATH, --hollow_node_path HOLLOW_NODE_PATH
                  Template hollow node file used for Kubemark
-nn NEW_NODE_PATH, --new_node_path NEW_NODE_PATH
                  Path to the YAML file containing the new node template for opensim
-n NODES_PATH, --nodes_path NODES_PATH
                  Path to the YAML file containing the nodes
-p PODS_PATH, --pods_path PODS_PATH
                  Path to the YAML file containing the pods
```
## Plotter
[plotter.py](plotter.py) is a script that can be used to plot the results of the simulation.
```text
usage: plotter.py [-h] -d DATA_DIRECTORY [-o OUTPUT_DIR]
```
## SimKube tracer
[simkube-tracer.sh](simkube-tracer.sh) is a script that converts vanilla Kubernetes nodes and pods into a trace admitted by SimKube.

```text
Usage: simkube-tracer.sh <-e EXPERIMENT_FILES_PATH> <-n NAMESPACE>
```
