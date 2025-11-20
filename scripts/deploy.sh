#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo "Loading environment variables from .env..."
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
else
    echo "Error: .env file not found. Copy .env.example to .env and configure."
    exit 1
fi

# Validate required variables
REQUIRED_VARS=(
    "AZURE_SUBSCRIPTION_ID"
    "ARM_CLIENT_ID"
    "ARM_CLIENT_SECRET"
    "SSH_PUBLIC_KEY"
    "RKE2_TOKEN"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: Required variable $var is not set in .env"
        exit 1
    fi
done

echo "=== Deploying Kubernetes on Azure ==="
echo ""

# Step 1: Terraform
echo "Step 1: Provisioning infrastructure with Terraform..."
cd "$PROJECT_ROOT/terraform"

# Export Terraform variables from environment
export TF_VAR_ssh_public_key="$SSH_PUBLIC_KEY"
export TF_VAR_environment="${ENVIRONMENT:-dev}"
export TF_VAR_location="${AZURE_LOCATION:-eastus}"
export TF_VAR_resource_group_name="${RESOURCE_GROUP_NAME:-rg-k8s-azure-dev}"
export TF_VAR_project_name="${PROJECT_NAME:-k8s-azure}"
export TF_VAR_vm_count="${VM_COUNT:-3}"
export TF_VAR_admin_username="${ADMIN_USERNAME:-azureuser}"

terraform init
terraform plan -out=tfplan -var-file=terraform.tfvars || terraform plan -out=tfplan
terraform apply -auto-approve tfplan

echo ""
echo "Infrastructure provisioned successfully!"
echo ""

# Step 2: Wait for VMs to be ready
echo "Step 2: Waiting for VMs to be ready..."
sleep 30

# Step 3: Generate Inventory
echo "Step 3: Generating Ansible inventory from Terraform outputs..."
cd "$PROJECT_ROOT"
./scripts/generate-inventory.sh

# Step 4: Ansible
echo "Step 4: Configuring Kubernetes with Ansible..."
cd "$PROJECT_ROOT/ansible"

# Test connectivity
echo "Testing SSH connectivity..."
ansible all -i inventory/hosts.yml -m ping

# Run playbook
echo "Running Ansible playbook..."
ansible-playbook -i inventory/hosts.yml playbooks/site.yml

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Kubeconfig saved to: $PROJECT_ROOT/kubeconfig"
echo ""
echo "To use the cluster:"
echo "  export KUBECONFIG=$PROJECT_ROOT/kubeconfig"
echo "  kubectl get nodes"
echo ""

# Display cluster info
if [ -f "$PROJECT_ROOT/kubeconfig" ]; then
    export KUBECONFIG="$PROJECT_ROOT/kubeconfig"
    kubectl get nodes
fi
