/// Invitation Accept Screen
///
/// Shown when a user clicks an invitation link from their email.
/// Displays invitation details and allows accept/decline.
/// On acceptance, directs the user to the program dashboard.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/routing/app_router.dart';

class InvitationAcceptScreen extends StatefulWidget {
  const InvitationAcceptScreen({super.key, required this.invitationId});

  final String invitationId;

  @override
  State<InvitationAcceptScreen> createState() => _InvitationAcceptScreenState();
}

class _InvitationAcceptScreenState extends State<InvitationAcceptScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;
  Map<String, dynamic>? _invitationData;
  String? _error;

  static const _bg = Color(0xFFF9FAFB);
  static const _surface = Colors.white;
  static const _onSurface = Color(0xFF1A1D1F);
  static const _onSurfaceVariant = Color(0xFF6B7280);
  static const _outline = Color(0xFFE5E7EB);
  static const _primary = Color(0xFFFFC812);
  static const _emerald = Color(0xFF10B981);
  static const _crimson = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _loadInvitation();
  }

  Future<void> _loadInvitation() async {
    if (widget.invitationId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Invalid invitation link.';
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('programInvitations')
          .doc(widget.invitationId)
          .get();

      if (!doc.exists) {
        setState(() {
          _isLoading = false;
          _error = 'This invitation has expired or is invalid.';
        });
        return;
      }

      final data = doc.data()!;
      if (data['status'] != 'pending') {
        setState(() {
          _isLoading = false;
          _error = 'This invitation has already been ${data['status']}.';
        });
        return;
      }

      setState(() {
        _invitationData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load invitation: $e';
      });
    }
  }

  Future<void> _acceptInvitation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Redirect to sign in
      context.go('/${AppRoutes.signIn}');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Update invitation status
      await FirebaseFirestore.instance
          .collection('programInvitations')
          .doc(widget.invitationId)
          .update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedByUid': user.uid,
      });

      // Add user to program team members
      await FirebaseFirestore.instance.collection('programTeamMembers').add({
        'name': _invitationData!['name'] ?? user.displayName ?? '',
        'email': user.email ?? '',
        'role': _invitationData!['role'] ?? 'Viewer',
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'invitedVia': widget.invitationId,
      });

      if (mounted) {
        // Direct to program dashboard
        context.go('/${AppRoutes.programDashboard}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome! You have joined the program team.'),
            backgroundColor: _emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = 'Failed to accept invitation: $e';
        });
      }
    }
  }

  Future<void> _declineInvitation() async {
    setState(() => _isProcessing = true);

    try {
      await FirebaseFirestore.instance
          .collection('programInvitations')
          .doc(widget.invitationId)
          .update({
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        context.go('/${AppRoutes.dashboard}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation declined.'),
            backgroundColor: _onSurfaceVariant,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = 'Failed to decline invitation: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : _error != null
                      ? _buildErrorState()
                      : _buildInvitationCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _crimson.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.error_outline, size: 40, color: _crimson),
        ),
        const SizedBox(height: 20),
        const Text(
          'Oops!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: _onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.go('/${AppRoutes.dashboard}'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: _onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Go to Dashboard'),
        ),
      ],
    );
  }

  Widget _buildInvitationCard() {
    final inviterName = _invitationData!['inviterName'] ?? 'Someone';
    final role = _invitationData!['role'] ?? 'Viewer';
    final email = _invitationData!['email'] ?? '';

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline, size: 40, color: _primary),
          ),
          const SizedBox(height: 24),

          // Title
          const Text(
            'You\'re Invited!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _onSurface,
            ),
          ),
          const SizedBox(height: 8),

          // Description
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 15, color: _onSurfaceVariant, height: 1.5),
              children: [
                TextSpan(text: inviterName),
                const TextSpan(text: ' has invited you to join as '),
                TextSpan(
                  text: role,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: _onSurface),
                ),
                const TextSpan(text: '\n'),
                TextSpan(text: email),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Accept button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _acceptInvitation,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('Accept Invitation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Decline button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isProcessing ? null : _declineInvitation,
              style: OutlinedButton.styleFrom(
                foregroundColor: _onSurfaceVariant,
                side: const BorderSide(color: _outline),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Decline'),
            ),
          ),
        ],
      ),
    );
  }
}
