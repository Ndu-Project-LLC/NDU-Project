import 'package:flutter/material.dart';

/// User roles for the platform with hierarchical permissions
enum SiteRole {
  /// Full platform control with authority over billing, user management,
  /// permissions, and all system settings
  owner('Owner', 5, Color(0xFFDC2626)),

  /// Manages users, permissions, and system configurations while supporting
  /// overall platform governance. Limited site control beyond projects.
  admin('Admin', 4, Color(0xFF8B5CF6)),

  /// Creates, modifies, and manages content, projects, or data within
  /// assigned areas of the platform. Project, program, and portfolio managers.
  editor('Editor', 3, Color(0xFFFBBF24)),

  /// Engages with the platform to execute tasks, collaborate, and utilize
  /// available features based on assigned access. Regular project users.
  user('User', 2, Color(0xFF10B981)),

  /// Limited, typically view-only access to specific content or areas
  /// without the ability to make changes. For vendors and external parties.
  guest('Guest', 1, Color(0xFF9CA3AF));

  final String displayName;
  final int level;
  final Color color;

  const SiteRole(this.displayName, this.level, this.color);

  /// Convert from string for Firestore storage
  static SiteRole fromString(String value) {
    return SiteRole.values.firstWhere(
      (role) => role.name.toLowerCase() == value.toLowerCase(),
      orElse: () => SiteRole.guest,
    );
  }

  /// Check if this role has higher or equal access than another role
  bool hasHigherOrEqualAccessThan(SiteRole other) {
    return level >= other.level;
  }

  /// Check if this role can manage users
  bool get canManageUsers => level >= SiteRole.admin.level;

  /// Check if this role can manage billing
  bool get canManageBilling => level >= SiteRole.owner.level;

  /// Check if this role can modify site settings
  bool get canModifySiteSettings => level >= SiteRole.admin.level;

  /// Check if this role can edit any content
  bool get canEditContent => level >= SiteRole.editor.level;

  /// Check if this role is read-only
  bool get isReadOnly => this == SiteRole.guest;

  /// Get icon for the role
  String get icon {
    switch (this) {
      case SiteRole.owner:
        return 'assets/icons/crown.svg';
      case SiteRole.admin:
        return 'assets/icons/admin.svg';
      case SiteRole.editor:
        return 'assets/icons/edit.svg';
      case SiteRole.user:
        return 'assets/icons/user.svg';
      case SiteRole.guest:
        return 'assets/icons/guest.svg';
    }
  }
}

/// Granular permissions for specific platform features
enum Permission {
  // Site Management
  manageBilling,
  manageUsers,
  manageRoles,
  manageSiteSettings,
  viewAnalytics,

  // Project Management
  createProject,
  editAnyProject,
  deleteAnyProject,
  archiveProject,

  // Program Management
  createProgram,
  editAnyProgram,
  deleteAnyProgram,

  // Portfolio Management
  createPortfolio,
  editAnyPortfolio,
  deleteAnyPortfolio,

  // Content Management
  createContent,
  editAnyContent,
  deleteAnyContent,
  publishContent,

  // Collaboration
  inviteUsers,
  moderateComments,
  exportData,

  // AI Features
  useAiGeneration,
  useAdvancedAiFeatures;

