# GitHub Copilot Instructions for Kubernetes-Azure Project

## Project Overview
This project provisions and configures a Kubernetes cluster on Azure using RKE2, managed through infrastructure-as-code practices.

## Technology Stack
- **Container**: Dev Container using `astumph/iac` image
- **Infrastructure Provisioning**: Terraform
- **Configuration Management**: Ansible
- **Workflow Management**: Azure Developer CLI (azd)
- **Target Platform**: Azure
- **Kubernetes Distribution**: RKE2 (Rancher Kubernetes Engine 2)
- **Container Runtime**: containerd

## Architecture
- **Virtual Machines**: Configurable number (default: 3) Ubuntu 22.04 VMs
- **Hardware**: Latest Azure D-series VMs
- **Networking**: Isolated, secure VNet
- **Kubernetes Setup**: 
  - 1 management/control plane node
  - 2+ worker nodes
  - RKE2 distribution with containerd runtime
- **Access**: Management plane accessible from internet (secured)
- **Organization**: All resources in a single Azure Resource Group

## Security Requirements
- **NO SECRETS IN CODE**: All secrets must be externalized
- **Environment Variables**: Use `.env` file for runtime secrets (excluded from git)
- **Network Security**: Secure VNet configuration with proper NSG rules
- **Kubernetes Security**: Follow security best practices:
  - RBAC enabled
  - Network policies
  - Pod security standards
  - Secrets encryption at rest
  - TLS for all components
- **Azure Security**: Use managed identities where possible

## Code Style and Conventions

### Terraform
- Use Terraform 1.5+ features
- Organize by logical components (network, compute, security)
- Use variables for all configurable values
- Output important resource information
- Use remote state for production
- Tag all resources appropriately
- Use `terraform.tfvars` for defaults, never commit secrets

### Ansible
- Use roles for organization
- Idempotent playbooks
- Use vault for sensitive data
- Clear task naming
- Proper error handling
- Use tags for selective execution

### Azure Developer CLI
- Follow azd conventions
- Use `azure.yaml` for service definitions
- Leverage azd hooks for workflow orchestration

## File Organization
```
/
├── .devcontainer/          # Dev container configuration
├── .github/                # GitHub specific files
├── terraform/              # Infrastructure code
│   ├── modules/           # Reusable Terraform modules
│   ├── environments/      # Environment-specific configs
│   └── main.tf            # Main configuration
├── ansible/               # Configuration management
│   ├── roles/            # Ansible roles
│   ├── inventory/        # Dynamic inventory
│   └── playbooks/        # Playbooks
├── scripts/              # Helper scripts
├── docs/                 # Documentation
├── .env.example          # Example environment variables
└── azure.yaml            # Azure Developer CLI config
```

## Environment Variables
Required environment variables (document in `.env.example`):
- `AZURE_SUBSCRIPTION_ID`: Azure subscription ID
- `AZURE_TENANT_ID`: Azure tenant ID
- `ARM_CLIENT_ID`: Service principal client ID (for Terraform)
- `ARM_CLIENT_SECRET`: Service principal secret
- `RKE2_TOKEN`: Shared secret for cluster nodes
- `SSH_PUBLIC_KEY`: Public SSH key for VM access

## Documentation Standards
- README.md with quickstart guide
- Architecture diagrams where helpful
- Inline comments for complex logic
- Separate docs/ for detailed guides:
  - Setup and prerequisites
  - Deployment guide
  - Troubleshooting
  - Security considerations
  - Maintenance procedures

## Development Workflow
1. Make changes in dev container
2. Test Terraform with `terraform plan`
3. Validate Ansible with `ansible-playbook --check`
4. Use `azd` commands for deployment
5. Document changes

## Best Practices for Copilot
- Suggest secure defaults
- Validate Azure resource names and conventions
- Ensure idempotency in all automation
- Add error handling and validation
- Include helpful comments for complex configurations
- Recommend monitoring and logging setup
- Consider cost optimization
- Follow principle of least privilege

## Common Tasks
- **Add new VM**: Update `vm_count` variable in Terraform
- **Modify VM size**: Update `vm_size` variable
- **Update Kubernetes**: Modify RKE2 version in Ansible vars
- **Scale workers**: Adjust node count and re-run provisioning
- **Rotate secrets**: Update in .env and re-provision

## Testing Approach
- Terraform: Use `terraform validate` and `terraform plan`
- Ansible: Use `--check` mode and `--syntax-check`
- Infrastructure: Test in dev environment first
- Use small VM sizes for testing to reduce costs

## Maintenance Notes
- Keep Terraform providers updated
- Monitor RKE2 releases for updates
- Regularly update base Ubuntu images
- Review security advisories
- Clean up unused resources to manage costs
