# Security Guide

This document outlines the security measures implemented in this project and recommendations for production use.

## Security Architecture

### Network Security

#### Virtual Network Isolation

- Dedicated VNet with custom address space (10.0.0.0/16)
- Isolated subnet for Kubernetes nodes (10.0.1.0/24)
- No direct internet access to worker nodes except via load balancer

#### Network Security Groups (NSGs)

**Control Plane NSG:**
- SSH (22): Restricted to specific IPs (configure `allowed_ssh_cidrs`)
- Kubernetes API (6443): Restricted to specific IPs (configure `allowed_k8s_api_cidrs`)
- RKE2 Server (9345): Internal VNet only
- VNet Internal: All traffic within VNet allowed

**Worker Node NSG:**
- SSH (22): Restricted to specific IPs
- NodePort Range (30000-32767): Open for service access
- VNet Internal: All traffic within VNet allowed

#### Recommendations for Production:

```terraform

# In terraform/terraform.tfvars

allowed_ssh_cidrs = ["YOUR_OFFICE_IP/32", "YOUR_VPN_IP/32"]
allowed_k8s_api_cidrs = ["YOUR_OFFICE_IP/32", "YOUR_VPN_IP/32"]
```

### Kubernetes Security

#### RKE2 Security Features

**CIS Benchmark Compliance:**
- RKE2 configured with `profile: cis-1.23`
- Implements CIS Kubernetes Benchmark standards
- Automated security hardening

**RBAC (Role-Based Access Control):**
- Enabled by default
- Fine-grained access control
- Principle of least privilege

**Pod Security:**
- Pod Security Policies (PSP) enabled
- Admission controllers active:
  - NodeRestriction
  - PodSecurityPolicy
  - ServiceAccount

**Secrets Encryption:**
- Secrets encrypted at rest
- `secrets-encryption: true` in RKE2 config

**Audit Logging:**
- API server audit logging enabled
- Logs stored: `/var/lib/rancher/rke2/server/logs/audit.log`
- 30-day retention, 10 backup files, 100MB max size

#### Network Policies

RKE2 uses Cilium CNI which supports network policies. Example policy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: production
spec:
  podSelector: {}
  policyTypes:

  - Ingress
---

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
  namespace: production
spec:
  podSelector: {}
  policyTypes:

  - Ingress

  ingress:

  - from:
    - podSelector: {}

```

### Authentication & Authorization

#### SSH Access

- Public key authentication only
- Password authentication disabled
- Keys managed via environment variables
- No hardcoded keys in code

#### Kubernetes API Access

- TLS required for all API communications
- Client certificate authentication
- kubeconfig with embedded certificates
- Token-based authentication for service accounts

#### Azure Authentication

- Service Principal for Terraform
- Managed Identities recommended for production
- Credentials stored in `.env` (not in code)
- Azure RBAC for Azure resource access

### Secrets Management

#### Current Implementation

**Environment Variables:**
- Sensitive data in `.env` file
- `.env` excluded from git
- Loaded at runtime
- Never committed to source control

**RKE2 Token:**
- Shared secret for node authentication
- Must be strong and random (32+ characters)
- Stored in `.env` and passed to nodes at provisioning

#### Production Recommendations

**Azure Key Vault Integration:**

```terraform

# Example: Using Azure Key Vault

data "azurerm_key_vault_secret" "rke2_token" {
  name         = "rke2-token"
  key_vault_id = azurerm_key_vault.main.id
}

# Pass to VMs securely

resource "azurerm_linux_virtual_machine" "vm" {

  # ... other config

  custom_data = base64encode(templatefile("cloud-init.yaml", {
    rke2_token = data.azurerm_key_vault_secret.rke2_token.value
  }))
}
```

**Kubernetes Secrets:**
- Never commit secrets to git
- Use Sealed Secrets or External Secrets Operator
- Rotate secrets regularly

Example with External Secrets Operator:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: azure-backend
spec:
  provider:
    azurekv:
      authType: ManagedIdentity
      vaultUrl: "https://my-vault.vault.azure.net"
```

### Compliance & Hardening

#### CIS Kubernetes Benchmark

The cluster is configured to comply with CIS benchmarks:

**Verify compliance:**

```bash

# Install kube-bench

kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml

# Check results

kubectl logs job/kube-bench
```

#### System Hardening

**Applied via Ansible common role:**
- Swap disabled
- Kernel modules loaded (overlay, br_netfilter)
- Sysctl settings for Kubernetes
- Firewall (UFW) managed
- NTP synchronization (chrony)
- Latest security updates

**Additional hardening recommendations:**

```yaml

# In ansible/roles/common/tasks/main.yml

- name: Configure fail2ban

  apt:
    name: fail2ban
    state: present

- name: Install security updates automatically

  apt:
    name: unattended-upgrades
    state: present
```

