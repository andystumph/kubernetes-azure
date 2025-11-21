#!/bin/bash
set -e

# Script to fix common markdown linting issues
# This addresses the most common issues found in CI

echo "🔧 Fixing markdown formatting issues..."

# Function to add blank line after headings where missing
fix_headings_blank_lines() {
    local file="$1"
    echo "  Processing headings in $file..."
    
    # Use perl for more reliable multi-line regex
    perl -i -0pe 's/(^##+ [^\n]+\n)([^\n])/$1\n$2/gm' "$file"
}

# Function to add blank lines around code blocks
fix_code_blocks() {
    local file="$1"
    echo "  Processing code blocks in $file..."
    
    # Add blank line before code blocks if missing
    perl -i -0pe 's/([^\n])\n(```)/\1\n\n\2/gm' "$file"
    
    # Add blank line after code blocks if missing
    perl -i -0pe 's/(```)\n([^\n])(?!```)/\1\n\n\2/gm' "$file"
}

# Function to add blank lines around lists
fix_lists() {
    local file="$1"
    echo "  Processing lists in $file..."
    
    # Add blank line before lists (-, *, 1.)
    perl -i -0pe 's/([^\n])\n([-*]|\d+\.) /\1\n\n\2 /gm' "$file"
    
    # Add blank line after lists
    perl -i -0pe 's/(^[-*]|\d+\.)[^\n]+\n([^\n-*\d])/$1\n\n$2/gm' "$file"
}

# Function to remove trailing spaces
fix_trailing_spaces() {
    local file="$1"
    echo "  Removing trailing spaces in $file..."
    sed -i 's/[[:space:]]*$//' "$file"
}

# Function to ensure single newline at end of file
fix_eof() {
    local file="$1"
    # Remove all trailing newlines and add exactly one
    perl -i -0pe 's/\n+$/\n/' "$file"
}

# Process all markdown files
for file in $(find . -name "*.md" -not -path "./.git/*" -not -path "./node_modules/*"); do
    echo "Processing $file..."
    
    # Make a backup
    cp "$file" "$file.bak"
    
    # Apply fixes
    fix_trailing_spaces "$file"
    # fix_headings_blank_lines "$file"  # Disabled - too aggressive
    # fix_code_blocks "$file"            # Disabled - too aggressive  
    # fix_lists "$file"                  # Disabled - too aggressive
    fix_eof "$file"
    
    # If file is unchanged, remove backup
    if cmp -s "$file" "$file.bak"; then
        rm "$file.bak"
    else
        echo "  ✓ Fixed issues in $file (backup: $file.bak)"
    fi
done

echo "✅ Markdown fix complete!"
echo "⚠️  Note: Auto-fix is conservative. Manual review may be needed."
echo "Run: ./scripts/ci-check.sh to verify remaining issues"
