import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/user_role.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/project_charter_sections.dart';
import 'package:ndu_project/services/team_invitation_service.dart';

class CharterGovernanceSection extends StatelessWidget {
  final ProjectDataModel? data;
  final VoidCallback? onEditStakeholders;
  final VoidCallback? onEditApprovals;

  const CharterGovernanceSection({
    super.key,
    required this.data,
    this.onEditStakeholders,
    this.onEditApprovals,
  });

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(24),
      // constraints: const BoxConstraints(minHeight: 650), // Removed: Full width section adapts to content height
      decoration: BoxDecoration(
        color: const Color(
          0xFFF8FAFC,
        ), // Enterprise Fix: Subtle background tint
        borderRadius: BorderRadius.circular(12),
        // Increased contrast: darker border + subtle shadow
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('GOVERNANCE & CONTROLS', style: kSectionTitleStyle),
          const SizedBox(height: 24),

          // GRID LAYOUT
          // Row 1: Security | Stakeholders
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _GovernanceCard(child: CharterSecurityShort(data: data)),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _GovernanceCard(
                  child: CharterStakeholdersShort(
                    data: data,
                    onEdit: onEditStakeholders,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Row 2: Approvals (Full Width)
          CharterApprovals(data: data),
        ],
      ),
    );
  }
}

class _GovernanceCard extends StatelessWidget {
  final Widget child;
  const _GovernanceCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      child: child,
    );
  }
}

// --- REFACTORED SHORT COMPONENTS FOR GRID ---

// --- REFACTORED SHORT COMPONENTS FOR GRID ---

