# Quick Reference Card

Essential commands and information for the Kubernetes on Azure project.

## 🚀 Quick Start Commands

```bash
# Setup
cp .env.example .env && vim .env

# Load ALL environment variables (critical for Terraform auth)
set -a && . ./.env && set +a
export TF_VAR_ssh_public_key="${SSH_PUBLIC_KEY}"

# Deploy everything
azd up

# Access cluster
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes

# Destroy everything
azd down
```

## 📝 Environment Variables (.env)

```bash
# Required
AZURE_SUBSCRIPTION_ID=<your-subscription-id>
ARM_CLIENT_ID=<service-principal-id>
ARM_CLIENT_SECRET=<service-principal-secret>
SSH_PUBLIC_KEY=<your-ssh-public-key>
RKE2_TOKEN=<secure-random-token>

# Optional (with defaults)
AZURE_LOCATION=eastus
VM_COUNT=3
RKE2_VERSION=v1.28.5+rke2r1
```

### Terraform Variable Mapping

Terraform variables are only auto-populated from the environment when they use the `TF_VAR_` prefix. This project defines a Terraform variable named `ssh_public_key` without a default, so Terraform (via `azd`) will prompt unless `TF_VAR_ssh_public_key` is set.

You may have `SSH_PUBLIC_KEY` in your `.env`, but `azd up` won't see it unless you also export:

```bash
export TF_VAR_ssh_public_key="$SSH_PUBLIC_KEY"
```

Recommended: run the helper script to load `.env` and persist the value into the azd environment (includes setting `TF_VAR_ssh_public_key`):

```bash
./scripts/load-env-and-sync-azd.sh --verbose
```

This sets `TF_VAR_ssh_public_key` for the current session and saves it to the active azd environment to avoid future prompts. The Azure Developer CLI does not translate `inputs:` for Terraform, so the `TF_VAR_` prefix (or a tfvars file) is mandatory for variables without defaults.

### Passing Variables to azd Terraform Provisioning

The `azure.yaml` now includes:
Terraform provider does NOT use `inputs:` in `azure.yaml` to set variables. Provide values via environment variables or tfvars files.

Required variable with no default: `ssh_public_key` → must be set as `TF_VAR_ssh_public_key`.

Set it once and avoid prompts:
```bash
azd env set TF_VAR_ssh_public_key "$(cat ~/.ssh/id_rsa.pub)"
```

If you still see a prompt:
1. Confirm azd environment value: `azd env get-values | grep TF_VAR_ssh_public_key`
2. Confirm runtime export (optional): `print -r -- "$TF_VAR_ssh_public_key" | head -c40`
3. Set/re-set if missing: `azd env set TF_VAR_ssh_public_key "$(cat ~/.ssh/id_rsa.pub)"`
4. Retry `azd up`

### Verifying the SSH Public Key Injection

Shell session (first 40 chars):
```bash
print -r -- ${TF_VAR_ssh_public_key} | cut -c1-40
```

Active azd environment value (grep for the key):
```bash
azd env show            # confirms which environment is active
azd env get-values | grep TF_VAR_ssh_public_key | cut -c1-120
```

If nothing is returned:
1. Ensure you ran: `./scripts/load-env-and-sync-azd.sh`
2. Confirm an environment is selected: `azd env list` then `azd env select <name>`
3. Manually set: `azd env set TF_VAR_ssh_public_key "$SSH_PUBLIC_KEY"`

Note: `azd env get <key>` is not a valid command; use `azd env get-values` and filter.

## 🔧 Terraform Commands

```bash
cd terraform

# Initialize
terraform init

# Plan changes
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan

# View outputs
terraform output

# Destroy
terraform destroy

# Validate
terraform validate
terraform fmt -check
```

## 🎭 Ansible Commands

