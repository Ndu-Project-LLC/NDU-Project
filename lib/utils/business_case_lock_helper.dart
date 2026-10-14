// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// BusinessCaseLockHelper
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Once a preferred solution is locked (preferredSolutionId != null OR
// frontEndPlanning.businessCaseLocked == true), all Business Case sections
// become read-only — the user can view them but cannot run AI generation
// or edit their content. This includes Risk Identification, IT
// Considerations, Infrastructure Considerations and Core Stakeholders.
//
// This helper centralises the lock-state check and provides:
//   - isBusinessCaseLocked(projectData) → bool
//   - showLockedToast(context) → SnackBar telling the user why the action
//     is blocked
//   - lockBanner(projectData) → a small banner widget to display at the
//     top of any Business Case screen when the lock is active
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';

class BusinessCaseLockHelper {
  BusinessCaseLockHelper._();

  /// True once a preferred solution has been chosen OR the
  /// `businessCaseLocked` flag has been explicitly set. In this state,
  /// every Business Case screen (Scope Statement, Potential Solutions,
  /// Risk Identification, IT Considerations, Infrastructure
  /// Considerations, Core Stakeholders, Initial Cost Estimate,
  /// Preferred Solution Analysis) is view-only — no AI generation, no
  /// inline edits.
  static bool isBusinessCaseLocked(ProjectDataModel? data) {
    if (data == null) return false;
    if (data.frontEndPlanning.businessCaseLocked) return true;
    if (data.preferredSolutionId != null &&
        data.preferredSolutionId!.isNotEmpty) {
      return true;
    }
    return false;
  }

  /// Show a SnackBar telling the user the Business Case is locked.
  static void showLockedToast(BuildContext context, {String? action}) {
    final verb = action ?? 'edit';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Business Case is locked. A preferred solution has been selected, '
          'so Business Case sections are view-only and can no longer be '
          '${verb}ed — including Risks, IT Considerations, Infrastructure '
          'Considerations and Core Stakeholders.',
        ),
        backgroundColor: const Color(0xFFD97706),
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
  }

  /// A small banner widget to display at the top of any Business Case
  /// screen when the lock is active.
  static Widget lockBanner(ProjectDataModel? data) {
    if (!isBusinessCaseLocked(data)) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD97706), width: 1),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline,
              size: 18, color: Color(0xFFD97706)),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Business Case is locked',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'A preferred solution has been selected. Business Case '
                  'sections are now view-only — you can review them but '
                  'cannot run AI generation or edit their content, including '
                  'Risks, IT Considerations, Infrastructure Considerations '
                  'and Core Stakeholders.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
