#!/usr/bin/env python3
"""
Improved markdown fixer - handles code fences and line wrapping better
"""

import re
from pathlib import Path


def fix_code_fence_blanks(content):
    """Add blank lines before/after code fences and add language spec"""
    lines = content.split('\n')
    result = []
    in_fence = False
    fence_line_num = -1
    
    for i, line in enumerate(lines):
        is_fence = line.strip().startswith('```')
        prev_line = lines[i-1] if i > 0 else ''
        next_line = lines[i+1] if i < len(lines)-1 else ''
        
        if is_fence:
            if not in_fence:
                # Opening fence
                # Add blank line before if needed
                if i > 0 and prev_line.strip() != '':
                    if result and result[-1] != '':
                        result.append('')
                
                # Add language if missing (use 'text' as default)
                if line.strip() == '```':
                    result.append('```text')
                else:
                    result.append(line)
                
                in_fence = True
                fence_line_num = i
            else:
                # Closing fence
                result.append(line)
                
                # Add blank line after if needed
                if i < len(lines)-1 and next_line.strip() != '':
                    result.append('')
                
                in_fence = False
        else:
            result.append(line)
    
    return '\n'.join(result)


def wrap_bare_urls_careful(content):
    """Wrap bare URLs in angle brackets, but be careful with markdown links"""
    lines = content.split('\n')
    result = []
    in_code_block = False
    
    for line in lines:
        if line.strip().startswith('```'):
            in_code_block = not in_code_block
            result.append(line)
            continue
        
        if in_code_block:
            result.append(line)
            continue
        
        # Find URLs not already in brackets or parentheses
        # Match: https://... but not (https://...) or <https://...> or [text](https://...)
        pattern = r'(?<![(<\[])\b(https?://[^\s\)<>\]]+)(?![>\)\]])'
        
        # Check if we're in a markdown link context
        if '[' in line and '](' in line:
            # Don't modify lines with markdown links
            result.append(line)
        elif line.strip().startswith('- ') and 'http' in line:
            # List items with URLs - be conservative
            result.append(line)
        else:
            # Wrap bare URLs
            modified = re.sub(pattern, r'<\1>', line)
            result.append(modified)
    
    return '\n'.join(result)


def fix_long_lines(content, max_length=120):
    """Try to wrap long lines intelligently"""
    lines = content.split('\n')
    result = []
    in_code_block = False
    
    for line in lines:
        if line.strip().startswith('```'):
            in_code_block = not in_code_block
            result.append(line)
            continue
        
        if in_code_block:
            result.append(line)
            continue
        
        # Skip lines that are likely URLs or special formatting
        if line.strip().startswith('http') or line.strip().startswith('-') or line.strip().startswith('*'):
            result.append(line)
            continue
        
        # If line is too long and contains sentences, try to wrap
        if len(line) > max_length and '. ' in line:
            # Try to break at sentence boundaries
            parts = line.split('. ')
            current = parts[0] + '.'
            for part in parts[1:]:
                if len(current) + len(part) + 2 > max_length:
                    result.append(current)
                    current = part
                else:
                    current += ' ' + part
            if current:
                result.append(current)
        else:
            result.append(line)
    
    return '\n'.join(result)


def process_file(filepath):
    """Process markdown file with improved fixes"""
    print(f"Processing {filepath}...")
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original = content
    
    # Apply fixes
    content = content.rstrip() + '\n'  # Fix EOF
    lines = content.split('\n')
    lines = [line.rstrip() for line in lines]  # Remove trailing spaces
    content = '\n'.join(lines)
    
    # Fix code fences
    content = fix_code_fence_blanks(content)
    
    # Wrap bare URLs (careful)
    content = wrap_bare_urls_careful(content)
    
    # Note: Line length fixing is too risky to automate fully
    
    if content != original:
        backup = str(filepath) + '.bak2'
        with open(backup, 'w', encoding='utf-8') as f:
            f.write(original)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print(f"  ✓ Fixed {filepath}")
        return True
    else:
        print(f"  - No changes")
        return False


def main():
    """Main function"""
    print("🔧 Applying improved markdown fixes...")
    
    # Find markdown files (exclude certain dirs)
    md_files = []
    for root, dirs, files in os.walk('.'):
        dirs[:] = [d for d in dirs if d not in ['.git', '.venv', 'node_modules', '__pycache__', '.terraform']]
        for file in files:
            if file.endswith('.md'):
                md_files.append(Path(root) / file)
    
    fixed = 0
    for filepath in sorted(md_files):
        if process_file(filepath):
            fixed += 1
    
    print(f"\n✅ Fixed {fixed}/{len(md_files)} files")
    print("Run: python3 scripts/check-markdown.py to verify")


if __name__ == '__main__':
    import os
    main()