```bash
cd ansible

# Generate inventory from Terraform outputs
../scripts/generate-inventory.sh

# Test connectivity
ansible all -i inventory/hosts.yml -m ping

# Run playbook
ansible-playbook -i inventory/hosts.yml playbooks/site.yml

# Check syntax
ansible-playbook --syntax-check playbooks/site.yml

# Dry run
ansible-playbook --check -i inventory/hosts.yml playbooks/site.yml

# Run specific role
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags common

# Verbose output
ansible-playbook -i inventory/hosts.yml playbooks/site.yml -vvv
```

## ☸️ Kubernetes Commands

```bash
# Set kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig

# Cluster info
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

# Node details
kubectl describe node <node-name>
kubectl top nodes

# Deploy application
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort

# View resources
kubectl get all -A
kubectl get events -A --sort-by='.lastTimestamp'

# Logs
kubectl logs -f <pod-name>
kubectl logs -f <pod-name> -n <namespace>

# Execute commands
kubectl exec -it <pod-name> -- /bin/bash

# Config
kubectl config view
kubectl config get-contexts
```

## ✅ CI/CD Commands

```bash
# Run all CI checks locally (recommended before pushing)
./scripts/ci-check.sh

# Terraform validation
cd terraform
terraform fmt -check -recursive
terraform validate
tflint --init && tflint

# Terraform security
tfsec .
checkov -d . --framework terraform

# Ansible validation
cd ansible
ansible-lint playbooks/site.yml
ansible-playbook playbooks/site.yml --syntax-check

# Shell script validation
shellcheck scripts/*.sh

# YAML validation
yamllint ansible/ azure.yaml .github/

# Markdown linting
markdownlint-cli2 "**/*.md"

# Secrets scanning
gitleaks detect --source . --verbose

# Security scanning
trivy config .
```

## 🔍 Troubleshooting Commands

```bash
# Azure CLI
az login
az account show
az vm list --resource-group <rg-name> --show-details --output table
az network nsg rule list --nsg-name <nsg-name> --output table

# SSH to nodes
ssh azureuser@<public-ip>

# RKE2 logs on nodes
sudo journalctl -u rke2-server -f    # Control plane
sudo journalctl -u rke2-agent -f     # Workers

# Check RKE2 status
sudo systemctl status rke2-server
sudo systemctl status rke2-agent

# View kubeconfig on control plane
sudo cat /etc/rancher/rke2/rke2.yaml

# Ansible inventory
ansible-inventory -i inventory/hosts.yml --list
ansible-inventory -i inventory/hosts.yml --graph

# Test network connectivity
telnet <control-plane-private-ip> 9345
curl -k https://<control-plane-public-ip>:6443
```

## 📦 Default Resource Names

```
Resource Group:       rg-k8s-azure-dev
VNet:                 vnet-k8s-azure-dev
Subnet:               snet-k8s-azure-dev
Control Plane VM:     vm-k8s-azure-cp-dev
Worker VMs:           vm-k8s-azure-worker01-dev, vm-k8s-azure-worker02-dev
Control Plane NSG:    nsg-k8s-azure-control-plane-dev
Worker NSG:           nsg-k8s-azure-worker-dev
Public IPs:           pip-k8s-azure-vm0-dev, pip-k8s-azure-vm1-dev, ...
```

## 🌐 Network Configuration

```
VNet CIDR:           10.0.0.0/16
Subnet CIDR:         10.0.1.0/24
Pod CIDR:            10.42.0.0/16
Service CIDR:        10.43.0.0/16
Kubernetes API:      https://<control-plane-ip>:6443
RKE2 Server Port:    9345
NodePort Range:      30000-32767
```

## 🔒 Security Ports

| Port  | Service          | Allowed From      |
|-------|------------------|-------------------|
| 22    | SSH              | Configured IPs    |
| 6443  | Kubernetes API   | Configured IPs    |
| 9345  | RKE2 Server      | Internal VNet     |
| 10250 | Kubelet          | Internal VNet     |
| 30000-32767 | NodePort   | All (0.0.0.0/0)   |

## 📂 Important File Locations

