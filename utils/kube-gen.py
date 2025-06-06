import os
import sys
import yaml
import copy
import argparse
import itertools
import threading
import time
from collections.abc import Callable
import pprint
from datetime import datetime
from typing import List, Dict, Tuple, Optional, Any

animation_msg: str = ""
template_hollow_node = None
simon_template = None
done = False
nodes = None
pods = None
new_node_path = None
total_node_resources: List[Tuple[int, int]] = []
selected_nodes: List[Dict[str, Any]] = []
selected_pods: List[Dict[str, Any]] = []
loaded_nodes_qty: int = 0

def create_folder(path: str) -> None:
    """Create a directory if it doesn't exist."""
    if not os.path.exists(path):
        os.makedirs(path, exist_ok=True)

def get_yaml_file(yaml_path: str, single: bool = True, limit: int = -1) -> Any:
    """Load YAML file(s) and return the parsed content."""
    try:
        with open(yaml_path) as yaml_file:
            if single:
                return yaml.safe_load(yaml_file)
            else:
                data = yaml.safe_load_all(yaml_file)
                res_list = list(data)
                limit = limit if 0 < limit < len(res_list) else len(res_list)
                return res_list[:limit]
    except Exception as e:
        global done
        done=True
        print(f'\rError opening file: {yaml_path}')
        print(e)
        sys.exit(-1)

def patch_kwok_node(base_node: Dict[str, Any]) -> None:
    """Apply KWOK node patches to the base node configuration."""
    patch_data = {
        'metadata': {
            'name': base_node['metadata']['name'],
            'annotations': {
                'kwok.x-k8s.io/node': 'fake'
            }
        },
        'spec':{
            'taints':[
                {
                    'effect': 'NoSchedule',
                    'key': 'openb-only',
                    'value': 'true'
                }
            ]
        }
    }
    base_node['metadata'].update(patch_data['metadata'])
    base_node['spec'] = patch_data['spec']
    # base_node['metadata']['labels'].update({"node-role.kubernetes.io/node": "simkube-node"})

def patch_kwok_pod(base_pod: Dict[str, Any]) -> None:
    """Apply KWOK node patches to the base node configuration."""
    patch_affinity = {
        "tolerations": [
            {
                "key": "openb-only",
                "operator": "Equal",
                "value": "true",
                "effect": "NoSchedule"
            }
        ]
    }
    base_pod['spec'].update(patch_affinity)

def patch_hollow_node(base_node: Dict[str, Any]) -> None:
    """Apply hollow node patches for Kubemark configuration."""
    global template_hollow_node
    new_node = copy.deepcopy(template_hollow_node)
    new_extended_resources = ','.join(f'{key}={value}' for key, value in base_node['status']['allocatable'].items())
    new_labels = ','.join(f'{key}={value}' for key, value in base_node['metadata']['labels'].items())

    new_node['metadata']['name'] = base_node['metadata']['name']
    new_node['metadata']['labels']['name'] = base_node['metadata']['name']
    new_node['spec']['containers'][0]['command'][-2] += f',{new_labels}'
    new_node['spec']['containers'][0]['command'][-1] = new_node['spec']['containers'][0]['command'][-1].replace('template_node_extended_resources',new_extended_resources)
    base_node.clear()
    base_node.update(new_node)

def patch_hollow_pod(base_pod: Dict[str, Any]) -> None:
    """Apply hollow pod patches for Kubemark configuration."""
    patch_affinity = {
                      'affinity': {
                        'nodeAffinity': {
                          'requiredDuringSchedulingIgnoredDuringExecution': {
                            'nodeSelectorTerms': [
                              {
                                'matchExpressions': [
                                  {
                                    'key': 'node-role.kubernetes.io/node',
                                    'operator': 'In',
                                    'values': ['kubemark-node']
                                  }
                                ]
                              }
                            ]
                          }
                        }
                      }
                    }
    base_pod['spec']['containers'][0]['imagePullPolicy'] = 'IfNotPresent'
    base_pod['spec']['containers'][0]['image'] = 'docker.io/busybox:latest'
    base_pod['metadata']['namespace'] = 'kubemark'
    base_pod['spec'].update(patch_affinity)

def parse_cpu(cpu_str: str) -> int:
    return int(cpu_str[:-1]) if cpu_str.endswith('m') else int(cpu_str)

def parse_memory(mem_str: str) -> int:
    return int(mem_str[:-2]) if mem_str.endswith('Mi') else int(mem_str)

