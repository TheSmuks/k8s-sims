kind create cluster --config=kind-config.yaml --name testing --image kindest/node:v1.29.0
kind get kubeconfig --name testing > ./config
sed -i 's|server: https://127.0.0.1:[0-9]\+|server: https://kubernetes.default.svc:443|' ./config
kubectl config use-context kind-testing
kubectl create ns kubemark
kubectl create secret generic kubeconfig \
--type=Opaque --namespace=kubemark \
--from-file=kubelet.kubeconfig=config \
--from-file=kubeproxy.kubeconfig=config
kubectl create -f hollow-node.yml
while [ $(kubectl get pods -n kubemark | grep "Running" | wc -l) -lt 750 ] 
do 
	RUNNING_CONTAINERS=$(kubectl get pods -n kubemark | grep "Running" | wc -l) 
	echo " $((750-$RUNNING_CONTAINERS)) containers remaining..." 
done; 

