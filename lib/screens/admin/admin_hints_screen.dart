import 'package:flutter/material.dart';
import 'package:ndu_project/models/page_hint_model.dart';
import 'package:ndu_project/services/hint_content_service.dart';
import 'package:ndu_project/services/hint_service.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';

class AdminHintsScreen extends StatefulWidget {
  const AdminHintsScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminHintsScreen()),
    );
  }

  @override
  State<AdminHintsScreen> createState() => _AdminHintsScreenState();
}

class _AdminHintsScreenState extends State<AdminHintsScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _statusFilter = 'all';
  String _categoryFilter = 'all';
  bool _deviceDisableViewedHints = false;
  Set<String> _deviceViewedPages = const <String>{};
  bool _localSettingsLoading = true;
  bool _seedInFlight = false;
  bool _bulkUpdateInFlight = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadLocalSettings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalSettings() async {
    final disableViewedHints = await HintService.disableViewedHints();
    final viewedPages = await HintService.viewedPages();
    if (!mounted) return;
    setState(() {
      _deviceDisableViewedHints = disableViewedHints;
      _deviceViewedPages = viewedPages;
      _localSettingsLoading = false;
    });
  }

  Future<void> _seedDefaultHints() async {
    setState(() => _seedInFlight = true);
    try {
      await HintContentService.seedDefaultHints();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default hint catalog initialized.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _seedInFlight = false);
    }
  }

  Future<void> _setAllHintsEnabled(bool enabled) async {
    setState(() => _bulkUpdateInFlight = true);
    try {
      await HintContentService.setAllHintsEnabled(enabled);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'All hint experiences are now enabled.'
                : 'All hint experiences are now disabled.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _bulkUpdateInFlight = false);
    }
  }

  Future<void> _setDeviceDisableViewedHints(bool value) async {
    await HintService.setDisableViewedHints(value);
    if (!mounted) return;
    setState(() => _deviceDisableViewedHints = value);
  }

  Future<void> _resetDeviceHintHistory() async {
    await HintService.enableAllHints();
    await _loadLocalSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hint replay reset for this device.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _toggleHintEnabled(PageHintConfig hint, bool enabled) async {
    final success = await HintContentService.saveHint(
      hint.copyWith(
        enabled: enabled,
        updatedAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${hint.pageLabel} ${enabled ? 'enabled' : 'disabled'}.'
              : 'Could not update ${hint.pageLabel}.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    PageHintConfig hint, {
    bool isNew = false,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final defaultHint = HintContentService.defaultForPage(hint.pageId);
    final updated = await showDialog<PageHintConfig>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _HintEditorDialog(
        hint: hint,
        defaultHint: defaultHint,
        isNew: isNew,
      ),
    );

    if (updated == null) return;
    final success = await HintContentService.saveHint(updated);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? isNew
                  ? 'Hint profile created.'
                  : 'Hint profile updated.'
              : 'Unable to save hint profile.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openCreateHint(BuildContext context) async {
    final now = DateTime.now();
    final draft = PageHintConfig(
      id: '',
      pageId: '',
      pageLabel: '',
      title: '',
      message: '',
      category: 'General',
      description: '',
      enabled: true,
      createdAt: now,
      updatedAt: now,
    );
    await _openEditor(context, draft, isNew: true);
  }

  Future<void> _previewHint(PageHintConfig hint) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _colorForCategory(hint.category).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.tips_and_updates_outlined,
                      color: _colorForCategory(hint.category),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hint.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${hint.pageLabel} • ${hint.category}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                hint.message,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Disable hints for pages I’ve viewed before.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    Switch(
                      value: _deviceDisableViewedHints,
                      onChanged: (_) {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: _hintActionColor,
                    foregroundColor: _hintActionForegroundColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Close Preview'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Row(
          children: [
            Icon(Icons.tips_and_updates_outlined,
                color: Color(0xFFFFC107), size: 28),
            SizedBox(width: 12),
            Text(
              'Hints',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _openCreateHint(context),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Create Hint'),
            style: TextButton.styleFrom(
              backgroundColor: _hintActionColor.withOpacity(0.18),
              foregroundColor: _hintActionForegroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: UnifiedProfileMenu(compact: true),
          ),
        ],
      ),
      body: SafeArea(
        top: true,
        child: StreamBuilder<List<PageHintConfig>>(
          stream: HintContentService.watchHints(),
          builder: (context, snapshot) {
            final remoteHints = snapshot.data ?? const <PageHintConfig>[];
            final hints = HintContentService.mergeWithDefaults(remoteHints);
            final categories = <String>{
              'all',
              ...hints.map((hint) => hint.category),
            }.toList()
              ..sort((a, b) {
                if (a == 'all') return -1;
                if (b == 'all') return 1;
                return a.toLowerCase().compareTo(b.toLowerCase());
              });
            final filteredHints = _applyFilters(hints);
            final activeCount = hints.where((hint) => hint.enabled).length;
            final disabledCount = hints.length - activeCount;
            final customizedCount = remoteHints.length;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHero(
                    totalCount: hints.length,
                    activeCount: activeCount,
                    disabledCount: disabledCount,
                    customizedCount: customizedCount,
                  ),
                  const SizedBox(height: 22),
                  _buildCommandDeck(),
                  const SizedBox(height: 22),
                  _buildFilters(categories),
                  const SizedBox(height: 20),
                  if (filteredHints.isEmpty)
                    _buildEmptyState()
                  else
                    _buildHintGrid(filteredHints),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero({
    required int totalCount,
    required int activeCount,
    required int disabledCount,
    required int customizedCount,
  }) {
    final stats = [
      _HeroMetricData(
        label: 'Hint Profiles',
        value: '$totalCount',
        icon: Icons.space_dashboard_outlined,
        color: const Color(0xFF4F46E5),
      ),
      _HeroMetricData(
        label: 'Active Right Now',
        value: '$activeCount',
        icon: Icons.visibility_outlined,
        color: const Color(0xFF16A34A),
      ),
      _HeroMetricData(
        label: 'Disabled',
        value: '$disabledCount',
        icon: Icons.visibility_off_outlined,
        color: const Color(0xFFF59E0B),
      ),
      _HeroMetricData(
        label: 'Customized',
        value: '$customizedCount',
        icon: Icons.auto_fix_high_outlined,
        color: const Color(0xFF7C3AED),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool stack = constraints.maxWidth < 1040;
          final double leftWidth =
              stack ? constraints.maxWidth : constraints.maxWidth * 0.47;
          final double rightWidth =
              stack ? constraints.maxWidth : constraints.maxWidth * 0.47;

          return Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              SizedBox(
                width: leftWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Experience Guidance Control',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Shape every first-run cue, assistant nudge, and guided moment from one deliberate control surface.',
                      style: TextStyle(
                        fontSize: 31,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Hints now have a dedicated operating surface: enable or mute them per screen, rewrite the copy, preview the dialog experience, and replay onboarding on this device without touching code.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: const [
                        _HeroChip(
                          icon: Icons.edit_note_outlined,
                          label: 'Per-screen content control',
                        ),
                        _HeroChip(
                          icon: Icons.tune_outlined,
                          label: 'Enable/disable instantly',
                        ),
                        _HeroChip(
                          icon: Icons.rocket_launch_outlined,
                          label: 'Replay onboarding on demand',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: rightWidth,
                child: Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: stats
                      .map(
                        (metric) => _HeroMetricCard(
                          data: metric,
                          width: stack ? rightWidth : (rightWidth - 14) / 2,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCommandDeck() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool stack = constraints.maxWidth < 980;
        final double panelWidth =
            stack ? constraints.maxWidth : (constraints.maxWidth - 18) / 2;

        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: [
            _CommandPanel(
              width: panelWidth,
              title: 'Global Catalog Controls',
              subtitle:
                  'Seed the platform hint catalog, then control visibility at scale across every connected hint surface.',
              accent: const Color(0xFF4F46E5),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ActionPillButton(
                    label:
                        _seedInFlight ? 'Initializing…' : 'Initialize Defaults',
                    icon: Icons.auto_fix_high_outlined,
                    accent: const Color(0xFF4F46E5),
                    onPressed: _seedInFlight ? null : _seedDefaultHints,
                  ),
                  _ActionPillButton(
                    label: _bulkUpdateInFlight ? 'Applying…' : 'Enable All',
                    icon: Icons.visibility_outlined,
                    accent: const Color(0xFF16A34A),
                    onPressed: _bulkUpdateInFlight
                        ? null
                        : () => _setAllHintsEnabled(true),
                  ),
                  _ActionPillButton(
                    label: _bulkUpdateInFlight ? 'Applying…' : 'Disable All',
                    icon: Icons.visibility_off_outlined,
                    accent: const Color(0xFFF59E0B),
                    onPressed: _bulkUpdateInFlight
                        ? null
                        : () => _setAllHintsEnabled(false),
                  ),
                ],
              ),
            ),
            _CommandPanel(
              width: panelWidth,
              title: 'This Device Preview Controls',
              subtitle:
                  'Tune replay behavior for this browser or device so you can QA onboarding sequences exactly as users will see them.',
              accent: const Color(0xFFFFC107),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Mute hints for screens already viewed here',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Keeps first-time hints for new screens while suppressing repeat pop-ups on this device.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      _localSettingsLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Switch(
                              value: _deviceDisableViewedHints,
                              onChanged: _setDeviceDisableViewedHints,
                            ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MetaChip(
                        label: 'Viewed here',
                        value: '${_deviceViewedPages.length}',
                        accent: const Color(0xFF4F46E5),
                      ),
                      _MetaChip(
                        label: 'Replay mode',
                        value: _deviceDisableViewedHints ? 'Focused' : 'Full',
                        accent: const Color(0xFF16A34A),
                      ),
                      _ActionPillButton(
                        label: 'Replay All Hints Here',
                        icon: Icons.restart_alt_outlined,
                        accent: const Color(0xFFFFC107),
                        onPressed: _resetDeviceHintHistory,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilters(List<String> categories) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VoiceTextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by screen, page id, category, or hint copy…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _searchController.clear(),
                    ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF4F46E5)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ..._buildChoiceRow(
                title: 'Status',
                options: const ['all', 'active', 'disabled', 'viewed', 'new'],
                selected: _statusFilter,
                onSelected: (value) => setState(() => _statusFilter = value),
              ),
              ..._buildChoiceRow(
                title: 'Category',
                options: categories,
                selected: _categoryFilter,
                onSelected: (value) => setState(() => _categoryFilter = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChoiceRow({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return [
      Padding(
        padding: const EdgeInsets.only(right: 2, top: 6),
        child: Text(
          '$title:',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
          ),
        ),
      ),
      ...options.map(
        (option) => ChoiceChip(
          label: Text(option == 'all' ? 'All' : _chipTitle(option)),
          selected: selected == option,
          onSelected: (_) => onSelected(option),
          selectedColor: _colorForCategory(option).withOpacity(0.14),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: selected == option
                ? _colorForCategory(option).withOpacity(0.35)
                : const Color(0xFFE5E7EB),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected == option
                ? _colorForCategory(option)
                : const Color(0xFF374151),
          ),
        ),
      ),
    ];
  }

  Widget _buildHintGrid(List<PageHintConfig> hints) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool mobile = constraints.maxWidth < 760;
        final bool tablet = constraints.maxWidth < 1220;
        final int columns = mobile ? 1 : (tablet ? 2 : 3);
        final double spacing = 18;
        final double cardWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: hints
              .map(
                (hint) => _HintCard(
                  hint: hint,
                  width: cardWidth,
                  accent: _colorForCategory(hint.category),
                  viewedOnThisDevice: _deviceViewedPages.contains(hint.pageId),
                  onPreview: () => _previewHint(hint),
                  onEdit: () => _openEditor(context, hint),
                  onToggleEnabled: (value) => _toggleHintEnabled(hint, value),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_outlined,
            size: 52,
            color: Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 12),
          const Text(
            'No hints match your current filters.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Clear the search or change filters to reveal the rest of the hint catalog.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  List<PageHintConfig> _applyFilters(List<PageHintConfig> hints) {
    final query = _searchController.text.trim().toLowerCase();
    return hints.where((hint) {
      if (_categoryFilter != 'all' && hint.category != _categoryFilter) {
        return false;
      }

      switch (_statusFilter) {
        case 'active':
          if (!hint.enabled) return false;
          break;
        case 'disabled':
          if (hint.enabled) return false;
          break;
        case 'viewed':
          if (!_deviceViewedPages.contains(hint.pageId)) return false;
          break;
        case 'new':
          if (_deviceViewedPages.contains(hint.pageId)) return false;
          break;
      }

      if (query.isEmpty) return true;
      final haystack = [
        hint.pageLabel,
        hint.pageId,
        hint.title,
        hint.message,
        hint.category,
        hint.description ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({
    required this.hint,
    required this.width,
    required this.accent,
    required this.viewedOnThisDevice,
    required this.onPreview,
    required this.onEdit,
    required this.onToggleEnabled,
  });

  final PageHintConfig hint;
  final double width;
  final Color accent;
  final bool viewedOnThisDevice;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggleEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.tips_and_updates_outlined, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hint.pageLabel,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hint.pageId,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: hint.enabled,
                onChanged: onToggleEnabled,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                label: 'Category',
                value: hint.category,
                accent: accent,
              ),
              _MetaChip(
                label: 'State',
                value: hint.enabled ? 'Enabled' : 'Disabled',
                accent: hint.enabled
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFF59E0B),
              ),
              if (viewedOnThisDevice)
                _MetaChip(
                  label: 'Device',
                  value: 'Viewed',
                  accent: const Color(0xFF4F46E5),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            hint.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hint.message,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.55,
              color: Color(0xFF4B5563),
            ),
          ),
          if ((hint.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              hint.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPreview,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Preview'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _hintActionColor.withOpacity(0.12),
                    foregroundColor: _hintActionForegroundColor,
                    side: BorderSide(color: _hintActionColor.withOpacity(0.7)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _hintActionColor,
                    foregroundColor: _hintActionForegroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Updated ${_relativeTime(hint.updatedAt)}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintEditorDialog extends StatefulWidget {
  const _HintEditorDialog({
    required this.hint,
    required this.defaultHint,
    required this.isNew,
  });

  final PageHintConfig hint;
  final PageHintConfig? defaultHint;
  final bool isNew;

  @override
  State<_HintEditorDialog> createState() => _HintEditorDialogState();
}

class _HintEditorDialogState extends State<_HintEditorDialog> {
  late final TextEditingController _pageIdController;
  late final TextEditingController _pageLabelController;
  late final TextEditingController _categoryController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _messageController;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _pageIdController = TextEditingController(text: widget.hint.pageId);
    _pageLabelController = TextEditingController(text: widget.hint.pageLabel);
    _categoryController = TextEditingController(text: widget.hint.category);
    _titleController = TextEditingController(text: widget.hint.title);
    _descriptionController =
        TextEditingController(text: widget.hint.description ?? '');
    _messageController = TextEditingController(text: widget.hint.message);
    _enabled = widget.hint.enabled;
  }

  @override
  void dispose() {
    _pageIdController.dispose();
    _pageLabelController.dispose();
    _categoryController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _restoreDefault() {
    final defaultHint = widget.defaultHint;
    if (defaultHint == null) return;
    setState(() {
      _pageIdController.text = defaultHint.pageId;
      _pageLabelController.text = defaultHint.pageLabel;
      _categoryController.text = defaultHint.category;
      _titleController.text = defaultHint.title;
      _descriptionController.text = defaultHint.description ?? '';
      _messageController.text = defaultHint.message;
      _enabled = defaultHint.enabled;
    });
  }

  void _save() {
    final pageId = _pageIdController.text.trim();
    final pageLabel = _pageLabelController.text.trim();
    final category = _categoryController.text.trim();
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (pageId.isEmpty ||
        pageLabel.isEmpty ||
        category.isEmpty ||
        title.isEmpty ||
        message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Page id, screen label, category, title, and message are required.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      widget.hint.copyWith(
        id: pageId,
        pageId: pageId,
        pageLabel: pageLabel,
        category: category,
        title: title,
        message: message,
        description: _descriptionController.text.trim(),
        enabled: _enabled,
        createdAt: widget.hint.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1120),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool stack = constraints.maxWidth < 920;
            final Widget form = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isNew ? 'Create Hint Profile' : 'Edit Hint Profile',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Control the exact guidance users see when a screen wants to introduce context, onboarding, or critical instructions.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _DialogField(
                        controller: _pageIdController,
                        label: 'Page ID',
                        hintText: 'e.g. initiation_phase',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _DialogField(
                        controller: _pageLabelController,
                        label: 'Screen Label',
                        hintText: 'e.g. Initiation Phase',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _DialogField(
                        controller: _categoryController,
                        label: 'Category',
                        hintText: 'e.g. Planning',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SwitchListTile.adaptive(
                        value: _enabled,
                        onChanged: (value) => setState(() => _enabled = value),
                        title: const Text(
                          'Hint Enabled',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: const Text(
                          'Disable this to stop the hint from appearing altogether.',
                          style: TextStyle(fontSize: 12),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _DialogField(
                  controller: _titleController,
                  label: 'Dialog Title',
                  hintText: 'Enter the hint headline',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                _DialogField(
                  controller: _descriptionController,
                  label: 'Internal Description',
                  hintText: 'What does this hint help with?',
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                _DialogField(
                  controller: _messageController,
                  label: 'Hint Message',
                  hintText: 'Write the exact hint content shown to users',
                  maxLines: 8,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            );

            final Widget preview = _HintPreviewPane(
              accent: _colorForCategory(_categoryController.text),
              pageLabel: _pageLabelController.text.trim().isEmpty
                  ? 'Untitled Screen'
                  : _pageLabelController.text.trim(),
              category: _categoryController.text.trim().isEmpty
                  ? 'General'
                  : _categoryController.text.trim(),
              title: _titleController.text.trim().isEmpty
                  ? 'Untitled Hint'
                  : _titleController.text.trim(),
              message: _messageController.text.trim().isEmpty
                  ? 'Your hint preview appears here as you write.'
                  : _messageController.text.trim(),
              enabled: _enabled,
            );

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stack) ...[
                    form,
                    const SizedBox(height: 20),
                    preview,
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 11, child: form),
                        const SizedBox(width: 20),
                        Expanded(flex: 9, child: preview),
                      ],
                    ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      if (widget.defaultHint != null)
                        TextButton.icon(
                          onPressed: _restoreDefault,
                          icon: const Icon(Icons.restore_outlined),
                          label: const Text('Restore System Default'),
                        ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save Hint'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _hintActionColor,
                          foregroundColor: _hintActionForegroundColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HintPreviewPane extends StatelessWidget {
  const _HintPreviewPane({
    required this.accent,
    required this.pageLabel,
    required this.category,
    required this.title,
    required this.message,
    required this.enabled,
  });

  final Color accent;
  final String pageLabel;
  final String category;
  final String title;
  final String message;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Preview',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$pageLabel • $category',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(color: accent.withOpacity(0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.info_outline, color: accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Disable hints for pages I’ve viewed before.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      Switch(value: false, onChanged: enabled ? (_) {} : null),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Got it'),
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

class _CommandPanel extends StatelessWidget {
  const _CommandPanel({
    required this.width,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.child,
  });

  final double width;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _HeroMetricData {
  const _HeroMetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _HeroMetricCard extends StatelessWidget {
  const _HeroMetricCard({required this.data, required this.width});

  final _HeroMetricData data;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: data.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: data.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
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

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF111827)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withOpacity(0.16)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF111827),
          ),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  const _ActionPillButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: accent.withOpacity(0.12),
        foregroundColor: accent,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.onChanged,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        VoiceTextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF4F46E5)),
            ),
          ),
        ),
      ],
    );
  }
}

Color _colorForCategory(String category) {
  final normalized = category.trim().toLowerCase();
  if (normalized.contains('init')) return const Color(0xFF4F46E5);
  if (normalized.contains('risk')) return const Color(0xFFDC2626);
  if (normalized.contains('arch')) return const Color(0xFF0EA5E9);
  if (normalized.contains('decision')) return const Color(0xFF7C3AED);
  if (normalized.contains('plan')) return const Color(0xFF16A34A);
  if (normalized.contains('new')) return const Color(0xFF4F46E5);
  if (normalized.contains('disabled')) return const Color(0xFFF59E0B);
  if (normalized.contains('active')) return const Color(0xFF16A34A);
  if (normalized.contains('viewed')) return const Color(0xFF4F46E5);
  return const Color(0xFFFFC107);
}

String _chipTitle(String value) {
  final normalized = value.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) return 'Unknown';
  return normalized
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) =>
          '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

String _relativeTime(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  final months = (diff.inDays / 30).floor();
  if (months < 12) return '${months}mo ago';
  final years = (months / 12).floor();
  return '${years}y ago';
}

const Color _pageBackgroundColor = Color(0xFFFFFFFF);
const Color _hintActionColor = Color(0xFFFFC107);
const Color _hintActionForegroundColor = Color(0xFF111827);
