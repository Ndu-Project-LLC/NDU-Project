import 'package:flutter/material.dart';
import 'package:ndu_project/models/user_role.dart';
import 'package:ndu_project/services/permission_service.dart';

/// Provider for user role and permission state
/// Makes it easy to access permission checks throughout the app
class UserRoleProvider with ChangeNotifier {
  final PermissionService _permissionService = PermissionService.instance;

  UserRoleAssignment? _currentRole;
  UserProfile? _currentProfile;
  bool _isLoading = false;
  String? _error;

  UserRoleAssignment? get currentRole => _currentRole;
  UserProfile? get currentProfile => _currentProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  SiteRole get siteRole => _currentRole?.siteRole ?? SiteRole.guest;
  bool get isOwner => siteRole == SiteRole.owner;
  bool get isAdmin => siteRole == SiteRole.admin;
  bool get isEditor => siteRole == SiteRole.editor;
  bool get isUser => siteRole == SiteRole.user;
  bool get isGuest => siteRole == SiteRole.guest;
  bool get canEditContent => siteRole.level >= SiteRole.editor.level;
  bool get canManageUsers => siteRole.level >= SiteRole.admin.level;
  bool get canManageBilling => siteRole == SiteRole.owner;

  /// Initialize the provider with current user's data
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadCurrentRole(),
        _loadCurrentProfile(),
      ]);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh the current user's role and profile
  Future<void> refresh() async {
    _permissionService.clearCache();
    await initialize();
  }

  Future<void> _loadCurrentRole() async {
    _currentRole = await _permissionService.getCurrentUserRole();
  }

  Future<void> _loadCurrentProfile() async {
    _currentProfile = await _permissionService.getCurrentUserProfile();
  }

  /// Check if current user has a specific permission
  bool hasPermission(Permission permission) {
    return _currentRole?.hasPermission(permission) ?? false;
  }

  /// Check if current user can edit a specific project
  bool canEditProject(String projectId) {
    if (_currentRole == null) return false;
    return _currentRole!.canEditProject(projectId);
  }

  /// Check if current user can delete a specific project
  bool canDeleteProject(String projectId) {
    if (_currentRole == null) return false;
    return _currentRole!.canDeleteProject(projectId);
  }

  /// Check if current user can access a specific project
  bool canAccessProject(String projectId) {
    if (_currentRole == null) return false;

    if (_currentRole!.siteRole == SiteRole.owner ||
        _currentRole!.siteRole == SiteRole.admin) {
      return true;
    }

    return _currentRole!.getProjectAccess(projectId) !=
        ResourceAccessLevel.none;
  }

  /// Get access level for a specific project
  ResourceAccessLevel getProjectAccess(String projectId) {
    return _currentRole?.getProjectAccess(projectId) ??
        ResourceAccessLevel.none;
  }

  /// Get access level for a specific program
  ResourceAccessLevel getProgramAccess(String programId) {
    return _currentRole?.getProgramAccess(programId) ??
        ResourceAccessLevel.none;
  }

  /// Get access level for a specific portfolio
  ResourceAccessLevel getPortfolioAccess(String portfolioId) {
    return _currentRole?.getPortfolioAccess(portfolioId) ??
        ResourceAccessLevel.none;
  }

  /// Get user's initials for avatar
  String get userInitials {
    return _currentProfile?.initials ?? '?';
  }

  /// Get user's display name
  String get displayName {
    return _currentProfile?.displayName ?? 'User';
  }

  /// Get user's email
  String get email {
    return _currentProfile?.email ?? '';
  }

  /// Get user's photo URL
  String? get photoUrl {
    return _currentProfile?.photoUrl;
  }

  /// Clear the current user data
  void clear() {
    _currentRole = null;
    _currentProfile = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}

/// Inherited widget for easy access to UserRoleProvider
class UserRoleInherited extends InheritedWidget {
  const UserRoleInherited({
    super.key,
    required this.provider,
    required super.child,
  });

  final UserRoleProvider provider;

  static UserRoleProvider of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<UserRoleInherited>();
    return result?.provider ?? UserRoleProvider();
  }

  @override
  bool updateShouldNotify(UserRoleInherited oldWidget) {
    return provider != oldWidget.provider;
  }
}

/// Convenience methods for permission checking in widgets
extension UserRoleBuildContext on BuildContext {
  /// Get the UserRoleProvider
  UserRoleProvider get roleProvider {
    return UserRoleInherited.of(this);
  }

  /// Check if current user has a specific permission
  bool hasPermission(Permission permission) {
    return roleProvider.hasPermission(permission);
  }

  /// Get current user's site role
  SiteRole get siteRole => roleProvider.siteRole;

  /// Check if current user is an owner
  bool get isOwner => roleProvider.isOwner;

  /// Check if current user is an admin
  bool get isAdmin => roleProvider.isAdmin;

  /// Check if current user is an editor
  bool get isEditor => roleProvider.isEditor;

  /// Check if current user is a regular user
  bool get isUser => roleProvider.isUser;

  /// Check if current user is a guest
  bool get isGuest => roleProvider.isGuest;

  /// Check if current user can edit content
  bool get canEditContent => roleProvider.canEditContent;

  /// Check if current user can manage users
  bool get canManageUsers => roleProvider.canManageUsers;

  /// Check if current user can manage billing
  bool get canManageBilling => roleProvider.canManageBilling;
}
