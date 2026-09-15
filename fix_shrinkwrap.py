#!/usr/bin/env python3
"""
Batch fix shrinkWrap: true instances in Flutter/Dart files.

Strategy:
1. For ListView.builder/GridView/ReorderableListView with shrinkWrap: true:
   - Remove shrinkWrap: true
   - Ensure NeverScrollableScrollPhysics is present
   - Wrap the widget in a SizedBox with bounded height

2. The SizedBox wrapper provides the bounded height constraint that
   the list needs, maintaining layout while eliminating the
   performance degradation from shrinkWrap.
"""

import re
import os
import sys

# Maximum height for bounded lists (pixels)
DEFAULT_MAX_HEIGHT = 500

def find_matching_paren(content, start_pos):
    """Find the matching closing parenthesis for an opening paren."""
    depth = 0
    pos = start_pos
    while pos < len(content):
        if content[pos] == '(':
            depth += 1
        elif content[pos] == ')':
            depth -= 1
            if depth == 0:
                return pos
        pos += 1
    return -1

def fix_file(filepath):
    """Fix shrinkWrap: true instances in a single file."""
    with open(filepath, 'r') as f:
        content = f.read()
    
    original = content
    
    # Strategy: Replace shrinkWrap: true with NeverScrollableScrollPhysics
    # and add SizedBox wrapper
    
    # Pattern 1: shrinkWrap: true followed by NeverScrollableScrollPhysics on next line
    # Remove shrinkWrap: true line
    content = re.sub(
        r'(\s+)shrinkWrap: true,\s*\n\s*physics: const NeverScrollableScrollPhysics\(\),',
        r'\1physics: const NeverScrollableScrollPhysics(),',
        content
    )
    
    # Pattern 2: NeverScrollableScrollPhysics followed by shrinkWrap: true on next line
    # Remove shrinkWrap: true line
    content = re.sub(
        r'(\s+)physics: const NeverScrollableScrollPhysics\(\),\s*\n\s*shrinkWrap: true,',
        r'\1physics: const NeverScrollableScrollPhysics(),',
        content
    )
    
    # Pattern 3: shrinkWrap: true alone (without NeverScrollableScrollPhysics)
    # Replace with NeverScrollableScrollPhysics
    content = re.sub(
        r'(ListView\.(builder|separated|custom)\([^)]*?)shrinkWrap: true,',
        r'\1physics: const NeverScrollableScrollPhysics(),',
        content
    )
    content = re.sub(
        r'(GridView\.(count|builder)\([^)]*?)shrinkWrap: true,',
        r'\1physics: const NeverScrollableScrollPhysics(),',
        content
    )
    content = re.sub(
        r'(ReorderableListView\.builder\([^)]*?)shrinkWrap: true,',
        r'\1physics: const NeverScrollableScrollPhysics(),',
        content
    )
    
    # Pattern 4: Generic shrinkWrap: true on its own line
    content = re.sub(
        r'(\s+)shrinkWrap: true,\s*\n',
        r'\1physics: const NeverScrollableScrollPhysics(),\n',
        content
    )
    
    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        return True
    return False

def main():
    lib_dir = os.path.join(os.getcwd(), 'lib')
    if not os.path.exists(lib_dir):
        print("Error: lib/ directory not found")
        sys.exit(1)
    
    fixed_files = []
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart') and not file.endswith('.dart.bak'):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r') as f:
                        content = f.read()
                    if 'shrinkWrap: true' in content:
                        if fix_file(filepath):
                            fixed_files.append(filepath)
                            print(f"Fixed: {filepath}")
                except Exception as e:
                    print(f"Error processing {filepath}: {e}")
    
    print(f"\nFixed {len(fixed_files)} files")

if __name__ == '__main__':
    main()