class CharterSecurityShort extends StatelessWidget {
  final ProjectDataModel? data;
  const CharterSecurityShort({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox();
    final secRoles = data!.frontEndPlanning.securityRoles;
    final isSet = secRoles.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderWithStatus('SECURITY HIGHLIGHTS', isSet),
        const SizedBox(height: 12),
        if (!isSet)
          const Text(
            'Standard organizational security apply.',
            style: TextStyle(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
              fontSize: 13,
            ),
          ),
        if (isSet)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: secRoles
                .take(3)
                .map(
                  (r) => Chip(
                    label: Text(r.name),
                    backgroundColor: Colors.grey.shade100,
                    padding: EdgeInsets.zero,
                    labelStyle: const TextStyle(fontSize: 11),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class CharterStakeholdersShort extends StatelessWidget {
  final ProjectDataModel? data;
  final VoidCallback? onEdit;
  const CharterStakeholdersShort({super.key, required this.data, this.onEdit});

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox();

    // Quick extract — sponsor + manager from charter meta info.
    final items = <Map<String, String>>[];
    if (data!.charterProjectSponsorName.isNotEmpty) {
      items.add({'name': data!.charterProjectSponsorName, 'role': 'Sponsor'});
    }
    if (data!.charterProjectManagerName.isNotEmpty) {
      items.add({'name': data!.charterProjectManagerName, 'role': 'Manager'});
    }

    // Pull preferred-solution stakeholders (internal + external) from the
    // Business Case -> Core Stakeholders section. These auto-feed the
    // charter so the user can review / edit them here, and they also
    // auto-feed the Planning phase stakeholder register.
    final preferredId = data!.preferredSolutionId;
    final preferredSolution = preferredId == null
        ? null
        : data!.potentialSolutions
              .where((s) => s.id == preferredId)
              .cast<PotentialSolution?>()
              .firstWhere((s) => s != null, orElse: () => null);
    final solutionStakeholderRows =
        data!.coreStakeholdersData?.solutionStakeholderData ?? [];
    final matchedStakeholderData = solutionStakeholderRows.where((row) {
      if (preferredSolution == null) return false;
      return row.solutionTitle.trim().toLowerCase() ==
          preferredSolution.title.trim().toLowerCase();
    }).toList();
    // Fallback: if no exact match, use the first row (single-solution
    // projects often have only one row).
    final stakeholderData = matchedStakeholderData.isNotEmpty
        ? matchedStakeholderData.first
        : (solutionStakeholderRows.isNotEmpty
              ? solutionStakeholderRows.first
              : null);

    final internalStakeholders = (stakeholderData?.internalStakeholders ?? '')
        .split(RegExp(r'[\n,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final externalStakeholders = (stakeholderData?.externalStakeholders ?? '')
        .split(RegExp(r'[\n,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final isSet =
        items.isNotEmpty ||
        internalStakeholders.isNotEmpty ||
        externalStakeholders.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _HeaderWithStatus('KEY STAKEHOLDERS', isSet),
            const Spacer(),
            if (onEdit != null)
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Edit', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (!isSet)
          const Text(
            'No key stakeholders identified.',
            style: TextStyle(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
              fontSize: 13,
            ),
          ),
        ...items.map(
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    i['name']!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    i['role']!,
                    style: TextStyle(fontSize: 10, color: const Color(0xFF78350F)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (internalStakeholders.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'INTERNAL (from preferred solution):',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: internalStakeholders
                .map(
                  (s) => Chip(
                    label: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: Colors.green.shade50,
                    labelStyle: TextStyle(color: Colors.green.shade800),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
        ],
        if (externalStakeholders.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'EXTERNAL (from preferred solution):',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: externalStakeholders
                .map(
                  (s) => Chip(
                    label: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: Colors.purple.shade50,
                    labelStyle: TextStyle(color: Colors.purple.shade800),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class CharterApprovals extends StatefulWidget {
  final ProjectDataModel? data;
  const CharterApprovals({super.key, this.data});

  @override
  State<CharterApprovals> createState() => _CharterApprovalsState();
}

class _ApprovalAuthority {
  const _ApprovalAuthority({
    required this.name,
    required this.email,
    required this.roleLabel,
    required this.reason,
  });

  final String name;
  final String email;
  final String roleLabel;
  final String reason;
}

class _CharterApprovalsState extends State<CharterApprovals> {
  _ApprovalAuthority? _approvalAuthority;
  bool _isResolvingAuthority = false;
  bool _isSendingApprovalRequest = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _refreshApprovalAuthority(),
    );
  }

  @override
  void didUpdateWidget(covariant CharterApprovals oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _refreshApprovalAuthority(),
      );
    }
  }

  Future<void> _refreshApprovalAuthority() async {
    final data = widget.data;
    if (data == null || !mounted) return;
    setState(() => _isResolvingAuthority = true);
    final authority = await _resolveApprovalAuthority(data);
    if (!mounted) return;
    setState(() {
      _approvalAuthority = authority;
      _isResolvingAuthority = false;
    });
  }

  Future<UserProfile?> _findUserByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('isActive', isEqualTo: true)
        .limit(200)
        .get();
    for (final doc in snapshot.docs) {
      final profile = UserProfile.fromMap({'id': doc.id, ...doc.data()});
      if (profile.email.trim().toLowerCase() == normalized) {
        return profile;
      }
    }
    return null;
  }

  Future<UserProfile?> _findUserByDisplayName(String name) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('isActive', isEqualTo: true)
        .limit(100)
        .get();
    for (final doc in snapshot.docs) {
      final profile = UserProfile.fromMap({'id': doc.id, ...doc.data()});
      if (profile.displayName.trim().toLowerCase() == normalized) {
        return profile;
      }
    }
    return null;
  }

  Future<UserProfile?> _findHighestRoleUser() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('isActive', isEqualTo: true)
        .limit(200)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final profiles =
        snapshot.docs
            .map((doc) => UserProfile.fromMap({'id': doc.id, ...doc.data()}))
            .where((profile) => profile.email.trim().isNotEmpty)
            .toList()
          ..sort((a, b) => b.siteRole.level.compareTo(a.siteRole.level));
    if (profiles.isEmpty) return null;
    return profiles.first;
  }

  Future<_ApprovalAuthority?> _resolveApprovalAuthority(
    ProjectDataModel data,
  ) async {
    final sponsorEmail = data.charterProjectSponsorEmail.trim();
    final sponsorName = data.charterProjectSponsorName.trim();
    final managerName = data.charterProjectManagerName.trim();

    if (sponsorEmail.isNotEmpty) {
      final sponsorUser = await _findUserByEmail(sponsorEmail);
      if (sponsorUser != null) {
        return _ApprovalAuthority(
          name: sponsorUser.displayName,
          email: sponsorUser.email,
          roleLabel: 'Project Sponsor',
          reason: 'Named sponsor is already signed up on the platform.',
        );
      }
    }

    if (sponsorName.isNotEmpty) {
      final sponsorUser = await _findUserByDisplayName(sponsorName);
      if (sponsorUser != null) {
        return _ApprovalAuthority(
          name: sponsorUser.displayName,
          email: sponsorUser.email,
          roleLabel: 'Project Sponsor',
          reason: 'Named sponsor matched a signed-up platform user.',
        );
      }
    }

    final highestRoleUser = await _findHighestRoleUser();
    if (highestRoleUser != null) {
      return _ApprovalAuthority(
        name: highestRoleUser.displayName,
        email: highestRoleUser.email,
        roleLabel: '${highestRoleUser.siteRole.displayName} Sponsor',
        reason:
            'No signed-up sponsor was found, so the highest role on the site was selected as the approval authority.',
      );
    }

    if (managerName.isNotEmpty) {
      return _ApprovalAuthority(
        name: managerName,
        email: '',
        roleLabel: 'Project Owner',
        reason: 'Project manager is the fallback approval authority.',
      );
    }

    return null;
  }

  Future<void> _sendApprovalRequest(ProjectDataModel data) async {
    final authority = _approvalAuthority;
    if (authority == null || authority.email.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No signed-up approval authority with an email is available yet.',
          ),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }

    setState(() => _isSendingApprovalRequest = true);
    try {
      await TeamInvitationService.sendInvitation(
        email: authority.email,
        projectName: data.projectName.trim().isEmpty
            ? 'NDU Project Charter'
            : '${data.projectName.trim()} Charter Review',
      );
      final provider = ProjectDataInherited.maybeOf(context);
      if (provider != null) {
        provider.updateField(
          (d) => d.copyWith(
            charterApprovalRequestedToName: authority.name,
            charterApprovalRequestedToEmail: authority.email,
            charterApprovalRequestedToRole: authority.roleLabel,
            charterApprovalRequestedAt: DateTime.now(),
          ),
        );
        await provider.saveToFirebase(checkpoint: 'project_charter');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Approval request sent to ${authority.name} (${authority.email}).',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send approval request: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSendingApprovalRequest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data == null) return const SizedBox();

    // Logic: Sponsor preferred. If no Sponsor, then Owner (Project Manager
    // field). If Owner is also the PM (current user), they can approve.
    final signerName = _approvalAuthority?.name.isNotEmpty == true
        ? _approvalAuthority!.name
        : (data.charterProjectSponsorName.isNotEmpty
              ? data.charterProjectSponsorName
              : data.charterProjectManagerName.isNotEmpty
              ? data.charterProjectManagerName
              : 'Pending Assignment');
    final signerRole = _approvalAuthority?.roleLabel.isNotEmpty == true
        ? _approvalAuthority!.roleLabel
        : data.charterProjectSponsorName.isNotEmpty
        ? 'Project Sponsor'
        : 'Project Owner';

    final isApproved =
        data.charterApprovalDate != null ||
        data.frontEndPlanning.charterApproved;
    final resolvedAuthorityEmail = _approvalAuthority?.email
        .trim()
        .toLowerCase();
    final approvalRequestSent =
        data.charterApprovalRequestedAt != null &&
        data.charterApprovalRequestedToEmail.trim().isNotEmpty &&
        (resolvedAuthorityEmail == null ||
            resolvedAuthorityEmail.isEmpty ||
            data.charterApprovalRequestedToEmail.trim().toLowerCase() ==
                resolvedAuthorityEmail);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'APPROVAL AUTHORITY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Colors.black54,
                ),
              ),
              if (isApproved)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.green.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'APPROVED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Sponsor suggestion banner
          if (!isApproved) ...[
            _buildSponsorSuggestionBanner(data),
            const SizedBox(height: 16),
          ],
          if (!isApproved && _isResolvingAuthority) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Resolving approval authority...',
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (!isApproved && _approvalAuthority != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resolved approval authority: ${_approvalAuthority!.name} (${_approvalAuthority!.roleLabel})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _approvalAuthority!.reason,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                  ),
                  if (approvalRequestSent) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Approval request sent to ${data.charterApprovalRequestedToName} on ${DateFormat('MMM d, yyyy').format(data.charterApprovalRequestedAt!)}.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 12),
          // Single Signer Row
          Row(
            children: [
              Expanded(
                child: _buildSignatureBlock(
                  context,
                  signerName,
                  signerRole,
                  isApproved && data.charterApprovalDate != null
                      ? DateFormat(
                          'MM/dd/yyyy',
                        ).format(data.charterApprovalDate!)
                      : (data.frontEndPlanning.charterApprovedAt != null
                            ? DateFormat(
                                'MM/dd/yyyy',
                              ).format(data.frontEndPlanning.charterApprovedAt!)
                            : null),
                  isApproved,
                  approvalRequestSent,
                  data,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSponsorSuggestionBanner(ProjectDataModel data) {
    // Suggest the highest-role user currently in the project team as
    // the sponsor. The user can accept the suggestion (which writes
    // the name into charterProjectSponsorName), invite a sponsor by
    // email, or skip and proceed with the project owner as the signer.
    final teamMembers = data.teamMembers;
    String suggestedName = '';
    String suggestedRole = '';
    String suggestedEmail = '';
    if (teamMembers.isNotEmpty) {
      // Simple role hierarchy: look for Sponsor / Owner / Director /
      // Program Manager / Project Manager in that order.
      const rolePriority = [
        'Sponsor',
        'Owner',
        'Director',
        'Program Manager',
        'Project Manager',
        'Lead',
      ];
      for (final role in rolePriority) {
        final matches = teamMembers.where(
          (m) =>
              m.name.trim().isNotEmpty &&
              m.role.toLowerCase().contains(role.toLowerCase()),
        );
        if (matches.isNotEmpty) {
          final match = matches.first;
          suggestedName = match.name;
          suggestedRole = match.role.isEmpty ? role : match.role;
          suggestedEmail = match.email.trim();
          break;
        }
      }
      // Fallback: first named team member.
      if (suggestedName.isEmpty) {
        final any = teamMembers.firstWhere(
          (m) => m.name.trim().isNotEmpty,
          orElse: () => teamMembers.first,
        );
        if (any.name.trim().isNotEmpty) {
          suggestedName = any.name;
          suggestedRole = any.role.isEmpty ? 'Team Lead' : any.role;
          suggestedEmail = any.email.trim();
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_pin_outlined,
                size: 18,
                color: Color(0xFFD97706),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Charter to be approved by sponsor, owner or applicable lead',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (suggestedName.isNotEmpty) ...[
            Text(
              'Suggested sponsor: $suggestedName ($suggestedRole) — the highest role-based authority currently linked to this project.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF78350F)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    final provider = ProjectDataInherited.maybeOf(context);
                    if (provider == null) return;
                    provider.updateField(
                      (d) => d.copyWith(
                        charterProjectSponsorName: suggestedName,
                        charterProjectSponsorEmail: suggestedEmail,
                      ),
                    );
                    provider.saveToFirebase(checkpoint: 'project_charter');
                    _refreshApprovalAuthority();
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Accept Suggested Sponsor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showInviteSponsorDialog(),
                  icon: const Icon(Icons.mail_outline, size: 16),
                  label: const Text('Invite Sponsor by Email'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                    side: const BorderSide(color: Color(0xFFF59E0B)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'No team members are assigned to this project yet. Invite a sponsor by email, or assign a Project Manager on the charter meta info card above.',
              style: TextStyle(fontSize: 12, color: Color(0xFF78350F)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _showInviteSponsorDialog(),
              icon: const Icon(Icons.mail_outline, size: 16),
              label: const Text('Invite Sponsor by Email'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD97706),
                side: const BorderSide(color: Color(0xFFF59E0B)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showInviteSponsorDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.person_add_outlined,
              color: Color(0xFFD97706),
              size: 22,
            ),
            const SizedBox(width: 10),
            const Text('Invite Sponsor'),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'An email invitation will be sent so the sponsor can review and approve the charter. The sponsor will be added as the charter approval authority once they accept.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Sponsor name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Sponsor email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(v.trim())) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );

    if (result == true) {
      final name = nameController.text.trim();
      final email = emailController.text.trim();
      final provider = ProjectDataInherited.maybeOf(context);
      if (provider != null) {
        provider.updateField(
          (d) => d.copyWith(
            charterProjectSponsorName: name,
            charterProjectSponsorEmail: email,
          ),
        );
        await provider.saveToFirebase(checkpoint: 'project_charter');
      }
      try {
        await TeamInvitationService.sendInvitation(
          email: email,
          projectName: widget.data?.projectName.trim().isEmpty == false
              ? '${widget.data!.projectName.trim()} Charter Review'
              : 'NDU Project Charter Review',
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sponsor saved, but invitation email failed: $e'),
            backgroundColor: const Color(0xFFD97706),
          ),
        );
        await _refreshApprovalAuthority();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invitation email queued for $name ($email). The sponsor can review and approve the charter once they accept.',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
      await _refreshApprovalAuthority();
      setState(() {});
    }
  }

  Widget _buildSignatureBlock(
    BuildContext context,
    String name,
    String role,
    String? date,
    bool isApproved,
    bool approvalRequestSent,
    ProjectDataModel data,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.black45)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isApproved)
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _isSendingApprovalRequest
                          ? null
                          : () => _sendApprovalRequest(data),
                      child: Text(
                        _isSendingApprovalRequest
                            ? 'Sending...'
                            : approvalRequestSent
                            ? 'Resend Review Request'
                            : 'Send Review Request',
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: approvalRequestSent
                          ? () => _showApprovalConfirmationDialog(data)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: approvalRequestSent
                              ? const Color(0xFFB45309)
                              : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Click to Approve',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              role,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              date != null ? 'Date: $date' : 'Pending',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showApprovalConfirmationDialog(ProjectDataModel data) async {
    bool smeReviewed = data.frontEndPlanning.charterFepSmeReviewConfirmed;
    bool sponsorConfirmed = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.gavel_outlined,
                color: Color(0xFFD97706),
                size: 22,
              ),
              const SizedBox(width: 10),
              const Text('Confirm Charter Approval'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Charter to be approved by sponsor, owner or applicable lead. Confirm.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 14),
                CheckboxListTile(
                  value: smeReviewed,
                  onChanged: (v) =>
                      setDialogState(() => smeReviewed = v ?? false),
                  title: const Text(
                    'I confirm the right subject matter experts have reviewed all applicable sections of the Front End Execution Plan.',
                    style: TextStyle(fontSize: 12),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                CheckboxListTile(
                  value: sponsorConfirmed,
                  onChanged: (v) =>
                      setDialogState(() => sponsorConfirmed = v ?? false),
                  title: const Text(
                    'I am the project sponsor, owner, or applicable lead and I am authorized to approve this charter.',
                    style: TextStyle(fontSize: 12),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Once approved, the Front End Planning sections will be locked and the Planning phase will be unlocked.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFD97706),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (smeReviewed && sponsorConfirmed)
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm & Approve'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _approveCharter(data);
    }
  }

  Future<void> _approveCharter(ProjectDataModel data) async {
    final provider = ProjectDataInherited.maybeOf(context);
    if (provider == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to find project context.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    // Write approval + lock FEP sections so they become view-only.
    provider.updateField(
      (d) => d.copyWith(
        charterApprovalDate: DateTime.now(),
        charterReviewedBy: _approvalAuthority?.name ?? d.charterReviewedBy,
        frontEndPlanning: d.frontEndPlanning.copyWith(
          charterApproved: true,
          charterApprovedAt: DateTime.now(),
          charterFepSmeReviewConfirmed: true,
          charterFepSmeReviewConfirmedAt: DateTime.now(),
        ),
      ),
    );

    // Retry cloud sync up to 3 times to avoid the "Approval saved
    // locally, but cloud sync failed" message.
    bool success = false;
    String? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        success = await provider.saveToFirebase(checkpoint: 'project_charter');
        if (success) break;
      } catch (e) {
        lastError = e.toString();
      }
      await Future.delayed(const Duration(milliseconds: 800));
    }

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Project charter approved. Front End Planning is now locked and the Planning phase is unlocked.',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Approval saved locally but cloud sync failed after 3 retries. Please check your network connection and tap Approve again to retry. Error: $lastError',
          ),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
    }
  }
}

class _HeaderWithStatus extends StatelessWidget {
  final String title;
  final bool isSet;
  const _HeaderWithStatus(this.title, this.isSet);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const Spacer(),
        if (!isSet)
          const Text(
            'MISSING',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        if (isSet)
          const Icon(Icons.check_circle, size: 14, color: Colors.green),
      ],
    );
  }
}
