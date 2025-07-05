# Template for creating a module, if the behavior of a certain function
# should not be modified then remove the code block corresponding to the function

# module.sh is then loaded into kube-run.sh

# Can override any of the variables used in kube-run.sh. Such as:
# START_TIME=0
# CLUSTER_NAME=""
# NAMESPACE="paib-gpu"
# CONTAINERS_TO_WATCH=""
# FILE_PATTERN="nodes-*.yaml"
# START=0
# RUN_CONDITION="true"
# UNSCHEDULED_PODS=0
# TIMEOUT_REACHED="0"

get_container_ids(){
    # Should print containers ID one per line
    :;
}

get_cgroup_base(){
    # Returns cgroup base path such as: /sys/fs/cgroups/program/...
    :;
}

get_memory_usage(){
    # Returns memory usage in Bytes
    :;
}

get_cpu_usage(){
    # Should return TOTAL_CPU_TIME USER_CPU_TIME SYS_CPU_TIME 
    :;
}

metric_collector(){
    # Parse $1 as type, return get_memory_usage or get_cpu_usage
    :;
}

save_metrics() {
    # Receives on $1 memory usage, $2, $3, and $4 represent CPU usage
    :;
}

wait_for_namespace(){
    # Function used to wait for a namespace to be fully created and operative
    :;
}

wait_for_simulator_state(){
    # Function used to wait for a certain simulator to reach desired state $1
    :;
}

check_max_time(){
    # Function used to check if simulation has exceeded the maximum time
    :;
}

watch_pod_scheduling(){
    # Function used to wait until all schedulable pods have a node assigned
    :;
}

# Cluster related
create_cluster(){
    # Creates the simulation cluster
    :;
}

cluster_setup(){
    # Cluster setup logic
    :;
}

deploy_objects(){
    # Used to deploy objects on the cluster
    :;
}

cleanup_cluster(){
    # Used to remove the cluster and resources related to the simulation
    :;
}