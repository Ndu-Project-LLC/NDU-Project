import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/models/user_model.dart';
import 'package:flutter/foundation.dart';

/// Service for managing users in Firestore
class UserService {
  static final _firestore = FirebaseFirestore.instance;
  static final _usersCollection = _firestore.collection('users');

  /// Admin email domains and specific emails
  static const List<String> _adminDomains = ['nduproject.com'];
  static const List<String> _adminEmails = ['chungu424@gmail.com', 'alick@thestackone.com'];

  /// Check if an email should have admin privileges
  static bool isAdminEmail(String email) {
    final emailLower = email.toLowerCase().trim();
    
    // Check specific admin emails
    if (_adminEmails.any((adminEmail) => adminEmail.toLowerCase() == emailLower)) {
      return true;
    }
    
    // Check admin domains
    for (final domain in _adminDomains) {
      if (emailLower.endsWith('@$domain')) {
        return true;
      }
    }
    
    return false;
  }

  /// Create or update user document in Firestore
  static Future<void> createOrUpdateUser(User firebaseUser, {bool? isAdmin}) async {
    try {
      final userDoc = await _usersCollection.doc(firebaseUser.uid).get();
      
      // Auto-detect admin status based on email if not explicitly provided
      final shouldBeAdmin = isAdmin ?? isAdminEmail(firebaseUser.email ?? '');
      
      if (userDoc.exists) {
        // Update existing user
        await _usersCollection.doc(firebaseUser.uid).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'displayName': firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'User',
          'photoUrl': firebaseUser.photoURL,
          'isAdmin': shouldBeAdmin, // Update admin status based on email
        });
      } else {
        // Create new user
        final userModel = UserModel(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          displayName: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'User',
          isAdmin: shouldBeAdmin,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          photoUrl: firebaseUser.photoURL,
        );
        await _usersCollection.doc(firebaseUser.uid).set(userModel.toJson());
      }
    } catch (e) {
      debugPrint('Error creating/updating user: $e');
      rethrow;
    }
  }

  /// Get user model from Firestore
  static Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (doc.exists) {
        return UserModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user: $e');
      return null;
    }
  }

  /// Check if current user is admin
  static Future<bool> isCurrentUserAdmin() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;
      
      // First check if email is in the admin list (always grants access)
      if (isAdminEmail(currentUser.email ?? '')) {
        // Ensure Firestore record is updated
        await createOrUpdateUser(currentUser, isAdmin: true);
        return true;
      }
      
      // Otherwise check Firestore
      final userModel = await getUser(currentUser.uid);
      return userModel?.isAdmin ?? false;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      // Fallback: check email directly
      final currentUser = FirebaseAuth.instance.currentUser;
      return isAdminEmail(currentUser?.email ?? '');
    }
  }

  /// Watch current user's admin status
  static Stream<bool> watchAdminStatus() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return Stream.value(false);
    
    return _usersCollection.doc(currentUser.uid).snapshots().map((doc) {
      if (!doc.exists) return false;
      final user = UserModel.fromJson(doc.data()!);
      return user.isAdmin;
    });
  }

  /// Get all users (admin only)
  static Stream<List<UserModel>> watchAllUsers() {
    return _usersCollection.orderBy('createdAt', descending: true).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => UserModel.fromJson(doc.data())).toList(),
    );
  }

  /// Update user admin status
  static Future<bool> updateUserAdminStatus(String uid, bool isAdmin) async {
    try {
      await _usersCollection.doc(uid).update({'isAdmin': isAdmin});
      return true;
    } catch (e) {
      debugPrint('Error updating admin status: $e');
      return false;
    }
  }

  /// Update user active status
  static Future<bool> updateUserActiveStatus(String uid, bool isActive) async {
    try {
      await _usersCollection.doc(uid).update({'isActive': isActive});
      return true;
    } catch (e) {
      debugPrint('Error updating active status: $e');
      return false;
    }
  }

  /// Delete user (admin only)
  static Future<bool> deleteUser(String uid) async {
    try {
      await _usersCollection.doc(uid).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting user: $e');
      return false;
    }
  }

  /// Get total user count
  static Future<int> getTotalUserCount() async {
    try {
      final snapshot = await _usersCollection.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting user count: $e');
      return 0;
    }
  }

  /// Get active user count
  static Future<int> getActiveUserCount() async {
    try {
      final snapshot = await _usersCollection.where('isActive', isEqualTo: true).count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting active user count: $e');
      return 0;
    }
  }

  /// Get admin user count
  static Future<int> getAdminUserCount() async {
    try {
      final snapshot = await _usersCollection.where('isAdmin', isEqualTo: true).count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting admin user count: $e');
      return 0;
    }
  }

  /// Search users by email or display name
  static Future<List<UserModel>> searchUsers(String query) async {
    try {
      final queryLower = query.toLowerCase().trim();
      
      // Search by email (exact prefix match)
      final emailResults = await _usersCollection
          .where('email', isGreaterThanOrEqualTo: queryLower)
          .where('email', isLessThan: '${queryLower}z')
          .limit(10)
          .get();

      // Get all users and filter by displayName (Firestore doesn't support case-insensitive search)
      final allUsers = await _usersCollection.limit(100).get();
      final nameResults = allUsers.docs
          .map((doc) => UserModel.fromJson(doc.data()))
          .where((user) => 
              user.displayName.toLowerCase().contains(queryLower) ||
              user.email.toLowerCase().contains(queryLower))
          .toList();

      // Combine and deduplicate results
      final emailUserIds = emailResults.docs.map((d) => d.id).toSet();
      final combined = emailResults.docs.map((d) => UserModel.fromJson(d.data())).toList();
      
      for (final user in nameResults) {
        if (!emailUserIds.contains(user.uid)) {
          combined.add(user);
        }
      }

      return combined.take(20).toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }
}
