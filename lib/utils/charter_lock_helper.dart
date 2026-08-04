// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CharterLockHelper
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Centralizes the "is the FEP locked?" check so all FEP screens and
// navigation gates use the same rule.
//
// Lock rule (per user spec, Task 5):
//   Once the Project Charter is approved (`charterApprovalDate != null`
//   OR `frontEndPlanning.charterApproved == true`), the entire Front
//   End Planning section becomes read-only. Nothing in FEP can change
//   after the approval timestamp. The Planning phase is unlocked only
//   after this lock engages.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/theme.dart';

class CharterLockHelper {
  /// Returns true if the FEP is locked because the charter has been
  /// approved.
  static bool isFepLocked(ProjectDataModel? data) {
    if (data == null) return false;
    return data.charterApprovalDate != null ||
        (data.frontEndPlanning.charterApproved ?? false);
  }

  /// Returns the approval timestamp (prefers `frontEndPlanning
  /// .charterApprovedAt`, falls back to `charterApprovalDate`).
  static DateTime? approvalDate(ProjectDataModel? data) {
    if (data == null) return null;
    return data.frontEndPlanning.charterApprovedAt ?? data.charterApprovalDate;
  }

  /// Returns the name of the person who approved / should approve the
  /// charter. Prefers the sponsor, then the project manager.
  static String approverName(ProjectDataModel? data) {
    if (data == null) return '';
    final sponsor = data.charterProjectSponsorName.trim();
    if (sponsor.isNotEmpty) return sponsor;
    final manager = data.charterProjectManagerName.trim();
    if (manager.isNotEmpty) return manager;
    return '';
  }

  /// A thin, non-blocking banner to render at the top of any FEP screen
  /// when the charter is locked. Returns `SizedBox()` if not locked.
  static Widget lockBanner(ProjectDataModel? data, {String? screenLabel}) {
    if (!isFepLocked(data)) return const SizedBox();

    final approvedAt = approvalDate(data);
    final by = approverName(data);
    final fmt = DateFormat.yMMMd().add_jm();
    final when = approvedAt != null ? fmt.format(approvedAt.toLocal()) : 'unknown time';
    final byLabel = by.isNotEmpty ? ' by $by' : '';
    final screenTag =
        screenLabel == null ? '' : ' — $screenLabel is now read-only';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: BrandColors.primaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BrandColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline,
              size: 16, color: BrandColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Charter approved$byLabel on $when.$screenTag',
              style: const TextStyle(
                fontSize: 12,
                color: BrandColors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
