#!/bin/sh
# Preprovision hook logic extracted from azure.yaml for clarity and YAML compliance.
set -eu

echo "[preprovision] Validating environment variables..."
if [ -f .env ]; then
  set -a
  . ./.env
  set +a
else
  echo "Error: .env file not found. Copy .env.example to .env and configure."
  exit 1
fi

# Validate required vars
missing=0
for v in RESOURCE_GROUP_NAME AZURE_LOCATION ENVIRONMENT PROJECT_NAME VM_COUNT ADMIN_USERNAME SSH_PUBLIC_KEY; do
  eval "val=\${$v}"
  if [ -z "$val" ]; then
    echo "Error: $v is not set in .env"
    missing=1
  fi
done
[ "$missing" = "1" ] && exit 1

if [ -z "${TF_VAR_ssh_public_key:-}" ]; then
  echo "[preprovision] ERROR: TF_VAR_ssh_public_key not set before preprovision hook."
  echo "[preprovision] This run may still prompt. Set it persistently with:"
  echo "    azd env set TF_VAR_ssh_public_key \"$SSH_PUBLIC_KEY\""
  echo "[preprovision] Continuing, exporting for subsequent steps, but initial Terraform variable resolution already occurred."
fi
echo "[preprovision] Ensuring TF_VAR_ssh_public_key present in environment"
export TF_VAR_ssh_public_key="${TF_VAR_ssh_public_key:-$SSH_PUBLIC_KEY}"

echo "[preprovision] Generating terraform/main.tfvars.json"
sh scripts/generate-tfvars-json.sh

echo "[preprovision] Done"