### Monitoring & Auditing

#### Audit Logs

**Kubernetes API Audit:**
- Location: `/var/lib/rancher/rke2/server/logs/audit.log`
- Retention: 30 days
- Includes all API requests

**View audit logs:**

```bash
ssh azureuser@<control-plane-ip>
sudo tail -f /var/lib/rancher/rke2/server/logs/audit.log | jq
```

#### Security Monitoring Tools

**Falco (Runtime Security):**

```bash

# Install Falco

kubectl apply -f https://raw.githubusercontent.com/falcosecurity/falco/master/deploy/kubernetes/falco-daemonset-configmap.yaml

# View alerts

kubectl logs -n falco -l app=falco
```

**Trivy (Vulnerability Scanning):**

```bash

# Scan cluster

trivy k8s --report summary cluster

# Scan specific namespace

trivy k8s --report summary namespace/production
```

### Data Protection

#### Encryption

**In-Transit:**
- All Kubernetes components use TLS
- Node-to-node encryption via Cilium (optional)
- External traffic via TLS termination

**At-Rest:**
- Kubernetes secrets encrypted at rest
- Azure disk encryption for VM disks (optional)

Enable Azure disk encryption:

```terraform
resource "azurerm_linux_virtual_machine" "vm" {

  # ... other config

  encryption_at_host_enabled = true

  os_disk {

    # ... other config

    security_encryption_type = "VMGuestStateOnly"
  }
}
```

#### Backup & Recovery

**etcd Backup:**

```bash

# Automated backup script
#!/bin/bash
BACKUP_DIR="/backups/etcd"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

sudo /var/lib/rancher/rke2/bin/etcdctl snapshot save \
  "${BACKUP_DIR}/etcd-${TIMESTAMP}.db" \

  --cacert /var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
  --cert /var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
  --key /var/lib/rancher/rke2/server/tls/etcd/server-client.key

# Upload to Azure Blob Storage

az storage blob upload \

  --account-name <storage-account> \
  --container-name etcd-backups \
  --file "${BACKUP_DIR}/etcd-${TIMESTAMP}.db" \
  --name "etcd-${TIMESTAMP}.db"

```

### Security Checklist

#### Before Production

- [ ] Change all default passwords and tokens
- [ ] Restrict NSG rules to specific IP ranges
- [ ] Enable Azure disk encryption
- [ ] Set up Azure Key Vault for secrets
- [ ] Configure backup automation
- [ ] Enable Azure Monitor and Log Analytics
- [ ] Set up alerts for security events
- [ ] Implement network policies
- [ ] Review and test disaster recovery plan
- [ ] Configure automated security updates
- [ ] Set up vulnerability scanning
- [ ] Implement runtime security monitoring
- [ ] Configure log aggregation and analysis
- [ ] Document security procedures
- [ ] Train team on security practices
- [ ] Schedule regular security audits

#### Regular Maintenance

- [ ] Weekly: Review audit logs
- [ ] Weekly: Check for security updates
- [ ] Monthly: Test backups and recovery
- [ ] Monthly: Review access permissions
- [ ] Monthly: Scan for vulnerabilities
- [ ] Quarterly: Run CIS benchmark scan
- [ ] Quarterly: Review and update NSG rules
- [ ] Quarterly: Rotate secrets and credentials
- [ ] Annually: Full security audit
- [ ] Annually: Disaster recovery drill

### Incident Response

#### Security Event Handling

1. **Detection**
   - Monitor alerts from Falco, Azure Security Center
   - Review audit logs regularly
   - Set up automated alerting

2. **Containment**

   ```bash

   # Isolate affected node

   kubectl cordon <node-name>
   kubectl drain <node-name> --ignore-daemonsets

   # Block network access

   az network nsg rule create \

     --resource-group <rg-name> \
     --nsg-name <nsg-name> \
     --name DenyAll \
     --priority 100 \
     --direction Inbound \
     --access Deny

   ```

3. **Investigation**
   - Collect logs and evidence
   - Analyze audit trails
   - Identify root cause

4. **Recovery**
   - Restore from clean backup if needed
   - Apply security patches
   - Update configurations

5. **Post-Incident**
   - Document findings
   - Update security measures
   - Train team on lessons learned

### Contact & Resources

**Security Resources:**
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [RKE2 Security](https://docs.rke2.io/security/hardening_guide)
- [Azure Security Best Practices](https://docs.microsoft.com/en-us/azure/security/fundamentals/best-practices-and-patterns)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)

**Report Security Issues:**
- Review the vulnerability disclosure policy
- Contact security team immediately
- Do not disclose publicly until patched
