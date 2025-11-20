# Deployment Guide

This guide walks through deploying the Kubernetes cluster on Azure.

## Prerequisites

Before deploying, ensure you've completed the [Setup Guide](SETUP.md).

## Deployment Methods

### Method 1: Using Azure Developer CLI (Recommended)

The simplest method using `azd`:

```bash
# From project root
./scripts/load-env-and-sync-azd.sh    # Ensure TF_VAR_ssh_public_key is set
azd up
```

This single command will:
1. Validate environment variables
2. Run Terraform to provision infrastructure
3. Run Ansible to configure Kubernetes
4. Generate kubeconfig file

### Method 2: Using the Deploy Script

```bash
# From project root
./scripts/deploy.sh
```

This script provides more visibility into each step.

### Method 3: Manual Step-by-Step

For full control and learning:

#### Step 1: Provision Infrastructure with Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Review the plan
terraform plan -out=tfplan

# Apply the infrastructure
terraform apply tfplan

# View outputs
terraform output
```

If Terraform prompts for `ssh_public_key`, export the variable first:
```bash
export TF_VAR_ssh_public_key="$SSH_PUBLIC_KEY"   # or set via azd env set TF_VAR_ssh_public_key
terraform apply tfplan
```

**What gets created:**
- Resource Group
- Virtual Network (VNet) with subnet
- Network Security Groups (NSGs) with rules
- Public IPs for each VM
- Network Interfaces
- 3 Virtual Machines (Ubuntu 22.04):
  - 1 control plane node
  - 2 worker nodes

#### Step 2: Wait for VMs to Initialize

```bash
# Wait 30-60 seconds for VMs to boot and be SSH-ready
sleep 30
```

#### Step 3: Generate Inventory and Configure Kubernetes with Ansible

```bash
# Generate static inventory from Terraform outputs
./scripts/generate-inventory.sh

cd ansible

# Test connectivity to all nodes
ansible all -i inventory/hosts.yml -m ping

# Run the configuration playbook
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

**What gets configured:**
- System prerequisites (kernel modules, sysctl settings)
- RKE2 installation on all nodes
- Control plane initialization
- Worker nodes joining the cluster
- Kubeconfig retrieval

**Note:** The `generate-inventory.sh` script creates a static inventory file from Terraform outputs. This is automatically done during `azd up` but can be run manually if needed.

#### Step 4: Access Your Cluster

```bash
# Set kubeconfig environment variable
export KUBECONFIG=$(pwd)/../kubeconfig

# Verify cluster
kubectl get nodes
kubectl cluster-info
kubectl get pods -A
```

## Post-Deployment Tasks

### 1. Verify Cluster Health

```bash
# Check all nodes are Ready
kubectl get nodes

# Verify system pods
kubectl get pods -A

# Check cluster info
kubectl cluster-info
```

Expected output:
```
NAME                STATUS   ROLES                       AGE   VERSION
k8s-control-plane   Ready    control-plane,etcd,master   5m    v1.28.5+rke2r1
k8s-worker-1        Ready    <none>                      3m    v1.28.5+rke2r1
k8s-worker-2        Ready    <none>                      3m    v1.28.5+rke2r1
```

### 2. Configure kubectl Context

```bash
# Add to your shell profile for persistence
echo "export KUBECONFIG=$HOME/path/to/kubernetes-azure/kubeconfig" >> ~/.bashrc
source ~/.bashrc

# Or copy to default location
mkdir -p ~/.kube
cp kubeconfig ~/.kube/config-azure
export KUBECONFIG=~/.kube/config-azure
```

### 3. Test Cluster Functionality

Deploy a test application:

```bash
# Create a test namespace
kubectl create namespace test

# Deploy nginx
kubectl create deployment nginx --image=nginx --namespace=test

# Expose it
kubectl expose deployment nginx --port=80 --type=NodePort --namespace=test

# Check status
kubectl get all -n test

# Get the NodePort
kubectl get svc nginx -n test

# Test from outside (replace with worker node IP and NodePort)
curl http://<worker-ip>:<node-port>
```

