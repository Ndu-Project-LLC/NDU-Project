# Firebase Deployment Instructions

## ✅ Project Configuration Fixed

The Firebase project has been configured:
- **Project ID**: `ndu-d3f60`
- **Active Project**: Set via `.firebaserc` file

## 🚀 Deploy Firestore Rules

### Step 1: Verify Project is Active
```bash
firebase use
```
Should show: `Now using project ndu-d3f60`

### Step 2: Deploy Firestore Rules
```bash
firebase deploy --only firestore:rules
```

### Step 3: Deploy Firestore Indexes (if needed)
```bash
firebase deploy --only firestore:indexes
```

### Step 4: Deploy Functions (if needed)
```bash
firebase deploy --only functions
```

## ⚠️ Important Notes

1. **Firestore API**: If you get an error about Firestore API not being enabled:
   - Go to Firebase Console: https://console.firebase.google.com/project/ndu-d3f60
   - Navigate to Firestore Database
   - The API will be automatically enabled when you create your first database

2. **Authentication**: Make sure you're logged in:
   ```bash
   firebase login
   ```

3. **Verify Deployment**: After deploying rules, check Firebase Console > Firestore Database > Rules to verify they're active.

## 📋 Updated Firestore Rules

The rules now include access for all new subcollections:
- `execution_tools`, `execution_issues`, `execution_enabling_works`, `execution_change_requests`
- `vendors`, `contracts`
- `ops_members`, `ops_checklist`
- `agile_stories`
- `salvage_team_members`, `salvage_inventory`, `salvage_disposal`
- `tool_integrations`

All authenticated users can read/write these subcollections under their projects.

## ✅ Testing After Deployment

1. Open the app and sign in
2. Create or open a project
3. Navigate to Execution Plan screen
4. Try adding a tool/enabling work/issue
5. Verify data appears in Firestore Console
6. Test editing and deleting
