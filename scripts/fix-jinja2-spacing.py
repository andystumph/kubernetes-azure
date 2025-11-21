#!/usr/bin/env python3
"""Fix Jinja2 spacing in Ansible YAML files."""

import re
from pathlib import Path


def fix_jinja2_spacing(content):
    """Add spaces inside Jinja2 braces: {{var}} -> {{ var }}."""
    # Pattern: {{ followed by anything without spaces at edges, then }}
    # This handles: {{var}}, {{func()}}, {{var|filter}}, etc.
    
    def add_spaces(match):
        inner = match.group(1)
        # Don't modify if it already has proper spacing
        if inner.startswith(' ') and inner.endswith(' '):
            return match.group(0)
        # Strip any existing spaces and add proper spacing
        inner = inner.strip()
        return '{{ ' + inner + ' }}'
    
    # Match {{...}} with optional spaces
    pattern = r'\{\{([^}]+)\}\}'
    fixed = re.sub(pattern, add_spaces, content)
    
    return fixed, fixed != content


def process_file(filepath):
    """Process a single YAML file."""
    print(f"Processing: {filepath}")
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    fixed_content, modified = fix_jinja2_spacing(content)
    
    if modified:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(fixed_content)
        print(f"  ✅ Fixed Jinja2 spacing")
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
        yaml_files.extend(ansible_dir.rglob('*.j2'))
    
    fixed_count = 0
    for filepath in sorted(yaml_files):
        if process_file(filepath):
            fixed_count += 1
    
    print(f"\n{'='*60}")
    print(f"Fixed {fixed_count} of {len(yaml_files)} files")
    print(f"{'='*60}")


if __name__ == '__main__':
    main()