### 4. Install Additional Components (Optional)

#### Install Metrics Server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify
kubectl top nodes
```

#### Install Kubernetes Dashboard

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Create admin user (for testing only)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# Get token
kubectl -n kubernetes-dashboard create token admin-user

# Access dashboard (in another terminal)
kubectl proxy

# Open in browser: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

## Scaling the Cluster

### Adding Worker Nodes

1. Update `.env`:
   ```bash
   VM_COUNT=5  # Increase from 3 to 5 (adds 2 workers)
   ```

2. Re-run deployment:
   ```bash
   azd up
   # or
   cd terraform && terraform apply
   ../scripts/generate-inventory.sh  # Regenerate inventory
   cd ansible && ansible-playbook -i inventory/hosts.yml playbooks/site.yml
   ```

### Removing Worker Nodes

1. Drain and delete nodes:
   ```bash
   kubectl drain k8s-worker-2 --ignore-daemonsets --delete-emptydir-data
   kubectl delete node k8s-worker-2
   ```

2. Update `.env` and re-run:
   ```bash
   VM_COUNT=2  # Decrease worker count
   terraform apply
   ```

## Updating Kubernetes Version

1. Update `.env`:
   ```bash
   RKE2_VERSION=v1.29.0+rke2r1  # New version
   ```

2. Update nodes one at a time:
   ```bash
   # Control plane
   ansible-playbook -i inventory/hosts.yml playbooks/site.yml --limit control_plane

   # Workers (one at a time)
   ansible-playbook -i inventory/hosts.yml playbooks/site.yml --limit worker-1
   ```

## Backup and Recovery

### Backup etcd

```bash
# SSH to control plane
ssh azureuser@<control-plane-ip>

# Backup etcd
sudo /var/lib/rancher/rke2/bin/etcdctl snapshot save /tmp/etcd-snapshot.db \
  --cacert /var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
  --cert /var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
  --key /var/lib/rancher/rke2/server/tls/etcd/server-client.key

# Download backup
scp azureuser@<control-plane-ip>:/tmp/etcd-snapshot.db ./backups/
```

### Restore from Backup

```bash
# Upload backup
scp ./backups/etcd-snapshot.db azureuser@<control-plane-ip>:/tmp/

# SSH to control plane
ssh azureuser@<control-plane-ip>

# Stop RKE2
sudo systemctl stop rke2-server

# Restore
sudo /var/lib/rancher/rke2/bin/etcdctl snapshot restore /tmp/etcd-snapshot.db \
  --data-dir=/var/lib/rancher/rke2/server/db/etcd

# Start RKE2
sudo systemctl start rke2-server
```

## Monitoring

### View Logs

```bash
# Terraform logs
cd terraform
terraform show

# Ansible logs
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/site.yml -vvv

# RKE2 logs (on nodes)
ssh azureuser@<node-ip>
sudo journalctl -u rke2-server -f  # control plane
sudo journalctl -u rke2-agent -f   # workers
```

### Azure Monitoring

```bash
# View resources
az resource list --resource-group rg-k8s-azure-dev --output table

# View VM status
az vm list --resource-group rg-k8s-azure-dev --show-details --output table

# View network info
az network vnet list --resource-group rg-k8s-azure-dev --output table
```

## Cleanup

### Destroy Infrastructure

**Warning**: This will delete all resources and cannot be undone!

```bash
# Using azd
azd down

# Or using script
./scripts/destroy.sh

# Or manually
cd terraform
terraform destroy
```

This will:
- Delete all VMs
- Delete all networking components
- Delete the resource group
- Clean up local kubeconfig

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.

## Next Steps

- Review [SECURITY.md](SECURITY.md) for security hardening
- Set up monitoring and logging
- Configure automated backups
- Implement CI/CD pipelines
- Deploy your applications
