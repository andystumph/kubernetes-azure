#!/usr/bin/env python3
"""Fix Ansible YAML linting issues."""

import os
import re
from pathlib import Path

# FQCN mappings for builtin modules
FQCN_MAPPINGS = {
    'apt': 'ansible.builtin.apt',
    'copy': 'ansible.builtin.copy',
    'fetch': 'ansible.builtin.fetch',
    'file': 'ansible.builtin.file',
    'get_url': 'ansible.builtin.get_url',
    'lineinfile': 'ansible.builtin.lineinfile',
    'replace': 'ansible.builtin.replace',
    'shell': 'ansible.builtin.shell',
    'systemd': 'ansible.builtin.systemd',
    'template': 'ansible.builtin.template',
    'wait_for': 'ansible.builtin.wait_for',
    'modprobe': 'community.general.modprobe',
    'sysctl': 'ansible.posix.sysctl',
    'timezone': 'community.general.timezone',
    'ufw': 'community.general.ufw',
}

# Truthy value mappings
TRUTHY_MAPPINGS = {
    'yes': 'true',
    'no': 'false',
    'Yes': 'true',
    'No': 'false',
    'YES': 'true',
    'NO': 'false',
}


def fix_fqcn(content):
    """Replace short module names with FQCN."""
    lines = content.split('\n')
    modified = False
    
    for i, line in enumerate(lines):
        # Match task lines like "  apt:" or "    - apt:"
        for short_name, fqcn in FQCN_MAPPINGS.items():
            # Pattern: spaces followed by module name and colon
            pattern = r'^(\s+(?:-\s+)?)(' + re.escape(short_name) + r':)'
            match = re.match(pattern, line)
            if match:
                indent = match.group(1)
                lines[i] = f"{indent}{fqcn}:"
                modified = True
                print(f"  Line {i+1}: {short_name} -> {fqcn}")
    
    return '\n'.join(lines), modified


def fix_truthy_values(content):
    """Replace yes/no with true/false."""
    lines = content.split('\n')
    modified = False
    
    for i, line in enumerate(lines):
        # Match lines like "  update_cache: yes" or "  enabled: no"
        for old_val, new_val in TRUTHY_MAPPINGS.items():
            # Pattern: key: yes/no (with optional spaces and comments)
            pattern = r'^(\s+\w+:\s+)(' + re.escape(old_val) + r')(\s*(?:#.*)?$)'
            match = re.match(pattern, line)
            if match:
                before = match.group(1)
                after = match.group(3) if match.group(3) else ''
                lines[i] = f"{before}{new_val}{after}"
                modified = True
                print(f"  Line {i+1}: {old_val} -> {new_val}")
    
    return '\n'.join(lines), modified


def fix_brace_spacing(content):
    """Fix too many spaces inside braces."""
    # Pattern: {{ spaces... }} should be {{...}}
    fixed = re.sub(r'\{\{\s+([^}]+?)\s+\}\}', r'{{\1}}', content)
    return fixed, fixed != content


def fix_trailing_spaces(content):
    """Remove trailing spaces."""
    lines = content.split('\n')
    fixed_lines = [line.rstrip() for line in lines]
    return '\n'.join(fixed_lines), lines != fixed_lines


def fix_line_endings(content):
    """Ensure Unix line endings."""
    fixed = content.replace('\r\n', '\n').replace('\r', '\n')
    return fixed, fixed != content


def process_file(filepath):
    """Process a single YAML file."""
    print(f"\nProcessing: {filepath}")
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original = content
    
    # Apply fixes
    content, mod1 = fix_line_endings(content)
    content, mod2 = fix_fqcn(content)
    content, mod3 = fix_truthy_values(content)
    content, mod4 = fix_brace_spacing(content)
    content, mod5 = fix_trailing_spaces(content)
    
    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"  ✅ Fixed")
        return True
    else:
        print(f"  ⏭️  No changes needed")
        return False


def main():
    """Main function."""
    base_dir = Path('/workspaces/kubernetes-azure')
    
    # Find all YAML files in ansible directory
    yaml_files = []
    ansible_dir = base_dir / 'ansible'
    if ansible_dir.exists():
        yaml_files.extend(ansible_dir.rglob('*.yml'))
        yaml_files.extend(ansible_dir.rglob('*.yaml'))
    
    # Add azure.yaml
    azure_yaml = base_dir / 'azure.yaml'
    if azure_yaml.exists():
        yaml_files.append(azure_yaml)
    
    # Add terraform/azure.yaml
    terraform_azure = base_dir / 'terraform' / 'azure.yaml'
    if terraform_azure.exists():
        yaml_files.append(terraform_azure)
    
    fixed_count = 0
    for filepath in sorted(yaml_files):
        if process_file(filepath):
            fixed_count += 1
    
    print(f"\n{'='*60}")
    print(f"Fixed {fixed_count} of {len(yaml_files)} files")
    print(f"{'='*60}")


if __name__ == '__main__':
    main()