```
On Control Plane Node:
/etc/rancher/rke2/config.yaml              # RKE2 config
/etc/rancher/rke2/rke2.yaml                # Kubeconfig
/var/lib/rancher/rke2/server/node-token    # Node token
/var/lib/rancher/rke2/server/logs/audit.log # Audit logs
/var/lib/rancher/rke2/bin/kubectl          # kubectl binary

On Worker Nodes:
/etc/rancher/rke2/config.yaml              # RKE2 config
/var/lib/rancher/rke2/agent/kubelet.kubeconfig # Kubelet config
```

## 🔄 Common Operations

### Add Worker Node
```bash
# Edit .env
VM_COUNT=4

# Apply
azd up
```

### Update RKE2 Version
```bash
# Edit .env
RKE2_VERSION=v1.29.0+rke2r1

# Redeploy
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

### Change VM Size
```bash
# Edit terraform/terraform.tfvars or .env
vm_size = "Standard_D8s_v5"

# Apply (requires VM recreation)
cd terraform
terraform apply
```

### Reset RKE2 on a Node
```bash
ssh azureuser@<node-ip>
sudo /usr/local/bin/rke2-uninstall.sh  # Or rke2-agent-uninstall.sh
# Re-run Ansible playbook
```

### Backup etcd
```bash
ssh azureuser@<control-plane-ip>
sudo /var/lib/rancher/rke2/bin/etcdctl snapshot save /tmp/backup.db \
  --cacert /var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
  --cert /var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
  --key /var/lib/rancher/rke2/server/tls/etcd/server-client.key
```

## 🎯 Azure CLI Quick Commands

```bash
# List all resources
az resource list --resource-group rg-k8s-azure-dev --output table

# Get VM IPs
az vm list-ip-addresses --resource-group rg-k8s-azure-dev --output table

# Start/Stop VMs (cost saving)
az vm start --name <vm-name> --resource-group rg-k8s-azure-dev
az vm stop --name <vm-name> --resource-group rg-k8s-azure-dev
az vm deallocate --name <vm-name> --resource-group rg-k8s-azure-dev

# View costs
az consumption usage list --output table

# Update NSG rule
az network nsg rule update \
  --resource-group rg-k8s-azure-dev \
  --nsg-name nsg-k8s-azure-control-plane-dev \
  --name AllowSSH \
  --source-address-prefixes "YOUR_IP/32"
```

## 🧪 Test Applications

### Deploy Test Nginx
```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get svc nginx
# Access: http://<worker-ip>:<nodeport>
```

### Deploy with YAML
```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
      - name: hello
        image: gcr.io/google-samples/hello-app:1.0
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: hello-world
spec:
  type: NodePort
  selector:
    app: hello
  ports:
  - port: 8080
    targetPort: 8080
EOF

kubectl get svc hello-world
```

## 📚 Documentation Links

- **Setup**: [docs/SETUP.md](docs/SETUP.md)
- **Deployment**: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)
- **Security**: [docs/SECURITY.md](docs/SECURITY.md)
- **Troubleshooting**: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **Project Summary**: [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)

## 💡 Tips

1. **Save costs**: Use `Standard_D2s_v5` for testing
2. **Speed up**: Use `-parallelism=10` with Terraform
3. **Debug**: Add `-vvv` to Ansible commands
4. **Monitor**: Set up Azure Monitor and Log Analytics
5. **Backup**: Schedule etcd backups regularly
6. **Update**: Keep RKE2 and components up to date
7. **Secure**: Restrict NSG IPs in production

## 🆘 Emergency Commands

```bash
# Complete teardown
azd down --force --purge

# Force delete resource group
az group delete --name rg-k8s-azure-dev --yes --no-wait

# Reset Terraform state
cd terraform
rm -rf .terraform .terraform.lock.hcl
terraform init

# Clean local artifacts
rm -f kubeconfig
rm -f ansible/inventory/hosts.yml

# Restart RKE2 services
ssh azureuser@<node-ip>
sudo systemctl restart rke2-server  # or rke2-agent
```

---

**Keep this file handy for quick reference!**
