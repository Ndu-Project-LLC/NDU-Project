#!/bin/bash

# Script to add AdminEditToggle to all screen files
# This script adds the necessary imports and widget to each screen

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "Starting batch update of screen files..."
echo ""

# Counter for statistics
processed=0
skipped=0
errors=0

# List of screens to skip (auth screens, landing, etc.)
skip_screens=(
  "auth_wrapper.dart"
  "landing_screen.dart"
  "sign_in_screen.dart"
  "create_account_screen.dart"
  "admin_content_screen.dart"
  "ssher_stacked_screen.dart"
  "settings_screen.dart"
  "team_management_screen.dart"
  "program_basics_screen.dart"
)

# Function to check if file should be skipped
should_skip() {
  local file="$1"
  local basename=$(basename "$file")
  
  for skip in "${skip_screens[@]}"; do
    if [ "$basename" == "$skip" ]; then
      return 0
    fi
  done
  return 1
}

# Function to check if file already has AdminEditToggle
has_admin_toggle() {
  local file="$1"
  grep -q "AdminEditToggle" "$file"
  return $?
}

# Function to process a single file
process_file() {
  local file="$1"
  local basename=$(basename "$file")
  
  echo -n "Processing: $basename ... "
  
  # Check if file already has AdminEditToggle
  if has_admin_toggle "$file"; then
    echo -e "${YELLOW}SKIP${NC} (already has AdminEditToggle)"
    ((skipped++))
    return 0
  fi
  
  # Check if file has KazAiChatBubble (indicator of Stack structure)
  if ! grep -q "const KazAiChatBubble()" "$file"; then
    echo -e "${YELLOW}SKIP${NC} (no KazAiChatBubble found)"
    ((skipped++))
    return 0
  fi
  
  # Create backup
  cp "$file" "$file.bak"
  
  # Step 1: Add imports after the last import statement
  # Find the last line that starts with 'import'
  last_import_line=$(grep -n "^import " "$file" | tail -1 | cut -d: -f1)
  
  if [ -z "$last_import_line" ]; then
    echo -e "${RED}ERROR${NC} (no imports found)"
    rm "$file.bak"
    ((errors++))
    return 1
  fi
  
  # Check if imports already exist
  has_admin_import=$(grep -c "admin_edit_toggle.dart" "$file")
  has_content_import=$(grep -c "content_text.dart" "$file")
  
  # Add imports if needed
  if [ "$has_admin_import" -eq 0 ] || [ "$has_content_import" -eq 0 ]; then
    # Create temp file with imports added
    head -n "$last_import_line" "$file" > "$file.tmp"
    
    if [ "$has_admin_import" -eq 0 ]; then
      echo "import 'package:ndu_project/widgets/admin_edit_toggle.dart';" >> "$file.tmp"
    fi
    
    if [ "$has_content_import" -eq 0 ]; then
      echo "import 'package:ndu_project/widgets/content_text.dart';" >> "$file.tmp"
    fi
    
    tail -n +"$((last_import_line + 1))" "$file" >> "$file.tmp"
    mv "$file.tmp" "$file"
  fi
  
  # Step 2: Add AdminEditToggle after KazAiChatBubble
  # Pattern: Find "const KazAiChatBubble()," followed by whitespace and "],"
  # Replace with: "const KazAiChatBubble(),\n          const AdminEditToggle(),\n        ],"
  
  perl -i -pe 's/(const KazAiChatBubble\(\),)\s*\n(\s*)\],/$1\n$2const AdminEditToggle(),\n$2],/g' "$file"
  
  # Verify the change was made
  if has_admin_toggle "$file"; then
    echo -e "${GREEN}OK${NC}"
    rm "$file.bak"
    ((processed++))
    return 0
  else
    echo -e "${RED}ERROR${NC} (pattern not found, restoring backup)"
    mv "$file.bak" "$file"
    ((errors++))
    return 1
  fi
}

# Main loop - process all screen files
for file in lib/screens/*_screen.dart; do
  if [ -f "$file" ]; then
    if should_skip "$file"; then
      echo "Skipping: $(basename "$file") (in skip list)"
      ((skipped++))
      continue
    fi
    
    process_file "$file"
  fi
done

echo ""
echo "======================================"
echo "Summary:"
echo "  Processed: $processed"
echo "  Skipped: $skipped"
echo "  Errors: $errors"
echo "======================================"
echo ""

if [ $errors -gt 0 ]; then
  echo -e "${YELLOW}Some files had errors. Please review manually.${NC}"
  exit 1
else
  echo -e "${GREEN}All files processed successfully!${NC}"
  exit 0
fi