  /// Get all permissions for a given role
  static Set<Permission> getPermissionsForRole(SiteRole role) {
    switch (role) {
      case SiteRole.owner:
        return Permission.values.toSet();
      case SiteRole.admin:
        return {
          // User management
          Permission.manageUsers,
          Permission.manageRoles,
          Permission.manageSiteSettings,
          Permission.viewAnalytics,

          // Projects/Programs/Portfolios
          Permission.createProject,
          Permission.editAnyProject,
          Permission.deleteAnyProject,
          Permission.archiveProject,
          Permission.createProgram,
          Permission.editAnyProgram,
          Permission.deleteAnyProgram,
          Permission.createPortfolio,
          Permission.editAnyPortfolio,
          Permission.deleteAnyPortfolio,

          // Content
          Permission.createContent,
          Permission.editAnyContent,
          Permission.deleteAnyContent,
          Permission.publishContent,

          // Collaboration
          Permission.inviteUsers,
          Permission.moderateComments,
          Permission.exportData,

          // AI
          Permission.useAiGeneration,
          Permission.useAdvancedAiFeatures,
        };
      case SiteRole.editor:
        return {
          Permission.viewAnalytics,
          Permission.createProject,
          Permission.createProgram,
          Permission.createPortfolio,
          Permission.createContent,
          Permission.editAnyContent,
          Permission.publishContent,
          Permission.inviteUsers,
          Permission.exportData,
          Permission.useAiGeneration,
        };
      case SiteRole.user:
        return {
          Permission.viewAnalytics,
          Permission.createContent,
          Permission.exportData,
          Permission.useAiGeneration,
        };
      case SiteRole.guest:
        return {
          Permission.viewAnalytics,
        };
    }
  }
}

/// Resource-specific access level
enum ResourceAccessLevel {
  /// Full control over the resource
  owner('Owner', 4),

  /// Can edit and manage the resource
  editor('Editor', 3),

  /// Can contribute but not delete
  contributor('Contributor', 2),

  /// Can only view
  viewer('Viewer', 1),

  /// No access
  none('No Access', 0);

  final String displayName;
  final int level;

  const ResourceAccessLevel(this.displayName, this.level);
}

/// User role assignment data model
class UserRoleAssignment {
  const UserRoleAssignment({
    required this.userId,
    required this.siteRole,
    this.projectAccess = const {},
    this.programAccess = const {},
    this.portfolioAccess = const {},
    this.customPermissions = const [],
    this.assignedBy,
    this.assignedAt,
    this.expiresAt,
    this.isActive = true,
  });

  final String userId;
  final SiteRole siteRole;
  final Map<String, ResourceAccessLevel> projectAccess; // projectId -> access level
  final Map<String, ResourceAccessLevel> programAccess; // programId -> access level
  final Map<String, ResourceAccessLevel> portfolioAccess; // portfolioId -> access level
  final List<Permission> customPermissions; // Additional permissions beyond role
  final String? assignedBy;
  final DateTime? assignedAt;
  final DateTime? expiresAt;
  final bool isActive;

  /// Check if user has a specific permission
  bool hasPermission(Permission permission) {
    if (!isActive) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;

    final rolePermissions = Permission.getPermissionsForRole(siteRole);
    return rolePermissions.contains(permission) || customPermissions.contains(permission);
  }

  /// Get access level for a specific project
  ResourceAccessLevel getProjectAccess(String projectId) {
    return projectAccess[projectId] ?? ResourceAccessLevel.none;
  }

  /// Get access level for a specific program
  ResourceAccessLevel getProgramAccess(String programId) {
    return programAccess[programId] ?? ResourceAccessLevel.none;
  }

  /// Get access level for a specific portfolio
  ResourceAccessLevel getPortfolioAccess(String portfolioId) {
    return portfolioAccess[portfolioId] ?? ResourceAccessLevel.none;
  }

  /// Check if user can edit a specific project
  bool canEditProject(String projectId) {
    if (siteRole == SiteRole.owner || siteRole == SiteRole.admin) return true;
    final accessLevel = getProjectAccess(projectId);
    return accessLevel.level >= ResourceAccessLevel.editor.level;
  }

  /// Check if user can delete a specific project
  bool canDeleteProject(String projectId) {
    if (siteRole == SiteRole.owner) return true;
    final accessLevel = getProjectAccess(projectId);
    return accessLevel == ResourceAccessLevel.owner;
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'siteRole': siteRole.name,
        'projectAccess': projectAccess.map(
          (key, value) => MapEntry(key, value.name),
        ),
        'programAccess': programAccess.map(
          (key, value) => MapEntry(key, value.name),
        ),
        'portfolioAccess': portfolioAccess.map(
          (key, value) => MapEntry(key, value.name),
        ),
        'customPermissions': customPermissions.map((p) => p.name).toList(),
        'assignedBy': assignedBy,
        'assignedAt': assignedAt?.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'isActive': isActive,
      };

