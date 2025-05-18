import yaml
import copy

def get_yaml_file(yaml_path:str, single:bool=True):
    with open(yaml_path) as yaml_file:
        if single:
            return yaml.safe_load(yaml_file)
        else:
            data = yaml.safe_load_all(yaml_file)
            return [ value for value in data ]
def replace_template_with_node(node, template:str):
    pass

def main() -> None:
    template: dict = get_yaml_file("hollow-node.yml")
    nodes = get_yaml_file("../../example/cluster/nodes/nodes.yaml", False)
    data: list = []
    for base_node in nodes:
        new_node = copy.deepcopy(template)
        new_node['metadata']['name'] = base_node['metadata']['name']
        new_node['metadata']['labels']['name'] = base_node['metadata']['name']
        new_labels = ",".join(f"{key}={value}" for key, value in base_node['metadata']['labels'].items())
        new_extended_resources = ",".join(f"{key}={value}" for key, value in base_node['status']['allocatable'].items())
        new_node['spec']['containers'][0]['command'][-2] += f",{new_labels}"
        new_node['spec']['containers'][0]['command'][-1] = new_node['spec']['containers'][0]['command'][-1].replace("template_node_extended_resources",new_extended_resources) 
        data.append(new_node)
    with open("hollow-nodes.yml", "w") as output_file:    
        yaml.dump_all(data, output_file, default_flow_style=False)

if __name__ == "__main__":
    main()
