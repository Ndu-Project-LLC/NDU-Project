# Admin Instance Deployment Guide

This guide explains how to deploy the admin instance of NDU Project to `admin.nduproject.com` while keeping the main user app on `nduproject.com`.

## Architecture Overview

The project uses a **single codebase with two entry points**:
- `lib/main.dart` → User application (nduproject.com)
- `lib/main_admin.dart` → Admin application (admin.nduproject.com)

Both apps share:
- Firebase backend (Auth, Firestore)
- Models, services, and utilities
- Theme and styling

## Prerequisites

1. Firebase project set up
2. Firebase CLI installed (`npm install -g firebase-tools`)
3. Domain configured (admin.nduproject.com)
4. Flutter installed

## Local Development

### Run User App
```bash
flutter run -d chrome --target=lib/main.dart
```

### Run Admin App
```bash
flutter run -d chrome --target=lib/main_admin.dart
```

## Building for Production

### Build User App
```bash
flutter build web --target=lib/main.dart --release
# Output: build/web/
```

### Build Admin App
```bash
flutter build web --target=lib/main_admin.dart --release --output=build/admin_web/
# Output: build/admin_web/
```

## Firebase Hosting Setup

### 1. Initialize Firebase Hosting (if not already done)

```bash
firebase init hosting
```

### 2. Configure Multiple Sites

In your Firebase Console:
1. Go to Hosting section
2. Click "Add another site"
3. Create a site named `ndu-project-admin` (or your preferred name)
4. Note both site names:
   - Main site: `ndu-project` (example)
   - Admin site: `ndu-project-admin`

### 3. Update `firebase.json`

Replace your `firebase.json` with:

```json
{
  "hosting": [
    {
      "target": "main",
      "public": "build/web",
      "ignore": [
        "firebase.json",
        "**/.*",
        "**/node_modules/**"
      ],
      "rewrites": [
        {
          "source": "**",
          "destination": "/index.html"
        }
      ]
    },
    {
      "target": "admin",
      "public": "build/admin_web",
      "ignore": [
        "firebase.json",
        "**/.*",
        "**/node_modules/**"
      ],
      "rewrites": [
        {
          "source": "**",
          "destination": "/index.html"
        }
      ]
    }
  ]
}
```

### 4. Configure Hosting Targets

Link your targets to Firebase sites:

```bash
# Link main site
firebase target:apply hosting main ndu-project

# Link admin site
firebase target:apply hosting admin ndu-project-admin
```

Replace `ndu-project` and `ndu-project-admin` with your actual Firebase site names.

### 5. Update `.firebaserc`

Your `.firebaserc` should look like:

```json
{
  "projects": {
    "default": "your-firebase-project-id"
  },
  "targets": {
    "your-firebase-project-id": {
      "hosting": {
        "main": [
          "ndu-project"
        ],
        "admin": [
          "ndu-project-admin"
        ]
      }
    }
  }
}
```

## Deployment

### Deploy Both Sites

```bash
# Build both apps
flutter build web --target=lib/main.dart --release
flutter build web --target=lib/main_admin.dart --release --output=build/admin_web/

# Deploy to Firebase
firebase deploy --only hosting
```

### Deploy Only User App

```bash
flutter build web --target=lib/main.dart --release
firebase deploy --only hosting:main
```

### Deploy Only Admin App

```bash
flutter build web --target=lib/main_admin.dart --release --output=build/admin_web/
firebase deploy --only hosting:admin
```

## Custom Domain Configuration

### In Firebase Console:

1. **For User App (nduproject.com)**:
   - Go to Hosting → Main site → "Add custom domain"
   - Enter: `nduproject.com`
   - Follow DNS configuration steps

2. **For Admin App (admin.nduproject.com)**:
   - Go to Hosting → Admin site → "Add custom domain"
   - Enter: `admin.nduproject.com`
   - Follow DNS configuration steps

### DNS Records:

You'll need to add DNS records (typically A records or CNAME) as instructed by Firebase.

## Granting Admin Access

Admin access is controlled by the `isAdmin` field in Firestore `users` collection.

### Method 1: Manually via Firebase Console

1. Go to Firestore Database
2. Navigate to `users` collection
3. Find the user document (by uid)
4. Add/Update field: `isAdmin: true`

### Method 2: Programmatically

Create a Firebase Cloud Function to set admin status:

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.setAdminStatus = functions.https.onCall(async (data, context) => {
  // Only existing admins can create new admins
  const callerUid = context.auth.uid;
  const callerDoc = await admin.firestore().collection('users').doc(callerUid).get();
  
  if (!callerDoc.data().isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can set admin status');
  }

  const { uid, isAdmin } = data;
  await admin.firestore().collection('users').doc(uid).update({ isAdmin });
  
  return { success: true };
});
```

## Automation Script (Optional)

Create a `deploy.sh` script:

```bash
#!/bin/bash

echo "Building user app..."
flutter build web --target=lib/main.dart --release

echo "Building admin app..."
flutter build web --target=lib/main_admin.dart --release --output=build/admin_web/

echo "Deploying to Firebase..."
firebase deploy --only hosting

echo "Deployment complete!"
echo "User app: https://nduproject.com"
echo "Admin app: https://admin.nduproject.com"
```

Make it executable:
```bash
chmod +x deploy.sh
```

Run it:
```bash
./deploy.sh
```

## Security Considerations

1. **Admin Access Control**: The admin app checks user permissions server-side via Firestore
2. **Firestore Rules**: Ensure your Firestore rules restrict admin operations:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId || isAdmin();
    }
    
    // Helper function
    function isAdmin() {
      return request.auth != null && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }
    
    // Projects - only admins can read all projects
    match /projects/{projectId} {
      allow read: if request.auth.uid == resource.data.ownerId || isAdmin();
      allow create: if request.auth != null;
      allow update, delete: if request.auth.uid == resource.data.ownerId || isAdmin();
    }
    
    // Content - only admins can modify
    match /content/{contentId} {
      allow read: if request.auth != null;
      allow write: if isAdmin();
    }
  }
}
```

## Troubleshooting

### Build Output Directory Issues

If you see files in the wrong directory:
- Ensure `--output` flag is correct
- Clear build cache: `flutter clean && flutter pub get`

### Firebase Deploy Fails

- Check `.firebaserc` has correct project ID
- Verify targets are configured: `firebase target:list`
- Re-authenticate: `firebase login`

### Admin Access Denied

- Verify user document in Firestore has `isAdmin: true`
- Check Firestore rules allow reading user documents
- Clear browser cache and refresh

## Monitoring

Monitor both deployments:
```bash
firebase hosting:sites:list
```

View logs:
```bash
firebase hosting:logs
```

## Rollback

If you need to rollback a deployment:
```bash
firebase hosting:rollback
```

---

For questions or issues, refer to:
- [Firebase Hosting Documentation](https://firebase.google.com/docs/hosting)
- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)
