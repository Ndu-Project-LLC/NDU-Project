import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Lightweight SSHER rollup for a single project.
class ProjectSsherRollup {
  final String projectId;
  final String projectName;
  final double totalCost;
  final int itemCount;
  final int highRiskCount;
  final Map<String, double> costByCategory;

  const ProjectSsherRollup({
    required this.projectId,
    required this.projectName,
    required this.totalCost,
    required this.itemCount,
    required this.highRiskCount,
    required this.costByCategory,
  });

  bool get hasSsherData => itemCount > 0 || totalCost > 0;
}

/// Aggregate SSHER rollup across multiple projects.
class SsherPortfolioRollup {
  final List<ProjectSsherRollup> projects;
  final double grandTotal;
  final int totalItems;
  final int totalHighRisk;
  final Map<String, double> costByCategory;

  const SsherPortfolioRollup({
    required this.projects,
    required this.grandTotal,
    required this.totalItems,
    required this.totalHighRisk,
    required this.costByCategory,
  });

  static const empty = SsherPortfolioRollup(
    projects: [],
    grandTotal: 0,
    totalItems: 0,
    totalHighRisk: 0,
    costByCategory: {},
  );

  int get projectsWithSsher =>
      projects.where((p) => p.hasSsherData).length;
}

/// Service that loads SSHER cost rollups across all of the user's projects
/// by reading each project doc's `ssherData.entries` field directly.
///
/// This avoids the heavy full-ProjectDataModel deserialization path used by
/// `ProjectDataProvider.loadFromFirebase` — we only need the SSHER entries
/// for the rollup.
class ProjectSsherRollupService {
  ProjectSsherRollupService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Loads SSHER rollups for the given project IDs in parallel batches.
  /// Returns a portfolio rollup with per-project + total SSHER cost.
  static Future<SsherPortfolioRollup> loadForProjects(
    List<String> projectIds, {
    int batchSize = 10,
  }) async {
    if (projectIds.isEmpty) return SsherPortfolioRollup.empty;

    final rollups = <ProjectSsherRollup>[];
    // Process in batches to avoid hammering Firestore with too many parallel
    // reads when the user owns many projects.
    for (var i = 0; i < projectIds.length; i += batchSize) {
      final batch = projectIds.skip(i).take(batchSize).toList();
      final results = await Future.wait(
        batch.map((id) => _loadOne(id)),
        eagerError: false,
      );
      for (final r in results) {
        if (r != null) rollups.add(r);
      }
    }

    double grandTotal = 0;
    int totalItems = 0;
    int totalHighRisk = 0;
    final byCategory = <String, double>{};
    for (final r in rollups) {
      grandTotal += r.totalCost;
      totalItems += r.itemCount;
      totalHighRisk += r.highRiskCount;
      r.costByCategory.forEach((cat, cost) {
        byCategory[cat] = (byCategory[cat] ?? 0) + cost;
      });
    }

    return SsherPortfolioRollup(
      projects: rollups,
      grandTotal: grandTotal,
      totalItems: totalItems,
      totalHighRisk: totalHighRisk,
      costByCategory: byCategory,
    );
  }

  /// Loads the SSHER rollup for a single project. Returns null if the project
  /// doc doesn't exist or doesn't have an `ssherData` field.
  static Future<ProjectSsherRollup?> _loadOne(String projectId) async {
    try {
      final doc =
          await _firestore.collection('projects').doc(projectId).get();
      if (!doc.exists) return null;
      final data = doc.data() ?? {};
      final projectName = (data['projectName'] ?? '').toString();
      final ssherData = data['ssherData'];
      if (ssherData is! Map) {
        return ProjectSsherRollup(
          projectId: projectId,
          projectName: projectName,
          totalCost: 0,
          itemCount: 0,
          highRiskCount: 0,
          costByCategory: const {},
        );
      }
      final entriesRaw = ssherData['entries'];
      if (entriesRaw is! List) {
        return ProjectSsherRollup(
          projectId: projectId,
          projectName: projectName,
          totalCost: 0,
          itemCount: 0,
          highRiskCount: 0,
          costByCategory: const {},
        );
      }

      double totalCost = 0;
      int itemCount = 0;
      int highRiskCount = 0;
      final byCategory = <String, double>{};
      for (final entryRaw in entriesRaw) {
        if (entryRaw is! Map) continue;
        final entry = entryRaw;
        final costStr = (entry['estimatedCost'] ?? '').toString();
        final cost = double.tryParse(
                costStr.replaceAll(',', '').replaceAll('\$', '')) ??
            0.0;
        if (cost > 0) itemCount++;
        totalCost += cost;
        final category = (entry['category'] ?? '').toString();
        if (category.isNotEmpty) {
          byCategory[category] = (byCategory[category] ?? 0) + cost;
        }
        final riskLevel = (entry['riskLevel'] ?? '').toString().toLowerCase();
        if (riskLevel == 'high') highRiskCount++;
      }

      return ProjectSsherRollup(
        projectId: projectId,
        projectName: projectName,
        totalCost: totalCost,
        itemCount: itemCount,
        highRiskCount: highRiskCount,
        costByCategory: byCategory,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProjectSsherRollupService: failed to load $projectId: $e');
      }
      return null;
    }
  }
}
