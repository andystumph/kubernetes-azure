# Troubleshooting Guide

Common issues and solutions for the Kubernetes on Azure project.

## Table of Contents

- [Terraform Issues](#terraform-issues)
- [Ansible Issues](#ansible-issues)
- [RKE2/Kubernetes Issues](#rke2kubernetes-issues)
- [Network Issues](#network-issues)
- [Azure-Specific Issues](#azure-specific-issues)
- [Performance Issues](#performance-issues)

## Terraform Issues

### Error: Service Principal Authentication Failed

**Symptoms:**

```text
Error: building account: Error building AzureRM Client: obtain subscription...
```

**Solutions:**

1. Verify credentials in `.env`:

   ```bash
   echo $ARM_CLIENT_ID
   echo $ARM_TENANT_ID

   # Don't echo the secret!

   ```

2. Test service principal login:

   ```bash
   az login --service-principal \

     -u $ARM_CLIENT_ID \
     -p $ARM_CLIENT_SECRET \
     --tenant $ARM_TENANT_ID

   ```

3. Check service principal permissions:

   ```bash
   az role assignment list --assignee $ARM_CLIENT_ID
   ```

4. Recreate service principal if needed:

   ```bash
   az ad sp delete --id $ARM_CLIENT_ID
   az ad sp create-for-rbac --name "kubernetes-azure-sp" --role="Contributor"
   ```

### Error: Resource Already Exists

**Symptoms:**

```text
Error: A resource with the ID "..." already exists
```

**Solutions:**

1. Import existing resource:

   ```bash
   terraform import azurerm_resource_group.main /subscriptions/.../resourceGroups/...
   ```

2. Or remove from Azure and retry:

   ```bash
   az group delete --name <resource-group-name>
   terraform apply
   ```

3. Check for state file conflicts:

   ```bash
   cd terraform
   rm -rf .terraform.lock.hcl
   terraform init -upgrade
   ```

### Error: Quota Exceeded

### Prompt: Terraform asks for `ssh_public_key` every run

**Symptoms:**

```text
var.ssh_public_key
   Enter a value:
```

**Cause:** Terraform variable `ssh_public_key` has no default and `TF_VAR_ssh_public_key` was not set before `azd up` / `terraform apply`.

**Fix Options:**

```bash

# Recommended - use loader script (exports + persists to azd env)

./scripts/load-env-and-sync-azd.sh

# Manual - set in azd environment (persists across sessions)

azd env set TF_VAR_ssh_public_key "$SSH_PUBLIC_KEY"

# Ad-hoc - export for current shell only

export TF_VAR_ssh_public_key="$SSH_PUBLIC_KEY"
```

**Verify:**

```bash
azd env get-values | grep TF_VAR_ssh_public_key | cut -c1-80
print -r -- "$TF_VAR_ssh_public_key" | head -c80
```

**Avoid Anti-Patterns:**
- Don’t rely solely on exporting inside pre-provision hooks; azd resolves variables before hooks run.
- Don’t split the SSH key across lines; it must be a single line.
- Don’t remove the `ssh-rsa` prefix.


**Symptoms:**

```text
Error: Code="QuotaExceeded" Message="The operation could not be completed as it
results in exceeding approved X cores quota"
```

**Solutions:**

1. Check current usage:

   ```bash
   az vm list-usage --location eastus --output table
   ```

2. Request quota increase:
   - Portal: https://portal.azure.com → Support → New support request
   - Or choose smaller VM size in `.env`:

     ```bash

     # In terraform/terraform.tfvars

     vm_size = "Standard_D2s_v5"  # Smaller size
     ```

## Ansible Issues

### Error: Cannot Connect to Hosts

**Symptoms:**

```text
fatal: [host]: UNREACHABLE! => {"msg": "Failed to connect to the host via ssh"}
```

**Solutions:**

1. Verify VMs are running:

   ```bash
   az vm list --resource-group <rg-name> --show-details --output table
   ```

2. Test SSH manually:

   ```bash
   ssh -i ~/.ssh/azure_k8s azureuser@<public-ip>
   ```

3. Check NSG rules:

   ```bash
   az network nsg rule list \

     --resource-group <rg-name> \
     --nsg-name <nsg-name> \
     --output table

   ```

4. **Regenerate inventory if VMs changed:**

   ```bash
   ./scripts/generate-inventory.sh
   ```

5. **SSH Key Issues - Dev Container Environment:**

   If SSH fails with `Permission denied (publickey)`, this is often due to SSH agent forwarding from the host:

   **Problem:** The dev container forwards SSH keys from your host OS (e.g., Windows), and SSH tries those keys first before the correct dev container key.

   **Solution:** The generated inventory is configured to use `IdentitiesOnly=yes` which forces SSH to only use the specified key file.

   **Test the connection:**

   ```bash

   # This should work (uses explicit key and IdentitiesOnly)

   ssh -o IdentitiesOnly=yes -i ~/.ssh/azure_k8s azureuser@<public-ip>

   # This might fail (tries agent keys first)

   ssh azureuser@<public-ip>
   ```

   **Check which keys the agent has:**

   ```bash
   ssh-add -l

   # You may see keys from your host OS (e.g., C:\Users\...\id_rsa)

   ```

   **Custom SSH Key Location:**

   If you're using a different SSH key name, set the `ANSIBLE_SSH_KEY_FILE` environment variable:

   ```bash

   # In .env or export directly

   export ANSIBLE_SSH_KEY_FILE=~/.ssh/my_custom_key
   ```

   The default is `~/.ssh/azure_k8s`. The inventory generator uses this variable with a fallback, and the generated `hosts.yml` will include this path.

6. Verify SSH key permissions:

   ```bash
   ls -l ~/.ssh/azure_k8s

   # Should be: -rw------- (600)

   # Fix if needed

   chmod 600 ~/.ssh/azure_k8s
   ```

7. Check inventory:

   ```bash
   cd ansible
   ansible-inventory -i inventory/hosts.yml --list
   ```

### Error: Python Interpreter Not Found

**Symptoms:**

```text
fatal: [host]: FAILED! => {"msg": "/usr/bin/python3: not found"}
```

**Solutions:**

1. Update ansible.cfg (already configured):

   ```ini
   [defaults]
   interpreter_python = auto_silent
   ```

2. Or explicitly set in inventory:

   ```yaml
   all:
     vars:
       ansible_python_interpreter: /usr/bin/python3
   ```

### Error: Privilege Escalation Failed

**Symptoms:**

```text
fatal: [host]: FAILED! => {"msg": "Missing sudo password"}
```

**Solutions:**

1. Ensure VM user has sudo without password:

   ```bash
   ssh azureuser@<ip>
   sudo cat /etc/sudoers.d/90-cloud-init-users

   # Should contain: azureuser ALL=(ALL) NOPASSWD:ALL

   ```

2. Or provide sudo password:

   ```bash
   ansible-playbook playbooks/site.yml --ask-become-pass
   ```

### Error: Inventory Generation Failed

**Symptoms:**

```text
Error: Could not retrieve Terraform outputs
```

**Solutions:**

1. Ensure Terraform state exists:

   ```bash
   cd terraform
   terraform output

   # Should show control_plane_public_ip, worker_public_ips, etc.

   ```

2. Re-run inventory generation:

   ```bash
   ./scripts/generate-inventory.sh
   ```

3. Check generated inventory:

   ```bash
   cat ansible/inventory/hosts.yml

   # Verify all IPs are present and correct

   ```

4. If Terraform outputs are missing, provision infrastructure first:

   ```bash
   cd terraform
   terraform apply
   cd ..
   ./scripts/generate-inventory.sh
   ```

**Note:** The project uses static inventory (`hosts.yml`) generated from Terraform outputs instead of Azure dynamic inventory (`azure_rm.yml`). This is more reliable and works better in dev container environments.

## RKE2/Kubernetes Issues

### RKE2 Service Won't Start

**Symptoms:**

```text
Job for rke2-server.service failed
```

**Solutions:**

1. Check logs:

   ```bash
   ssh azureuser@<control-plane-ip>
   sudo journalctl -u rke2-server -n 100 --no-pager
   ```

2. Common issues and fixes:

   **Token mismatch:**

   ```bash

   # Verify token matches across all nodes

   sudo cat /etc/rancher/rke2/config.yaml
   ```

   **Port already in use:**

   ```bash

   # Check for conflicts

   sudo netstat -tlnp | grep -E '6443|9345|10250'

   # Kill conflicting processes

   sudo systemctl stop rke2-server
   sudo systemctl start rke2-server
   ```

   **Insufficient resources:**

   ```bash

   # Check memory and disk

   free -h
   df -h

   # RKE2 requires: 4GB RAM, 40GB disk minimum

   ```

3. Reset and reinstall:

   ```bash

   # Complete reset (DESTRUCTIVE)

   sudo /usr/local/bin/rke2-uninstall.sh

   # Re-run Ansible playbook

   ```

### Nodes Not Joining Cluster

**Symptoms:**

```text
kubectl get nodes

# Worker nodes missing or NotReady
```

**Solutions:**

1. Check worker logs:

   ```bash
   ssh azureuser@<worker-ip>
   sudo journalctl -u rke2-agent -n 100 --no-pager
   ```

2. Verify server connectivity:

   ```bash

   # On worker node

   curl -k https://<control-plane-private-ip>:9345

   # Should return "404 page not found" (endpoint exists)

   ```

3. Check token:

   ```bash

   # On worker

   sudo cat /etc/rancher/rke2/config.yaml

   # Verify token matches control plane

   ```

4. Network issues:

   ```bash

   # Test connectivity from worker to control plane

   telnet <control-plane-private-ip> 9345

   # Check NSG rules allow internal traffic

   az network nsg rule list --nsg-name <worker-nsg> --output table
   ```

### Pods Stuck in Pending

**Symptoms:**

```text
kubectl get pods -A

# Pods showing Pending status
```

**Solutions:**

1. Describe the pod:

   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   ```

2. Common causes:

   **Insufficient resources:**

   ```bash
   kubectl top nodes
   kubectl describe nodes

   # Look for resource pressure

   ```

   **Image pull errors:**

   ```bash
   kubectl describe pod <pod-name>

   # Check Events section for ImagePullBackOff

   # Test image pull manually

   ssh azureuser@<worker-ip>
   sudo /var/lib/rancher/rke2/bin/crictl pull <image-name>
   ```

   **Node selector mismatch:**

   ```bash
   kubectl get nodes --show-labels

   # Verify pod's nodeSelector matches node labels

   ```

### kubectl Commands Fail

**Symptoms:**

```text
The connection to the server <ip>:6443 was refused
```

**Solutions:**

1. Check kubeconfig:

   ```bash
   echo $KUBECONFIG
   cat $KUBECONFIG

   # Verify server address and certificates

   ```

2. Verify API server is running:

   ```bash
   ssh azureuser@<control-plane-ip>
   sudo systemctl status rke2-server
   sudo netstat -tlnp | grep 6443
   ```

3. Test connectivity:

   ```bash
   curl -k https://<control-plane-public-ip>:6443

   # Should return certificate-related error (expected)

   ```

4. Re-fetch kubeconfig:

   ```bash
   cd ansible
   ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags kubeconfig
   ```

## Network Issues

### Cannot Access Kubernetes API

**Symptoms:**

```text
dial tcp <ip>:6443: i/o timeout
```

**Solutions:**

1. Check NSG rules:

   ```bash
   az network nsg rule list \

     --resource-group <rg-name> \
     --nsg-name <control-plane-nsg> \
     --query "[?name=='AllowKubernetesAPI']"

   ```

2. Verify public IP:

   ```bash
   az network public-ip show \

     --resource-group <rg-name> \
     --name <pip-name> \
     --query ipAddress

   ```

3. Test from different location:

   ```bash

   # From another machine

   telnet <public-ip> 6443
   ```

4. Update allowed IPs:

   ```terraform

   # In terraform/terraform.tfvars

   allowed_k8s_api_cidrs = ["0.0.0.0/0"]  # Temporarily allow all
   ```

### NodePort Services Not Accessible

**Symptoms:**

```text
curl http://<worker-ip>:<nodeport>

# Connection timeout
```

**Solutions:**

1. Verify service:

   ```bash
   kubectl get svc -A
   kubectl describe svc <service-name>
   ```

2. Check NSG rules:

   ```bash
   az network nsg rule list \

     --resource-group <rg-name> \
     --nsg-name <worker-nsg> \
     --query "[?name=='AllowNodePort']"

   ```

3. Test from worker node:

   ```bash
   ssh azureuser@<worker-ip>
   curl localhost:<nodeport>

   # If this works, it's a network issue

   ```

## Azure-Specific Issues

### Subscription Not Found

**Symptoms:**

```text
Error: The subscription '<id>' could not be found
```

**Solutions:**

1. List available subscriptions:

   ```bash
   az account list --output table
   ```

2. Set correct subscription:

   ```bash
   az account set --subscription "<subscription-id>"
   ```

3. Verify in `.env`:

   ```bash
   grep AZURE_SUBSCRIPTION_ID .env
   ```

### VM Size Not Available

**Symptoms:**

```text
Error: Code="SkuNotAvailable" Message="The requested VM size Standard_D4s_v5
is not available in location 'eastus'"
```

**Solutions:**

1. Check available sizes:

   ```bash
   az vm list-sizes --location eastus --output table | grep Standard_D
   ```

2. Find alternative:

   ```bash
   az vm list-skus \

     --location eastus \
     --size Standard_D \
     --all --output table

   ```

3. Update configuration:

   ```terraform

   # In terraform/terraform.tfvars

   vm_size = "Standard_D4s_v3"  # Use available size
   ```

## Performance Issues

### Slow Deployment

**Symptoms:**
- Terraform takes very long to apply
- Ansible playbook execution is slow

**Solutions:**

1. Enable SSH connection reuse (already configured in ansible.cfg):

   ```ini
   [ssh_connection]
   pipelining = True
   ```

2. Use parallel execution:

   ```bash

   # Terraform

   terraform apply -parallelism=10

   # Ansible

   ansible-playbook playbooks/site.yml --forks 10
   ```

3. Optimize Terraform:

   ```bash

   # Use targeted applies

   terraform apply -target=azurerm_resource_group.main
   ```

### High Resource Usage on VMs

**Symptoms:**

```text
kubectl top nodes

# Shows high CPU/memory usage
```

**Solutions:**

1. Check pod resource requests/limits:

   ```bash
   kubectl describe nodes

   # Look at "Allocated resources" section

   ```

2. Scale up VM size:

   ```terraform

   # In terraform/terraform.tfvars

   vm_size = "Standard_D8s_v5"  # More resources
   ```

3. Add more worker nodes:

   ```bash

   # In .env

   VM_COUNT=5  # Add more workers
   ```

4. Optimize workloads:

   ```yaml
   resources:
     requests:
       memory: "64Mi"
       cpu: "100m"
     limits:
       memory: "128Mi"
       cpu: "200m"
   ```

## Getting Help

### Collecting Diagnostic Information

```bash

# Create diagnostic bundle

mkdir -p /tmp/k8s-diagnostics

# Terraform state

cd terraform
terraform show > /tmp/k8s-diagnostics/terraform-state.txt

# Ansible inventory

cd ../ansible
ansible-inventory -i inventory/hosts.yml --list \
  > /tmp/k8s-diagnostics/inventory.json

# Kubernetes info

export KUBECONFIG=../kubeconfig
kubectl get nodes -o wide > /tmp/k8s-diagnostics/nodes.txt
kubectl get pods -A -o wide > /tmp/k8s-diagnostics/pods.txt
kubectl get events -A --sort-by='.lastTimestamp' \
  > /tmp/k8s-diagnostics/events.txt

# Package

tar -czf k8s-diagnostics.tar.gz -C /tmp k8s-diagnostics/
```

### Support Resources

- **Project Issues**: Open an issue in the repository
- **RKE2 Documentation**: https://docs.rke2.io/
- **Azure Support**: https://azure.microsoft.com/support/
- **Kubernetes Community**: https://kubernetes.io/community/
- **Terraform Azure Provider**: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
