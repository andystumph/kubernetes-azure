#!/usr/bin/env bash
# Safely load .env and sync selected variables into the current azd environment.
# Usage: ./scripts/load-env-and-sync-azd.sh [--no-azd] [-v|--verbose]
# POSIX-friendly implementation (avoid bash-only constructs) so accidental 'sh script' still works.
set -eu

# Guard: ensure running under bash for reliability (associative arrays avoided but still want bash features)
if [ -z "${BASH_VERSION:-}" ]; then
  echo "[sync] WARNING: Not running under bash. Use './scripts/load-env-and-sync-azd.sh' (without 'sh')." >&2
fi

NO_AZD=0
VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    --no-azd) NO_AZD=1 ;;
    -v|--verbose) VERBOSE=1 ;;
  esac
done

if [ ! -f .env ]; then
  echo "[sync] .env file not found. Copy .env.example to .env and populate values." >&2
  exit 1
fi

# Parse .env (KEY=VALUE per line). Preserve spaces inside quoted values.
PARSED_COUNT=0
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in 
    ''|\#*) continue;;
  esac
  # Require an '=' delimiter
  case "$line" in *"="*) ;; *) continue;; esac
  key=${line%%=*}
  value=${line#*=}
  # Trim surrounding quotes if both ends have them
  if [ "${value#\"}" != "$value" ] && [ "${value%\"}" != "$value" ]; then
    value=${value#\"}
    value=${value%\"}
  fi
  # Export
  export "$key=$value"
  PARSED_COUNT=$((PARSED_COUNT+1))
done < ./.env

echo "[sync] Loaded .env variables (parsed $PARSED_COUNT keys)." 

# Required keys check
REQUIRED_KEYS="AZURE_SUBSCRIPTION_ID ARM_CLIENT_ID ARM_CLIENT_SECRET SSH_PUBLIC_KEY RKE2_TOKEN"
MISSING=""
for k in $REQUIRED_KEYS; do
  eval val="\${$k:-}"
  if [ -z "$val" ]; then
    MISSING="$MISSING $k"
  fi
done
if [ -n "${MISSING// }" ]; then
  echo "[sync] Missing required variables:$MISSING" >&2
  exit 1
fi

# Export Terraform variable needed
if [ -n "${SSH_PUBLIC_KEY:-}" ]; then
  export TF_VAR_ssh_public_key="$SSH_PUBLIC_KEY"
else
  echo "[sync] SSH_PUBLIC_KEY empty; cannot export TF_VAR_ssh_public_key" >&2
  exit 1
fi

case "$SSH_PUBLIC_KEY" in 
  ssh-rsa*|ssh-ed25519*) ;; 
  *) echo "[sync] WARNING: SSH_PUBLIC_KEY not recognized as rsa or ed25519" >&2;;
esac

if [ "$VERBOSE" = 1 ]; then
  len=${#TF_VAR_ssh_public_key}
  echo "[sync] Exported TF_VAR_ssh_public_key (length=$len)"
  printf '[sync] First 60 chars: %s\n' "${TF_VAR_ssh_public_key%%${TF_VAR_ssh_public_key#????????????????????????????????????????????????????????????}}"
fi

if [ "$NO_AZD" = 0 ]; then
  echo "[sync] Persisting Terraform variable into azd environment..." 
  if azd env set TF_VAR_ssh_public_key "$SSH_PUBLIC_KEY" >/dev/null 2>&1; then
    echo "[sync] azd environment updated (TF_VAR_ssh_public_key)." 
  else
    echo "[sync] ERROR: Failed to persist TF_VAR_ssh_public_key to azd environment." >&2
    echo "[sync] HINT: Ensure an azd environment is selected (azd env list / azd env select)." >&2
  fi
else
  echo "[sync] Skipping azd env persistence (--no-azd specified)." 
fi

echo "[sync] Done. Verify: print -r -- \"$TF_VAR_ssh_public_key\" | cut -c1-60" 
