#!/bin/sh
set -eu
# Generates terraform/main.tfvars.json from environment variables expected in .env
# It excludes ssh_public_key which is passed via TF_VAR_ssh_public_key.

: "${RESOURCE_GROUP_NAME:?RESOURCE_GROUP_NAME not set}"
: "${AZURE_LOCATION:?AZURE_LOCATION not set}"
: "${ENVIRONMENT:?ENVIRONMENT not set}"
: "${PROJECT_NAME:?PROJECT_NAME not set}"
: "${VM_COUNT:?VM_COUNT not set}"
: "${ADMIN_USERNAME:?ADMIN_USERNAME not set}"

cat > terraform/main.tfvars.json <<EOF
{
  "resource_group_name": "${RESOURCE_GROUP_NAME}",
  "location": "${AZURE_LOCATION}",
  "environment": "${ENVIRONMENT}",
  "project_name": "${PROJECT_NAME}",
  "vm_count": ${VM_COUNT},
  "admin_username": "${ADMIN_USERNAME}"
}
EOF
