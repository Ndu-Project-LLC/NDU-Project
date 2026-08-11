// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CharterTechProcHelper
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Once a preferred solution is locked, the charter's "Technical &
// Procurement" bento should source its IT Considerations and
// Infrastructure text from the preferred solution's
// `SolutionAnalysisItem` (the analysis record that matches
// `preferredSolutionId`), instead of from the dedicated FEP
// IT Considerations / Infrastructure Considerations pages.
//
// The Business Case section itself is locked (view-only) once a
// preferred solution is selected. To let the user still tailor the
// charter's wording without unlocking the Business Case, the charter
// stores its own override text (`ProjectDataModel.charterITOverride`
// and `ProjectDataModel.charterInfraOverride`). When non-empty, the
// override takes precedence over the preferred-solution text.
//
// This helper centralises:
//   - preferredSolutionAnalysisItem(projectData) → SolutionAnalysisItem?
//   - preferredSolutionITText(projectData)      → String? (joined
//       technologies + itConsiderationText)
//   - preferredSolutionInfraText(projectData)   → String? (joined
//       infrastructure + infraConsiderationText)
//   - charterITText(projectData)                → String? (override ?? preferred)
//   - charterInfraText(projectData)             → String? (override ?? preferred)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:ndu_project/models/project_data_model.dart';

class CharterTechProcHelper {
  CharterTechProcHelper._();

  /// Look up the [SolutionAnalysisItem] that corresponds to the locked
  /// preferred solution. Returns `null` when no preferred solution is
  /// selected, when the analysis record is missing, or when no item
  /// matches by id / title.
  static SolutionAnalysisItem? preferredSolutionAnalysisItem(
      ProjectDataModel? data) {
    if (data == null) return null;
    final preferredId = data.preferredSolutionId;
    if (preferredId == null || preferredId.isEmpty) return null;

    final analysis = data.preferredSolutionAnalysis;
    if (analysis == null || analysis.solutionAnalyses.isEmpty) return null;

    // 1. Match by selectedSolutionId (most reliable).
    for (final item in analysis.solutionAnalyses) {
      // The SolutionAnalysisItem itself doesn't carry an id, but the
      // PreferredSolutionAnalysis records the selected one.
      if (analysis.selectedSolutionId != null &&
          analysis.selectedSolutionId!.isNotEmpty &&
          analysis.selectedSolutionId == preferredId &&
          item.solutionTitle.trim().isNotEmpty &&
          item.solutionTitle ==
              (analysis.selectedSolutionTitle ??
                  data.preferredSolution?.title ??
                  '')) {
        return item;
      }
    }

    // 2. Match by title against the preferred solution.
    final preferred = data.preferredSolution;
    if (preferred == null) return null;
    for (final item in analysis.solutionAnalyses) {
      if (item.solutionTitle.trim().isNotEmpty &&
          item.solutionTitle.trim() == preferred.title.trim()) {
        return item;
      }
    }

    // 3. Fall back to the analysis' selectedSolutionTitle.
    if (analysis.selectedSolutionTitle != null &&
        analysis.selectedSolutionTitle!.trim().isNotEmpty) {
      for (final item in analysis.solutionAnalyses) {
        if (item.solutionTitle.trim() ==
            analysis.selectedSolutionTitle!.trim()) {
          return item;
        }
      }
    }

    return null;
  }

  /// Build the IT considerations text for the charter from the
  /// preferred solution. Joins the technologies list and appends the
  /// free-text `itConsiderationText` when present. Returns `null` when
  /// there is no preferred solution or no IT data recorded.
  static String? preferredSolutionITText(ProjectDataModel? data) {
    final item = preferredSolutionAnalysisItem(data);
    if (item == null) return null;

    final parts = <String>[];
    if (item.technologies.isNotEmpty) {
      parts.add('Technologies: ${item.technologies.join(', ')}');
    }
    final freeText = item.itConsiderationText?.trim() ?? '';
    if (freeText.isNotEmpty) {
      parts.add(freeText);
    }
    if (parts.isEmpty) return null;
    return parts.join('\n\n');
  }

  /// Build the Infrastructure text for the charter from the preferred
  /// solution. Joins the infrastructure list and appends the free-text
  /// `infraConsiderationText` when present. Returns `null` when there
  /// is no preferred solution or no infrastructure data recorded.
  static String? preferredSolutionInfraText(ProjectDataModel? data) {
    final item = preferredSolutionAnalysisItem(data);
    if (item == null) return null;

    final parts = <String>[];
    if (item.infrastructure.isNotEmpty) {
      parts.add('Infrastructure: ${item.infrastructure.join(', ')}');
    }
    final freeText = item.infraConsiderationText?.trim() ?? '';
    if (freeText.isNotEmpty) {
      parts.add(freeText);
    }
    if (parts.isEmpty) return null;
    return parts.join('\n\n');
  }

  /// The IT considerations text to display in the charter. Returns the
  /// charter-side override when set; otherwise falls back to the
  /// preferred-solution text. Returns `null` when neither is
  /// available.
  static String? charterITText(ProjectDataModel? data) {
    final override = data?.charterITOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    return preferredSolutionITText(data);
  }

  /// The Infrastructure text to display in the charter. Returns the
  /// charter-side override when set; otherwise falls back to the
  /// preferred-solution text. Returns `null` when neither is
  /// available.
  static String? charterInfraText(ProjectDataModel? data) {
    final override = data?.charterInfraOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    return preferredSolutionInfraText(data);
  }
}
