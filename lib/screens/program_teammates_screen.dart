/// Program Teammates Screen
///
/// World-class team management page for the Program Dashboard.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/team_invitation_service.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';

class ProgramTeammatesScreen extends StatefulWidget {
  const ProgramTeammatesScreen({super.key});

  @override
  State<ProgramTeammatesScreen> createState() =>
      _ProgramTeammatesScreenState();
}

class _ProgramTeammatesScreenState extends State<ProgramTeammatesScreen> {
  static const int _maxMembers = 7;

  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedRole = 'Viewer';
  bool _isInviting = false;
  String? _inviteError;
  String? _inviteSuccess;

  static const List<String> _roles = [
    'Admin',
    'Project Manager',
    'Team Lead',
    'Contributor',
    'Viewer',
  ];

  static const _bg = Color(0xFFF9FAFB);
  static const _surface = Colors.white;
  static const _onSurface = Color(0xFF1A1D1F);
  static const _onSurfaceVariant = Color(0xFF6B7280);
  static const _outline = Color(0xFFE5E7EB);
  static const _primary = Color(0xFFFFC812);
  static const _primaryDark = Color(0xFFF59E0B);
  static const _emerald = Color(0xFF10B981);
  static const _amber = Color(0xFFF59E0B);
  static const _crimson = Color(0xFFEF4444);

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String get _currentUserEmail =>
      FirebaseAuth.instance.currentUser?.email ?? '';
  String get _currentUserName => FirebaseAuthService.displayNameOrEmail();

  void _showInviteSheet() {
    _emailController.clear();
    _nameController.clear();
    _selectedRole = 'Viewer';
    _inviteError = null;
    _inviteSuccess = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => _InviteBottomSheet(
          emailController: _emailController,
          nameController: _nameController,
          selectedRole: _selectedRole,
          roles: _roles,
          isInviting: _isInviting,
          inviteError: _inviteError,
          inviteSuccess: _inviteSuccess,
          onRoleChanged: (v) => setSheetState(() => _selectedRole = v!),
          onInvite: () async {
            setSheetState(() => _isInviting = true);
            await _sendInvitation();
            if (ctx.mounted) setSheetState(() {});
          },
        ),
      ),
    );
  }

  Future<void> _sendInvitation() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _inviteError = 'Please enter a valid email address.';
      _isInviting = false;
      return;
    }
    if (email.toLowerCase() == _currentUserEmail.toLowerCase()) {
      _inviteError = 'You cannot invite yourself.';
      _isInviting = false;
      return;
    }

    try {
      await TeamInvitationService.sendInvitation(
        email: email,
        inviterName: _currentUserName,
        projectName: 'Program Team',
      );

      await FirebaseFirestore.instance.collection('programInvitations').add({
        'email': email,
        'name': _nameController.text.trim(),
        'role': _selectedRole,
        'inviterUid': FirebaseAuth.instance.currentUser?.uid,
        'inviterName': _currentUserName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _inviteSuccess = 'Invitation sent to $email';
      _inviteError = null;
      _isInviting = false;
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      _inviteError = e.toString().replaceAll('Exception: ', '');
      _isInviting = false;
    }
  }

  Future<void> _removeMember(String memberId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Team Member'),
        content: Text('Remove $name from the program team?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _crimson),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('programTeamMembers')
          .doc(memberId)
          .delete();
    }
  }

  Future<void> _updateRole(String memberId, String newRole) async {
    await FirebaseFirestore.instance
        .collection('programTeamMembers')
        .doc(memberId)
        .update({'role': newRole});
  }

  Future<void> _cancelInvitation(String invitationId) async {
    await FirebaseFirestore.instance
        .collection('programInvitations')
        .doc(invitationId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = FirebaseAuthService.displayNameOrEmail();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(user, displayName),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTeamStats(),
                        const SizedBox(height: 24),
                        _sectionTitle('Team Members'),
                        const SizedBox(height: 12),
                        _buildTeamMembersList(),
                        const SizedBox(height: 28),
                        _sectionTitle('Pending Invitations'),
                        const SizedBox(height: 12),
                        _buildPendingInvitationsList(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: const KazAiChatBubble(positioned: false),
    );
  }

  Widget _buildHeader(User? user, String displayName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _outline)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => context.go('/${AppRoutes.programDashboard}'),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.people_outline, size: 20, color: _onSurfaceVariant),
          const SizedBox(width: 8),
          const Text(
            'Program Teammates',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _onSurface,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _showInviteSheet,
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text('Invite Teammate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: _onSurface,
              elevation: 2,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 18,
            backgroundColor: _primary,
            child: Text(
              displayName.isNotEmpty
                  ? displayName.characters.first.toUpperCase()
                  : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('programTeamMembers')
          .snapshots(),
      builder: (context, snapshot) {
        final memberCount = snapshot.data?.docs.length ?? 0;
        final remaining = _maxMembers - memberCount - 1;
        final fillPercent = (memberCount + 1) / _maxMembers;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _outline),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 8,
                  offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: fillPercent,
                      strokeWidth: 6,
                      backgroundColor: _outline,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        fillPercent >= 0.8 ? _amber : _emerald,
                      ),
                    ),
                    Text(
                      '${(fillPercent * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Team Capacity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$memberCount of $_maxMembers seats filled  •  $remaining remaining',
                      style: const TextStyle(
                          fontSize: 13, color: _onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(_maxMembers, (i) {
                        final filled = i < memberCount + 1;
                        return Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: filled ? _primary : _outline,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: filled ? _primaryDark : _outline,
                            ),
                          ),
                          child: Icon(
                            filled ? Icons.person : Icons.person_outline,
                            size: 16,
                            color:
                                filled ? Colors.white : _onSurfaceVariant,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: _onSurface,
      ),
    );
  }

  Widget _buildTeamMembersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('programTeamMembers')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyState(
            icon: Icons.people_outline,
            message: 'No team members yet.\nInvite someone to get started!',
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Unknown';
            final email = data['email'] ?? '';
            final role = data['role'] ?? 'Viewer';
            final memberId = doc.id;
            final isMe =
                email.toLowerCase() == _currentUserEmail.toLowerCase();

            return _memberTile(
              name: name,
              email: email,
              role: role,
              isCurrentUser: isMe,
              onRoleChanged: (r) { if (r != null) _updateRole(memberId, r); },
              onRemove: () => _removeMember(memberId, name),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _memberTile({
    required String name,
    required String email,
    required String role,
    required bool isCurrentUser,
    required ValueChanged<String?> onRoleChanged,
    required VoidCallback onRemove,
  }) {
    final initials = name.isNotEmpty
        ? name.characters.take(2).join().toUpperCase()
        : email.isNotEmpty
            ? email.characters.first.toUpperCase()
            : 'U';
    final rc = _roleColor(role);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: rc.withValues(alpha: 0.15),
            child: Text(initials,
                style: TextStyle(
                    color: rc, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _onSurface)),
                  if (isCurrentUser) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _emerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('You',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _emerald)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(email,
                    style: const TextStyle(
                        fontSize: 12, color: _onSurfaceVariant)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: rc.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: rc.withValues(alpha: 0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: role,
                isDense: true,
                items: _roles
                    .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r,
                            style:
                                TextStyle(fontSize: 12, color: _roleColor(r)))))
                    .toList(),
                onChanged: isCurrentUser ? null : onRoleChanged,
                style: TextStyle(
                    fontSize: 12, color: rc, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (!isCurrentUser) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: _crimson,
              onPressed: onRemove,
              tooltip: 'Remove member',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingInvitationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('programInvitations')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyState(
            icon: Icons.mail_outline,
            message: 'No pending invitations.',
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final email = data['email'] ?? '';
            final name = data['name'] ?? '';
            final role = data['role'] ?? 'Viewer';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.mail_outline,
                        size: 20, color: _amber),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.isNotEmpty ? name : email,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _onSurface)),
                        const SizedBox(height: 2),
                        Text('$email  •  $role',
                            style: const TextStyle(
                                fontSize: 12, color: _onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Pending',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _amber)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    color: _crimson,
                    onPressed: () => _cancelInvitation(doc.id),
                    tooltip: 'Cancel invitation',
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _emptyState({required IconData icon, required String message}) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outline),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: _outline),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 14, color: _onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Admin':
        return _crimson;
      case 'Project Manager':
        return _primary;
      case 'Team Lead':
        return _emerald;
      case 'Contributor':
        return const Color(0xFF6366F1);
      default:
        return _onSurfaceVariant;
    }
  }
}

