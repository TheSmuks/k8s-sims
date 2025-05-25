import yaml
import copy
import argparse

def get_yaml_file(yaml_path:str, single:bool=True):
    with open(yaml_path) as yaml_file:
        if single:
            return yaml.safe_load(yaml_file)
        else:
            data = yaml.safe_load_all(yaml_file)
            return [ value for value in data ]
def replace_template_with_node(node, template:str):
    pass

def main(args) -> None:
    template: dict = get_yaml_file("hollow-node.yml")
    nodes = get_yaml_file("../../example/cluster/nodes/nodes.yaml", False)
    data: list = []
    total_resources = []
    node_count = args.count
    for base_node in nodes[:node_count]:
        new_node = copy.deepcopy(template)
        new_node['metadata']['name'] = base_node['metadata']['name']
        new_node['metadata']['labels']['name'] = base_node['metadata']['name']
        new_labels = ",".join(f"{key}={value}" for key, value in base_node['metadata']['labels'].items())
        new_extended_resources = ",".join(f"{key}={value}" for key, value in base_node['status']['allocatable'].items())
        new_node['spec']['containers'][0]['command'][-2] += f",{new_labels}"
        new_node['spec']['containers'][0]['command'][-1] = new_node['spec']['containers'][0]['command'][-1].replace("template_node_extended_resources",new_extended_resources) 
        total_resources.append((int(base_node['status']['capacity']['cpu'][:-1]), int(base_node['status']['capacity']['memory'][:-2])))
        data.append(new_node)
    with open("hollow-nodes.yml", "w") as output_file:    
        yaml.dump_all(data, output_file, default_flow_style=False)
    pods = get_yaml_file("../../example/applications/simulation/pods.yaml", False)
    pods_data: list = []
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
    for pod in pods:
        pod_cpu_req = int(pod['spec']['containers'][0]['resources']['requests']['cpu'][:-1])
        pod_mem_req = int(pod['spec']['containers'][0]['resources']['requests']['memory'][:-2])
        pod['spec']['containers'][0]['imagePullPolicy'] = 'IfNotPresent'
        pod['spec']['containers'][0]['image'] = 'docker.io/busybox:latest'
        pod['metadata']['namespace'] = 'kubemark'
        pod['spec'].update(affinity_block)
        available_res_id = next(
            (idx for idx, remaining_res in enumerate(total_resources)
             if (remaining_res[0] - pod_cpu_req) >= 0 and (remaining_res[1] - pod_mem_req) >= 0),
            None
        )
        if available_res_id is not None:
            total_resources[available_res_id] = ((total_resources[available_res_id][0] - pod_cpu_req), (total_resources[available_res_id][1] - pod_mem_req))
            pods_data.append(pod)
        else:
            break
    with open("pods.yaml", "w") as output_file:    
        yaml.dump_all(pods_data, output_file, default_flow_style=False)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
                    prog='pod-to-hollow-node.py')
    parser.add_argument('-c', '--count', type=int, default=400)
    args = parser.parse_args()    
    main(args)
