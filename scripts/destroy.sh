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
fi

echo "=== Destroying Kubernetes Azure Infrastructure ==="
echo ""
echo "WARNING: This will destroy all resources in the infrastructure!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Destruction cancelled."
    exit 0
fi

cd "$PROJECT_ROOT/terraform"

echo "Destroying infrastructure..."
terraform destroy -auto-approve

echo ""
echo "Cleaning up local files..."
rm -f "$PROJECT_ROOT/kubeconfig"
rm -f "$PROJECT_ROOT/ansible/inventory/hosts.yml"

echo ""
echo "=== Destruction Complete ==="
