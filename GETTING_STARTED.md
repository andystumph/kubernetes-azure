# Getting Started with Kubernetes on Azure

Welcome! This guide will help you get your Kubernetes cluster up and running on Azure in under 15 minutes.

## ⚡ TL;DR - Quick Start

```bash
# 1. Configure
cp .env.example .env && vim .env

# 2. Open in dev container (VS Code - wait for postCreateCommand to finish)
code . → F1 → "Reopen in Container"

# 3. Inside dev container: Initialize azd environment
azd init --environment dev

# 4. Load ALL environment variables (critical for Terraform auth)
set -a && . ./.env && set +a
export TF_VAR_ssh_public_key="${SSH_PUBLIC_KEY}"

# 5. Deploy (Terraform + Ansible)
azd up

# 6. Use your cluster
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

## 📋 What You'll Get

After completing this guide, you'll have:

- ✅ 3 Ubuntu 22.04 VMs on Azure (1 control plane + 2 workers)
- ✅ RKE2 Kubernetes cluster (v1.28.5+)
- ✅ Secure networking with NSGs and isolated VNet
- ✅ Production-ready with CIS hardening
- ✅ Kubeconfig ready to use
- ✅ Cilium CNI for advanced networking
- ✅ Fully automated with IaC

## 🎯 Prerequisites

### What You Need

1. **Azure Account**
   - Active subscription
   - Contributor access
   - ~$450/month budget (or ~$50 for testing with smaller VMs)

2. **Local Machine**
   - Docker Desktop running
   - VS Code with Dev Containers extension
   - 10GB free disk space

3. **Time Required**
   - First time: ~30 minutes (reading + setup)
   - Deploy time: ~10-15 minutes
   - Subsequent deploys: ~5 minutes

### What You'll Learn

- Infrastructure as Code with Terraform
- Configuration management with Ansible  
- Azure networking and security
- Kubernetes administration basics
- DevOps best practices

## 🚀 Step-by-Step Setup

### Step 1: Get Azure Credentials (5 minutes)

#### 1.1 Login to Azure
```bash
az login
az account list --output table
az account set --subscription "Your-Subscription-Name"
```

#### 1.2 Create Service Principal
```bash
az ad sp create-for-rbac \
  --name "kubernetes-azure-sp" \
  --role="Contributor" \
  --scopes="/subscriptions/YOUR_SUBSCRIPTION_ID"
```

**Save this output!** You'll need:
- `appId` → This is your ARM_CLIENT_ID
- `password` → This is your ARM_CLIENT_SECRET
- `tenant` → This is your ARM_TENANT_ID

#### 1.3 Generate SSH Key (if you don't have one)
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/azure_k8s -N ""
cat ~/.ssh/azure_k8s.pub  # This is your SSH_PUBLIC_KEY
```

#### 1.4 Generate RKE2 Token
```bash
openssl rand -base64 32  # This is your RKE2_TOKEN
```

### Step 2: Configure Environment (3 minutes)

#### 2.1 Clone/Setup Project
```bash
cd /path/to/projects
git clone <your-repo-url> kubernetes-azure
cd kubernetes-azure
```

#### 2.2 Create .env File
```bash
cp .env.example .env
```

#### 2.3 Edit .env with Your Values
```bash
vim .env  # or use your favorite editor
```

**Fill in these values:**
```bash
# From Azure
AZURE_SUBSCRIPTION_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AZURE_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AZURE_LOCATION=eastus  # or your preferred region

# From Service Principal
ARM_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
ARM_CLIENT_SECRET=your-secret-here
ARM_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
ARM_TENANT_ID=${AZURE_TENANT_ID}

# Your generated token
RKE2_TOKEN=your-32-character-token-here

# Your SSH public key (one long line)
SSH_PUBLIC_KEY=ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ...

# Project settings (can leave as defaults)
VM_COUNT=3
RKE2_VERSION=v1.28.5+rke2r1
ADMIN_USERNAME=azureuser
```

**💡 Tip:** For testing, you can use smaller/cheaper VMs by adding:
```bash
# In .env or terraform/terraform.tfvars
vm_size = "Standard_D2s_v5"  # ~$70/month instead of ~$125
```

### Step 3: Initialize azd and Load Environment (2 minutes)

#### 3.1 Initialize azd Environment

Inside the dev container terminal:
```bash
# Initialize azd (creates environment if first run)
azd init --environment dev
```

