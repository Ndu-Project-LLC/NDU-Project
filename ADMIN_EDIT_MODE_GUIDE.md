# Admin Inline Content Editing System

## Overview
This system allows administrators to edit application text content directly on any page by toggling "Edit Mode". When enabled, all editable text elements become clickable and can be modified in place, with changes automatically synced to Firestore.

## Features
- **Visual Inline Editing**: Click any editable text element to modify it
- **Admin-Only Access**: Only users with admin email addresses can enable edit mode
- **Real-time Sync**: Changes are immediately saved to Firestore and reflected across all users
- **Toggle Control**: Simple floating button to enable/disable edit mode
- **Non-Intrusive**: Edit mode is completely invisible to non-admin users

## Architecture

### Core Components

#### 1. **AppContentProvider** (`lib/providers/app_content_provider.dart`)
- Manages global edit mode state
- Handles content caching and Firestore synchronization
- Provides `isEditMode` flag and `toggleEditMode()` method

#### 2. **EditableContentText** (`lib/widgets/content_text.dart`)
- Replacement for static Text widgets
- Shows as normal text when edit mode is OFF
- Shows with blue border and edit icon when edit mode is ON
- Opens edit dialog on click

#### 3. **AdminEditToggle** (`lib/widgets/admin_edit_toggle.dart`)
- Floating action button visible only to admin users
- Toggles edit mode on/off
- Positioned at bottom-right of screen

#### 4. **AppContentService** & **AppContentModel**
- Handle Firestore operations (CRUD)
- Data model for content items (key, value, category)

## How to Add Edit Mode to a Screen

### Step 1: Add Imports
Add these two imports to your screen file:

```dart
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/content_text.dart';
```

### Step 2: Add AdminEditToggle Widget
Most screens have a Stack widget with KazAiChatBubble. Add AdminEditToggle after it:

```dart
return Scaffold(
  body: Stack(
    children: [
      // ... your page content
      const KazAiChatBubble(),
      const AdminEditToggle(),  // ADD THIS LINE
    ],
  ),
);
```

### Step 3: Replace Static Text with EditableContentText
Find Text widgets that should be editable and replace them:

**Before:**
```dart
Text(
  'SSHER Plan Summary',
  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
)
```

**After:**
```dart
EditableContentText(
  contentKey: 'ssher_plan_summary_title',
  fallback: 'SSHER Plan Summary',
  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  category: 'ssher',
)
```

### Key Parameters for EditableContentText
- `contentKey`: Unique identifier for this content (use snake_case)
- `fallback`: Default text to show if not in Firestore
- `style`: TextStyle to apply (same as normal Text widget)
- `category`: Optional category for organization (e.g., 'ssher', 'execution', 'planning')
- `textAlign`, `maxLines`, `overflow`: Standard Text widget properties

## Example Implementations

### Example 1: SSHER Screen (Complete Implementation)
See `/lib/screens/ssher_stacked_screen.dart` for a fully implemented example with:
- AdminEditToggle added to Stack
- Multiple EditableContentText widgets for titles and descriptions
- Proper content keys and categories

### Example 2: Settings Screen
See `/lib/screens/settings_screen.dart` for implementation on a screen with tabs

### Example 3: Program Basics Screen  
See `/lib/screens/program_basics_screen.dart` for implementation on a simple screen

## Admin Setup

### Adding Admin Users
Edit `/lib/widgets/admin_edit_toggle.dart` and add admin email addresses:

```dart
const List<String> _adminEmails = [
  'admin@example.com',
  'youremail@company.com',  // ADD YOUR EMAIL HERE
  'anotheradmin@company.com',
];
```

**Important**: Restart the app after adding emails for changes to take effect.

## Usage Instructions for Admins

### Enabling Edit Mode
1. Sign in with an admin email address
2. Navigate to any page with editable content
3. Click the blue "Edit Content" button at bottom-right
4. All editable text elements will now show with blue borders

