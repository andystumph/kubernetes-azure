#!/bin/bash
# Validation script to check setup before deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Kubernetes on Azure - Setup Validation ==="
echo ""

ERRORS=0
WARNINGS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++))
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

# Check required tools
echo "Checking required tools..."

if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
    print_success "Terraform installed (version $TERRAFORM_VERSION)"
else
    print_error "Terraform not found. Please install Terraform >= 1.5.0"
fi

if command -v ansible &> /dev/null; then
    ANSIBLE_VERSION=$(ansible --version | head -n1)
    print_success "Ansible installed ($ANSIBLE_VERSION)"
else
    print_error "Ansible not found. Please install Ansible"
fi

if command -v az &> /dev/null; then
    AZ_VERSION=$(az version --output json | jq -r '."azure-cli"')
    print_success "Azure CLI installed (version $AZ_VERSION)"
else
    print_error "Azure CLI not found. Please install Azure CLI"
fi

if command -v kubectl &> /dev/null; then
    print_success "kubectl installed"
else
    print_warning "kubectl not found. Will be installed by RKE2, but useful to have locally"
fi

if command -v azd &> /dev/null; then
    print_success "Azure Developer CLI (azd) installed"
else
    print_warning "azd not found. Optional but recommended for easy deployment"
fi

echo ""
echo "Checking environment configuration..."

# Check .env file exists
if [ -f "$PROJECT_ROOT/.env" ]; then
    print_success ".env file exists"
    
    # Load .env
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
    
    # Check required variables
    REQUIRED_VARS=(
        "AZURE_SUBSCRIPTION_ID"
        "AZURE_TENANT_ID"
        "ARM_CLIENT_ID"
        "ARM_CLIENT_SECRET"
        "SSH_PUBLIC_KEY"
        "RKE2_TOKEN"
    )
    
    for var in "${REQUIRED_VARS[@]}"; do
        if [ -z "${!var}" ]; then
            print_error "Environment variable $var is not set in .env"
        else
            # Check if still has example value
            if [[ "${!var}" == *"your-"* ]] || [[ "${!var}" == *"here"* ]]; then
                print_error "$var still has example value. Please set real value."
            else
                print_success "$var is set"
            fi
        fi
    done
    
    # Validate RKE2_TOKEN length
    if [ -n "$RKE2_TOKEN" ] && [ ${#RKE2_TOKEN} -lt 32 ]; then
        print_warning "RKE2_TOKEN is less than 32 characters. Consider using a longer token for security."
    fi
    
    # Validate SSH key format
    if [ -n "$SSH_PUBLIC_KEY" ]; then
        if [[ $SSH_PUBLIC_KEY == ssh-rsa* ]] || [[ $SSH_PUBLIC_KEY == ssh-ed25519* ]]; then
            print_success "SSH_PUBLIC_KEY format looks valid"
        else
            print_error "SSH_PUBLIC_KEY does not appear to be a valid SSH public key"
        fi
    fi
    
else
    print_error ".env file not found. Copy .env.example to .env and configure it."
fi

echo ""
echo "Checking Azure authentication..."

# Check Azure CLI login
if az account show &> /dev/null; then
    CURRENT_SUB=$(az account show --query id -o tsv)
    CURRENT_SUB_NAME=$(az account show --query name -o tsv)
    print_success "Azure CLI authenticated (Subscription: $CURRENT_SUB_NAME)"
    
    # Check if subscription matches
    if [ -n "$AZURE_SUBSCRIPTION_ID" ] && [ "$CURRENT_SUB" != "$AZURE_SUBSCRIPTION_ID" ]; then
        print_warning "Current Azure subscription ($CURRENT_SUB) doesn't match AZURE_SUBSCRIPTION_ID in .env"
        echo "           Run: az account set --subscription $AZURE_SUBSCRIPTION_ID"
    fi
else
    print_error "Azure CLI not authenticated. Run: az login"
fi

# Test service principal if credentials are set
if [ -n "$ARM_CLIENT_ID" ] && [ -n "$ARM_CLIENT_SECRET" ] && [ -n "$ARM_TENANT_ID" ]; then
    echo ""
    echo "Testing service principal authentication..."
    
    if az login --service-principal \
        -u "$ARM_CLIENT_ID" \
        -p "$ARM_CLIENT_SECRET" \
        --tenant "$ARM_TENANT_ID" &> /dev/null; then
        print_success "Service principal authentication works"
        
        # Check permissions
        ROLE=$(az role assignment list --assignee "$ARM_CLIENT_ID" --query "[?roleDefinitionName=='Contributor'].roleDefinitionName" -o tsv | head -n1)
        if [ "$ROLE" == "Contributor" ]; then
            print_success "Service principal has Contributor role"
        else
            print_warning "Service principal may not have sufficient permissions"
        fi
    else
        print_error "Service principal authentication failed. Check ARM_CLIENT_ID, ARM_CLIENT_SECRET, and ARM_TENANT_ID"
    fi
fi

echo ""
echo "Checking project structure..."

REQUIRED_DIRS=(
    ".devcontainer"
    ".github"
    "terraform"
    "ansible"
    "ansible/roles"
    "ansible/playbooks"
    "scripts"
    "docs"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$PROJECT_ROOT/$dir" ]; then
        print_success "Directory $dir exists"
    else
        print_error "Directory $dir is missing"
    fi
done

REQUIRED_FILES=(
    "terraform/main.tf"
    "terraform/variables.tf"
    "terraform/outputs.tf"
    "ansible/ansible.cfg"
    "ansible/playbooks/site.yml"
    ".gitignore"
    "azure.yaml"
    "README.md"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$PROJECT_ROOT/$file" ]; then
        print_success "File $file exists"
    else
        print_error "File $file is missing"
    fi
done

echo ""
echo "Checking Terraform configuration..."

cd "$PROJECT_ROOT/terraform"

if terraform init -backend=false &> /dev/null; then
    print_success "Terraform configuration is valid"
else
    print_error "Terraform configuration has errors. Run: cd terraform && terraform init"
fi

if terraform validate &> /dev/null; then
    print_success "Terraform validation passed"
else
    print_warning "Terraform validation has warnings"
fi

echo ""
echo "Checking Ansible configuration..."

cd "$PROJECT_ROOT/ansible"

if ansible-playbook --syntax-check playbooks/site.yml &> /dev/null; then
    print_success "Ansible playbook syntax is valid"
else
    print_error "Ansible playbook has syntax errors. Run: ansible-playbook --syntax-check playbooks/site.yml"
fi

echo ""
echo "=== Validation Summary ==="
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! You're ready to deploy.${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review your .env configuration"
    echo "  2. Run: azd up"
    echo "  3. Or run: ./scripts/deploy.sh"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Validation passed with $WARNINGS warning(s).${NC}"
    echo ""
    echo "You can proceed, but review the warnings above."
else
    echo -e "${RED}✗ Validation failed with $ERRORS error(s) and $WARNINGS warning(s).${NC}"
    echo ""
    echo "Please fix the errors above before deploying."
    exit 1
fi

echo ""
echo "Documentation:"
echo "  - Setup guide:          docs/SETUP.md"
echo "  - Deployment guide:     docs/DEPLOYMENT.md"
echo "  - CI/CD guide:          docs/CI_CD.md"
echo "  - Quick reference:      QUICK_REFERENCE.md"
echo ""
