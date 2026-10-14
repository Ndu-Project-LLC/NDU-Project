#!/usr/bin/env python3
"""
Script to add AdminEditToggle to all screens in the project.
This script:
1. Adds import statements for admin_edit_toggle and content_text
2. Adds AdminEditToggle widget to existing Stack (if present)
3. Skips files that already have AdminEditToggle
"""

import os
import re
from pathlib import Path

# Configuration
SCREENS_DIR = Path("lib/screens")
IMPORT_ADMIN_TOGGLE = "import 'package:ndu_project/widgets/admin_edit_toggle.dart';"
IMPORT_CONTENT_TEXT = "import 'package:ndu_project/widgets/content_text.dart';"
ADMIN_TOGGLE_WIDGET = "            const AdminEditToggle(),"

# Screens to skip (auth screens, wrappers, etc.)
SKIP_SCREENS = [
    'auth_wrapper.dart',
    'landing_screen.dart',
    'sign_in_screen.dart',
    'create_account_screen.dart',
    'admin_content_screen.dart',  # Old admin screen, can be deleted
]

def should_process_file(file_path):
    """Check if file should be processed"""
    file_name = file_path.name
    
    if file_name in SKIP_SCREENS:
        return False
    
    if not file_name.endswith('_screen.dart'):
        return False
        
    return True

def file_has_admin_toggle(content):
    """Check if file already has AdminEditToggle"""
    return 'AdminEditToggle' in content

def add_imports(content):
    """Add necessary imports if not present"""
    lines = content.split('\n')
    
    # Find the last import statement
    last_import_idx = -1
    for i, line in enumerate(lines):
        if line.strip().startswith('import '):
            last_import_idx = i
    
    if last_import_idx == -1:
        return content  # No imports found, skip
    
    # Check if imports already exist
    has_admin_toggle_import = IMPORT_ADMIN_TOGGLE in content
    has_content_text_import = IMPORT_CONTENT_TEXT in content
    
    # Add imports after last import
    if not has_admin_toggle_import or not has_content_text_import:
        insert_idx = last_import_idx + 1
        if not has_admin_toggle_import:
            lines.insert(insert_idx, IMPORT_ADMIN_TOGGLE)
            insert_idx += 1
        if not has_content_text_import:
            lines.insert(insert_idx, IMPORT_CONTENT_TEXT)
    
    return '\n'.join(lines)

def add_admin_toggle_to_stack(content):
    """Add AdminEditToggle to existing Stack widget"""
    # Pattern to find Stack with KazAiChatBubble
    # We want to add AdminEditToggle after KazAiChatBubble
    
    # Look for the pattern: const KazAiChatBubble(),
    # followed by whitespace and closing bracket ]
    pattern = r'(const KazAiChatBubble\(\),)\s*\n(\s*)\],'
    
    replacement = r'\1\n\2const AdminEditToggle(),\n\2],'
    
    modified_content = re.sub(pattern, replacement, content)
    
    # If pattern not found, try alternative pattern without comma
    if modified_content == content:
        pattern = r'(const KazAiChatBubble\(\))\s*\n(\s*)\],'
        replacement = r'\1,\n\2const AdminEditToggle(),\n\2],'
        modified_content = re.sub(pattern, replacement, content)
    
    return modified_content

def process_file(file_path):
    """Process a single screen file"""
    print(f"Processing: {file_path.name}")
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check if already has AdminEditToggle
    if file_has_admin_toggle(content):
        print(f"  ✓ Already has AdminEditToggle, skipping")
        return False
    
    # Add imports
    content = add_imports(content)
    
    # Add AdminEditToggle to Stack
    original_content = content
    content = add_admin_toggle_to_stack(content)
    
    if content == original_content:
        print(f"  ⚠ Could not find Stack with KazAiChatBubble pattern")
        return False
    
    # Write back
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"  ✓ Added AdminEditToggle")
    return True

def main():
    """Main function"""
    if not SCREENS_DIR.exists():
        print(f"Error: {SCREENS_DIR} not found")
        return
    
    processed = 0
    skipped = 0
    errors = 0
    
    screen_files = sorted(SCREENS_DIR.glob('*_screen.dart'))
    
    print(f"Found {len(screen_files)} screen files")
    print()
    
    for file_path in screen_files:
        if not should_process_file(file_path):
            print(f"Skipping: {file_path.name}")
            skipped += 1
            continue
        
        try:
            if process_file(file_path):
                processed += 1
            else:
                skipped += 1
        except Exception as e:
            print(f"  ✗ Error: {e}")
            errors += 1
        
        print()
    
    print("=" * 60)
    print(f"Summary:")
    print(f"  Processed: {processed}")
    print(f"  Skipped: {skipped}")
    print(f"  Errors: {errors}")
    print("=" * 60)

if __name__ == '__main__':
    main()
