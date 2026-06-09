#!/bin/bash
readonly LOCAL_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DEFAULT_RUNS=3
readonly DEFAULT_START=0
readonly DEFAULT_MEMORY_THRESHOLD=95
readonly DEFAULT_MAX_SIMULATION_TIME=-1
readonly DEFAULT_EXPERIMENT_FILES_PATH="${LOCAL_PATH}/data/big"
readonly DEFAULT_OUTPUT_FOLDER="${LOCAL_PATH}/results"

VERBOSE=""
print_logo(){
    cat << EOF
  _  __     _          _____  _               _             
 | |/ /    | |        |  __ \(_)             | |            
 | ' /_   _| |__   ___| |  | |_ _ __ ___  ___| |_ ___  _ __ 
 |  <| | | | '_ \ / _ \ |  | | | '__/ _ \/ __| __/ _ \| '__|
 | . \ |_| | |_) |  __/ |__| | | | |  __/ (__| || (_) | |   
 |_|\_\__,_|_.__/ \___|_____/|_|_|  \___|\___|\__\___/|_|   
------------------------------------------------------------
EOF
}
usage() {
    print_logo
    cat << EOF
Usage: $(basename "$0") [options]

Optional arguments:
  -e EXPERIMENT_PATH   Path to experiment files directory (default: $DEFAULT_EXPERIMENT_FILES_PATH)
  -n RUNS              Number of runs per experiment (default: $DEFAULT_RUNS)
  -s START             Resume from a specific node count (default: $DEFAULT_START)
  -o OUT_FOLDER        Output folder for experiment results (default: $DEFAULT_OUTPUT_FOLDER)
  -t MEMORY_THRESHOLD  Memory threshold percentage (default: $DEFAULT_MEMORY_THRESHOLD)
  -x MAX_SIMULATION_TIME  Max allowed duration for a simulation (default: $DEFAULT_MAX_SIMULATION_TIME)
  -p PLOT_RESULTS      Automatically plots results from the experimentation (default: False)
  -v                   Verbose mode (default: false)
  -h                   Show this help message

Example:
  $(basename "$0") -e ./experiments -n 5 -o results/
EOF
}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    local color_reset="\033[0m"
    local color_info="\033[1;34m"
    local color_warn="\033[1;33m"
    local color_error="\033[1;31m"
    local color_debug="\033[0;37m"
    local color_sim="\033[0;33m"

    local color=""
    case "$level" in
        INFO)  color="$color_info" ;;
        WARN)  color="$color_warn" ;;
        ERROR) color="$color_error" ;;
        DEBUG) color="$color_debug" ;;
        *)     level="INFO"; color="$color_info" ;;
    esac

    if [[ -t 1 ]]; then
        echo -e "${color}[${timestamp}] [${level}]${color_reset} ${message}"
    else
        echo "[${timestamp}] [${level}] ${message}"
    fi
}

parse_args() {
    local OPTIND
    while getopts 'hvpe:c:n:s:o:t:x:' opt; do
        case "$opt" in
            e) EXPERIMENT_FILES_PATH=$(realpath "$OPTARG") ;;
            n) RUNS="$OPTARG" ;;
            s) START="$OPTARG" ;;
            o) OUT_FOLDER=$(realpath "$OPTARG") ;;
            t) MEMORY_THRESHOLD="$OPTARG" ;;
            x) MAX_SIMULATION_TIME="$OPTARG" ;;
            v) VERBOSE="true" ;;
            p) PLOT_RESULTS="true" ;;
            h) usage; exit 0 ;;
            :) log ERROR "Option -$OPTARG requires an argument." >&2; usage; exit 1 ;;
            ?) log ERROR "Invalid option -$OPTARG" >&2; usage; exit 1 ;;
        esac
    done

    if [[ -z $OUT_FOLDER ]]; then
        OUT_FOLDER=$DEFAULT_OUTPUT_FOLDER
    fi
    mkdir -p "$OUT_FOLDER"

    if [[ -z $MAX_SIMULATION_TIME ]]; then
        MAX_SIMULATION_TIME=$DEFAULT_MAX_SIMULATION_TIME
    fi

    if [[ -z $EXPERIMENT_FILES_PATH ]]; then
        EXPERIMENT_FILES_PATH="${DEFAULT_EXPERIMENT_FILES_PATH}"
    fi

    if [[ -z $START ]]; then
        START=$DEFAULT_START
    fi

    if [[ -z $MEMORY_THRESHOLD ]]; then
        MEMORY_THRESHOLD=$DEFAULT_MEMORY_THRESHOLD
    fi

    if [[ -z $RUNS ]]; then
        RUNS=$DEFAULT_RUNS
    fi

    if [[ ! -d "$EXPERIMENT_FILES_PATH" ]]; then
        log ERROR "Experiment files path does not exist: $EXPERIMENT_FILES_PATH" >&2
        exit 1
    fi
}
cleanup() {
    log INFO "Interrupted. Cleaning up..."
    # Kill any remaining child processes
    jobs -p | xargs -r kill
    exit 1
}

load_modules() {
    mapfile -t SIMULATORS < "$LOCAL_PATH/SIM_MODULES"
    if [[ ${#SIMULATORS[@]} -eq 0 ]]; then
        log ERROR "No simulators found in MODULES file" >&2
        exit 1
    fi
}

clean_cluster() {
    local SIMULATOR="$1"
    if [[ ${SIMULATOR} =~ ^(kube-sched|kubemark|simkube)$ ]]; then
        kind delete clusters --all
    elif [[ ${SIMULATOR} = "kwok" ]]; then
        kwokctl delete cluster --all
    fi
}

print_logo
log INFO "Loading modules..."
load_modules
log INFO "Modules loaded: ${SIMULATORS[*]}"

parse_args "$@"
log INFO "[Run all] - Received arguments: $*"
if [[ ! -z "${VERBOSE}" ]]; then
    set -euxo pipefail
fi

trap cleanup SIGINT
for i in "${!SIMULATORS[@]}"; do
    [[ -z "${SIMULATORS[i]}" ]] && continue
    log INFO "Starting experiments for ${SIMULATORS[i]}"
    if [[ ${SIMULATORS[i]} =~ ^(kwok|kube-sched)$ ]]; then
        DATA_PATH="${EXPERIMENT_FILES_PATH}/vanilla"
    elif [[ ${SIMULATORS[i]} = "k8s" ]]; then
        DATA_PATH="${EXPERIMENT_FILES_PATH}/k8s"
    else
        DATA_PATH="${EXPERIMENT_FILES_PATH}/${SIMULATORS[i]}"
    fi
    "${LOCAL_PATH}/kube-run.sh" -m "${SIMULATORS[i]}" \
    -e "${DATA_PATH}" \
    -n "${RUNS}" \
    -s "${START}" \
    -t "${MEMORY_THRESHOLD}" \
    -x "${MAX_SIMULATION_TIME}" \
    -o "${OUT_FOLDER}/${SIMULATORS[i]}.csv"
    if [[ $? -ne 0 ]]; then
        log WARN "${SIMULATORS[i]} experiment interrupted."
        clean_cluster "${SIMULATORS[i]}"
        break
    fi
    log INFO "Experiment for ${SIMULATORS[i]} completed"
    log INFO "Deleting all remaining kind clusters"
    clean_cluster "${SIMULATORS[i]}"
done
if [[ -n "$PLOT_RESULTS" ]]; then
    python "${LOCAL_PATH}/utils/kube-plot.py" -d "$OUT_FOLDER" -o "$OUT_FOLDER/plots" -l -b
fi