def generate_n_nodes(start_pos: int, end_pos: int, step_size: int, node_output_folder: str, pod_output_folder: str, _node_callback: Optional[Callable] = None, _pod_callback: Optional[Callable] = None, file_preffix: str = '') -> None:
    """Generate and save node and pod configurations within the specified range."""
    global nodes, pods, total_node_resources, selected_nodes, selected_pods, loaded_nodes_qty
    pods_to_remove: List[Dict[str, Any]] = []
    node_count: int = end_pos
    for node in nodes[start_pos:end_pos]:
        if _node_callback:
            # Mutate node using callback
            _node_callback(node)
        selected_nodes.append(node)

    for pod in pods:
        pod_cpu_req = parse_cpu(pod['spec']['containers'][0]['resources']['requests']['cpu'])
        pod_mem_req = parse_memory(pod['spec']['containers'][0]['resources']['requests']['memory'])
        if _pod_callback:
            # Mutate pod using callback
            _pod_callback(pod)
        pod['spec']['containers'][0]['imagePullPolicy'] = 'IfNotPresent'
        available_res_id = next(
            (idx for idx, remaining_res in enumerate(total_node_resources[start_pos:end_pos])
             if (remaining_res[0] - pod_cpu_req) >= 0 and (remaining_res[1] - pod_mem_req) >= 0),
            None
        )
        if available_res_id is not None:
            available_res_id = available_res_id + start_pos
            total_node_resources[available_res_id] = (
                                    (total_node_resources[available_res_id][0] - pod_cpu_req),
                                    (total_node_resources[available_res_id][1] - pod_mem_req)
                                )
            selected_pods.append(pod)
            pods_to_remove.append(pod)

    remainder = node_count%step_size
    node_count = node_count if remainder == 0 else node_count-remainder
    # Save nodes
    with open(os.path.join(node_output_folder, f'{file_preffix}nodes-{node_count}.yaml'), 'w') as output_file:
        yaml.dump_all(selected_nodes, output_file, default_flow_style=False)

    # Save pods file
    with open(os.path.join(pod_output_folder, f'{file_preffix}pods-{node_count}.yaml'), 'w') as output_file:
        yaml.dump_all(selected_pods, output_file, default_flow_style=False)
    print_msg(f"Generated {node_count} nodes and {len(selected_pods)} pods.", True)
    for pod in pods_to_remove:
        pods.remove(pod)

def generate_simon_config(output_folder: str, node_output_path: str, pod_output_path: str, count: int) -> None:
    """Generate Simon configuration file for OpenSim."""
    global simon_template, new_node_path
    new_simon_file: Dict[str, Any] = copy.deepcopy(simon_template)
    new_simon_file['spec']['cluster']['customConfig'] = os.path.join(node_output_path, f'opensim-nodes-{count}.yaml')
    new_simon_file['spec']['appList'][0]['name'] = f'simulation-{count}'
    new_simon_file['spec']['appList'][0]['path'] = os.path.join(pod_output_path, f'opensim-pods-{count}.yaml')
    new_simon_file['spec']['newNode'] = new_node_path
    # Save simon file
    with open(os.path.join(output_folder, f'simon-config-{count}.yaml'), 'w') as output_file:
        yaml.dump(new_simon_file, output_file, default_flow_style=False)

def initialize_opensim_directory(output_path: str, node_count: int, step: int) -> List[Tuple[str, str]]:
    """Initialize OpenSim directory structure and generate configuration files."""
    global loaded_nodes_qty
    node_count = node_count if loaded_nodes_qty > node_count else node_count - (node_count%loaded_nodes_qty)
    applications_path = os.path.join(output_path, 'applications')
    create_folder(applications_path)
    output_folders = []
    steps = node_count//step
    for i in range(0, steps):
        data_size = (i+1)*step
        nodes_path = os.path.join(output_path, f'cluster-{data_size}')
        pods_path = os.path.join(applications_path, f'pods-{data_size}')
        create_folder(nodes_path)
        create_folder(pods_path)
        generate_simon_config(output_path, nodes_path, pods_path, data_size)
        output_folders.append((nodes_path, pods_path))
    return output_folders

def initialize_resources(node_count: int, nodes_path: str, pods_path: str) -> None:
    """Load and initialize node and pod resources from YAML files."""
    global nodes, pods, total_node_resources, loaded_nodes_qty
    nodes = get_yaml_file(args.nodes_path, False, args.node_count)
    pods = get_yaml_file(args.pods_path, False)
    for node in nodes:
        total_node_resources.append((int(node['status']['capacity']['cpu'][:-1]), int(node['status']['capacity']['memory'][:-2])))
    loaded_nodes_qty = len(nodes)

def animate() -> None:
    """Display rotating animation indicator while processing."""
    global done, animation_msg
    for c in itertools.cycle(['|', '/', '-', '\\']):
        if done:
            break
        print(f'\r{animation_msg}... ' + c, end='')
        time.sleep(0.1)

def print_msg(msg: str, cr: bool = False) -> None:
    """Print timestamped message with optional carriage return."""
    current_time = datetime.now().strftime("[%H:%M:%S]")
    cr_str = "\r" if cr else ""
    print(f"{cr_str}{current_time} - {msg}")

