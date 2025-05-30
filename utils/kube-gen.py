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

animation_msg: str = ""
template_hollow_node = None
done = False
nodes = None
pods = None
total_node_resources: list = []
selected_nodes: list = []
selected_pods: list = []
loaded_nodes_qty: int = 0

def get_yaml_file(yaml_path:str, single:bool=True, limit: int=-1):
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

def patch_kwok_node(base_node: dict)-> None:
    patch_metadata = {
        'metadata': {
            'annotations': {
                'kwok.x-k8s.io/node': 'fake'
            }
        }
    }
    base_node.update(patch_metadata)

def patch_hollow_node(base_node: dict)-> None:
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

def patch_hollow_pod(base_pod: dict)-> None:
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



def generate_n_nodes(start_pos: int, end_pos: int, output_folder: str, _node_callback:Callable=None, _pod_callback:Callable=None, file_preffix=''):
    global nodes, pods, total_node_resources, selected_nodes, selected_pods
    pods_to_remove: list = []
    node_count = end_pos
    for node in nodes[start_pos:end_pos]:
        if _node_callback:
            # Mutate node using callback
            _node_callback(node)
        selected_nodes.append(node)

    for pod in pods:
        pod_cpu_req = int(pod['spec']['containers'][0]['resources']['requests']['cpu'][:-1])
        pod_mem_req = int(pod['spec']['containers'][0]['resources']['requests']['memory'][:-2])
        if _pod_callback:
            # Mutate pod using callback
            _pod_callback(pod)
        available_res_id = next(
            (idx for idx, remaining_res in enumerate(total_node_resources)
             if (remaining_res[0] - pod_cpu_req) >= 0 and (remaining_res[1] - pod_mem_req) >= 0),
            None
        )
        if available_res_id is not None:
            total_node_resources[available_res_id] = ((total_node_resources[available_res_id][0] - pod_cpu_req), (total_node_resources[available_res_id][1] - pod_mem_req))
            selected_pods.append(pod)
            pods_to_remove.append(pod)
        else:
            break

    # Save nodes
    with open(os.path.join(output_folder, f'{file_preffix}nodes-{node_count}.yaml'), 'w') as output_file:    
        yaml.dump_all(selected_nodes, output_file, default_flow_style=False)

    # Save pods file
    with open(os.path.join(output_folder, f'{file_preffix}pods-{node_count}.yaml'), 'w') as output_file:    
        yaml.dump_all(selected_pods, output_file, default_flow_style=False)

    for pod in pods_to_remove:
        pods.remove(pod)

def initialize_resources(node_count: int, nodes_path: str, pods_path: str):
    global nodes, pods, total_node_resources, loaded_nodes_qty
    nodes = get_yaml_file(args.nodes_path, False, args.node_count)
    pods = get_yaml_file(args.pods_path, False)
    for node in nodes:
        total_node_resources.append((int(node['status']['capacity']['cpu'][:-1]), int(node['status']['capacity']['memory'][:-2])))
    loaded_nodes_qty = len(nodes)

def animate():
    global done, animation_msg
    for c in itertools.cycle(['|', '/', '-', '\\']):
        if done:
            break
        print(f'\r{animation_msg}... ' + c, end='')
        time.sleep(0.1)

def print_msg(msg: str, cr:bool=False)-> None:
    current_time = datetime.now().strftime("[%H:%M:%S]")
    cr_str = "\r" if cr else ""    
    print(f"{cr_str}{current_time} - {msg}")

def print_ascii():
    print(r"""
      _  __     _           _____            
     | |/ /    | |         / ____|           
     | ' /_   _| |__   ___| |  __  ___ _ __  
     |  <| | | | '_ \ / _ \ | |_ |/ _ \ '_ \ 
     | . \ |_| | |_) |  __/ |__| |  __/ | | |
     |_|\_\__,_|_.__/ \___|\_____|\___|_| |_|
    
-------------------------------------------------""")

def main(args) -> None:
    global done, animation_msg, loaded_nodes_qty
    if not os.path.exists(args.output_folder):
        os.mkdir(args.output_folder) 
    if args.kubemark or args.simkube:
        print_msg(f'{"SimKube" if args.simkube else "Kubemark"} selected.')

    increment = args.increment if args.increment > 0 else args.node_count 
    node_callback: Callable = None
    pod_callback: Callable = None
    preffix = ''

    if args.kubemark:
        global template_hollow_node
        template_hollow_node = get_yaml_file(args.hollow_node_path)
        node_callback = patch_hollow_node
        pod_callback = patch_hollow_pod
        preffix = 'kubemark-'
    elif args.simkube:
        node_callback = patch_kwok_node
        preffix = 'simkube-'

    print_msg("Loading resources...")
    animation_msg = "Loading"
    animation_thread = threading.Thread(target=animate)
    animation_thread.start()
    initialize_resources(args.node_count, args.nodes_path, args.pods_path)
    done = True
    animation_thread.join()
    print_msg('Finished loading!                 ', True)
    
    stop_iteration = False
    steps = args.node_count//increment
    for i in range(0, steps):
        if stop_iteration:
            break
        done = False
        start_pos = i*increment
        end_pos = start_pos+increment
        node_qty = (i+1)*increment
        if abs(node_qty - loaded_nodes_qty) <= increment:
            stop_iteration = True
            node_qty = loaded_nodes_qty
            end_pos = loaded_nodes_qty
        print_msg(f'Generating {node_qty} nodes...')
        animation_msg = "Generating"
        animation_thread = threading.Thread(target=animate)
        animation_thread.start()
        generate_n_nodes(start_pos, end_pos, args.output_folder, node_callback, pod_callback, preffix)
        done = True
        animation_thread.join()
        print_msg('Finished!                 ', True)
    print_msg(f'Files saved to output folder: {args.output_folder}')
        
if __name__ == '__main__':
    parser = argparse.ArgumentParser(
                    prog='kube-gen.py')
    parser.add_argument('-o', '--output_folder', type=str, required=True, help='Output folder where generated files are saved')
    parser.add_argument('-c', '--node_count', type=int, default=400, help='Quantity of nodes to generate')
    parser.add_argument('-i', '--increment', type=int, default=0, help='Used to generate multiple files with steps of size n')
    parser.add_argument('-k', '--kubemark', default=False, action='store_true', help='Applies the kubemark patches to the generated files')
    parser.add_argument('-s', '--simkube', default=False, action='store_true', help='Applies the simkube patches to the generated files')
    parser.add_argument('-hn', '--hollow_node_path', type=str, default='hollow-node.yml', help='Template hollow node file used for Kubemark')
    parser.add_argument('-n', '--nodes_path', type=str, default='../example/cluster/nodes/nodes.yaml', help='Path of the YAML file containing the nodes')
    parser.add_argument('-p', '--pods_path', type=str, default='../example/applications/simulation/pods.yaml',  help='Path of the YAML file containing the pods')
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
