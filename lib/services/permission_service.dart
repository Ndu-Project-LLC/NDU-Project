import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/models/user_role.dart';

/// World-class permission service for role-based access control
/// Handles all authorization checks and user role management
class PermissionService {
  PermissionService._();

  static final PermissionService instance = PermissionService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for user roles to reduce Firestore reads
  final Map<String, UserRoleAssignment> _roleCache = {};
  final Map<String, UserProfile> _profileCache = {};

  /// Stream of current user's role assignment
  Stream<UserRoleAssignment?> get currentUserRoleStream {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(null);

    return _firestore
        .collection('user_roles')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists
            ? UserRoleAssignment.fromMap(doc.data()!)
            : _createDefaultRole(userId));
  }

  /// Stream of user profile
  Stream<UserProfile?> get userProfileStream {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserProfile.fromMap(doc.data()!) : null);
  }

  /// Get current user's role assignment (cached)
  Future<UserRoleAssignment?> getCurrentUserRole() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    if (_roleCache.containsKey(userId)) {
      final cached = _roleCache[userId]!;
      // Check if cache is still valid (not expired)
      if (cached.expiresAt == null || DateTime.now().isBefore(cached.expiresAt!)) {
        return cached;
      }
    }

    final doc = await _firestore.collection('user_roles').doc(userId).get();
    final role = doc.exists
        ? UserRoleAssignment.fromMap(doc.data()!)
        : _createDefaultRole(userId);

    _roleCache[userId] = role;
  
    return role;
  }

  /// Get current user's profile (cached)
  Future<UserProfile?> getCurrentUserProfile() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    if (_profileCache.containsKey(userId)) {
      return _profileCache[userId];
    }

    final doc = await _firestore.collection('users').doc(userId).get();
    final profile = doc.exists ? UserProfile.fromMap(doc.data()!) : null;

    if (profile != null) {
      _profileCache[userId] = profile;
    }

    return profile;
  }

  /// Check if current user has a specific permission
  Future<bool> hasPermission(Permission permission) async {
    final role = await getCurrentUserRole();
    return role?.hasPermission(permission) ?? false;
  }

  /// Check if current user has any of the specified permissions
  Future<bool> hasAnyPermission(List<Permission> permissions) async {
    final role = await getCurrentUserRole();
    if (role == null) return false;

    return permissions.any((p) => role.hasPermission(p));
  }

  /// Check if current user has all of the specified permissions
  Future<bool> hasAllPermissions(List<Permission> permissions) async {
    final role = await getCurrentUserRole();
    if (role == null) return false;

    return permissions.every((p) => role.hasPermission(p));
  }

  /// Check if current user can access a specific project
  Future<bool> canAccessProject(String projectId) async {
    final role = await getCurrentUserRole();
    if (role == null) return false;

    // Owners and admins can access all projects
    if (role.siteRole == SiteRole.owner ||
        role.siteRole == SiteRole.admin) {
      return true;
    }

    return role.getProjectAccess(projectId) != ResourceAccessLevel.none;
  }

  /// Check if current user can edit a specific project
  Future<bool> canEditProject(String projectId) async {
    final role = await getCurrentUserRole();
    if (role == null) return false;

    // Owners and admins can edit all projects
    if (role.siteRole == SiteRole.owner ||
        role.siteRole == SiteRole.admin) {
      return true;
    }

    return role.canEditProject(projectId);
  }

  /// Check if current user can delete a specific project
  Future<bool> canDeleteProject(String projectId) async {
    final role = await getCurrentUserRole();
    if (role == null) return false;

    return role.canDeleteProject(projectId);
  }

  /// Get current user's site role
  Future<SiteRole> getCurrentSiteRole() async {
    final role = await getCurrentUserRole();
    return role?.siteRole ?? SiteRole.guest;
  }

  /// Check if current user is at least an admin
  Future<bool> isAdminOrHigher() async {
    final role = await getCurrentSiteRole();
    return role.level >= SiteRole.admin.level;
  }

  /// Check if current user is an owner
  Future<bool> isOwner() async {
    final role = await getCurrentSiteRole();
    return role == SiteRole.owner;
  }

  /// Check if current user is a guest (read-only)
  Future<bool> isGuest() async {
    final role = await getCurrentSiteRole();
    return role == SiteRole.guest;
  }

  /// Assign a role to a user (Admin/Owner only)
  Future<void> assignUserRole({
    required String userId,
    required SiteRole role,
    String? assignedBy,
    DateTime? expiresAt,
    Map<String, ResourceAccessLevel>? projectAccess,
    Map<String, ResourceAccessLevel>? programAccess,
    Map<String, ResourceAccessLevel>? portfolioAccess,
    List<Permission>? customPermissions,
  }) async {
    final currentRole = await getCurrentUserRole();
    if (currentRole == null) {
      throw Exception('Not authenticated');
    }

    // Only owners can assign owner role
    if (role == SiteRole.owner && currentRole.siteRole != SiteRole.owner) {
      throw Exception('Only owners can assign owner role');
    }

    // Only admins and above can assign roles
    if (currentRole.siteRole.level < SiteRole.admin.level) {
      throw Exception('Insufficient permissions to assign roles');
    }

    // Cannot assign a role higher than your own
    if (role.level > currentRole.siteRole.level) {
      throw Exception('Cannot assign a role higher than your own');
    }

    final assignment = UserRoleAssignment(
      userId: userId,
      siteRole: role,
      assignedBy: assignedBy ?? _auth.currentUser?.uid,
      assignedAt: DateTime.now(),
      expiresAt: expiresAt,
      projectAccess: projectAccess ?? {},
      programAccess: programAccess ?? {},
      portfolioAccess: portfolioAccess ?? {},
      customPermissions: customPermissions ?? [],
    );

    await _firestore
        .collection('user_roles')
        .doc(userId)
        .set(assignment.toMap(), SetOptions(merge: true));

    // Update the user's profile as well
    await _firestore.collection('users').doc(userId).update({
      'siteRole': role.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update cache
    _roleCache[userId] = assignment;
  }

  /// Grant project access to a user
  Future<void> grantProjectAccess({
    required String userId,
    required String projectId,
    required ResourceAccessLevel accessLevel,
  }) async {
    final currentRole = await getCurrentUserRole();
    if (currentRole == null) {
      throw Exception('Not authenticated');
    }

    // Must be admin or above to grant access
    if (currentRole.siteRole.level < SiteRole.admin.level) {
      throw Exception('Insufficient permissions');
    }

    await _firestore.collection('user_roles').doc(userId).set({
      'projectAccess.$projectId': accessLevel.name,
    }, SetOptions(merge: true));

    // Invalidate cache
    _roleCache.remove(userId);
  }

  /// Revoke project access from a user
  Future<void> revokeProjectAccess({
    required String userId,
    required String projectId,
  }) async {
    final currentRole = await getCurrentUserRole();
    if (currentRole == null) {
      throw Exception('Not authenticated');
    }

    // Must be admin or above to revoke access
    if (currentRole.siteRole.level < SiteRole.admin.level) {
      throw Exception('Insufficient permissions');
    }

    await _firestore.collection('user_roles').doc(userId).update({
      'projectAccess.$projectId': FieldValue.delete(),
    });

    // Invalidate cache
    _roleCache.remove(userId);
  }

  /// Update user profile
  Future<void> updateUserProfile(UserProfile profile) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('Not authenticated');
    }

    // Can only update your own profile unless you're admin
    final currentRole = await getCurrentUserRole();
    if (profile.id != currentUserId &&
        (currentRole?.siteRole.level ?? 0) < SiteRole.admin.level) {
      throw Exception('Insufficient permissions');
    }

    await _firestore.collection('users').doc(profile.id).update({
      'displayName': profile.displayName,
      'phoneNumber': profile.phoneNumber,
      'department': profile.department,
      'jobTitle': profile.jobTitle,
      'organization': profile.organization,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Invalidate cache
    _profileCache.remove(profile.id);
  }

  /// Get all users with their roles (Admin/Owner only)
  Future<List<UserProfile>> getAllUsers() async {
    final currentRole = await getCurrentUserRole();
    if (currentRole == null ||
        currentRole.siteRole.level < SiteRole.admin.level) {
      throw Exception('Insufficient permissions');
    }

    final snapshot = await _firestore
        .collection('users')
        .orderBy('displayName')
        .get();

    return snapshot.docs
        .map((doc) => UserProfile.fromMap(doc.data()))
        .toList();
  }

  /// Get users by role
  Future<List<UserProfile>> getUsersByRole(SiteRole role) async {
    final currentRole = await getCurrentUserRole();
    if (currentRole == null ||
        currentRole.siteRole.level < SiteRole.admin.level) {
      throw Exception('Insufficient permissions');
    }

    final snapshot = await _firestore
        .collection('users')
        .where('siteRole', isEqualTo: role.name)
        .orderBy('displayName')
        .get();

    return snapshot.docs
        .map((doc) => UserProfile.fromMap(doc.data()))
        .toList();
  }

  /// Search users by name or email
  Future<List<UserProfile>> searchUsers(String query) async {
    final currentRole = await getCurrentUserRole();
    if (currentRole == null ||
        currentRole.siteRole.level < SiteRole.admin.level) {
      throw Exception('Insufficient permissions');
    }

    // Simple search - in production, use a proper search service
    final snapshot = await _firestore
        .collection('users')
        .orderBy('displayName')
        .limit(20)
        .get();

    final queryLower = query.toLowerCase();
    return snapshot.docs
        .map((doc) => UserProfile.fromMap(doc.data()))
        .where((user) =>
            user.displayName.toLowerCase().contains(queryLower) ||
            user.email.toLowerCase().contains(queryLower))
        .toList();
  }

  /// Deactivate a user account (Admin/Owner only)
  Future<void> deactivateUser(String userId) async {
    final currentRole = await getCurrentUserRole();
    if (currentRole == null ||
        currentRole.siteRole.level < SiteRole.admin.level) {
      throw Exception('Insufficient permissions');
    }

    await _firestore.collection('users').doc(userId).update({
      'isActive': false,
      'deactivatedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('user_roles').doc(userId).update({
      'isActive': false,
    });

    // Invalidate cache
    _roleCache.remove(userId);
    _profileCache.remove(userId);
  }

  /// Reactivate a user account (Admin/Owner only)
  Future<void> reactivateUser(String userId) async {
    final currentRole = await getCurrentUserRole();
    if (currentRole == null ||
        currentRole.siteRole.level < SiteRole.admin.level) {
      throw Exception('Insufficient permissions');
    }

    await _firestore.collection('users').doc(userId).update({
      'isActive': true,
      'reactivatedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('user_roles').doc(userId).update({
      'isActive': true,
    });

    // Invalidate cache
    _roleCache.remove(userId);
    _profileCache.remove(userId);
  }

  /// Create default role for a new user
  UserRoleAssignment _createDefaultRole(String userId) {
    return UserRoleAssignment(
      userId: userId,
      siteRole: SiteRole.user,
      assignedAt: DateTime.now(),
    );
  }

  /// Clear all caches
  void clearCache() {
    _roleCache.clear();
    _profileCache.clear();
  }

  /// Invalidate cache for a specific user
  void invalidateUserCache(String userId) {
    _roleCache.remove(userId);
    _profileCache.remove(userId);
  }

  // Stream builders for reactive UI

  /// Stream all users (for admin panel)
  Stream<List<UserProfile>> getAllUsersStream() {
    return _firestore
        .collection('users')
        .orderBy('displayName')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserProfile.fromMap(doc.data())).toList());
  }

  /// Stream users by role
  Stream<List<UserProfile>> getUsersByRoleStream(SiteRole role) {
    return _firestore
        .collection('users')
        .where('siteRole', isEqualTo: role.name)
        .orderBy('displayName')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserProfile.fromMap(doc.data())).toList());
  }

  /// Get role assignment for a specific user
  Stream<UserRoleAssignment?> getUserRoleStream(String userId) {
    return _firestore
        .collection('user_roles')
        .doc(userId)
        .snapshots()
        .map((doc) =>
            doc.exists ? UserRoleAssignment.fromMap(doc.data()!) : null);
  }

  /// Update last login timestamp
  Future<void> updateLastLogin() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore.collection('users').doc(userId).update({
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }
}
