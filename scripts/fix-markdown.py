#!/usr/bin/env python3
"""
Fix common markdown linting issues in the project.
Addresses the 438 errors found in CI.
"""

import re
import os
from pathlib import Path


def fix_blank_lines_around_headings(content):
    """Add blank lines before and after headings"""
    lines = content.split('\n')
    result = []
    
    for i, line in enumerate(lines):
        # Check if current line is a heading
        is_heading = line.strip().startswith('#') and ' ' in line
        prev_line = lines[i-1] if i > 0 else ''
        next_line = lines[i+1] if i < len(lines)-1 else ''
        
        # Add blank line before heading if needed
        if is_heading and i > 0 and prev_line.strip() != '' and prev_line.strip().startswith('#') == False:
            if result and result[-1] != '':
                result.append('')
        
        result.append(line)
        
        # Add blank line after heading if needed
        if is_heading and i < len(lines)-1 and next_line.strip() != '' and not next_line.strip().startswith('#'):
            if next_line.strip() and not next_line.startswith('```'):
                result.append('')
    
    return '\n'.join(result)


def fix_blank_lines_around_fences(content):
    """Add blank lines before and after code fences"""
    lines = content.split('\n')
    result = []
    in_fence = False
    
    for i, line in enumerate(lines):
        is_fence = line.strip().startswith('```')
        prev_line = lines[i-1] if i > 0 else ''
        next_line = lines[i+1] if i < len(lines)-1 else ''
        
        if is_fence:
            if not in_fence:  # Opening fence
                # Add blank line before if needed
                if i > 0 and prev_line.strip() != '':
                    if result and result[-1] != '':
                        result.append('')
                result.append(line)
                in_fence = True
            else:  # Closing fence
                result.append(line)
                # Add blank line after if needed
                if i < len(lines)-1 and next_line.strip() != '':
                    result.append('')
                in_fence = False
        else:
            result.append(line)
    
    return '\n'.join(result)


def fix_blank_lines_around_lists(content):
    """Add blank lines before and after lists"""
    lines = content.split('\n')
    result = []
    in_list = False
    list_pattern = re.compile(r'^(\s*)[-*]|\d+\.\s')
    
    for i, line in enumerate(lines):
        is_list = bool(list_pattern.match(line))
        prev_line = lines[i-1] if i > 0 else ''
        next_line = lines[i+1] if i < len(lines)-1 else ''
        
        if is_list and not in_list:
            # Starting a list - add blank line before if needed
            if i > 0 and prev_line.strip() != '' and not list_pattern.match(prev_line):
                if result and result[-1] != '':
                    result.append('')
            in_list = True
        elif not is_list and in_list:
            # Ending a list
            in_list = False
            # Add blank line before current line if needed
            if line.strip() != '':
                if result and result[-1] != '':
                    result.append('')
        
        result.append(line)
    
    return '\n'.join(result)


def fix_trailing_spaces(content):
    """Remove trailing spaces from lines"""
    lines = content.split('\n')
    return '\n'.join(line.rstrip() for line in lines)


def add_language_to_fences(content):
    """Add 'text' language to fences without language specified"""
    lines = content.split('\n')
    result = []
    
    for line in lines:
        if line.strip() == '```':
            # Check if this is an opening fence (simple heuristic)
            result.append('```text')
        else:
            result.append(line)
    
    return '\n'.join(result)


def fix_eof_newline(content):
    """Ensure file ends with exactly one newline"""
    content = content.rstrip('\n')
    return content + '\n'


def wrap_bare_urls(content):
    """Wrap bare URLs in angle brackets"""
    # Match URLs that are not already in markdown link syntax
    # This is a simple pattern and may need refinement
    pattern = r'(?<!\(|\[|<)(https?://[^\s\)]+)(?!\)|]|>)'
    return re.sub(pattern, r'<\1>', content)


def fix_line_length(content, max_length=120):
    """Break long lines (best effort - manual review recommended)"""
    # This is complex and error-prone, so we'll skip auto-fix
    # Manual review is better for line length issues
    return content


def process_markdown_file(filepath):
    """Process a single markdown file"""
    print(f"Processing {filepath}...")
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original = content
    
    # Apply fixes in order
    content = fix_trailing_spaces(content)
    content = fix_blank_lines_around_headings(content)
    content = fix_blank_lines_around_fences(content)
    content = fix_blank_lines_around_lists(content)
    # content = add_language_to_fences(content)  # Can break existing code blocks
    # content = wrap_bare_urls(content)  # Can break existing links
    content = fix_eof_newline(content)
    
    if content != original:
        # Backup original
        backup_path = str(filepath) + '.bak'
        with open(backup_path, 'w', encoding='utf-8') as f:
            f.write(original)
        
        # Write fixed content
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print(f"  ✓ Fixed {filepath} (backup: {backup_path})")
        return True
    else:
        print(f"  - No changes needed for {filepath}")
        return False


def main():
    """Main function to process all markdown files"""
    print("🔧 Fixing markdown formatting issues...")
    
    # Find all markdown files
    md_files = []
    for root, dirs, files in os.walk('.'):
        # Skip certain directories
        dirs[:] = [d for d in dirs if d not in ['.git', 'node_modules', '.venv', '__pycache__']]
        
        for file in files:
            if file.endswith('.md'):
                md_files.append(Path(root) / file)
    
    fixed_count = 0
    for filepath in sorted(md_files):
        if process_markdown_file(filepath):
            fixed_count += 1
    
    print(f"\n✅ Processed {len(md_files)} files, fixed {fixed_count} files")
    print("⚠️  Note: Some issues (line length, bare URLs) require manual review")
    print("Run: ./scripts/ci-check.sh to verify remaining issues")


if __name__ == '__main__':
    main()
