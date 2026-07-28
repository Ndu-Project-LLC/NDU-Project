# Admin System Setup Summary

## What Was Created

### 1. User Management System
- **User Model** (`lib/models/user_model.dart`): Tracks users with admin role flag
- **User Service** (`lib/services/user_service.dart`): Manages user CRUD operations and admin permissions

### 2. Admin Application (`lib/main_admin.dart`)
Separate entry point for admin dashboard with:
- **Admin Home Screen**: System overview with stats (total users, active users, admins, projects)
- **User Management Screen**: View, edit, and manage all users and permissions
- **Project Overview Screen**: View all projects across the platform
- **Admin Auth Wrapper**: Restricts access to users with `isAdmin: true`

### 3. Auto-User Creation
Updated `AuthWrapper` to automatically create/update user records in Firestore on sign-in.

### 4. Deployment Infrastructure
- **ADMIN_DEPLOYMENT.md**: Complete deployment guide for two domains
- **deploy.sh**: Automated build and deployment script
- Firebase Hosting configuration for multiple sites

## How It Works

### User Flow (nduproject.com)
1. User signs in → User record created in Firestore `users` collection
2. User accesses normal project management features
3. `isAdmin: false` by default

### Admin Flow (admin.nduproject.com)
1. Admin signs in → Checked against `users` collection
2. If `isAdmin: true` → Access granted to admin dashboard
3. If `isAdmin: false` → Access denied message
4. Admin can:
   - View all users and toggle admin/active status
   - View all projects across the platform
   - Manage app content (existing feature)

## Granting Admin Access

### Option 1: Firebase Console (First Admin)
1. Go to Firestore Database
2. Open `users` collection
3. Find your user document
4. Add field: `isAdmin: true`

### Option 2: Via Admin Dashboard (Subsequent Admins)
1. Sign in to admin dashboard
2. Go to User Management
3. Click "Make Admin" button next to user

## Project Structure

```
lib/
├── main.dart                          # User app entry
├── main_admin.dart                    # Admin app entry (NEW)
├── models/
│   └── user_model.dart               # User model with admin flag (NEW)
├── services/
│   ├── user_service.dart             # User management (NEW)
│   └── project_service.dart          # Updated with admin methods
├── screens/
│   ├── auth_wrapper.dart             # Updated to create users
│   └── admin/                        # Admin screens (NEW)
│       ├── admin_auth_wrapper.dart
│       ├── admin_home_screen.dart
│       ├── admin_users_screen.dart
│       └── admin_projects_screen.dart
└── ...
```

## Local Development

### Run User App
```bash
flutter run -d chrome --target=lib/main.dart
```

### Run Admin App
```bash
flutter run -d chrome --target=lib/main_admin.dart
```

## Deployment

### Quick Deploy (Both Apps)
```bash
chmod +x deploy.sh
./deploy.sh
```

### Manual Deploy
```bash
# Build user app
flutter build web --target=lib/main.dart --release

# Build admin app
flutter build web --target=lib/main_admin.dart --release --output=build/admin_web/

# Deploy to Firebase
firebase deploy --only hosting
```

## Next Steps

1. **Set up Firebase Hosting targets** (see ADMIN_DEPLOYMENT.md)
2. **Grant yourself admin access** via Firestore Console
3. **Configure custom domains** for both sites
4. **Update Firestore security rules** to protect admin operations
5. **Test both deployments**

## Security Notes

- Admin access is controlled by Firestore `users.isAdmin` field
- Admin wrapper validates permissions on every load
- Update Firestore rules to restrict admin operations (see ADMIN_DEPLOYMENT.md)
- Both apps share the same Firebase backend

## Features Available to Admins

✅ View system-wide statistics
✅ Manage all users (view, activate/deactivate, grant/revoke admin)
✅ View all projects across the platform
✅ Edit app content and labels (existing feature)
✅ Full access to user app features

## Benefits of This Architecture

✅ Single codebase - easier maintenance
✅ Shared models and services
✅ Separate deployments and domains
✅ Role-based access control
✅ Scalable for future admin features
