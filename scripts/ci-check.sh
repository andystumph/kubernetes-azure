#!/bin/bash
# Run all CI checks locally before pushing to GitHub
# This mirrors the GitHub Actions workflow for local validation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

FAILED_CHECKS=()
PASSED_CHECKS=()

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

run_check() {
    local check_name="$1"
    local command="$2"
    
    echo ""
    echo -e "${BLUE}Running: $check_name${NC}"
    
    if eval "$command"; then
        print_success "$check_name passed"
        PASSED_CHECKS+=("$check_name")
        return 0
    else
        print_error "$check_name failed"
        FAILED_CHECKS+=("$check_name")
        return 1
    fi
}

cd "$PROJECT_ROOT"

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    Local CI/CD Validation - All Checks            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo "This script runs all CI checks locally to catch issues before pushing."
echo ""

# Check if required tools are installed
print_header "Checking Required Tools"

MISSING_TOOLS=()

check_tool() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 not found"
        MISSING_TOOLS+=("$1")
    else
        print_success "$1 is installed"
    fi
}

check_tool terraform
check_tool tflint
check_tool tfsec
check_tool ansible
check_tool ansible-lint
check_tool shellcheck
check_tool yamllint
check_tool markdownlint-cli2
check_tool gitleaks
check_tool trivy

if command -v pip &> /dev/null; then
    if ! pip show checkov &> /dev/null; then
        print_warning "checkov not found (install with: pip install checkov)"
        MISSING_TOOLS+=("checkov")
    else
        print_success "checkov is installed"
    fi
fi

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo ""
    print_error "Missing tools: ${MISSING_TOOLS[*]}"
    echo ""
    echo "Install missing tools:"
    echo ""
    
    for tool in "${MISSING_TOOLS[@]}"; do
        case "$tool" in
            terraform)
                echo "  brew install terraform  # or download from terraform.io"
                ;;
            tflint)
                echo "  brew install tflint  # or curl install from github.com/terraform-linters/tflint"
                ;;
            tfsec)
                echo "  brew install tfsec  # or curl install from github.com/aquasecurity/tfsec"
                ;;
            ansible|ansible-lint)
                echo "  pip install ansible ansible-lint"
                ;;
            shellcheck)
                echo "  brew install shellcheck  # or apt-get install shellcheck"
                ;;
            yamllint)
                echo "  pip install yamllint"
                ;;
            markdownlint-cli2)
                echo "  npm install -g markdownlint-cli2"
                ;;
            gitleaks)
                echo "  brew install gitleaks  # or download from github.com/gitleaks/gitleaks"
                ;;
            trivy)
                echo "  brew install aquasecurity/trivy/trivy  # or download from github.com/aquasecurity/trivy"
                ;;
            checkov)
                echo "  pip install checkov"
                ;;
        esac
    done
    echo ""
    echo "After installing tools, run this script again."
    exit 1
fi

# 1. TERRAFORM VALIDATION
print_header "1. Terraform Validation"

cd "$PROJECT_ROOT/terraform"

run_check "Terraform Format" "terraform fmt -check -recursive" || true
run_check "Terraform Init" "terraform init -backend=false" || true
run_check "Terraform Validate" "terraform validate" || true

if command -v tflint &> /dev/null; then
    run_check "TFLint Init" "tflint --init" || true
    run_check "TFLint" "tflint --format compact" || true
fi

cd "$PROJECT_ROOT"

# 2. TERRAFORM SECURITY
print_header "2. Terraform Security"

cd "$PROJECT_ROOT/terraform"

if command -v tfsec &> /dev/null; then
    run_check "tfsec" "tfsec . --no-color" || true
fi

if command -v checkov &> /dev/null; then
    run_check "Checkov" "checkov -d . --framework terraform --quiet --compact" || true
fi

cd "$PROJECT_ROOT"

# 3. ANSIBLE LINTING
print_header "3. Ansible Linting"

cd "$PROJECT_ROOT/ansible"

if command -v ansible-lint &> /dev/null; then
    run_check "Ansible Lint" "ansible-lint playbooks/site.yml" || true
fi

run_check "Ansible Syntax" "ansible-playbook playbooks/site.yml --syntax-check" || true

cd "$PROJECT_ROOT"

# 4. SHELL SCRIPT VALIDATION
print_header "4. Shell Script Validation"

if command -v shellcheck &> /dev/null; then
    run_check "ShellCheck" "shellcheck scripts/*.sh" || true
fi

# Check script permissions
echo ""
echo "Checking script permissions..."
for script in scripts/*.sh; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            print_success "$script is executable"
        else
            print_warning "$script is not executable (run: chmod +x $script)"
        fi
    fi
done

# 5. YAML VALIDATION
print_header "5. YAML Validation"

if command -v yamllint &> /dev/null; then
    run_check "YAML Lint" "yamllint ansible/ azure.yaml .github/" || true
fi

# 6. MARKDOWN LINTING
print_header "6. Markdown Linting"

if command -v markdownlint-cli2 &> /dev/null; then
    run_check "Markdown Lint" "markdownlint-cli2 '**/*.md'" || true
fi

# 7. SECRETS DETECTION
print_header "7. Secrets Detection"

if command -v gitleaks &> /dev/null; then
    run_check "Gitleaks" "gitleaks detect --source . --no-banner --redact" || true
fi

# 8. DOCUMENTATION CHECK
print_header "8. Documentation Check"

echo ""
echo "Checking required documentation files..."

required_files=(
    "README.md"
    "GETTING_STARTED.md"
    "docs/SETUP.md"
    "docs/DEPLOYMENT.md"
    "docs/SECURITY.md"
    "docs/TROUBLESHOOTING.md"
    "docs/CI_CD.md"
    ".env.example"
)

missing_files=()
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        print_success "$file exists"
    else
        print_error "$file missing"
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -eq 0 ]; then
    PASSED_CHECKS+=("Documentation Check")
else
    FAILED_CHECKS+=("Documentation Check")
fi

# 9. ENVIRONMENT VARIABLES CHECK
print_header "9. Environment Variables Check"

echo ""
echo "Checking environment variables documentation..."

required_vars=(
    "AZURE_SUBSCRIPTION_ID"
    "AZURE_TENANT_ID"
    "ARM_CLIENT_ID"
    "ARM_CLIENT_SECRET"
    "RKE2_TOKEN"
    "SSH_PUBLIC_KEY"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if grep -q "$var" .env.example; then
        print_success "$var documented in .env.example"
    else
        print_error "$var missing in .env.example"
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -eq 0 ]; then
    PASSED_CHECKS+=("Environment Variables Check")
else
    FAILED_CHECKS+=("Environment Variables Check")
fi

# 10. DEPENDENCY SECURITY
print_header "10. Dependency Security"

if command -v trivy &> /dev/null; then
    run_check "Trivy Config Scan" "trivy config . --exit-code 0" || true
fi

# SUMMARY
print_header "Validation Summary"

echo ""
echo "Passed checks: ${#PASSED_CHECKS[@]}"
echo "Failed checks: ${#FAILED_CHECKS[@]}"
echo ""

if [ ${#FAILED_CHECKS[@]} -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ All CI checks passed!                          ║${NC}"
    echo -e "${GREEN}║    Your code is ready to push.                    ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ✗ Some checks failed                              ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Failed checks:"
    for check in "${FAILED_CHECKS[@]}"; do
        echo -e "  ${RED}✗${NC} $check"
    done
    echo ""
    echo "Please fix the issues above before pushing."
    echo ""
    echo "For help, see: docs/CI_CD.md"
    echo ""
    exit 1
fi
