# CI/CD Pipeline Documentation

## Overview

This project uses GitHub Actions to provide comprehensive continuous integration and validation for all code changes. The CI pipeline runs automatically on every push to `main` and on all pull requests targeting `main`.

## Pipeline Status

The current status of the CI pipeline is displayed in the README badge:

[![CI/CD Pipeline](https://github.com/andystumph/kubernetes-azure/actions/workflows/ci.yml/badge.svg)](https://github.com/andystumph/kubernetes-azure/actions/workflows/ci.yml)

## What Gets Tested

### 1. Terraform Validation (`terraform-validate`)

**Purpose**: Ensures Terraform code is properly formatted and syntactically correct.

**Checks performed**:
- `terraform fmt -check`: Verifies code follows Terraform formatting standards
- `terraform validate`: Validates syntax and configuration
- `tflint`: Advanced linting for Terraform best practices

**Local execution**:
```bash
cd terraform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate

# Install and run tflint
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
tflint --init
tflint
```

### 2. Terraform Security (`terraform-security`)

**Purpose**: Scans Terraform code for security vulnerabilities and misconfigurations.

**Tools used**:
- **tfsec**: Static analysis security scanner for Terraform
- **Checkov**: Policy-as-code scanner that detects security and compliance issues

**Local execution**:
```bash
# Install tfsec
brew install tfsec  # macOS
# or
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# Run tfsec
cd terraform
tfsec .

# Install Checkov
pip install checkov

# Run Checkov
checkov -d terraform --framework terraform
```

**Common issues detected**:
- Unencrypted storage accounts
- Overly permissive network security rules
- Missing encryption at rest
- Publicly accessible resources
- Missing resource tags

### 3. Ansible Linting (`ansible-lint`)

**Purpose**: Validates Ansible playbooks and roles follow best practices.

**Checks performed**:
- `ansible-lint`: Checks for common mistakes and style issues
- `ansible-playbook --syntax-check`: Validates YAML syntax

**Local execution**:
```bash
# Install ansible-lint
pip install ansible ansible-lint

# Run ansible-lint
cd ansible
ansible-lint playbooks/site.yml

# Check syntax
ansible-playbook playbooks/site.yml --syntax-check
```

### 4. Ansible Security (`ansible-security`)

**Purpose**: Runs security-focused checks on Ansible code.

**Checks performed**:
- Production profile linting with stricter rules
- Checks for hardcoded secrets
- Validates privilege escalation usage

**Local execution**:
```bash
cd ansible
ansible-lint --profile production playbooks/site.yml
```

### 5. Shell Script Validation (`shell-scripts`)

**Purpose**: Ensures shell scripts are properly written and follow best practices.

**Checks performed**:
- `shellcheck`: Static analysis for shell scripts
- Permission verification for executable scripts

**Local execution**:
```bash
# Install shellcheck
brew install shellcheck  # macOS
# or
sudo apt-get install shellcheck  # Ubuntu

# Run shellcheck
shellcheck scripts/*.sh

# Check permissions
ls -la scripts/*.sh
```

**Common issues detected**:
- Unquoted variables
- Incorrect command substitution
- Missing error handling
- Potential race conditions

### 6. Markdown Linting (`markdown-lint`)

**Purpose**: Ensures documentation is consistently formatted.

**Checks performed**:
- Validates all `.md` files against markdown style rules
- Checks for broken links in documentation

**Local execution**:
```bash
# Install markdownlint-cli2
npm install -g markdownlint-cli2

# Run linter
markdownlint-cli2 "**/*.md"
```

### 7. YAML Validation (`yaml-lint`)

**Purpose**: Validates YAML files are properly formatted.

**Files checked**:
- Ansible playbooks and inventory
- Azure Developer CLI configuration
- GitHub Actions workflows

**Local execution**:
```bash
# Install yamllint
pip install yamllint

# Run yamllint
yamllint -d "{extends: default, rules: {line-length: {max: 120}}}" ansible/ azure.yaml .github/
```

### 8. Secrets Detection (`secrets-scan`)

**Purpose**: Prevents accidental commit of sensitive information.

**Tool used**:
- **Gitleaks**: Scans git history for secrets and credentials

**Local execution**:
```bash
# Install gitleaks
brew install gitleaks  # macOS
# or download from https://github.com/gitleaks/gitleaks/releases

# Run gitleaks
gitleaks detect --source . --verbose
```

**What it detects**:
- API keys and tokens
- Passwords and connection strings
- Private keys
- AWS/Azure credentials
- Database connection strings

### 9. Documentation Check (`documentation-check`)

**Purpose**: Ensures required documentation files exist and are accessible.

**Required files**:
- `README.md`
- `GETTING_STARTED.md`
- `docs/SETUP.md`
- `docs/DEPLOYMENT.md`
- `docs/SECURITY.md`
- `docs/TROUBLESHOOTING.md`
- `.env.example`

**Checks performed**:
- Verifies all required files exist
- Validates markdown links aren't broken
- Checks documentation is up-to-date

**Local execution**:
```bash
# Check required files
for file in README.md GETTING_STARTED.md docs/SETUP.md docs/DEPLOYMENT.md docs/SECURITY.md docs/TROUBLESHOOTING.md .env.example; do
  [ -f "$file" ] && echo "✓ $file" || echo "✗ $file missing"
done

# Check markdown links
npm install -g markdown-link-check
find . -name "*.md" -exec markdown-link-check {} \;
```

### 10. Dependency Security (`dependency-check`)

**Purpose**: Scans for vulnerabilities in dependencies and configurations.

**Tool used**:
- **Trivy**: Comprehensive security scanner

**Local execution**:
```bash
# Install Trivy
brew install aquasecurity/trivy/trivy  # macOS
# or download from https://github.com/aquasecurity/trivy/releases

# Run Trivy
trivy config .
```

### 11. Integration Validation (`integration-check`)

**Purpose**: Validates that different components of the project work together correctly.

**Checks performed**:
- Azure Developer CLI configuration exists
- Terraform outputs match Ansible requirements
- Environment variables are documented in `.env.example`
- Required environment variables are present

**Local execution**:
```bash
# Run the validation script (if created)
./scripts/validate-setup.sh

# Check environment variables
required_vars=("AZURE_SUBSCRIPTION_ID" "AZURE_TENANT_ID" "ARM_CLIENT_ID" "ARM_CLIENT_SECRET" "RKE2_TOKEN" "SSH_PUBLIC_KEY")
for var in "${required_vars[@]}"; do
  grep -q "$var" .env.example && echo "✓ $var" || echo "✗ $var missing"
done
```

## Running All Checks Locally

### Quick Method: Automated Script

The easiest way to run all CI checks locally is to use the provided script:

```bash
./scripts/ci-check.sh
```

This script will:
- Check that all required tools are installed
- Run all CI validations in the same order as GitHub Actions
- Provide a clear summary of passed/failed checks
- Exit with an error if any check fails

### Manual Method: Individual Commands

To run checks individually or if you prefer manual control:

```bash
# 1. Terraform checks
cd terraform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
tflint --init && tflint
tfsec .
checkov -d . --framework terraform

# 2. Ansible checks
cd ../ansible
ansible-lint playbooks/site.yml
ansible-playbook playbooks/site.yml --syntax-check

# 3. Shell script checks
cd ..
shellcheck scripts/*.sh

# 4. YAML validation
yamllint ansible/ azure.yaml .github/

# 5. Markdown linting
markdownlint-cli2 "**/*.md"

# 6. Secrets scanning
gitleaks detect --source . --verbose

# 7. Security scanning
trivy config .
```

## CI/CD Workflow Structure

The workflow is organized into 11 parallel jobs plus a final summary job:

```
┌─────────────────────────────────────────────────────┐
│                   Pull Request / Push                │
└─────────────────────────────────────────────────────┘
                           ↓
    ┌──────────────────────────────────────────────┐
    │          Run checks in parallel:              │
    ├──────────────────────────────────────────────┤
    │  • Terraform Validation                       │
    │  • Terraform Security                         │
    │  • Ansible Linting                            │
    │  • Ansible Security                           │
    │  • Shell Script Validation                    │
    │  • Markdown Linting                           │
    │  • YAML Validation                            │
    │  • Secrets Detection                          │
    │  • Documentation Check                        │
    │  • Dependency Security                        │
    │  • Integration Validation                     │
    └──────────────────────────────────────────────┘
                           ↓
                   All jobs must pass
                           ↓
              ┌────────────────────────┐
              │  All Checks Complete   │
              │  (Summary Job)         │
              └────────────────────────┘
```

## Handling Failures

When a CI check fails:

1. **Review the failure logs**: Click on the failed job in GitHub Actions to see detailed output
2. **Run locally**: Use the local execution commands above to reproduce the issue
3. **Fix the issue**: Address the specific problem identified
4. **Test locally**: Re-run the check locally to verify the fix
5. **Commit and push**: The CI will automatically re-run

### Common Failures and Fixes

#### Terraform fmt failure
```bash
# Auto-fix formatting
cd terraform
terraform fmt -recursive
git add .
git commit -m "Fix Terraform formatting"
```

#### Ansible lint failure
```bash
# Review and fix issues
cd ansible
ansible-lint playbooks/site.yml
# Address each issue, then commit
```

#### Shellcheck warnings
```bash
# Fix shell script issues
shellcheck scripts/deploy.sh
# Address warnings about quoting, error handling, etc.
```

#### Secrets detected
```bash
# NEVER commit the fix if secrets are exposed
# Instead:
# 1. Remove the secret from the code
# 2. Add it to .env (which is gitignored)
# 3. Update .env.example with placeholder
# 4. Consider rotating the exposed secret
```

## Skipping CI (Not Recommended)

In rare cases where you need to skip CI (e.g., documentation-only changes to README), add to your commit message:

```bash
git commit -m "docs: Update README [skip ci]"
```

**Warning**: Only use this for trivial changes that don't affect functionality.

## CI Performance

Typical execution times:
- **Fast checks** (~1-2 minutes): YAML, Markdown, Shell scripts
- **Medium checks** (~2-4 minutes): Terraform validation, Ansible linting
- **Slower checks** (~3-5 minutes): Security scans (tfsec, Checkov, Trivy)

Total pipeline execution: ~5-7 minutes (jobs run in parallel)

## Security Considerations

The CI pipeline:
- ✅ Never exposes secrets or credentials
- ✅ Runs in isolated GitHub-hosted runners
- ✅ Uses pinned versions of actions (e.g., `@v4`)
- ✅ Uploads security findings to GitHub Security tab
- ✅ Blocks merges if security issues are found

## Required Secrets

The CI workflow does not require any GitHub secrets to run. All checks run against the code without needing Azure credentials.

## Extending the Pipeline

To add new checks:

1. Edit `.github/workflows/ci.yml`
2. Add a new job following the existing pattern
3. Add the job name to the `needs` array of `all-checks-complete`
4. Document the new check in this file
5. Provide local execution instructions

Example:
```yaml
new-check:
  name: New Validation
  runs-on: ubuntu-latest
  steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Run new check
      run: |
        # Your validation command
```

## Troubleshooting

### Workflow not running
- Check that the workflow file is in `.github/workflows/`
- Verify the trigger conditions (`on: push` / `on: pull_request`)
- Check branch protection rules

### Permission errors
- GitHub Actions needs `contents: read` permissions (default)
- For security uploads, `security-events: write` is granted automatically

### Cache issues
- Clear runner cache: Re-run the workflow
- For Terraform: Delete `.terraform` directory if needed

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [Ansible Lint Rules](https://ansible-lint.readthedocs.io/en/latest/default_rules/)
- [ShellCheck Wiki](https://github.com/koalaman/shellcheck/wiki)

## Contact

For questions or issues with the CI/CD pipeline, please open an issue in the repository.
