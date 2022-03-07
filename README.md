# K8s-Cloud-init
Cloud init files to deploy k8s masters and nodes with kubeadm. 

# Example with multipass

* Deploy them :
```bash
multipass launch --cpus 2 --mem 2G --disk 20G --name master --cloud-init cloud-init-master-cd.yaml
multipass launch --cpus 2 --mem 2G --disk 20G --name node1 --cloud-init cloud-init-nodes-cd.yaml
multipass launch --cpus 2 --mem 2G --disk 20G --name node2 --cloud-init cloud-init-nodes-cd.yaml
```

* Join nodes to the cluster (on the master) :
```bash
kubeadm token create --print-join-command
```
