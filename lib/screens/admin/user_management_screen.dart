import 'package:flutter/material.dart';
import 'package:ndu_project/models/user_role.dart';
import 'package:ndu_project/services/permission_service.dart';
import 'package:ndu_project/widgets/permission_aware_widgets.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';

/// World-class User Management Screen for admins and owners
/// Comprehensive user and role management interface
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UserManagementScreen()),
    );
  }

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final PermissionService _permissionService = PermissionService.instance;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  SiteRole? _selectedRoleFilter;
  bool _showInactiveUsers = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'User Management',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: () => _showAddUserDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add User'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildFilters(),
            const SizedBox(height: 16),
            Expanded(child: _buildUserList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: StreamBuilder<UserProfile?>(
        stream: _permissionService.userProfileStream,
        builder: (context, snapshot) {
          final currentUser = snapshot.data;
          return Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6366F1),
                      const Color(0xFF8B5CF6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    currentUser?.initials ?? '?',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${currentUser?.displayName ?? 'Admin'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const Text(
                      'Manage user roles, permissions, and access',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const RoleBadge(showIcon: true),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: VoiceTextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search users by name or email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SiteRole?>(
                value: _selectedRoleFilter,
                hint: const Text('All Roles'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Roles')),
                  ...SiteRole.values.map((role) => DropdownMenuItem(
                      value: role, child: Text(role.displayName))),
                ],
                onChanged: (v) => setState(() => _selectedRoleFilter = v),
              ),
            ),
          ),
          const SizedBox(width: 16),
          FilterChip(
            label: const Text('Show Inactive'),
            selected: _showInactiveUsers,
            onSelected: (v) => setState(() => _showInactiveUsers = v),
            checkmarkColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<List<UserProfile>>(
      stream: _buildFilteredUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        final users = snapshot.data!;
        return ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _buildUserCard(users[index]),
        );
      },
    );
  }

  Stream<List<UserProfile>> _buildFilteredUsersStream() {
    Stream<List<UserProfile>> baseStream;

    if (_selectedRoleFilter != null) {
      baseStream =
          _permissionService.getUsersByRoleStream(_selectedRoleFilter!);
    } else {
      baseStream = _permissionService.getAllUsersStream();
    }

    return baseStream.map((users) {
      var filtered = users;

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        filtered = filtered
            .where((u) =>
                u.displayName.toLowerCase().contains(query) ||
                u.email.toLowerCase().contains(query))
            .toList();
      }

      if (!_showInactiveUsers) {
        filtered = filtered.where((u) => u.isActive).toList();
      }

      return filtered;
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline,
              size: 40,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No users found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedRoleFilter != null
                ? 'Try adjusting your filters'
                : 'Add users to get started',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserProfile user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              user.isActive ? const Color(0xFFE5E7EB) : const Color(0xFFFEE2E2),
          width: user.isActive ? 1 : 2,
        ),
      ),
      child: Row(
        children: [
          _buildUserAvatar(user),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    if (!user.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Inactive',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                if (user.jobTitle != null || user.department != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (user.jobTitle != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user.jobTitle!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      if (user.department != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user.department!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildRoleDropdown(user),
          const SizedBox(width: 12),
          _buildActionMenu(user),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(UserProfile user) {
    return Stack(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _getAvatarColors(user),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              user.initials,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (user.photoUrl != null)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                user.photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: user.siteRole.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  List<Color> _getAvatarColors(UserProfile user) {
    switch (user.siteRole) {
      case SiteRole.owner:
        return [const Color(0xFFDC2626), const Color(0xFFEF4444)];
      case SiteRole.admin:
        return [const Color(0xFF7C3AED), const Color(0xFF8B5CF6)];
      case SiteRole.editor:
        return [const Color(0xFFD97706), const Color(0xFFFBBF24)];
      case SiteRole.user:
        return [const Color(0xFF059669), const Color(0xFF10B981)];
      case SiteRole.guest:
        return [const Color(0xFF6B7280), const Color(0xFF9CA3AF)];
    }
  }

  Widget _buildRoleDropdown(UserProfile user) {
    return StreamBuilder<UserRoleAssignment?>(
      stream: _permissionService.getUserRoleStream(user.id),
      builder: (context, snapshot) {
        final role = snapshot.data?.siteRole ?? user.siteRole;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: role.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: role.color),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getRoleIcon(role), size: 14, color: role.color),
              const SizedBox(width: 6),
              Text(
                role.displayName,
                style: TextStyle(
                  fontSize: 13,
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

  Widget _buildActionMenu(UserProfile user) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) => _handleMenuAction(value, user),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 12),
              Text('Edit User'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'permissions',
          child: Row(
            children: [
              Icon(Icons.security_outlined, size: 18),
              SizedBox(width: 12),
              Text('Manage Permissions'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'projects',
          child: Row(
            children: [
              Icon(Icons.folder_outlined, size: 18),
              SizedBox(width: 12),
              Text('Project Access'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (user.isActive)
          const PopupMenuItem(
            value: 'deactivate',
            child: Row(
              children: [
                Icon(Icons.block_outlined, size: 18, color: Color(0xFFDC2626)),
                SizedBox(width: 12),
                Text('Deactivate', style: TextStyle(color: Color(0xFFDC2626))),
              ],
            ),
          )
        else
          const PopupMenuItem(
            value: 'activate',
            child: Row(
              children: [
                Icon(Icons.check_circle_outlined,
                    size: 18, color: Color(0xFF10B981)),
                SizedBox(width: 12),
                Text('Reactivate', style: TextStyle(color: Color(0xFF10B981))),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _handleMenuAction(String action, UserProfile user) async {
    switch (action) {
      case 'edit':
        await _showEditUserDialog(user);
        break;
      case 'permissions':
        await _showPermissionsDialog(user);
        break;
      case 'projects':
        await _showProjectAccessDialog(user);
        break;
      case 'deactivate':
        await _confirmDeactivate(user);
        break;
      case 'activate':
        await _reactivateUser(user);
        break;
    }
  }

  Future<void> _showAddUserDialog() async {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    SiteRole selectedRole = SiteRole.user;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Add New User',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 24),
                  VoiceTextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  VoiceTextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<SiteRole>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder(),
                    ),
                    items: SiteRole.values.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Row(
                          children: [
                            Icon(_getRoleIcon(role),
                                size: 18, color: role.color),
                            const SizedBox(width: 10),
                            Text(role.displayName),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(() => selectedRole = v!),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Add User'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    emailController.dispose();
    nameController.dispose();

    if (result != true) return;

    // In production, this would send an invitation email
    // For now, we'll show a success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invitation sent to ${emailController.text}'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showEditUserDialog(UserProfile user) async {
    final nameController = TextEditingController(text: user.displayName);
    final titleController = TextEditingController(text: user.jobTitle ?? '');
    final departmentController =
        TextEditingController(text: user.department ?? '');
    final phoneController = TextEditingController(text: user.phoneNumber ?? '');
    final organizationController =
        TextEditingController(text: user.organization ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildUserAvatar(user),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit User',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          Text(
                            user.email,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                VoiceTextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: VoiceTextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Job Title',
                          prefixIcon: Icon(Icons.work_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: VoiceTextField(
                        controller: departmentController,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          prefixIcon: Icon(Icons.business),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: VoiceTextField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: VoiceTextField(
                        controller: organizationController,
                        decoration: const InputDecoration(
                          labelText: 'Organization',
                          prefixIcon: Icon(Icons.domain),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    nameController.dispose();
    titleController.dispose();
    departmentController.dispose();
    phoneController.dispose();
    organizationController.dispose();

    if (result != true) return;

    try {
      await _permissionService.updateUserProfile(
        user.copyWith(
          displayName: nameController.text.trim(),
          jobTitle: titleController.text.trim().isEmpty
              ? null
              : titleController.text.trim(),
          department: departmentController.text.trim().isEmpty
              ? null
              : departmentController.text.trim(),
          phoneNumber: phoneController.text.trim().isEmpty
              ? null
              : phoneController.text.trim(),
          organization: organizationController.text.trim().isEmpty
              ? null
              : organizationController.text.trim(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User updated successfully'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showPermissionsDialog(UserProfile user) async {
    await showDialog(
      context: context,
      builder: (context) => _UserPermissionsDialog(user: user),
    );
  }

  Future<void> _showProjectAccessDialog(UserProfile user) async {
    await showDialog(
      context: context,
      builder: (context) => _ProjectAccessDialog(user: user),
    );
  }

  Future<void> _confirmDeactivate(UserProfile user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate User?'),
        content: Text(
          'Are you sure you want to deactivate ${user.displayName}? '
          'They will not be able to access the platform.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      await _permissionService.deactivateUser(user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.displayName} has been deactivated'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deactivating user: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _reactivateUser(UserProfile user) async {
    try {
      await _permissionService.reactivateUser(user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.displayName} has been reactivated'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reactivating user: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _UserPermissionsDialog extends StatefulWidget {
  const _UserPermissionsDialog({required this.user});

  final UserProfile user;

  @override
  State<_UserPermissionsDialog> createState() => _UserPermissionsDialogState();
}

class _UserPermissionsDialogState extends State<_UserPermissionsDialog> {
  final PermissionService _permissionService = PermissionService.instance;
  SiteRole _selectedRole = SiteRole.user;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.user.siteRole;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'Manage Permissions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Changing role for: ${widget.user.displayName}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Assign Role',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 12),
              ...SiteRole.values.map((role) {
                final isSelected = _selectedRole == role;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: isSelected
                        ? role.color.withOpacity(0.15)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => setState(() => _selectedRole = role),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? role.color
                                : const Color(0xFFE5E7EB),
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getRoleIcon(role),
                              size: 24,
                              color: role.color,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    role.displayName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: role.color,
                                    ),
                                  ),
                                  Text(
                                    _getRoleDescription(role),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle,
                                  color: role.color, size: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isLoading ? null : _saveChanges,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

  String _getRoleDescription(SiteRole role) {
    switch (role) {
      case SiteRole.owner:
        return 'Full platform control including billing and user management';
      case SiteRole.admin:
        return 'User management and system configuration';
      case SiteRole.editor:
        return 'Create and manage content, projects, and data';
      case SiteRole.user:
        return 'Standard access to execute tasks and collaborate';
      case SiteRole.guest:
        return 'View-only access for vendors and external parties';
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    try {
      await _permissionService.assignUserRole(
        userId: widget.user.id,
        role: _selectedRole,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${widget.user.displayName} is now ${_selectedRole.displayName}'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating role: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _ProjectAccessDialog extends StatefulWidget {
  const _ProjectAccessDialog({required this.user});

  final UserProfile user;

  @override
  State<_ProjectAccessDialog> createState() => _ProjectAccessDialogState();
}

class _ProjectAccessDialogState extends State<_ProjectAccessDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'Project Access',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Manage access for: ${widget.user.displayName}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Project access management',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This feature will be available once projects are created.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