#### 3.2 Load Environment Variables

Terraform requires service principal credentials (ARM_*) and the SSH key. Load all variables from .env:

```bash
# Load ALL environment variables (ARM_*, SSH_PUBLIC_KEY, etc.)
set -a && . ./.env && set +a

# Export SSH key specifically for Terraform
export TF_VAR_ssh_public_key="${SSH_PUBLIC_KEY}"
```

Verify variables are set:
```bash
env | grep -E '^ARM_|^TF_VAR_' | head -5
```

**Important:** 
- The `set -a` command exports all variables as they're read from .env
- This ensures Terraform uses service principal auth instead of Azure CLI
- The SSH key must be a single continuous line with no line breaks

### Step 4: Validate Setup (2 minutes)

#### 4.1 Open in Dev Container
```bash
code .
```

When VS Code opens:
1. You'll see a popup: "Reopen in Container" → Click it
2. Wait ~3-5 minutes for container to build (first time only)
   - The `postCreateCommand` will install azd, Ansible collections, and Python dependencies
   - Watch the terminal for "Done. Press any key to close the terminal."
3. Open a new terminal after setup completes

#### 4.2 Run Validation (Optional)
```bash
./scripts/validate-setup.sh
```

This checks:
- All tools are installed
- Environment variables are set
- Azure authentication works
- Project structure is correct

**Fix any errors before proceeding!**

### Step 5: Deploy Infrastructure (10-15 minutes)

#### Option A: One Command (Recommended)
```bash
azd up
```

This will:
1. Validate environment
2. Run Terraform to create Azure resources
3. Run Ansible to configure Kubernetes (via postprovision hook)
4. Download kubeconfig file

**Note:** Since the dev container pre-installs all dependencies (Azure Ansible collection + Python requirements), the Ansible postprovision hook should complete successfully. If it fails, see Option B.

#### Option B: Complete Configuration Manually

If `azd up` completed Terraform but skipped Ansible (or if you want step-by-step control):

```bash
# 1. Wait for VMs to boot (if just provisioned)
sleep 60

# 2. Generate static inventory from Terraform
./scripts/generate-inventory.sh

# 3. Test connectivity (using static inventory)
cd /workspaces/kubernetes-azure
ANSIBLE_CONFIG=ansible/ansible.cfg ANSIBLE_INVENTORY_ENABLED=yaml,ini \
  ansible all -i ansible/inventory/hosts.yml -m ping

# 4. Run Kubernetes configuration
ANSIBLE_CONFIG=ansible/ansible.cfg ANSIBLE_INVENTORY_ENABLED=yaml,ini \
  ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml

# 5. Return to project root
cd ..
```

**☕ Take a break!** Ansible configuration takes 10-15 minutes.

**Note:** The project uses static inventory generated from Terraform outputs to work around known issues with the Azure dynamic inventory plugin in azure.azcollection v3.11.0.

### Step 6: Access Your Cluster (1 minute)

#### 6.1 Set Kubeconfig
```bash
export KUBECONFIG=$(pwd)/kubeconfig
```

#### 6.2 Verify Cluster
```bash
kubectl get nodes
```

**Expected output:**
```
NAME                STATUS   ROLES                       AGE   VERSION
k8s-control-plane   Ready    control-plane,etcd,master   5m    v1.28.5+rke2r1
k8s-worker-1        Ready    <none>                      3m    v1.28.5+rke2r1
k8s-worker-2        Ready    <none>                      3m    v1.28.5+rke2r1
```

#### 6.3 Check System Pods
```bash
kubectl get pods -A
```

All pods should be "Running" or "Completed".

### Step 7: Deploy Test Application (2 minutes)

```bash
# Create a test deployment
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort

# Get the NodePort
kubectl get svc nginx

# Test it (replace with your worker node public IP and NodePort)
curl http://<worker-public-ip>:<nodeport>
```

**🎉 Congratulations!** Your cluster is working!

## 📚 Next Steps

