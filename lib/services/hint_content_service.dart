import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ndu_project/models/page_hint_model.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';

/// Firestore-backed catalog for screen hint content and availability.
class HintContentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'page_hints';
  static final DateTime _seedTimestamp = DateTime(2024, 1, 1);

  static List<PageHintConfig> defaults() {
    final generated = <String, PageHintConfig>{
      for (final hint in _sidebarDefaults()) hint.pageId: hint,
    };
    for (final hint in _curatedDefaults()) {
      generated[hint.pageId] = hint;
    }
    final list = generated.values.toList()..sort(_sortHints);
    return list;
  }

  static List<PageHintConfig> _curatedDefaults() => [
        PageHintConfig(
          id: 'initiation_phase',
          pageId: 'initiation_phase',
          pageLabel: 'Scope Statement',
          title: 'Business Case',
          message:
              'Enter your project notes and detailed business case here. Use the formatting toolbar above text fields for bold, underline, headings, and undo functionality.',
          category: 'Initiation',
          description:
              'Guides first-time users through the initial business case and project notes experience.',
          enabled: true,
          createdAt: _seedTimestamp,
          updatedAt: _seedTimestamp,
        ),
        PageHintConfig(
          id: 'core_stakeholders',
          pageId: 'core_stakeholders',
          pageLabel: 'Core Stakeholders',
          title: 'Core Stakeholders',
          message:
              'Identify key stakeholders for each potential solution. Separate internal stakeholders (team members, departments) from external stakeholders (regulatory bodies, vendors, government agencies).',
          category: 'Planning',
          description:
              'Helps teams distinguish internal and external stakeholder groups for each solution path.',
          enabled: true,
          createdAt: _seedTimestamp,
          updatedAt: _seedTimestamp,
        ),
        PageHintConfig(
          id: 'potential_solutions',
          pageId: 'potential_solutions',
          pageLabel: 'Potential Solutions',
          title: 'Notification',
          message:
              'Although KAZ AI-generated outputs can provide valuable insights, please review and refine them as needed to ensure they align with your project requirements.',
          category: 'Planning',
          description:
              'Reminds users to validate AI-generated solution proposals before moving forward.',
          enabled: true,
          createdAt: _seedTimestamp,
          updatedAt: _seedTimestamp,
        ),
        PageHintConfig(
          id: 'risk_identification',
          pageId: 'risk_identification',
          pageLabel: 'Risk Identification',
          title: 'Risk Identification',
          message:
              'Identify up to 3 delivery risks per potential solution. Use "Generate risks" for AI suggestions tailored to each solution. Risks auto-save as you edit.',
          category: 'Risk',
          description:
              'Frames how risks should be captured and how the AI assist flow works on the screen.',
          enabled: true,
          createdAt: _seedTimestamp,
          updatedAt: _seedTimestamp,
        ),
        PageHintConfig(
          id: 'it_considerations',
          pageId: 'it_considerations',
          pageLabel: 'IT Considerations',
          title: 'IT Considerations',
          message:
              'List the core technology considerations for each potential solution. Click "Generate Technologies" to get AI suggestions tailored to each solution.',
          category: 'Architecture',
          description:
              'Introduces the core technology design prompts and AI generation entry point.',
          enabled: true,
          createdAt: _seedTimestamp,
          updatedAt: _seedTimestamp,
        ),
        PageHintConfig(
          id: 'infrastructure_considerations',
          pageId: 'infrastructure_considerations',
          pageLabel: 'Infrastructure Considerations',
          title: 'Infrastructure Considerations',
          message:
              'List the main infrastructure considerations for each potential solution. If suggestions look repetitive, refine each entry to match the specific solution.',
          category: 'Architecture',
          description:
              'Guides users to tailor infrastructure guidance to each solution instead of accepting repeated AI output.',
          enabled: true,
          createdAt: _seedTimestamp,
          updatedAt: _seedTimestamp,
        ),
        PageHintConfig(
          id: 'preferred_solution_analysis',
          pageId: 'preferred_solution_analysis',
          pageLabel: 'Preferred Solution Analysis',
          title: 'Preferred Solution Analysis',
          message:
              'Review each solution\'s analysis, then select your preferred option. Use "View More Details" to see full information before selecting. Complete this step before continuing to Work Breakdown Structure.',
          category: 'Decisioning',
          description:
              'Explains the evaluation and selection flow before moving into downstream planning.',
          enabled: true,
          createdAt: _seedTimestamp,
          updatedAt: _seedTimestamp,
        ),

        // ─── Inner-Page Navigation Hints ───────────────────────────────────

        PageHintConfig(
          id: 'design_planning_nav',
          pageId: 'design_planning_nav',
          pageLabel: 'Design Planning',
          title: 'Guided Multi-Section Navigation',
          message:
              'Design Planning is divided into 14 sequential sections. Use the navigation hint at the top to jump between sections. Complete or mark each section as "Not applicable" to unlock the next one.',
          category: 'Design Phase',
          description:
              'Inner-page navigation guide for the Design Planning multi-section form.',
          enabled: true,
          createdAt: _seedTimestamp,
          updatedAt: _seedTimestamp,
        ),
        PageHintConfig(
          id: 'planning_technology_nav',
          pageId: 'planning_technology_nav',
          pageLabel: 'Planning Technology',
          title: 'Technology Tabs Navigation',
          message:
              'This screen has 5 technology tabs: Inventory, AI Integrations, External Integrations, Definitions, and AI Recommendations. Use the navigation hint to switch between them quickly.',
          category: 'Planning',
          description:
              'Inner-page navigation guide for the Planning Technology tabbed interface.',
          enabled: true,
          createdAt: _seedTimestamp,
          updatedAt: _seedTimestamp,
        ),
        PageHintConfig(
          id: 'planning_contracting_nav',
          pageId: 'planning_contracting_nav',
          pageLabel: 'Planning Contracting',
          title: 'Contracting Workflow Tabs',
          message:
              'Navigate through 8 contracting workflow stages using the navigation hint. Each tab represents a phase from initial Overview through to Handoff.',
          category: 'Planning',
          description:
              'Inner-page navigation guide for the Planning Contracting workflow.',
          enabled: true,
          createdAt: _seedTimestamp,
          updatedAt: _seedTimestamp,
        ),
        PageHintConfig(
          id: 'interface_management_nav',
          pageId: 'interface_management_nav',
          pageLabel: 'Interface Management',
          title: 'Interface Management Sections',
          message:
              'This screen has 7 sections covering the full interface management lifecycle. Use the navigation hint to jump to Register, Architecture, RACI, Risks, Handoff, Maturity, or Audit Trail.',
          category: 'Execution',
          description:
              'Inner-page navigation guide for Interface Management.',
          enabled: true,
          createdAt: _seedTimestamp,
          updatedAt: _seedTimestamp,
        ),
        PageHintConfig(
          id: 'fep_procurement_nav',
          pageId: 'fep_procurement_nav',
          pageLabel: 'Procurement',
          title: 'Procurement Workflow Navigation',
          message:
              'Navigate 7 procurement stages using the navigation hint. Some tabs are locked until earlier stages are completed. The mini-map shows your current position in the workflow.',
          category: 'Front End Planning',
          description:
              'Inner-page navigation guide for the Procurement workflow.',
          enabled: true,
          createdAt: _seedTimestamp,
          updatedAt: _seedTimestamp,
        ),
        PageHintConfig(
          id: 'project_plan_nav',
          pageId: 'project_plan_nav',
          pageLabel: 'Project Plan',
          title: 'Project Plan Tabs',
          message:
              'The Project Plan screen has 5 tabs: Overview, Resources, Tasks, Budget, and Risks. Use the navigation hint to switch between planning views.',
          category: 'Planning',
          description:
              'Inner-page navigation guide for Project Plan.',
          enabled: true,
          createdAt: _seedTimestamp,
          updatedAt: _seedTimestamp,
        ),
        PageHintConfig(
          id: 'quality_management_nav',
          pageId: 'quality_management_nav',
          pageLabel: 'Quality Management',
          title: 'Quality Management Tabs',
          message:
              'Navigate between 5 quality management views: Plan, Targets, QA Tracking, QC Tracking, and Metrics using the navigation hint.',
          category: 'Execution',
          description:
              'Inner-page navigation guide for Quality Management.',
          enabled: true,
          createdAt: _seedTimestamp,
          updatedAt: _seedTimestamp,
        ),
        PageHintConfig(
          id: 'security_management_nav',
          pageId: 'security_management_nav',
          pageLabel: 'Security Management',
          title: 'Security Management Tabs',
          message:
              'This screen has 5 security management tabs: Dashboard, Roles, Permissions, Settings, and Access Logs. Use the navigation hint to move between them.',
          category: 'Execution',
          description:
              'Inner-page navigation guide for Security Management.',
          enabled: true,
          createdAt: _seedTimestamp,
          updatedAt: _seedTimestamp,
        ),
        PageHintConfig(
          id: 'ssher_stacked_nav',
          pageId: 'ssher_stacked_nav',
          pageLabel: 'SSHER',
          title: 'SSHER Category Navigation',
          message:
              'Switch between 5 SSHER categories: Safety, Security, Health, Environment, and Regulatory using the navigation hint at the top.',
          category: 'Execution',
          description:
              'Inner-page navigation guide for SSHER stacked screen.',
          enabled: true,
          createdAt: _seedTimestamp,
          updatedAt: _seedTimestamp,
        ),
        PageHintConfig(
          id: 'cost_analysis_nav',
          pageId: 'cost_analysis_nav',
          pageLabel: 'Cost Analysis',
          title: 'Benefit Categories Navigation',
          message:
              'This screen has 9 benefit categories. Use the compact navigation hint to quickly switch between Revenue, Cost Saving, Operational Efficiency, and more.',
          category: 'Planning',
          description:
              'Inner-page navigation guide for Cost Analysis benefit categories.',
          enabled: true,
          createdAt: _seedTimestamp,
          updatedAt: _seedTimestamp,
        ),
      ];

  static List<PageHintConfig> _sidebarDefaults() {
    return SidebarNavigationService.allItems.map((item) {
      final pageId = _hintPageIdForCheckpoint(item.checkpoint);
      final category =
          SidebarNavigationService.phaseForCheckpoint(item.checkpoint) ??
              'General';
      return PageHintConfig(
        id: pageId,
        pageId: pageId,
        pageLabel: item.label,
        title: item.label,
        message:
            'Use this workspace to complete the ${item.label} section. Review project context, capture the required details, and save progress before moving to the next sidebar page.',
        category: category,
        description:
            'Default guidance profile for the ${item.label} sidebar page.',
        enabled: true,
        createdAt: _seedTimestamp,
        updatedAt: _seedTimestamp,
      );
    }).toList();
  }

  static Stream<List<PageHintConfig>> watchHints() {
    return _firestore
        .collection(_collectionName)
        .snapshots(includeMetadataChanges: false)
        .map((snapshot) {
      final hints = snapshot.docs
          .map((doc) => PageHintConfig.fromJson(doc.data(), doc.id))
          .toList();
      hints.sort(_sortHints);
      return hints;
    });
  }

  static Future<List<PageHintConfig>> getAllHints() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      final hints = snapshot.docs
          .map((doc) => PageHintConfig.fromJson(doc.data(), doc.id))
          .toList();
      hints.sort(_sortHints);
      return hints;
    } catch (error) {
      debugPrint('HintContentService.getAllHints error: $error');
      return const <PageHintConfig>[];
    }
  }

  static Future<PageHintConfig?> getHint(String pageId) async {
    try {
      final doc =
          await _firestore.collection(_collectionName).doc(pageId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return PageHintConfig.fromJson(data, doc.id);
    } catch (error) {
      debugPrint('HintContentService.getHint error for $pageId: $error');
      return null;
    }
  }

  static Future<PageHintConfig> getResolvedHint({
    required String pageId,
    required String fallbackTitle,
    required String fallbackMessage,
  }) async {
    final remote = await getHint(pageId);
    if (remote != null) return remote;
    return defaultForPage(
          pageId,
          fallbackTitle: fallbackTitle,
          fallbackMessage: fallbackMessage,
        ) ??
        PageHintConfig(
          id: pageId,
          pageId: pageId,
          pageLabel: _humanize(pageId),
          title: fallbackTitle,
          message: fallbackMessage,
          category: 'General',
          description: 'Ad hoc hint configuration for $pageId.',
          enabled: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
  }

  static List<PageHintConfig> mergeWithDefaults(List<PageHintConfig> stored) {
    final merged = <String, PageHintConfig>{
      for (final hint in defaults()) hint.pageId: hint,
      for (final hint in stored) hint.pageId: hint,
    };
    final list = merged.values.toList()..sort(_sortHints);
    return list;
  }

  static PageHintConfig? defaultForPage(
    String pageId, {
    String? fallbackTitle,
    String? fallbackMessage,
  }) {
    for (final hint in defaults()) {
      if (hint.pageId == pageId) return hint;
    }
    if ((fallbackTitle ?? '').trim().isEmpty ||
        (fallbackMessage ?? '').trim().isEmpty) {
      return null;
    }
    return PageHintConfig(
      id: pageId,
      pageId: pageId,
      pageLabel: _humanize(pageId),
      title: fallbackTitle!.trim(),
      message: fallbackMessage!.trim(),
      category: 'General',
      description: 'Fallback hint for $pageId.',
      enabled: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Future<bool> saveHint(PageHintConfig hint) async {
    try {
      final normalized = hint.copyWith(
        id: hint.pageId,
        pageId: hint.pageId.trim(),
        pageLabel: hint.pageLabel.trim(),
        title: hint.title.trim(),
        message: hint.message.trim(),
        category:
            hint.category.trim().isEmpty ? 'General' : hint.category.trim(),
        description: hint.description?.trim().isEmpty ?? true
            ? null
            : hint.description?.trim(),
        updatedAt: DateTime.now(),
      );
      await _firestore
          .collection(_collectionName)
          .doc(normalized.pageId)
          .set(normalized.toJson(), SetOptions(merge: true));
      return true;
    } catch (error) {
      debugPrint('HintContentService.saveHint error: $error');
      return false;
    }
  }

  static Future<bool> deleteHint(String pageId) async {
    try {
      await _firestore.collection(_collectionName).doc(pageId).delete();
      return true;
    } catch (error) {
      debugPrint('HintContentService.deleteHint error: $error');
      return false;
    }
  }

  static Future<void> seedDefaultHints({bool overwrite = false}) async {
    final batch = _firestore.batch();
    final collection = _firestore.collection(_collectionName);

    for (final hint in defaults()) {
      final docRef = collection.doc(hint.pageId);
      if (!overwrite) {
        final existing = await docRef.get();
        if (existing.exists) continue;
      }
      batch.set(docRef, hint.toJson(), SetOptions(merge: true));
    }

    await batch.commit();
  }

  static Future<void> setAllHintsEnabled(bool enabled) async {
    final existing = await getAllHints();
    final merged = mergeWithDefaults(existing);
    final batch = _firestore.batch();
    final collection = _firestore.collection(_collectionName);
    final now = DateTime.now();

    for (final hint in merged) {
      batch.set(
        collection.doc(hint.pageId),
        hint
            .copyWith(
              enabled: enabled,
              updatedAt: now,
            )
            .toJson(),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  static int _sortHints(PageHintConfig a, PageHintConfig b) {
    final aIndex = _sidebarSortIndex(a.pageId);
    final bIndex = _sidebarSortIndex(b.pageId);
    if (aIndex != bIndex) return aIndex.compareTo(bIndex);
    final category =
        a.category.toLowerCase().compareTo(b.category.toLowerCase());
    if (category != 0) return category;
    return a.pageLabel.toLowerCase().compareTo(b.pageLabel.toLowerCase());
  }

  static String _hintPageIdForCheckpoint(String checkpoint) {
    if (checkpoint == 'business_case') return 'initiation_phase';
    return checkpoint;
  }

  static int _sidebarSortIndex(String pageId) {
    final index = SidebarNavigationService.allItems.indexWhere(
      (item) => _hintPageIdForCheckpoint(item.checkpoint) == pageId,
    );
    if (index == -1) return 10000;
    return index;
  }

  static String _humanize(String value) {
    final cleaned = value.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    if (cleaned.isEmpty) return 'Untitled Hint';
    return cleaned
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }
}