def print_ascii() -> None:
    """Print ASCII art banner for the application."""
    print(r"""      _  __     _           _____
     | |/ /    | |         / ____|
     | ' /_   _| |__   ___| |  __  ___ _ __
     |  <| | | | '_ \ / _ \ | |_ |/ _ \ '_ \
     | . \ |_| | |_) |  __/ |__| |  __/ | | |
     |_|\_\__,_|_.__/ \___|\_____|\___|_| |_|

-------------------------------------------------""")

def main(args: argparse.Namespace) -> None:
    """Main function that orchestrates the Kubernetes resource generation process."""
    global done, animation_msg, loaded_nodes_qty, simon_template, new_node_path
    output_folder = os.path.abspath(args.output_folder)
    create_folder(output_folder)

    increment: int = args.increment if args.increment > 0 else args.node_count
    node_callback: Optional[Callable] = None
    pod_callback: Optional[Callable] = None
    preffix: str = ''
    node_output_folder: str = output_folder
    pod_output_folder: str = output_folder
    output_folders: List[Tuple[str, str]] = []

    print_msg("Loading resources...")
    animation_msg = "Loading"
    animation_thread = threading.Thread(target=animate)
    animation_thread.start()
    initialize_resources(args.node_count, args.nodes_path, args.pods_path)
    done = True
    animation_thread.join()
    print_msg('Finished loading!                 ', True)

    if args.kubemark:
        global template_hollow_node
        template_hollow_node = get_yaml_file(args.hollow_node_path)
        node_callback = patch_hollow_node
        pod_callback = patch_hollow_pod
        preffix = 'kubemark-'
    elif args.simkube:
        node_callback = patch_kwok_node
        pod_callback = patch_kwok_pod
        preffix = 'simkube-'
    elif args.open_sim:
        preffix = 'opensim-'
        new_node_path = os.path.abspath(args.new_node_path)
        simon_template = get_yaml_file('simon-config.yaml')
        output_folders = initialize_opensim_directory(output_folder, args.node_count, increment)

    if preffix != '':
        print_msg(f'{preffix.capitalize()[:-1]} selected.')

    stop_iteration = False
    steps = args.node_count//increment
    for i in range(0, steps):
        if stop_iteration:
            break
        done = False
        start_pos = i*increment
        end_pos = start_pos+increment
        node_qty = (i+1)*increment
        if abs(node_qty - loaded_nodes_qty) < increment:
            stop_iteration = True
            node_qty = loaded_nodes_qty
            end_pos = loaded_nodes_qty
        print_msg(f'Generating {node_qty} nodes...')
        animation_msg = "Generating"
        animation_thread = threading.Thread(target=animate)
        animation_thread.start()
        if len(output_folders) > 0:
            node_output_folder, pod_output_folder = output_folders.pop(0)
        generate_n_nodes(start_pos, end_pos, increment, node_output_folder, pod_output_folder, node_callback, pod_callback, preffix)
        done = True
        animation_thread.join()
        print_msg('Finished!                 ', True)
    print_msg(f'Files saved to output folder: {output_folder}')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
                    prog='kube-gen.py')
    parser.add_argument('-o', '--output_folder', type=str, required=True, help='Output folder where generated files are saved')
    parser.add_argument('-c', '--node_count', type=int, default=400, help='Quantity of nodes to generate')
    parser.add_argument('-i', '--increment', type=int, default=0, help='Used to generate multiple files with steps of size n')
    parser.add_argument('-k', '--kubemark', default=False, action='store_true', help='Applies the kubemark patches to the generated files')
    parser.add_argument('-s', '--simkube', default=False, action='store_true', help='Applies the simkube patches to the generated files')
    parser.add_argument('-os', '--open_sim', default=False, action='store_true', help='Generates files with the opensim folder structure')
    parser.add_argument('-hn', '--hollow_node_path', type=str, default='hollow-node.yml', help='Template hollow node file used for Kubemark')
    parser.add_argument('-nn', '--new_node_path', type=str, default='base/newnode', help='Path to the YAML file containing the new node template for opensim')
    parser.add_argument('-n', '--nodes_path', type=str, default='base/nodes.yaml', help='Path to the YAML file containing the nodes')
    parser.add_argument('-p', '--pods_path', type=str, default='base/pods.yaml',  help='Path to the YAML file containing the pods')
    print_ascii()
    try:
        args = parser.parse_args()
        if args.kubemark and (args.node_count is None or args.hollow_node_path is None or args.nodes_path is None or args.pods_path is None):
            raise Exception('Required arguments not provided')
        elif args.output_folder is None:
            raise Exception('No output folder provided')
    except:
        parser.print_help()
        sys.exit(-1)
    main(args)
