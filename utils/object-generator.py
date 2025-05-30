import os
import sys
import yaml
import copy
import argparse
from collections.abc import Callable
import pprint

template_hollow_node = None

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

def patch_hollow_node(base_node: dict):
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

def patch_hollow_pod(base_pod: dict):
    affinity_block = {
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
    base_pod['spec'].update(affinity_block)

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

def main(args) -> None:
    if not os.path.exists(args.output_folder):
        os.mkdir(args.output_folder) 
    if args.kubemark:
        print("Kubemark hollow nodes and pods generation starting...")
        global template_hollow_node
        template_hollow_node = get_yaml_file(args.hollow_node_path)
        generate_n_nodes(args.node_count, args.nodes_path, args.pods_path, args.output_folder, patch_hollow_node, patch_hollow_pod, 'kubemark')
    else:
        print("Nodes and pods generation starting...")
        generate_n_nodes(args.node_count, args.nodes_path, args.pods_path, args.output_folder)
        
if __name__ == '__main__':
    parser = argparse.ArgumentParser(
                    prog='object-generator.py')
    parser.add_argument('-o', '--output_folder', type=str, required=True)
    parser.add_argument('-c', '--node_count', type=int, default=400)
    parser.add_argument('-k', '--kubemark', default=False, action='store_true')
    parser.add_argument('-hn', '--hollow_node_path', type=str, default='hollow-node.yml')
    parser.add_argument('-n', '--nodes_path', type=str, default='../example/cluster/nodes/nodes.yaml')
    parser.add_argument('-p', '--pods_path', type=str, default='../example/applications/simulation/pods.yaml')
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
