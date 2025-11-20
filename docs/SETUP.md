# Setup Guide

This guide provides detailed instructions for setting up the Kubernetes on Azure project.

## Prerequisites

### Required Software

1. **Docker Desktop** or compatible container runtime
   - Download: https://www.docker.com/products/docker-desktop
   - Ensure it's running before opening the dev container

2. **Visual Studio Code**
   - Download: https://code.visualstudio.com/
   - Install the Dev Containers extension: `ms-vscode-remote.remote-containers`

3. **Azure CLI** (if not using dev container)
   - Download: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli

### Azure Requirements

1. **Azure Subscription**
   - Active Azure subscription with appropriate permissions
   - Ability to create resource groups, VMs, networks, and security groups

2. **Service Principal**
   - Create a service principal for Terraform authentication

   ```bash
   az login
   az account set --subscription "YOUR_SUBSCRIPTION_ID"
   az ad sp create-for-rbac --name "kubernetes-azure-sp" --role="Contributor" --scopes="/subscriptions/YOUR_SUBSCRIPTION_ID"
   ```

   Save the output:
   - `appId` → `ARM_CLIENT_ID`
   - `password` → `ARM_CLIENT_SECRET`
   - `tenant` → `ARM_TENANT_ID`

3. **SSH Key Pair**
   - Generate if you don't have one:
   
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/azure_k8s -N ""
   ```

## Initial Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd kubernetes-azure
```

### 2. Configure Environment Variables

```bash
# Copy the example environment file
cp .env.example .env

# Edit the .env file with your actual values
# Use your favorite editor
vim .env
# or
code .env
```

Required variables to configure:

```bash
# Azure Credentials
AZURE_SUBSCRIPTION_ID=<your-subscription-id>
AZURE_TENANT_ID=<your-tenant-id>
AZURE_LOCATION=eastus  # or your preferred region

# Terraform Service Principal
ARM_CLIENT_ID=<service-principal-client-id>
ARM_CLIENT_SECRET=<service-principal-secret>
ARM_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
ARM_TENANT_ID=${AZURE_TENANT_ID}

# RKE2 Configuration
RKE2_TOKEN=<generate-a-secure-random-token>
RKE2_VERSION=v1.28.5+rke2r1  # or latest stable version

# SSH Access
SSH_PUBLIC_KEY=<your-ssh-public-key>

# Project Configuration
ENVIRONMENT=dev
PROJECT_NAME=k8s-azure
RESOURCE_GROUP_NAME=rg-k8s-azure-dev
VM_COUNT=3  # 1 control plane + 2 workers

# Admin username for VMs
ADMIN_USERNAME=azureuser
```

### 3. Generate RKE2 Token

Generate a secure random token for RKE2 cluster authentication:

```bash
# Linux/Mac
openssl rand -base64 32

# Or use this
head -c 32 /dev/urandom | base64
```

### 4. Get Your SSH Public Key

```bash
cat ~/.ssh/id_rsa.pub
# or
cat ~/.ssh/azure_k8s.pub
```

Copy the entire output (starts with `ssh-rsa`) to the `SSH_PUBLIC_KEY` variable in `.env`.

### 5. Persist Terraform SSH Public Key Variable

Terraform variable `ssh_public_key` has no default. Set it via environment before running `azd up` to avoid prompts.

Recommended:
```bash
./scripts/load-env-and-sync-azd.sh --verbose
```

Manual alternative:
```bash
set -a; . ./.env; set +a
azd env set TF_VAR_ssh_public_key "$SSH_PUBLIC_KEY"
```

Verification:
```bash
azd env get-values | grep TF_VAR_ssh_public_key | cut -c1-80
```

## Development Container Setup

### Option 1: Using VS Code (Recommended)

1. Open the project in VS Code:
   ```bash
   code .
   ```

2. When prompted, click "Reopen in Container"
   - Or press `F1` and select "Dev Containers: Reopen in Container"

3. Wait for the container to build (first time only)

4. The container will automatically:
   - Install required tools (Terraform, Ansible, Azure CLI)
   - Mount your `.env` file
   - Mount your Azure CLI credentials
   - Set up the environment

### Option 2: Manual Setup (Without Dev Container)

If not using the dev container, install these tools:

```bash
# Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Ansible
sudo apt update
sudo apt install -y ansible python3-pip
pip3 install ansible[azure]

# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Azure Developer CLI
curl -fsSL https://aka.ms/install-azd.sh | bash
```

## Verification

Verify your setup:

```bash
# Check tool versions
terraform version
ansible --version
az version
azd version

# Login to Azure
az login

# Verify subscription
az account show

# Test Terraform authentication
cd terraform
terraform init
```

## Inventory Configuration

This project uses a **static inventory file** (`ansible/inventory/hosts.yml`) that is automatically generated from Terraform outputs.

The `scripts/generate-inventory.sh` script:
- Extracts VM IP addresses from Terraform state
- Creates a YAML inventory file with control plane and worker node groups
- Configures SSH connection parameters

This approach is more reliable than Azure dynamic inventory (azure_rm) and works seamlessly with the dev container environment.

The inventory generation happens automatically during `azd up` via the postprovision hook, but you can also run it manually:

```bash
./scripts/generate-inventory.sh
```

## Next Steps

Once setup is complete, proceed to [DEPLOYMENT.md](DEPLOYMENT.md) for deployment instructions.

## Troubleshooting

### Docker Issues

**Problem**: Dev container won't start
- Ensure Docker Desktop is running
- Try restarting Docker Desktop
- Check Docker has enough resources (CPU, Memory, Disk)

### Azure Authentication Issues

**Problem**: `az login` fails
- Clear cached credentials: `az account clear`
- Try browser-based login: `az login --use-device-code`

**Problem**: Terraform can't authenticate
- Verify service principal credentials in `.env`
- Test: `az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID`

### SSH Key Issues

**Problem**: SSH key format error
- Ensure no line breaks in the SSH public key string
- The key should be one continuous line starting with `ssh-rsa`
- Remove any comments at the end if needed

### Environment Variable Issues

**Problem**: Variables not loading
- Ensure `.env` file is in the project root
- Check file permissions: `chmod 600 .env`
- Verify no syntax errors in `.env` (no spaces around `=`)
- Restart the dev container after editing `.env`

## Additional Resources

- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [RKE2 Documentation](https://docs.rke2.io/)
- [Ansible Azure Guide](https://docs.ansible.com/ansible/latest/scenario_guides/guide_azure.html)
