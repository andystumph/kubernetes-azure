#!/usr/bin/env sh
# Robust Ansible postprovision hook
# Loads environment, maps ARM_* vars to Azure inventory expectations, validates, then runs playbook with logging.
set -eu

log() { printf '%s\n' "[postprovision][$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"; }

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

log "Starting Ansible postprovision hook"

# Load .env if present to ensure variables available in this non-interactive shell
if [ -f ".env" ]; then
  log "Loading .env variables"
  set -a
  . ./.env
  set +a
  
  # Handle variable references in .env file (e.g., ARM_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID})
  # Re-evaluate to resolve any ${VAR} references
  ARM_SUBSCRIPTION_ID=$(eval echo "$ARM_SUBSCRIPTION_ID")
  ARM_TENANT_ID=$(eval echo "$ARM_TENANT_ID")
  export ARM_SUBSCRIPTION_ID ARM_TENANT_ID
fi

# Map ARM_* variables (Terraform convention) to AZURE_* expected by azure_rm inventory (Ansible convention)
# Provide both naming schemes to maximize compatibility.
[ -n "${ARM_CLIENT_ID:-}" ] && export AZURE_CLIENT_ID="$ARM_CLIENT_ID"
[ -n "${ARM_CLIENT_SECRET:-}" ] && export AZURE_CLIENT_SECRET="$ARM_CLIENT_SECRET" && export AZURE_SECRET="$ARM_CLIENT_SECRET"
[ -n "${ARM_TENANT_ID:-}${AZURE_TENANT_ID:-}" ] && export AZURE_TENANT="${ARM_TENANT_ID:-${AZURE_TENANT_ID:-}}"
[ -n "${ARM_SUBSCRIPTION_ID:-}${AZURE_SUBSCRIPTION_ID:-}" ] && export AZURE_SUBSCRIPTION_ID="${ARM_SUBSCRIPTION_ID:-${AZURE_SUBSCRIPTION_ID:-}}"

# Derive resource group name default if not set
: "${RESOURCE_GROUP_NAME:=rg-k8s-azure-dev}"
export RESOURCE_GROUP_NAME

# Quick validation of required env vars for inventory auth
missing=""
for v in AZURE_CLIENT_ID AZURE_CLIENT_SECRET AZURE_TENANT AZURE_SUBSCRIPTION_ID; do
  eval val="\${$v:-}"
  [ -z "$val" ] && missing="$missing $v"
  log "$v=${val:+SET}" || true
done
if [ -n "$missing" ]; then
  log "ERROR: Missing required Azure auth variables:$missing"
  log "Ensure service principal values are in .env (ARM_CLIENT_ID/ARM_CLIENT_SECRET/ARM_TENANT_ID/ARM_SUBSCRIPTION_ID)."
  exit 1
fi

log "All required Azure authentication variables are set"
log "AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID"
log "AZURE_TENANT=$AZURE_TENANT"
log "AZURE_CLIENT_ID=$AZURE_CLIENT_ID"
log "RESOURCE_GROUP_NAME=$RESOURCE_GROUP_NAME"

# Ensure Ansible is installed
if ! command -v ansible-playbook >/dev/null 2>&1; then
  log "ERROR: ansible-playbook not found in PATH"
  exit 1
fi

# Ensure inventory directory exists prior to generation or permission adjustments
mkdir -p "${ROOT_DIR}/ansible/inventory"

# Generate static inventory from Terraform outputs
log "Generating static Ansible inventory from Terraform outputs..."
if [ -x "${ROOT_DIR}/scripts/generate-inventory.sh" ]; then
  if "${ROOT_DIR}/scripts/generate-inventory.sh"; then
    log "Static inventory generated successfully"
  else
    log "WARNING: Failed to generate static inventory, will attempt to use dynamic inventory"
  fi
else
  log "WARNING: generate-inventory.sh not found or not executable"
fi

cd ansible
log "Working directory: $(pwd)"

