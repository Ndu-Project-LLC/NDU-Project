library;

/// Stakeholders Screen — stakeholder list with SME flag + access control matrix.
///
/// Rendered inside the Cost Estimate module's [ResponsiveScaffold] body —
/// no Scaffold of its own. Light-mode (white) theme.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';

class StakeholdersScreen extends StatelessWidget {
  const StakeholdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CostEstimateProvider>(
      builder: (context, provider, _) {
        final estimate = provider.estimate!;
        final canEdit = (provider.currentRole == RBACRole.approver ||
            provider.currentRole == RBACRole.admin) &&
            estimate.status == EstimateStatus.draft;
        final smeCount = estimate.stakeholders.where((s) => s.sme).length;
        final isAdmin = provider.currentRole == RBACRole.admin;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.group, color: LightModeColors.accent, size: 20),
                  SizedBox(width: 8),
                  Text('Stakeholders & Access',
                      style: TextStyle(
                          color: Color(0xFF1A1D1F),
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              // Verbatim SME prompt
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LightModeColors.accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: LightModeColors.accent.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: LightModeColors.accent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Include required stakeholders and applicable Subject Matter Experts in the Estimate Development process',
                        style: TextStyle(
                            color: Color(0xFFD97706),
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stakeholders
                  Expanded(
                    child: _buildStakeholdersSection(
                        context, provider, estimate, canEdit, smeCount),
                  ),
                  const SizedBox(width: 24),
                  // Access control
                  Expanded(
                    child: _buildAccessSection(
                        context, provider, estimate, isAdmin),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStakeholdersSection(
    BuildContext context,
    CostEstimateProvider provider,
    CostEstimate estimate,
    bool canEdit,
    int smeCount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Stakeholders',
                    style: TextStyle(
                        color: Color(0xFF1A1D1F),
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text(
                  '${estimate.stakeholders.length} total · $smeCount SMEs',
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 12),
                ),
              ],
            ),
            if (canEdit)
              FilledButton.icon(
                onPressed: () => _showAddStakeholderDialog(context, provider),
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('Add'),
                style: FilledButton.styleFrom(
                  backgroundColor: LightModeColors.accent,
                  foregroundColor: LightModeColors.lightOnPrimary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (estimate.stakeholders.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4E7EC)),
            ),
            child: const Center(
              child: Text('No stakeholders yet.',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
            ),
          )
        else
          ...estimate.stakeholders.map((s) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: s.sme
                          ? LightModeColors.accent
                          : const Color(0xFFF3F4F6),
                      child: Text(
                        s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: s.sme
                              ? LightModeColors.lightOnPrimary
                              : const Color(0xFF495057),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(s.name,
                                  style: const TextStyle(
                                      color: Color(0xFF1A1D1F),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              if (s.sme) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: LightModeColors.accent
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('SME',
                                      style: TextStyle(
                                          color: Color(0xFFD97706),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          Text('${s.role} · ${s.email}',
                              style: const TextStyle(
                                  color: Color(0xFF6B7280), fontSize: 11)),
                        ],
                      ),
                    ),
                    if (canEdit)
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 16, color: Color(0xFFB91C1C)),
                        onPressed: () => provider.removeStakeholder(s.id),
                      ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _buildAccessSection(
    BuildContext context,
    CostEstimateProvider provider,
    CostEstimate estimate,
    bool isAdmin,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield,
                        color: LightModeColors.accent, size: 16),
                    const SizedBox(width: 6),
                    const Text('Access Control',
                        style: TextStyle(
                            color: Color(0xFF1A1D1F),
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('Your role: ${provider.currentRole.label}',
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 12)),
              ],
            ),
            if (isAdmin)
              FilledButton.icon(
                onPressed: () => _showGrantAccessDialog(context, provider),
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('Grant'),
                style: FilledButton.styleFrom(
                  backgroundColor: LightModeColors.accent,
                  foregroundColor: LightModeColors.lightOnPrimary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Role switcher
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('YOUR ROLE (FOR TESTING)',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: RBACRole.values.map((r) {
                  final isActive = provider.currentRole == r;
                  return ChoiceChip(
                    label: Text(r.label),
                    selected: isActive,
                    onSelected: (_) => provider.setCurrentRole(r),
                    selectedColor:
                        LightModeColors.accent.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: isActive
                          ? LightModeColors.accent
                          : const Color(0xFF495057),
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: isActive
                          ? LightModeColors.accent
                          : const Color(0xFFE4E7EC),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Access list
        ...estimate.access.map((a) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE4E7EC)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        LightModeColors.accent.withValues(alpha: 0.1),
                    child: Text(
                      a.userEmail.isNotEmpty
                          ? a.userEmail[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: LightModeColors.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(a.userEmail,
                        style: const TextStyle(
                            color: Color(0xFF1A1D1F), fontSize: 13)),
                  ),
                  if (isAdmin)
                    DropdownButton<RBACRole>(
                      value: a.role,
                      items: RBACRole.values
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r.label,
                                    style: const TextStyle(
                                        color: Color(0xFF1A1D1F),
                                        fontSize: 12)),
                              ))
                          .toList(),
                      onChanged: (r) {
                        if (r != null) provider.grantAccess(a.userEmail, r);
                      },
                      dropdownColor: Colors.white,
                      underline: const SizedBox(),
                    ),
                ],
              ),
            )),
        // Role capabilities legend
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ROLE CAPABILITIES',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1)),
              const SizedBox(height: 8),
              ...RBACRole.values.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(r.label,
                              style: const TextStyle(
                                  color: LightModeColors.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          child: Text(r.desc,
                              style: const TextStyle(
                                  color: Color(0xFF495057), fontSize: 12)),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddStakeholderDialog(
      BuildContext context, CostEstimateProvider provider) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    bool sme = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Add stakeholder',
              style: TextStyle(color: Color(0xFF1A1D1F))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(color: Color(0xFF6B7280))),
                style: const TextStyle(color: Color(0xFF1A1D1F)),
              ),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Color(0xFF6B7280))),
                style: const TextStyle(color: Color(0xFF1A1D1F)),
              ),
              TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Role / title',
                    labelStyle: TextStyle(color: Color(0xFF6B7280))),
                style: const TextStyle(color: Color(0xFF1A1D1F)),
              ),
              CheckboxListTile(
                value: sme,
                onChanged: (v) => setState(() => sme = v ?? false),
                title: const Text('Subject Matter Expert',
                    style: TextStyle(color: Color(0xFF1A1D1F), fontSize: 13)),
                activeColor: LightModeColors.accent,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF6B7280))),
            ),
            FilledButton(
              onPressed: () {
                provider.addStakeholder(Stakeholder(
                  id: newId('sh'),
                  name: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  role: roleCtrl.text.trim(),
                  sme: sme,
                  includedInDevelopment: true,
                ));
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(
                  backgroundColor: LightModeColors.accent,
                  foregroundColor: LightModeColors.lightOnPrimary),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showGrantAccessDialog(
      BuildContext context, CostEstimateProvider provider) {
    final emailCtrl = TextEditingController();
    RBACRole role = RBACRole.viewer;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Grant access',
              style: TextStyle(color: Color(0xFF1A1D1F))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Color(0xFF6B7280))),
                style: const TextStyle(color: Color(0xFF1A1D1F)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RBACRole>(
                value: role,
                items: RBACRole.values
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r.label,
                              style: const TextStyle(
                                  color: Color(0xFF1A1D1F))),
                        ))
                    .toList(),
                onChanged: (r) => setState(() => role = r!),
                decoration: const InputDecoration(
                    labelText: 'Role',
                    labelStyle: TextStyle(color: Color(0xFF6B7280))),
                dropdownColor: Colors.white,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF6B7280))),
            ),
            FilledButton(
              onPressed: () {
                provider.grantAccess(emailCtrl.text.trim(), role);
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(
                  backgroundColor: LightModeColors.accent,
                  foregroundColor: LightModeColors.lightOnPrimary),
              child: const Text('Grant'),
            ),
          ],
        ),
      ),
    );
  }
}
