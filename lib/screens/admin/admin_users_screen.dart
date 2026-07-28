import 'package:flutter/material.dart';
import 'package:ndu_project/models/user_model.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/services/navigation_context_service.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _filterBy = 'all';

  @override
  Widget build(BuildContext context) {
    // Record admin dashboard context for logo navigation
    NavigationContextService.instance
        .setLastAdminDashboard(AppRoutes.adminUsers);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: Row(
          children: [
            const Icon(Icons.people, color: Color(0xFF2196F3), size: 28),
            const SizedBox(width: 12),
            const Text('User Management',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black)),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: UnifiedProfileMenu(compact: true),
          ),
        ],
      ),
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: UserService.watchAllUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Error: ${snapshot.error}'),
                        ],
                      ),
                    );
                  }

                  final allUsers = snapshot.data ?? [];
                  final filteredUsers = _filterUsers(allUsers);

                  if (filteredUsers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_outline,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('No users found',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(32),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) => _UserCard(
                      user: filteredUsers[index],
                      onToggleAdmin: () =>
                          _toggleAdminStatus(filteredUsers[index]),
                      onToggleActive: () =>
                          _toggleActiveStatus(filteredUsers[index]),
                      onDelete: () => _deleteUser(filteredUsers[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          const Text('Filter: ',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          ...[
            {'label': 'All Users', 'value': 'all'},
            {'label': 'Admins', 'value': 'admins'},
            {'label': 'Active', 'value': 'active'},
            {'label': 'Inactive', 'value': 'inactive'},
          ].map((filter) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(filter['label']!),
                  selected: _filterBy == filter['value'],
                  onSelected: (selected) {
                    if (selected) setState(() => _filterBy = filter['value']!);
                  },
                  selectedColor: const Color(0xFFFFC107),
                  backgroundColor: Colors.grey.withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: _filterBy == filter['value']
                        ? Colors.black
                        : Colors.black87,
                    fontWeight: _filterBy == filter['value']
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  List<UserModel> _filterUsers(List<UserModel> users) {
    switch (_filterBy) {
      case 'admins':
        return users.where((u) => u.isAdmin).toList();
      case 'active':
        return users.where((u) => u.isActive).toList();
      case 'inactive':
        return users.where((u) => !u.isActive).toList();
      default:
        return users;
    }
  }

  Future<void> _toggleAdminStatus(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(user.isAdmin ? 'Remove Admin Access' : 'Grant Admin Access'),
        content: Text(
          user.isAdmin
              ? 'Are you sure you want to remove admin access for ${user.displayName}?'
              : 'Are you sure you want to grant admin access to ${user.displayName}?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  user.isAdmin ? Colors.red : const Color(0xFFFFC107),
            ),
            child: Text(user.isAdmin ? 'Remove' : 'Grant'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success =
          await UserService.updateUserAdminStatus(user.uid, !user.isAdmin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Admin status updated'
                : 'Failed to update admin status'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleActiveStatus(UserModel user) async {
    final success =
        await UserService.updateUserActiveStatus(user.uid, !user.isActive);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              success ? 'User status updated' : 'Failed to update user status'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
            'Are you sure you want to delete ${user.displayName}? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await UserService.deleteUser(user.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'User deleted successfully'
                : 'Failed to delete user'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onToggleAdmin,
    required this.onToggleActive,
    required this.onDelete,
  });

  final UserModel user;
  final VoidCallback onToggleAdmin;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFFFC107).withOpacity(0.2),
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.black),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(user.displayName,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          if (user.isAdmin) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC107).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('ADMIN',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                          if (!user.isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('INACTIVE',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.red)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(user.email,
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey.withOpacity(0.2)),
            const SizedBox(height: 16),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.calendar_today,
                  label: 'Joined ${_formatDate(user.createdAt)}',
                ),
                const SizedBox(width: 16),
                if (user.lastLoginAt != null)
                  _InfoChip(
                    icon: Icons.login,
                    label: 'Last login ${_formatDate(user.lastLoginAt!)}',
                  ),
                const Spacer(),
                IconButton(
                  onPressed: onToggleAdmin,
                  icon: Icon(user.isAdmin
                      ? Icons.admin_panel_settings
                      : Icons.admin_panel_settings_outlined),
                  color: user.isAdmin ? const Color(0xFFFFC107) : Colors.grey,
                  tooltip: user.isAdmin ? 'Remove Admin' : 'Make Admin',
                ),
                IconButton(
                  onPressed: onToggleActive,
                  icon: Icon(user.isActive ? Icons.check_circle : Icons.block),
                  color: user.isActive ? Colors.green : Colors.red,
                  tooltip: user.isActive ? 'Deactivate' : 'Activate',
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                  tooltip: 'Delete User',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) return '${diff.inMinutes}m ago';
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