# Normalize permissions to prevent Ansible from treating inventory as executable script.
chmod 755 . 2>/dev/null || true
chmod 755 inventory 2>/dev/null || true
chmod 644 inventory/azure_rm.yml 2>/dev/null || true
chmod 644 inventory/hosts.yml 2>/dev/null || true
log "Normalized directory and inventory permissions"

# SSH Configuration for Ansible
# These environment variables ensure correct SSH key usage, especially in dev containers
# where SSH agent forwarding may provide incorrect keys from the host OS.
# IdentitiesOnly=yes forces SSH to only use the specified key file.
ANSIBLE_SSH_ARGS="-o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o IdentitiesOnly=yes"
export ANSIBLE_SSH_ARGS
ANSIBLE_PRIVATE_KEY_FILE="${ANSIBLE_SSH_KEY_FILE:-${HOME}/.ssh/azure_k8s}"
export ANSIBLE_PRIVATE_KEY_FILE
log "SSH key file: $ANSIBLE_PRIVATE_KEY_FILE"

# Inventory diagnostics
log "Generating inventory graph for diagnostics (non-fatal)"
ANSIBLE_CONFIG="${PWD}/ansible.cfg" export ANSIBLE_CONFIG
# Disable problematic auto plugin to avoid azure.azcollection bugs
ANSIBLE_INVENTORY_ENABLED="yaml,ini,host_list,script" export ANSIBLE_INVENTORY_ENABLED
log "Using ansible.cfg: $ANSIBLE_CONFIG"
log "ANSIBLE_INVENTORY_ENABLED: $ANSIBLE_INVENTORY_ENABLED"

# Prefer static inventory (hosts.yml) if available, fallback to dynamic (azure_rm.yml)
INVENTORY_FILE="inventory/hosts.yml"
if [ ! -f "$INVENTORY_FILE" ]; then
  log "Static inventory not found, attempting dynamic inventory"
  INVENTORY_FILE="inventory/azure_rm.yml"
fi
log "Using inventory: $INVENTORY_FILE"

# Note: Inventory graph may fail if VMs aren't yet running or due to Azure collection issues
# This is non-fatal - proceed to playbook anyway
if ansible-inventory -i "$INVENTORY_FILE" --graph >/tmp/inventory_graph.txt 2>/tmp/inventory_graph.err; then
  sed -e 's/^/[inventory-success]/' /tmp/inventory_graph.txt || true
else
  log "Note: Inventory graph generation had issues (expected if VMs not yet running)" && head -5 /tmp/inventory_graph.err | sed -e 's/^/[inventory-note]/' || true
fi

# Attempt a ping to all before full playbook
log "Attempting ping to all hosts"
if ! ansible all -i "$INVENTORY_FILE" -m ping >/tmp/ping.out 2>/tmp/ping.err; then
  log "WARNING: Ping failed; continuing to playbook. See ping.err for details." && sed -e 's/^/[ping-error]/' /tmp/ping.err || true
else
  sed -e 's/^/[ping]/' /tmp/ping.out
fi

PLAYBOOK_LOG="${ROOT_DIR}/ansible-postprovision.log"
log "Running playbook site.yml (verbose)"
if ansible-playbook -vvv -i "$INVENTORY_FILE" playbooks/site.yml 2>&1 | tee "$PLAYBOOK_LOG"; then
  log "Playbook completed successfully"
else
  rc=$?
  log "Playbook failed with exit code $rc. Truncated tail:" && tail -n 40 "$PLAYBOOK_LOG" | sed -e 's/^/[playbook-tail]/'
  exit $rc
fi

# Kubeconfig presence check
if [ -f "${ROOT_DIR}/kubeconfig" ]; then
  log "kubeconfig fetched successfully -> ${ROOT_DIR}/kubeconfig"
else
  log "WARNING: kubeconfig not found after playbook run"
fi

log "Postprovision Ansible hook finished"