  factory UserRoleAssignment.fromMap(Map<String, dynamic> map) {
    return UserRoleAssignment(
      userId: map['userId'] as String,
      siteRole: SiteRole.fromString(map['siteRole'] as String? ?? 'user'),
      projectAccess: (map['projectAccess'] as Map<String, dynamic>?)
              ?.map(
                (key, value) => MapEntry(
                  key,
                  ResourceAccessLevel.values.firstWhere(
                    (e) => e.name == value,
                    orElse: () => ResourceAccessLevel.none,
                  ),
                ),
              ) ??
          {},
      programAccess: (map['programAccess'] as Map<String, dynamic>?)
              ?.map(
                (key, value) => MapEntry(
                  key,
                  ResourceAccessLevel.values.firstWhere(
                    (e) => e.name == value,
                    orElse: () => ResourceAccessLevel.none,
                  ),
                ),
              ) ??
          {},
      portfolioAccess: (map['portfolioAccess'] as Map<String, dynamic>?)
              ?.map(
                (key, value) => MapEntry(
                  key,
                  ResourceAccessLevel.values.firstWhere(
                    (e) => e.name == value,
                    orElse: () => ResourceAccessLevel.none,
                  ),
                ),
              ) ??
          {},
      customPermissions: (map['customPermissions'] as List<dynamic>?)
              ?.map(
                (p) => Permission.values.firstWhere(
                  (e) => e.name == p,
                  orElse: () => Permission.viewAnalytics,
                ),
              )
              .toList() ??
          [],
      assignedBy: map['assignedBy'] as String?,
      assignedAt: map['assignedAt'] != null
          ? DateTime.parse(map['assignedAt'] as String)
          : null,
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'] as String)
          : null,
      isActive: map['isActive'] as bool? ?? true,
    );
  }
}

/// User profile with role information
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.siteRole,
    this.photoUrl,
    this.phoneNumber,
    this.department,
    this.jobTitle,
    this.organization,
    this.lastLoginAt,
    this.createdAt,
    this.isActive = true,
    this.isEmailVerified = false,
  });

  final String id;
  final String email;
  final String displayName;
  final SiteRole siteRole;
  final String? photoUrl;
  final String? phoneNumber;
  final String? department;
  final String? jobTitle;
  final String? organization;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final bool isActive;
  final bool isEmailVerified;

  /// Get initials for avatar
  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'siteRole': siteRole.name,
        'photoUrl': photoUrl,
        'phoneNumber': phoneNumber,
        'department': department,
        'jobTitle': jobTitle,
        'organization': organization,
        'lastLoginAt': lastLoginAt?.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
        'isActive': isActive,
        'isEmailVerified': isEmailVerified,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String,
      siteRole: SiteRole.fromString(map['siteRole'] as String? ?? 'user'),
      photoUrl: map['photoUrl'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      department: map['department'] as String?,
      jobTitle: map['jobTitle'] as String?,
      organization: map['organization'] as String?,
      lastLoginAt: map['lastLoginAt'] != null
          ? DateTime.parse(map['lastLoginAt'] as String)
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      isActive: map['isActive'] as bool? ?? true,
      isEmailVerified: map['isEmailVerified'] as bool? ?? false,
    );
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    SiteRole? siteRole,
    String? photoUrl,
    String? phoneNumber,
    String? department,
    String? jobTitle,
    String? organization,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    bool? isActive,
    bool? isEmailVerified,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      siteRole: siteRole ?? this.siteRole,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      department: department ?? this.department,
      jobTitle: jobTitle ?? this.jobTitle,
      organization: organization ?? this.organization,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    );
  }
}