### Learn More
- 📖 [Full README](README.md) - Complete project documentation
- 🔧 [Deployment Guide](docs/DEPLOYMENT.md) - Advanced deployment options
- 🔒 [Security Guide](docs/SECURITY.md) - Hardening for production
- 🆘 [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues

### Customize Your Cluster
- **Add Workers**: Edit `VM_COUNT` in `.env` and run `azd up`
- **Change VM Size**: Edit `vm_size` in `terraform/terraform.tfvars`
- **Update Kubernetes**: Edit `RKE2_VERSION` in `.env`
- **Restrict Access**: Edit `allowed_*_cidrs` in `terraform/terraform.tfvars`

### Deploy Real Applications
```bash
# Deploy from YAML
kubectl apply -f your-app.yaml

# Use Helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install my-app bitnami/nginx

# Deploy from a Git repo
kubectl apply -k github.com/your-org/your-app
```

### Monitor Your Cluster
```bash
# Install metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# View resource usage
kubectl top nodes
kubectl top pods -A

# Watch events
kubectl get events -A --watch
```

## 🧹 Cleanup

When you're done experimenting:

```bash
# Destroy everything
azd down

# Or manually
cd terraform
terraform destroy

# Confirm deletion
az group list --output table
```

**⚠️ Warning:** This deletes all resources and cannot be undone!

## 💰 Cost Management

### Estimated Costs (US East)

**Default Configuration:**
- 3x Standard_D4s_v5: ~$370/month
- Storage & networking: ~$80/month  
- **Total: ~$450/month**

**Budget Configuration** (for testing):
- 3x Standard_D2s_v5: ~$185/month
- Storage & networking: ~$50/month
- **Total: ~$235/month**

### Cost Saving Tips

1. **Stop VMs when not in use:**
   ```bash
   az vm deallocate --resource-group rg-k8s-azure-dev --name vm-k8s-azure-cp-dev
   # Saves ~60% of compute cost
   ```

2. **Use smaller VMs for testing:**
   ```bash
   # In terraform/terraform.tfvars
   vm_size = "Standard_B2s"  # ~$30/month per VM
   ```

3. **Delete when not needed:**
   ```bash
   azd down
   # Recreate later with: azd up
   ```

4. **Set up budget alerts:**
   ```bash
   az consumption budget create \
     --amount 100 \
     --category cost \
     --name k8s-budget \
     --time-grain monthly
   ```

## 🆘 Getting Help

### Something Not Working?

1. **Check validation:**
   ```bash
   ./scripts/validate-setup.sh
   ```

2. **Review logs:**
   ```bash
   # Terraform
   cd terraform && terraform show
   
   # Ansible
   cd ansible && ansible-playbook playbooks/site.yml -vvv
   
   # Kubernetes
   kubectl get events -A --sort-by='.lastTimestamp'
   ```

3. **Check troubleshooting guide:**
   - [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

4. **Common issues:**
   - **Can't SSH to VMs**: Check NSG rules and public IPs
   - **Nodes not Ready**: Wait 5 minutes, RKE2 needs time to initialize
   - **Can't access API**: Check NSG allows your IP on port 6443
   - **Terraform errors**: Check service principal permissions

### Still Stuck?

- 💬 Open an issue on GitHub
- 📖 Read the [full documentation](README.md)
- 🔍 Search [Troubleshooting Guide](docs/TROUBLESHOOTING.md)

## 📖 Additional Resources

### Official Documentation
- [RKE2 Docs](https://docs.rke2.io/)
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [Azure Docs](https://docs.microsoft.com/azure/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

### Useful Tools
- [k9s](https://k9scli.io/) - Terminal UI for Kubernetes
- [Lens](https://k8slens.dev/) - Kubernetes IDE
- [Helm](https://helm.sh/) - Package manager for Kubernetes
- [Flux](https://fluxcd.io/) - GitOps for Kubernetes

### Learning Resources
- [Kubernetes Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
- [Azure Learn](https://docs.microsoft.com/learn/azure/)
- [Terraform Tutorials](https://learn.hashicorp.com/terraform)

## 🎓 What You've Accomplished

✅ Created production-grade infrastructure as code  
✅ Deployed a secure, hardened Kubernetes cluster  
✅ Learned DevOps and cloud engineering practices  
✅ Set up automated deployment pipelines  
✅ Implemented security best practices  

**You're now ready to deploy real applications!**

## 🤝 Contributing

Want to improve this project?
1. Fork the repository
2. Make your changes
3. Test thoroughly (see [CI/CD docs](docs/CI_CD.md) for running checks locally)
4. Ensure CI checks pass
5. Submit a pull request

## 📄 License

This project is provided as-is for educational and production use.

---

**Happy Clustering! 🚀**

Questions? Check the [FAQ](docs/TROUBLESHOOTING.md#frequently-asked-questions) or open an issue.