### Editing Content
1. Click any text element with a blue border
2. Edit the text in the dialog that appears
3. Click "Save" to update
4. Changes are immediately visible to all users

### Disabling Edit Mode
1. Click the red "Exit Edit Mode" button at bottom-right
2. All blue borders disappear and normal view resumes

## Content Organization

### Recommended Category Structure
- `general`: App-wide content (welcome messages, etc.)
- `ssher`: SSHER-related content
- `execution`: Execution plan content
- `planning`: Planning phase content
- `initiation`: Initiation phase content
- `team`: Team management content
- `risk`: Risk management content
- `cost`: Cost analysis content

### Content Key Naming Convention
Use descriptive, hierarchical keys:
- `{page}_{section}_{element}`
- Examples:
  - `ssher_plan_summary_title`
  - `ssher_plan_summary_description`
  - `execution_strategy_heading`
  - `team_management_intro_text`

## Firestore Structure

### Collection: `app_content`
Each document contains:
```json
{
  "key": "ssher_plan_summary_title",
  "value": "SSHER Plan Summary",
  "category": "ssher",
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

### Security Rules
Configured in `/firestore.rules`:
- All authenticated users can READ content
- Only authenticated users can WRITE/UPDATE/DELETE content
- (Consider restricting write access to admin users only in production)

## Batch Update Script

A shell script is provided to add AdminEditToggle to all screens automatically:

```bash
chmod +x update_all_screens.sh
./update_all_screens.sh
```

This script will:
- Add necessary imports to all screen files
- Add AdminEditToggle widget after KazAiChatBubble
- Skip files that already have the toggle
- Create backups before modifying

## Troubleshooting

### Edit button not showing
- Verify your email is in the `_adminEmails` list in `admin_edit_toggle.dart`
- Ensure you're signed in with that email
- Restart the app after adding your email

### Content not saving
- Check Firestore rules allow authenticated users to write
- Verify Firebase is properly initialized
- Check browser console for errors

### Content not loading
- Ensure Firestore rules allow reading
- Verify the content provider is initialized in `main.dart`
- Check that `AppContentProvider` is watching content

### Edits not appearing immediately
- Content updates are real-time via Firestore listeners
- If not working, check the `watchContent()` method in AppContentProvider
- Verify network connectivity

## Migration Guide

### From Old Admin Content Screen
The old `/lib/screens/admin_content_screen.dart` can be safely deleted as it's replaced by this inline editing system.

### Updating Existing Content
1. Enable edit mode as an admin
2. Click each text element you want to update
3. First edit creates the Firestore document
4. Subsequent edits update the existing document

## Best Practices

### 1. Use Descriptive Content Keys
Bad: `text1`, `label_a`, `heading`
Good: `ssher_safety_section_title`, `execution_plan_intro_paragraph`

### 2. Keep Fallback Values
Always provide meaningful fallback text that matches the original static text

### 3. Organize by Category
Use consistent category names across related pages

### 4. Don't Over-Edit
Not every text element needs to be editable. Focus on:
- Page titles and headings
- Instructional text
- Descriptions and explanations
- Labels and button text

Avoid making editable:
- Dynamic data from Firestore
- User-generated content
- Form field values
- Calculated/computed text

### 5. Test After Implementation
Always verify:
- Edit mode toggles properly
- Content saves correctly
- Content appears for non-admin users
- Real-time updates work

## Performance Considerations

- Content is cached in AppContentProvider to minimize Firestore reads
- Only admins see the edit toggle, reducing overhead for regular users
- Real-time listeners are efficient and only trigger on actual changes

## Future Enhancements

Potential improvements to consider:
- Rich text editing (bold, italic, links)
- Image upload support
- Bulk import/export of content
- Version history and rollback
- Role-based permissions (super admin, content editor, etc.)
- Preview mode before publishing changes
- Multi-language support

## Support

For issues or questions:
1. Check this guide first
2. Review the example implementations
3. Check Firestore console for data
4. Review app logs for errors
