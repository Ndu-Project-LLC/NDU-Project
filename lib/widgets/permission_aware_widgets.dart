import 'package:flutter/material.dart';
import 'package:ndu_project/models/user_role.dart';
import 'package:ndu_project/providers/user_role_provider.dart';

/// Permission-aware widgets for conditional UI rendering

/// Widget that only shows its child when the user has the specified permission
class PermissionRequired extends StatelessWidget {
  const PermissionRequired({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  final Permission permission;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final provider = UserRoleInherited.of(context);
    if (provider.hasPermission(permission)) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}

/// Widget that only shows its child when the user has any of the specified permissions
class AnyPermissionRequired extends StatelessWidget {
  const AnyPermissionRequired({
    super.key,
    required this.permissions,
    required this.child,
    this.fallback,
  });

  final List<Permission> permissions;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final provider = UserRoleInherited.of(context);
    if (permissions.any((p) => provider.hasPermission(p))) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}

/// Widget that only shows its child when the user has the specified role level or higher
class RoleRequired extends StatelessWidget {
  const RoleRequired({
    super.key,
    required this.minRole,
    required this.child,
    this.fallback,
  });

  final SiteRole minRole;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final provider = UserRoleInherited.of(context);
    if (provider.siteRole.hasHigherOrEqualAccessThan(minRole)) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}

/// Widget that only shows its child when the user is an owner
class OwnerOnly extends StatelessWidget {
  const OwnerOnly({
    super.key,
    required this.child,
    this.fallback,
  });

  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final provider = UserRoleInherited.of(context);
    if (provider.isOwner) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}

/// Widget that only shows its child when the user is an admin or owner
class AdminOnly extends StatelessWidget {
  const AdminOnly({
    super.key,
    required this.child,
    this.fallback,
  });

  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final provider = UserRoleInherited.of(context);
    if (provider.isAdmin || provider.isOwner) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}

/// Widget that only shows its child when the user is an editor, admin, or owner
class EditorOnly extends StatelessWidget {
  const EditorOnly({
    super.key,
    required this.child,
    this.fallback,
  });

  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final provider = UserRoleInherited.of(context);
    if (provider.canEditContent) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}

/// Widget that only shows its child when the user can edit a specific project
class CanEditProject extends StatelessWidget {
  const CanEditProject({
    super.key,
    required this.projectId,
    required this.child,
    this.fallback,
  });

  final String projectId;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final provider = UserRoleInherited.of(context);
    if (provider.canEditProject(projectId)) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}

/// Widget that only shows its child when the user can delete a specific project
class CanDeleteProject extends StatelessWidget {
  const CanDeleteProject({
    super.key,
    required this.projectId,
    required this.child,
    this.fallback,
  });

  final String projectId;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final provider = UserRoleInherited.of(context);
    if (provider.canDeleteProject(projectId)) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}

/// Widget that shows different content based on user role
class RoleBuilder extends StatelessWidget {
  const RoleBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(
    BuildContext context,
    SiteRole role,
    bool isOwner,
    bool isAdmin,
    bool isEditor,
    bool isUser,
    bool isGuest,
  ) builder;

  @override
  Widget build(BuildContext context) {
    final provider = UserRoleInherited.of(context);
    return builder(
      context,
      provider.siteRole,
      provider.isOwner,
      provider.isAdmin,
      provider.isEditor,
      provider.isUser,
      provider.isGuest,
    );
  }
}

/// Widget that wraps a button and disables it if user lacks permission
class PermissionActionButton extends StatelessWidget {
  const PermissionActionButton({
    super.key,
    required this.permission,
    required this.onPressed,
    required this.child,
    this.tooltip,
  });

  final Permission permission;
  final VoidCallback onPressed;
  final Widget child;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final provider = UserRoleInherited.of(context);
    final hasPermission = provider.hasPermission(permission);

    return Tooltip(
      message: tooltip ??
          (hasPermission
              ? ''
              : 'You do not have permission to perform this action'),
      child: IgnorePointer(
        ignoring: !hasPermission,
        child: Opacity(
          opacity: hasPermission ? 1.0 : 0.5,
          child: child,
        ),
      ),
    );
  }
}

/// Widget that shows content based on whether user can manage billing
class BillingManagerOnly extends StatelessWidget {
  const BillingManagerOnly({
    super.key,
    required this.child,
    this.fallback,
  });

  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final provider = UserRoleInherited.of(context);
    if (provider.canManageBilling) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}

/// Widget that shows content based on whether user can manage users
class UserManagerOnly extends StatelessWidget {
  const UserManagerOnly({
    super.key,
    required this.child,
    this.fallback,
  });

  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final provider = UserRoleInherited.of(context);
    if (provider.canManageUsers) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}

/// Banner widget that shows when user is in read-only (guest) mode
class GuestModeBanner extends StatelessWidget {
  const GuestModeBanner({
    super.key,
    this.message = 'You are in view-only mode. Some features are limited.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final provider = UserRoleInherited.of(context);
    if (!provider.isGuest) return const SizedBox.shrink();

    return MaterialBanner(
      content: Text(message),
      leading: const Icon(Icons.visibility_outlined),
      backgroundColor: const Color(0xFFF3F4F6),
      actions: const [],
    );
  }
}

/// Badge widget that displays user's role
class RoleBadge extends StatelessWidget {
  const RoleBadge({
    super.key,
    this.showIcon = false,
  });

  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return RoleBuilder(
      builder: (context, role, isOwner, isAdmin, isEditor, isUser, isGuest) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: role.color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: role.color,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon) ...[
                Icon(
                  _getRoleIcon(role),
                  size: 14,
                  color: role.color,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                role.displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: role.color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getRoleIcon(SiteRole role) {
    switch (role) {
      case SiteRole.owner:
        return Icons.workspace_premium;
      case SiteRole.admin:
        return Icons.admin_panel_settings;
      case SiteRole.editor:
        return Icons.edit;
      case SiteRole.user:
        return Icons.person;
      case SiteRole.guest:
        return Icons.visibility;
    }
  }
}

/// Dropdown menu for role selection (admin only)
class RoleDropdown extends StatelessWidget {
  const RoleDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final SiteRole value;
  final ValueChanged<SiteRole> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<SiteRole>(
      value: value,
      onChanged: enabled ? (v) => onChanged(v!) : null,
      decoration: InputDecoration(
        labelText: 'Role',
        prefixIcon: const Icon(Icons.badge),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
      ),
      items: SiteRole.values.map((role) {
        return DropdownMenuItem(
          value: role,
          child: Row(
            children: [
              Icon(
                _getRoleIcon(role),
                size: 18,
                color: role.color,
              ),
              const SizedBox(width: 10),
              Text(role.displayName),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: role.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Level ${role.level}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: role.color,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _getRoleIcon(SiteRole role) {
    switch (role) {
      case SiteRole.owner:
        return Icons.workspace_premium;
      case SiteRole.admin:
        return Icons.admin_panel_settings;
      case SiteRole.editor:
        return Icons.edit;
      case SiteRole.user:
        return Icons.person;
      case SiteRole.guest:
        return Icons.visibility;
    }
  }
}

/// Widget that shows a lock icon overlay when content is restricted
class RestrictedContent extends StatelessWidget {
  const RestrictedContent({
    super.key,
    required this.child,
    this.message = 'This content requires higher access level',
  });

  final Widget child;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock,
                      size: 32,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Restricted Access',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
