# Quick Start: Adding Inline Edit Mode to Any Screen

## ✅ Already Implemented
These screens already have the edit toggle:
- ✓ SSHER Stacked Screen
- ✓ Settings Screen
- ✓ Program Basics Screen
- ✓ Team Management Screen

## 📝 Quick Implementation (3 Steps)

### Step 1: Add Imports (at top of file)
```dart
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/content_text.dart';
```

### Step 2: Add Toggle to Stack (in build method)
```dart
return Scaffold(
  body: Stack(
    children: [
      // ... existing content
      const KazAiChatBubble(),
      const AdminEditToggle(),  // ← ADD THIS
    ],
  ),
);
```

### Step 3: Make Text Editable (replace Text widgets)
```dart
// Before:
Text('My Heading', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))

// After:
EditableContentText(
  contentKey: 'page_section_heading',  // unique snake_case key
  fallback: 'My Heading',              // default text
  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
  category: 'general',                 // optional: for organization
)
```

## 🎯 Content Key Naming
Format: `{page}_{section}_{element}`

Examples:
- `execution_plan_title`
- `risk_assessment_intro_text`  
- `cost_analysis_summary_heading`
- `team_roles_description_paragraph`

## 👤 Add Your Admin Email
Edit `/lib/widgets/admin_edit_toggle.dart`:
```dart
const List<String> _adminEmails = [
  'admin@example.com',
  'YOUR_EMAIL@domain.com',  // ← ADD HERE
];
```

## 🚀 Automated Update (Optional)
Run the provided script to update all remaining screens automatically:
```bash
chmod +x update_all_screens.sh
./update_all_screens.sh
```

This will:
- ✓ Add imports to all screen files
- ✓ Add AdminEditToggle after KazAiChatBubble
- ✓ Skip files already updated
- ✓ Create backups before modifying

## 📚 Full Documentation
See `ADMIN_EDIT_MODE_GUIDE.md` for complete details, troubleshooting, and best practices.
