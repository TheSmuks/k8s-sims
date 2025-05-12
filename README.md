
# K8sims
K8sims is a repository containing a guide on how to run a selected number of Kubernetes simulators.
Specs of the computer where the simulations were run.
```
OS: Linux Mint 22.1 x86_64
Kernel: Linux 6.8.0-59-generic
CPU: 12th Gen Intel(R) Core(TM) i5-12600K (16) @ 4.90 Gz
GPU: NVIDIA GeForce RTX 3080 LHR
Memory: 32 GiB DDR4 3200 Mhz
Shell: bash 5.2.21
```
## Required Dependencies
This project requires several tools and languages to be installed on your system. Ensure all dependencies below are properly installed before proceeding.

### 1. [Go](https://go.dev/doc/install)
Install the latest stable version of Go by following the official installation guide.

### 2. Docker
Docker must be installed and running. It is used for containerization and managing development environments.

- [Docker Installation Guide](https://docs.docker.com/get-docker/)

### 3. `make`
`make` is used to run predefined build and automation tasks from a Makefile.

- Linux: Usually available via the system package manager (`sudo apt install make` or `sudo pacman -S make`)
- macOS: Install via Xcode Command Line Tools (`xcode-select --install`)
- Windows: Use via MSYS2 or WSL, or install GNU Make via [GnuWin](http://gnuwin32.sourceforge.net/packages/make.htm)

### 4. Python Environment

Ensure Python 3 and associated tooling are installed.

- **Python 3**
  - Recommended version: ≥ 3.8
  - [Download Python](https://www.python.org/downloads/)
- **pip** (Python package installer)
  - Usually comes bundled with Python 3
- **venv** (Virtual Environment module)
  - Included in the Python 3 standard library (`python3 -m venv`)

### 5. Rust

Install the Rust toolchain, including `cargo`.

- Recommended installation method: [Rustup](https://rustup.rs)
## Installing dependencies
```sh
python3 -m venv venv # Virtual env to avoid messing with existing packages
venv/bin/activate
pip install -r requirements.txt
```
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
## Running simulations
- In order to run Alibaba's OpenSimulator refer to [README-OpenSim](./opensim/README.md)
- In order to run Kubernetes Scheduler Simulator refer to [README-kube-sched-sim](./kub-scheduler-simulator/README.md)
- In order to run SimKube refer to [README-SimKube](./simkube/README.md)

