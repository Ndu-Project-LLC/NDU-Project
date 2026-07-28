import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/widgets/execution_phase_ui.dart';
import 'package:ndu_project/widgets/launch_editable_section.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';

class ExecutionSectionSpec {
  const ExecutionSectionSpec({
    required this.key,
    required this.title,
    required this.description,
    this.includeStatus = true,
    this.titleLabel = 'Title',
  });

  final String key;
  final String title;
  final String description;
  final bool includeStatus;
  final String titleLabel;
}

class ExecutionPhasePage extends StatefulWidget {
  const ExecutionPhasePage({
    super.key,
    required this.pageKey,
    required this.title,
    required this.subtitle,
    required this.sections,
    this.introText,
    this.navigation,
  });

  final String pageKey;
  final String title;
  final String subtitle;
  final String? introText;
  final List<ExecutionSectionSpec> sections;
  final PhaseNavigationSpec? navigation;

  @override
  State<ExecutionPhasePage> createState() => _ExecutionPhasePageState();
}

class _ExecutionPhasePageState extends State<ExecutionPhasePage> {
  final Map<String, List<LaunchEntry>> _sectionData = {};
  bool _loading = true;
  Timer? _autoSaveDebounce;

  String? get _projectId {
    try {
      final provider = ProjectDataInherited.maybeOf(context);
      return provider?.projectData.projectId;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    for (final section in widget.sections) {
      _sectionData[section.key] = <LaunchEntry>[];
    }
    _loadData();
  }

  Future<void> _loadData() async {
    final String? projectId = _projectId;
    if (projectId == null || projectId.isEmpty) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final data = await ExecutionPhaseService.loadPageData(
        projectId: projectId,
        pageKey: widget.pageKey,
      );

      if (!mounted) return;
      setState(() {
        if (data != null && data.isNotEmpty) {
          _sectionData
            ..clear()
            ..addAll(data);
        }
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading execution phase data: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);
    final double horizontalPadding = isMobile ? 16 : 32;

    return ResponsiveScaffold(
      activeItemLabel: widget.title,
      appBarTitle: widget.title,
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: isMobile ? 16 : 28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            for (final section in widget.sections) ...[
              LaunchEditableSection(
                title: section.title,
                description: section.description,
                entries: _sectionData[section.key]!,
                onAdd: () => _addEntry(_sectionData[section.key]!, section),
                onRemove: (index) => _removeEntry(section.key, index),
                onEdit: (index, entry) => _editEntry(
                  _sectionData[section.key]!,
                  section,
                  index,
                  entry,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (widget.navigation != null) ...[
              const SizedBox(height: 24),
              LaunchPhaseNavigation(
                backLabel: widget.navigation!.backLabel,
                nextLabel: widget.navigation!.nextLabel,
                onBack: widget.navigation!.onBack,
                onNext: widget.navigation!.onNext,
              ),
            ],
            const SizedBox(height: 48),
          ],
        ),
      ),
      floatingActionButton: const KazAiChatBubble(positioned: false),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final List<Widget> metadata = widget.introText == null
        ? const <Widget>[]
        : [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                widget.introText!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF475569),
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ];

    return ExecutionPageHeader(
      badge: 'Execution Phase',
      title: widget.title,
      description: _loading ? '${widget.subtitle} · Loading...' : widget.subtitle,
      metadata: metadata,
    );
  }

  Future<void> _addEntry(
    List<LaunchEntry> target,
    ExecutionSectionSpec section,
  ) async {
    final LaunchEntry? entry = await showLaunchEntryDialog(
      context,
      titleLabel: section.titleLabel,
      detailsLabel: 'Details',
      includeStatus: section.includeStatus,
    );
    if (entry != null && mounted) {
      setState(() => target.add(entry));
      _autoSave();
    }
  }

  Future<void> _editEntry(
    List<LaunchEntry> target,
    ExecutionSectionSpec section,
    int index,
    LaunchEntry currentEntry,
  ) async {
    final LaunchEntry? entry = await showLaunchEntryDialog(
      context,
      titleLabel: section.titleLabel,
      detailsLabel: 'Details',
      includeStatus: section.includeStatus,
      initialEntry: currentEntry,
    );
    if (entry != null && mounted) {
      setState(() => target[index] = entry);
      _autoSave();
    }
  }

  void _removeEntry(String sectionKey, int index) {
    setState(() => _sectionData[sectionKey]!.removeAt(index));
    _autoSave();
  }

  void _autoSave() {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _persistChanges();
      }
    });
  }

  Future<void> _persistChanges() async {
    final String? projectId = _projectId;
    if (projectId == null || projectId.isEmpty) return;

    try {
      await ExecutionPhaseService.savePageData(
        projectId: projectId,
        pageKey: widget.pageKey,
        sections: _sectionData,
        userId: FirebaseAuth.instance.currentUser?.uid,
      );
    } catch (e) {
      debugPrint('Error persisting execution phase data: $e');
    }
  }
}

class PhaseNavigationSpec {
  const PhaseNavigationSpec({
    required this.backLabel,
    required this.nextLabel,
    required this.onBack,
    required this.onNext,
  });

  final String backLabel;
  final String nextLabel;
  final VoidCallback onBack;
  final VoidCallback onNext;
}