// ─── Invite Bottom Sheet ─────────────────────────────────────────────────
class _InviteBottomSheet extends StatelessWidget {
  const _InviteBottomSheet({
    required this.emailController,
    required this.nameController,
    required this.selectedRole,
    required this.roles,
    required this.isInviting,
    required this.inviteError,
    required this.inviteSuccess,
    required this.onRoleChanged,
    required this.onInvite,
  });

  final TextEditingController emailController;
  final TextEditingController nameController;
  final String selectedRole;
  final List<String> roles;
  final bool isInviting;
  final String? inviteError;
  final String? inviteSuccess;
  final ValueChanged<String?> onRoleChanged;
  final VoidCallback onInvite;

  static const _surface = Colors.white;
  static const _onSurface = Color(0xFF1A1D1F);
  static const _onSurfaceVariant = Color(0xFF6B7280);
  static const _outline = Color(0xFFE5E7EB);
  static const _primary = Color(0xFFFFC812);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Invite Teammate',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _onSurface,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'They\'ll receive an email invitation to join your program.',
              style: TextStyle(fontSize: 13, color: _onSurfaceVariant),
            ),
            const SizedBox(height: 20),

            // Name field
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'Full name (optional)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            // Email field
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Email address',
                prefixIcon:
                    const Icon(Icons.email_outlined, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            // Role selector
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: roles
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: onRoleChanged,
            ),
            const SizedBox(height: 16),

            // Error / success
            if (inviteError != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(inviteError!,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFFEF4444))),
                    ),
                  ],
                ),
              ),
            if (inviteSuccess != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 16, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(inviteSuccess!,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF10B981))),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Send button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isInviting ? null : onInvite,
                icon: isInviting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_outlined, size: 18),
                label: Text(isInviting ? 'Sending...' : 'Send Invitation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: _onSurface,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
