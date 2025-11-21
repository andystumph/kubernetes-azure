# Kubernetes on Azure with RKE2

[![CI/CD Pipeline](https://github.com/andystumph/kubernetes-azure/actions/workflows/ci.yml/badge.svg)](https://github.com/andystumph/kubernetes-azure/actions/workflows/ci.yml)

This project provisions a production-ready Kubernetes cluster on Azure using RKE2 (Rancher Kubernetes Engine 2) with infrastructure-as-code practices.

## 🏗️ Architecture

- **Infrastructure**: Azure VMs (Ubuntu 22.04) in a secure VNet
- **Kubernetes**: RKE2 with containerd runtime
- **Configuration**: 1 control plane node + 2+ worker nodes (configurable)
- **Management**: Terraform + Ansible + Azure Developer CLI

## 📋 Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop) or compatible container runtime
- [VS Code](https://code.visualstudio.com/) with [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- Azure subscription with appropriate permissions
- Azure CLI authenticated (`az login`)

## 🚀 Quick Start

### 1. Setup Environment

```bash

# Clone the repository

git clone <repository-url>
cd kubernetes-azure

# Copy and configure environment variables

cp .env.example .env

# Edit .env with your Azure credentials and configuration

vim .env

# (Recommended) Load .env and persist Terraform SSH key variable for azd

./scripts/load-env-and-sync-azd.sh --verbose

# OR manually if you prefer:

set -a; . ./.env; set +a
azd env set TF_VAR_ssh_public_key "$SSH_PUBLIC_KEY"
```

### 2. Open in Dev Container

1. Open the project in VS Code
2. **Platform Note**: The dev container is configured for Windows by default. For Linux/Mac, see [.devcontainer/README.md](.devcontainer/README.md) for configuration adjustments.
3. Press `F1` and select "Dev Containers: Reopen in Container"
4. Wait for the container to build and start

### 3. Deploy Infrastructure

```bash

# Login to Azure

az login

# Initialize and deploy
# Ensure Terraform variable is present (one-time)

azd env get-values | grep TF_VAR_ssh_public_key || azd env set TF_VAR_ssh_public_key "$SSH_PUBLIC_KEY"
azd up
```

This will:

- Provision Azure resources (VNet, VMs, NSGs, etc.)
- Configure RKE2 Kubernetes cluster
- Generate kubeconfig file

### 4. Access Your Cluster

```bash

# Set kubeconfig

export KUBECONFIG=$(pwd)/kubeconfig

# Verify cluster

kubectl get nodes
kubectl cluster-info
```

## 📁 Project Structure

```text
.
├── .devcontainer/          # Dev container configuration
│   └── devcontainer.json
├── .github/                # GitHub Copilot instructions
│   └── copilot-instructions.md
├── terraform/              # Infrastructure as code
│   ├── main.tf            # Main Terraform configuration
│   ├── variables.tf       # Variable definitions
│   ├── outputs.tf         # Output values
│   ├── network.tf         # Network resources
│   ├── compute.tf         # VM resources
│   └── security.tf        # Security configurations
├── ansible/               # Configuration management
│   ├── ansible.cfg        # Ansible configuration
│   ├── inventory/         # Inventory files
│   │   └── hosts.yml      # Generated static inventory
│   ├── roles/             # Ansible roles
│   │   ├── common/        # Common setup
│   │   ├── rke2-server/   # Control plane setup
│   │   └── rke2-agent/    # Worker node setup
│   └── playbooks/         # Playbooks
│       └── site.yml       # Main playbook
├── scripts/               # Helper scripts
│   ├── generate-inventory.sh  # Generate inventory from Terraform outputs
│   ├── postprovision-ansible.sh  # Ansible postprovision hook
│   ├── preprovision.sh    # Pre-provision setup
│   └── load-env-and-sync-azd.sh  # Environment loader
├── docs/                  # Documentation
│   ├── SETUP.md          # Detailed setup guide
│   ├── DEPLOYMENT.md     # Deployment guide
│   ├── SECURITY.md       # Security considerations
│   └── TROUBLESHOOTING.md # Troubleshooting guide
├── .env.example          # Example environment variables
├── .gitignore            # Git ignore patterns
├── azure.yaml            # Azure Developer CLI config
└── README.md             # This file
```

## 🔧 Configuration

## ⚙️ Using Azure Developer CLI (azd) with Terraform

The project is wired so that `azd` orchestrates Terraform (provision) and then Ansible (post-provision) via `azure.yaml`.

### Flow Overview

1. Load environment variables (service principal, project settings) from `.env`.
2. `azd provision` runs Terraform in `./terraform`.
3. After Terraform succeeds, an Ansible playbook configures the VMs into an RKE2 cluster.
4. `azd up` combines provision + (future) deploy phases.

### Required Environment Variables

These must be populated in `.env` (see `.env.example`):

- Azure auth: `AZURE_SUBSCRIPTION_ID`, `AZURE_TENANT_ID`, `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET` (SP credentials)
- Infra metadata: `ENVIRONMENT`, `PROJECT_NAME`, `RESOURCE_GROUP_NAME`, `AZURE_LOCATION`
- Cluster: `VM_COUNT`, `RKE2_VERSION`, `RKE2_TOKEN`
- Access: `SSH_PUBLIC_KEY`

Use the helper script to export and persist them:

```bash
./scripts/load-env-and-sync-azd.sh
```

Or manual export:

```bash
set -a; . ./.env; set +a
azd env set TF_VAR_ssh_public_key "$SSH_PUBLIC_KEY"
```

### Supplying Terraform Variables

Terraform prompts if `ssh_public_key` isn't set. Provide it via one of:

1. Persisted azd environment variable (recommended): `azd env set TF_VAR_ssh_public_key "$SSH_PUBLIC_KEY"`
2. Append to `terraform/terraform.tfvars` (HCL):

   ```hcl
   ssh_public_key = "${SSH_PUBLIC_KEY}"
   ```

3. Create `terraform/main.tfvars.json` (JSON tfvars) generated from `.env` (a helper script `scripts/generate-tfvars-json.sh` can be extended to include this field).

### Common Commands

```bash
azd env list                 # Show environments
azd env new dev              # Create/select environment
azd provision                # Terraform provisioning + post hooks (Ansible)
azd up                       # Provision + (future) deploy
azd down                     # Destroy resources + cleanup hooks
azd show                     # Show current environment outputs
```

### Existing Resource Group Collision

If `RESOURCE_GROUP_NAME` already exists (manually created or from a prior run) Terraform will halt with a message about importing the resource. Resolve by either:

- Importing:

  ```bash
  terraform -chdir=terraform init
  terraform -chdir=terraform import azurerm_resource_group.main \
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}"
  ```

- Or choosing a new `RESOURCE_GROUP_NAME` in `.env` (e.g. append a numeric suffix) and re-running provision.

### Authentication Notes

Terraform prefers the explicit ARM_* environment variables. Ensure these are exported; otherwise it falls back to Azure CLI interactive auth (causing msal errors inside the dev container). Minimum set:

```bash
export ARM_CLIENT_ID=$ARM_CLIENT_ID
export ARM_CLIENT_SECRET=$ARM_CLIENT_SECRET
export ARM_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID
export ARM_TENANT_ID=$AZURE_TENANT_ID
```

### Hooks (Pre/Post Provision)

Pre-provision logic (environment loading & tfvars generation) can run automatically via `hooks` in `azure.yaml`. If you encounter schema or YAML parsing issues, temporarily do manual exports (as above) and keep logic in scripts (`scripts/preprovision.sh`) for clarity.

### Troubleshooting Quick Reference

| Symptom | Cause | Fix |
|--------|-------|-----|
| `terraform` prompts for `ssh_public_key` | `TF_VAR_ssh_public_key` not set before azd run | Run `./scripts/load-env-and-sync-azd.sh` or `azd env set TF_VAR_ssh_public_key "$SSH_PUBLIC_KEY"` |
| `resource group already exists` error | Pre-existing RG | Import RG or change name |
| `msal NormalizedResponse` AttributeError | CLI-based auth path in container | Ensure ARM_* env vars exported |
| Hooks appear ignored | YAML schema / indentation issue | Simplify `azure.yaml`; call scripts directly |

### Safe Iteration Loop

```bash
set -a; . ./.env; set +a
export TF_VAR_ssh_public_key="$SSH_PUBLIC_KEY"
azd provision   # or azd up

# Make infra changes

terraform -chdir=terraform plan
azd provision   # re-run to apply via azd
```

### Cleanup & Cost Control

Always run:

```bash
azd down
```

when finished experimenting; this removes the resource group (unless you imported an externally managed one).

---

### Environment Variables

See `.env.example` for all available configuration options. Key variables:

- `VM_COUNT`: Number of VMs (default: 3, minimum: 2)
- `AZURE_LOCATION`: Azure region (default: eastus)
- `RKE2_VERSION`: RKE2 version to install
- `ANSIBLE_SSH_KEY_FILE`: Path to SSH private key for Ansible connections (default: `~/.ssh/azure_k8s`)
  - Use this to override the default SSH key location if you're using a different key file
  - Example: `export ANSIBLE_SSH_KEY_FILE=~/.ssh/my_custom_key`

### Scaling

To change the number of worker nodes:

1. Update `VM_COUNT` in `.env`
2. Run `azd up` to apply changes

## 🛡️ Security

- All secrets are stored in `.env` (never committed to git)
- Network security groups restrict access
- RKE2 configured with security best practices:
  - RBAC enabled
  - Pod Security Standards enforced
  - Network policies ready
  - TLS for all components
- SSH key-based authentication only

See [docs/SECURITY.md](docs/SECURITY.md) for detailed security information.

## 🧪 Testing

```bash

# Validate Terraform

cd terraform
terraform validate
terraform plan

# Check Ansible syntax

cd ansible
ansible-playbook --syntax-check playbooks/site.yml

# Dry run Ansible

ansible-playbook --check -i inventory/hosts.yml playbooks/site.yml
```

## 🧹 Cleanup

To destroy all resources:

```bash
azd down
```

Or manually:

```bash
cd terraform
terraform destroy
```

## 📚 Documentation

- [Setup Guide](docs/SETUP.md) - Detailed setup instructions
- [Deployment Guide](docs/DEPLOYMENT.md) - Step-by-step deployment
- [Security](docs/SECURITY.md) - Security configuration details
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [CI/CD Pipeline](docs/CI_CD.md) - Continuous integration and validation

## 🤝 Contributing

1. Follow the coding standards in `.github/copilot-instructions.md`
2. Test changes in a dev environment first
3. Run CI checks locally before pushing (see [CI/CD docs](docs/CI_CD.md))
4. Update documentation for any changes
5. Ensure all CI checks pass before requesting review

## 📝 License

This project is provided as-is for educational and production use.

## 🆘 Support

For issues and questions:

1. Check [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
2. Review logs: `azd show` or check individual Terraform/Ansible logs
3. Open an issue with details and logs
