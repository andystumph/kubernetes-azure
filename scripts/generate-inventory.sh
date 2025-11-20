#!/bin/bash
set -e

# Script to generate Ansible inventory from Terraform outputs
# Both 'azd up' and direct 'terraform apply' use the same state file (configured in terraform backend)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
INVENTORY_FILE="$PROJECT_ROOT/ansible/inventory/hosts.yml"

echo "Generating Ansible inventory from Terraform outputs..."

cd "$TERRAFORM_DIR"

# Get Terraform outputs (works with both azd and direct terraform usage)
CONTROL_PLANE_IP=$(terraform output -raw control_plane_public_ip 2>/dev/null || echo "")
CONTROL_PLANE_PRIVATE_IP=$(terraform output -raw control_plane_private_ip 2>/dev/null || echo "")
WORKER_IPS=$(terraform output -json worker_public_ips 2>/dev/null || echo "[]")
WORKER_PRIVATE_IPS=$(terraform output -json worker_private_ips 2>/dev/null || echo "[]")
ADMIN_USER=$(terraform output -raw admin_username 2>/dev/null || echo "azureuser")

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
