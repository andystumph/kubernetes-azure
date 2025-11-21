#!/usr/bin/env python3
"""
Quick markdown lint checker - counts common issues
"""

import re
from pathlib import Path


def check_file(filepath):
    """Check a single file for common issues"""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    issues = []
    in_code_block = False
    prev_line = ''
    
    for i, line in enumerate(lines, 1):
        line_rstrip = line.rstrip('\n')
        
        # Check for code fence
        if line_rstrip.startswith('```'):
            in_code_block = not in_code_block
            
            # Check for language specification
            if not in_code_block and line_rstrip == '```':
                issues.append(f"Line {i}: MD040 - Code fence without language")
            
            # Check for blank line before fence (opening)
            if not in_code_block and prev_line.strip() != '':
                if i > 1 and not prev_line.startswith('#'):
                    issues.append(f"Line {i}: MD031 - Missing blank line before code fence")
            
            # Check for blank line after fence (closing)
            if in_code_block and i < len(lines):
                next_line = lines[i] if i < len(lines) else ''
                if next_line.strip() != '':
                    issues.append(f"Line {i}: MD031 - Missing blank line after code fence")
        
        # Check for heading
        if line_rstrip.startswith('#') and ' ' in line_rstrip:
            # Check for blank line before heading
            if i > 1 and prev_line.strip() != '':
                issues.append(f"Line {i}: MD022 - Missing blank line before heading")
            
            # Check for blank line after heading
            if i < len(lines):
                next_line = lines[i] if i < len(lines) else ''
                if next_line.strip() != '' and not next_line.startswith('#'):
                    issues.append(f"Line {i}: MD022 - Missing blank line after heading")
        
        # Check for trailing spaces (excluding list continuations)
        if line_rstrip != line_rstrip.rstrip():
            spaces = len(line_rstrip) - len(line_rstrip.rstrip())
            if spaces not in [2]:  # 2 spaces are allowed for line breaks
                issues.append(f"Line {i}: MD009 - Trailing spaces ({spaces})")
        
        # Check line length
        if len(line_rstrip) > 120 and not in_code_block:
            if not line_rstrip.startswith('http'):  # Skip URL lines
                issues.append(f"Line {i}: MD013 - Line too long ({len(line_rstrip)} > 120)")
        
        # Check for bare URLs
        if not in_code_block:
            urls = re.findall(r'(?<![(<])(https?://[^\s\)>]+)(?![>)])', line)
            for url in urls:
                issues.append(f"Line {i}: MD034 - Bare URL: {url[:50]}...")
        
        prev_line = line_rstrip
    
    # Check EOF
    if lines and lines[-1].endswith('\n\n'):
        issues.append(f"EOF: MD047 - Multiple trailing newlines")
    elif lines and not lines[-1].endswith('\n'):
        issues.append(f"EOF: MD047 - Missing trailing newline")
    
    return issues


def main():
    """Check all markdown files"""
    md_files = list(Path('.').rglob('*.md'))
    # Exclude certain directories
    exclude_dirs = ['.git', 'node_modules', '.venv', '__pycache__', '.terraform']
    md_files = [f for f in md_files if not any(ex in str(f) for ex in exclude_dirs)]
    
    total_issues = 0
    
    for filepath in sorted(md_files):
        issues = check_file(filepath)
        if issues:
            print(f"\n{filepath} ({len(issues)} issues):")
            for issue in issues[:5]:  # Show first 5 issues
                print(f"  {issue}")
            if len(issues) > 5:
                print(f"  ... and {len(issues) - 5} more")
            total_issues += len(issues)
    
    print(f"\n{'='*60}")
    print(f"Total: {total_issues} issues across {len(md_files)} files")
    
    if total_issues == 0:
        print("✅ No issues found!")
        return 0
    else:
        print(f"❌ Found {total_issues} issues")
        return 1


if __name__ == '__main__':
    exit(main())
