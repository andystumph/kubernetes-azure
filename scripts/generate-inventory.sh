#!/bin/bash
set -e

# Script to generate Ansible inventory from Terraform outputs
# Both 'azd up' and direct 'terraform apply' use the same state file (configured in terraform backend)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INVENTORY_FILE="$PROJECT_ROOT/ansible/inventory/hosts.yml"

# Ensure inventory directory exists (prevent failure if not under version control)
mkdir -p "$PROJECT_ROOT/ansible/inventory"

echo "Generating Ansible inventory from Terraform outputs..."

# Determine which Terraform state directory to use
# When using 'azd up', state is in .azure/<env>/terraform/
# When using direct 'terraform apply', state is in terraform/ directory
AZURE_ENV_NAME="${AZURE_ENV_NAME:-dev}"
if [ -f "$PROJECT_ROOT/.azure/$AZURE_ENV_NAME/terraform/terraform.tfstate" ]; then
  TERRAFORM_DIR="$PROJECT_ROOT/.azure/$AZURE_ENV_NAME/terraform"
  echo "Using azd state location: $TERRAFORM_DIR"
else
  TERRAFORM_DIR="$PROJECT_ROOT/terraform"
  echo "Using direct terraform location: $TERRAFORM_DIR"
fi

cd "$TERRAFORM_DIR"

# Get Terraform outputs from state file directly
# This works regardless of where the .tf files are located
STATE_FILE="$TERRAFORM_DIR/terraform.tfstate"
if [ ! -f "$STATE_FILE" ]; then
  echo "Error: Terraform state file not found at $STATE_FILE"
  exit 1
fi

CONTROL_PLANE_IP=$(jq -r '.outputs.control_plane_public_ip.value // ""' "$STATE_FILE")
CONTROL_PLANE_PRIVATE_IP=$(jq -r '.outputs.control_plane_private_ip.value // ""' "$STATE_FILE")
WORKER_IPS=$(jq -c '.outputs.worker_public_ips.value // []' "$STATE_FILE")
WORKER_PRIVATE_IPS=$(jq -c '.outputs.worker_private_ips.value // []' "$STATE_FILE")
ADMIN_USER=$(jq -r '.outputs.admin_username.value // "azureuser"' "$STATE_FILE")

# Get SSH private key path from environment variable or use default
SSH_KEY_FILE="${ANSIBLE_SSH_KEY_FILE:-~/.ssh/azure_k8s}"

if [ -z "$CONTROL_PLANE_IP" ]; then
    echo "Error: Could not retrieve Terraform outputs. Make sure infrastructure is provisioned."
    exit 1
fi

# Create inventory file
cat > "$INVENTORY_FILE" << EOF
---
all:
  vars:
    ansible_user: $ADMIN_USER
    ansible_ssh_private_key_file: $SSH_KEY_FILE
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
    
  children:
    control_plane:
      hosts:
        control-plane-0:
          ansible_host: $CONTROL_PLANE_IP
          private_ip: $CONTROL_PLANE_PRIVATE_IP
          
    workers:
      hosts:
EOF

# Add worker nodes
WORKER_COUNT=$(echo "$WORKER_IPS" | jq '. | length')
for i in $(seq 0 $((WORKER_COUNT - 1))); do
    WORKER_IP=$(echo "$WORKER_IPS" | jq -r ".[$i]")
    WORKER_PRIVATE_IP=$(echo "$WORKER_PRIVATE_IPS" | jq -r ".[$i]")
    echo "        worker-$i:" >> "$INVENTORY_FILE"
    echo "          ansible_host: $WORKER_IP" >> "$INVENTORY_FILE"
    echo "          private_ip: $WORKER_PRIVATE_IP" >> "$INVENTORY_FILE"
done

echo "Inventory file generated at: $INVENTORY_FILE"
echo ""
echo "Control Plane: $CONTROL_PLANE_IP"
echo "Workers: $(echo "$WORKER_IPS" | jq -r '.[]' | tr '\n' ' ')"
