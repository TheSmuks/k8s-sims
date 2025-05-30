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

template_hollow_node = None
done = False

def get_yaml_file(yaml_path:str, single:bool=True, limit: int=-1):
    try:
        with open(yaml_path) as yaml_file:
            if single:
                return yaml.safe_load(yaml_file)
            else:
                data = yaml.safe_load_all(yaml_file)
                if limit > 0:
                    return [ next(data) for _ in range(limit) ]
                return [ value for value in data ]
    except:
        print(f'Error opening file: {yaml_path}')
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

def generate_n_nodes(node_count: int,  nodes_path: str, pods_path: str, output_folder: str, _node_callback:Callable=None, _pod_callback:Callable=None, file_preffix=''):
    nodes = get_yaml_file(nodes_path, False, node_count)
    pods = get_yaml_file(pods_path, False)
    total_resources: list = []
    selected_nodes: list = []
    selected_pods: list = []
    for node in nodes:
        total_resources.append((int(node['status']['capacity']['cpu'][:-1]), int(node['status']['capacity']['memory'][:-2])))
        if _node_callback:
            # Mutate node using callback
            _node_callback(node)
        selected_nodes.append(node)

    # Save nodes
    with open(os.path.join(output_folder, f'{file_preffix}-nodes-{node_count}.yaml'), 'w') as output_file:    
        yaml.dump_all(selected_nodes, output_file, default_flow_style=False)

    for pod in pods:
        pod_cpu_req = int(pod['spec']['containers'][0]['resources']['requests']['cpu'][:-1])
        pod_mem_req = int(pod['spec']['containers'][0]['resources']['requests']['memory'][:-2])
        if _pod_callback:
            # Mutate pod using callback
            _pod_callback(pod)
        available_res_id = next(
            (idx for idx, remaining_res in enumerate(total_resources)
             if (remaining_res[0] - pod_cpu_req) >= 0 and (remaining_res[1] - pod_mem_req) >= 0),
            None
        )
        if available_res_id is not None:
            total_resources[available_res_id] = ((total_resources[available_res_id][0] - pod_cpu_req), (total_resources[available_res_id][1] - pod_mem_req))
            selected_pods.append(pod)
        else:
            break
    # Save pods file
    with open(os.path.join(output_folder, f'{file_preffix}-pods-{node_count}.yaml'), 'w') as output_file:    
        yaml.dump_all(selected_pods, output_file, default_flow_style=False)

def animate():
    global done
    for c in itertools.cycle(['|', '/', '-', '\\']):
        if done:
            break
        print('\rProcessing... ' + c, end='')
        time.sleep(0.1)

def start_animation_thread():
    t = threading.Thread(target=animate)
    t.start()

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
    
-------------------------------------------------                                         
    """)

def main(args) -> None:
    if not os.path.exists(args.output_folder):
        os.mkdir(args.output_folder) 
    if args.kubemark or args.simkube:
        print_msg(f'{"SimKube" if args.simkube else "Kubemark"} selected.')
    print_msg(f'Generating {args.node_count} nodes...')
    start_animation_thread()
    if args.kubemark:
        global template_hollow_node
        template_hollow_node = get_yaml_file(args.hollow_node_path)
        generate_n_nodes(args.node_count, args.nodes_path, args.pods_path, args.output_folder, patch_hollow_node, patch_hollow_pod, 'kubemark')
    elif args.simkube:
        generate_n_nodes(args.node_count, args.nodes_path, args.pods_path, args.output_folder, patch_kwok_node, None, 'simkube')
    else:
        generate_n_nodes(args.node_count, args.nodes_path, args.pods_path, args.output_folder)
    global done    
    done = True
    print_msg('Finished!                 ', True)
    print_msg(f'Files saved to output folder: {args.output_folder}')
        
if __name__ == '__main__':
    parser = argparse.ArgumentParser(
                    prog='kube-gen.py')
    parser.add_argument('-o', '--output_folder', type=str, required=True)
    parser.add_argument('-c', '--node_count', type=int, default=400)
    parser.add_argument('-k', '--kubemark', default=False, action='store_true')
    parser.add_argument('-s', '--simkube', default=False, action='store_true')
    parser.add_argument('-hn', '--hollow_node_path', type=str, default='hollow-node.yml')
    parser.add_argument('-n', '--nodes_path', type=str, default='../example/cluster/nodes/nodes.yaml')
    parser.add_argument('-p', '--pods_path', type=str, default='../example/applications/simulation/pods.yaml')
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
