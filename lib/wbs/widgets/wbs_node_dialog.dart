/// WBS Node Dialog — world-class modal for adding / editing WBS nodes.
///
/// Replaces the previous basic AlertDialog with a hero-header, smart
/// suggestion chips, animated focus states, real-time char counter,
/// live preview chip, and footer action bar — all rendered in the
/// NDU yellow theme (LightModeColors.accent / lightPrimaryContainer).
///
/// Used by [WBSBuilderScreen] for both Add and Edit flows.

library;

import 'package:flutter/material.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';

/// Open the world-class "Add Node" dialog.
///
/// [level] is the depth (1-based) of the new node.
/// [levelLabel] is the framework-aware label (e.g. "Deliverable").
/// [parentId] is the parent node ID to attach the new node under.
/// [parentName] optionally shows the parent's name in the hero subtitle.
/// [framework] is used to drive smart suggestion chips.
Future<void> showWBSAddNodeDialog(
  BuildContext context, {
  required WBSProvider provider,
  required int level,
  required String levelLabel,
  required String? parentId,
  String? parentName,
  WBSFramework? framework,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0xFF0B1220).withValues(alpha: 0.55),
    builder: (ctx) => _WBSNodeDialog(
      mode: _WBSNodeDialogMode.add,
      provider: provider,
      level: level,
      levelLabel: levelLabel,
      parentId: parentId,
      parentName: parentName,
      framework: framework,
    ),
  );
}

/// Open the world-class "Edit Node" dialog.
Future<void> showWBSEditNodeDialog(
  BuildContext context, {
  required WBSProvider provider,
  required WBSNode node,
  required WBSFramework framework,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0xFF0B1220).withValues(alpha: 0.55),
    builder: (ctx) => _WBSNodeDialog(
      mode: _WBSNodeDialogMode.edit,
      provider: provider,
      level: node.level.value,
      levelLabel: nodeLevelLabel(node, framework),
      parentId: null,
      parentName: null,
      framework: framework,
      existingNode: node,
    ),
  );
}

enum _WBSNodeDialogMode { add, edit }

class _WBSNodeDialog extends StatefulWidget {
  const _WBSNodeDialog({
    required this.mode,
    required this.provider,
    required this.level,
    required this.levelLabel,
    required this.parentId,
    required this.parentName,
    required this.framework,
    this.existingNode,
  });

  final _WBSNodeDialogMode mode;
  final WBSProvider provider;
  final int level;
  final String levelLabel;
  final String? parentId;
  final String? parentName;
  final WBSFramework? framework;
  final WBSNode? existingNode;

  @override
  State<_WBSNodeDialog> createState() => _WBSNodeDialogState();
}

class _WBSNodeDialogState extends State<_WBSNodeDialog>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final FocusNode _nameFocus;
  late final FocusNode _descFocus;
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  String? _selectedMethodology;
  bool _isHybrid = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingNode;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _descCtrl = TextEditingController(text: existing?.description ?? '');
    _nameFocus = FocusNode();
    _descFocus = FocusNode();

    _isHybrid =
        widget.provider.wbs?.methodology == ProjectMethodology.hybrid;
    _selectedMethodology = existing?.methodology;

    _nameCtrl.addListener(() {
      final err = _nameCtrl.text.trim().isEmpty;
      if (err != _hasError) setState(() => _hasError = err);
    });

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();

    // Autofocus name field after the entrance animation settles.
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _nameFocus.dispose();
    _descFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  // Smart suggestion chips — framework + level aware.
  List<String> get _suggestions {
    final fm = widget.framework;
    if (fm == null) return const [];
    final lvl = widget.level;
    // Generic deliverable-noun suggestions for level 1.
    if (lvl == 1) {
      switch (fm) {
        case WBSFramework.agile:
          return const [
            'Onboarding Epic',
            'Activation Epic',
            'Retention Epic',
            'Monetization Epic',
            'Platform Epic',
          ];
        case WBSFramework.waterfallDeliverable:
          return const [
            'Platform Design',
            'Software Development',
            'Testing & QA',
            'Deployment & Rollout',
            'Training & Handover',
          ];
        case WBSFramework.waterfallDiscipline:
          return const [
            'Civil & Structural',
            'Mechanical',
            'Electrical',
            'Instrumentation & Controls',
            'Commissioning',
          ];
        case WBSFramework.waterfallFunctional:
          return const [
            'Engineering',
            'Procurement',
            'Construction',
            'Quality Assurance',
            'Operations',
          ];
        case WBSFramework.waterfallGeographic:
          return const [
            'Northern Region',
            'Southern Region',
            'Coastal District',
            'Highland Site',
            'Central Hub',
          ];
        case WBSFramework.waterfallPhase:
          return const [
            'Initiation Phase',
            'Design Phase',
            'Implementation Phase',
            'Verification Phase',
            'Closeout Phase',
          ];
      }
    }
    // Level 2+ suggestions — keep generic, framework-agnostic work packages.
    if (lvl == 2) {
      return const [
        'Detailed Design',
        'Procurement Package',
        'Fabrication',
        'Site Preparation',
        'Integration & Test',
      ];
    }
    if (lvl >= 3) {
      return const [
        'Specification Document',
        'Vendor Selection',
        'Inspection & Sign-off',
        'Installation',
        'Documentation Pack',
      ];
    }
    return const [];
  }

  String get _hintText {
    final lvl = widget.level;
    if (lvl <= 2) {
      return 'Use a deliverable noun (e.g. “Platform Design”) — not an activity verb.';
    }
    return 'Describe the work package or activity (e.g. “Conduct integration testing”).';
  }

  String get _heroTitle {
    if (widget.mode == _WBSNodeDialogMode.edit) {
      return 'Edit ${widget.levelLabel}';
    }
    return 'Add Level ${widget.level} — ${widget.levelLabel}';
  }

  String get _heroEyebrow {
    if (widget.mode == _WBSNodeDialogMode.edit) {
      return 'WORK BREAKDOWN STRUCTURE · EDIT';
    }
    return 'WORK BREAKDOWN STRUCTURE · NEW NODE';
  }

  String? get _heroSubtitle {
    final parent = widget.parentName?.trim();
    if (parent == null || parent.isEmpty) return null;
    return 'Under: $parent';
  }

  IconData get _heroIcon {
    if (widget.mode == _WBSNodeDialogMode.edit) return Icons.edit_outlined;
    return Icons.add_rounded;
  }

  String get _primaryActionLabel {
    if (widget.mode == _WBSNodeDialogMode.edit) return 'Save Changes';
    return 'Create ${widget.levelLabel}';
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _hasError = true);
      _nameFocus.requestFocus();
      return;
    }
    final desc = _descCtrl.text.trim();

    if (widget.mode == _WBSNodeDialogMode.edit && widget.existingNode != null) {
      widget.provider.updateNode(
        widget.existingNode!.id,
        widget.existingNode!.copyWith(
          name: name,
          description: desc.isEmpty ? null : desc,
        ),
      );
    } else {
      final id = widget.provider.addChildNode(widget.parentId!, name, desc);
      if (_isHybrid &&
          _selectedMethodology != null &&
          id.isNotEmpty) {
        widget.provider.setNodeMethodology(id, _selectedMethodology);
      }
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;
    final dialogWidth = isWide ? 620.0 : 520.0;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(
            horizontal: 24, vertical: 24),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: _buildCard(dialogWidth),
        ),
      ),
    );
  }

  Widget _buildCard(double width) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Material(
          color: Colors.white,
          elevation: 0,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeroHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSuggestionChips(),
                      const SizedBox(height: 16),
                      _buildNameField(),
                      const SizedBox(height: 14),
                      _buildDescriptionField(),
                      if (_isHybrid && widget.level == 1) ...[
                        const SizedBox(height: 14),
                        _buildMethodologyPicker(),
                      ],
                      const SizedBox(height: 14),
                      _buildLivePreview(),
                    ],
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Hero Header ──────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFC812), // Brand yellow
            Color(0xFFFFD34D), // Lighter yellow
            Color(0xFFFFE896), // Pale yellow
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHeroIconBadge(),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _heroEyebrow,
                  style: const TextStyle(
                    color: Color(0xFF5B4500),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _heroTitle,
                  style: const TextStyle(
                    color: Color(0xFF2A1F00),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                if (_heroSubtitle != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 13,
                        color: Color(0xFF7A5C00),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _heroSubtitle!,
                          style: const TextStyle(
                            color: Color(0xFF7A5C00),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          _buildCloseButton(),
        ],
      ),
    );
  }

  Widget _buildHeroIconBadge() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.7),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B6914).withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        _heroIcon,
        color: const Color(0xFF2A1F00),
        size: 26,
      ),
    );
  }

  Widget _buildCloseButton() {
    return Material(
      color: Colors.white.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(
            Icons.close_rounded,
            size: 18,
            color: Color(0xFF2A1F00),
          ),
        ),
      ),
    );
  }

  // ─── Suggestion Chips ─────────────────────────────────────────────────
  Widget _buildSuggestionChips() {
    final suggestions = _suggestions;
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.bolt_rounded,
              size: 14,
              color: LightModeColors.accent,
            ),
            const SizedBox(width: 6),
            const Text(
              'Quick suggestions',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4CC),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'TAP TO USE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7A5C00),
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: suggestions.map((s) {
            return _SuggestionChip(
              label: s,
              onTap: () {
                _nameCtrl.text = s;
                _nameCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: s.length),
                );
                _descFocus.requestFocus();
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Name Field ───────────────────────────────────────────────────────
  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Name',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1D1F),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFFDC2626),
              ),
            ),
            const Spacer(),
            _CharCounter(controller: _nameCtrl, max: 80),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _nameCtrl,
          focusNode: _nameFocus,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _descFocus.requestFocus(),
          decoration: InputDecoration(
            hintText: 'e.g. Platform Design',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            filled: true,
            fillColor: const Color(0xFFFAFAF9),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _hasError
                    ? const Color(0xFFDC2626)
                    : const Color(0xFFE4E7EC),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: LightModeColors.accent, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFDC2626), width: 1.6),
            ),
          ),
          style: const TextStyle(
            color: Color(0xFF1A1D1F),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _hasError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              size: 13,
              color: _hasError
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _hasError
                    ? 'A name is required to create this ${widget.levelLabel.toLowerCase()}.'
                    : _hintText,
                style: TextStyle(
                  fontSize: 11,
                  color: _hasError
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Description Field ────────────────────────────────────────────────
  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1D1F),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'OPTIONAL',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6B7280),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Spacer(),
            _CharCounter(controller: _descCtrl, max: 280),
          ],
        ),
        const SizedBox(height: 6),
        VoiceTextField(
          controller: _descCtrl,
          focusNode: _descFocus,
          maxLines: 3,
          decoration: InputDecoration(
            hintText:
                'What does this ${widget.levelLabel.toLowerCase()} cover? Why does it matter?',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            filled: true,
            fillColor: const Color(0xFFFAFAF9),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: LightModeColors.accent, width: 1.6),
            ),
          ),
          style: const TextStyle(
            color: Color(0xFF1A1D1F),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ─── Methodology Picker (Hybrid only) ─────────────────────────────────
  Widget _buildMethodologyPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Methodology',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1D1F),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _MethodologyOption(
                  label: 'Waterfall',
                  icon: Icons.waterfall_chart_rounded,
                  selected: _selectedMethodology == 'waterfall',
                  onTap: () => setState(() => _selectedMethodology = 'waterfall'),
                ),
              ),
              Expanded(
                child: _MethodologyOption(
                  label: 'Agile',
                  icon: Icons.speed_rounded,
                  selected: _selectedMethodology == 'agile',
                  onTap: () => setState(() => _selectedMethodology = 'agile'),
                ),
              ),
              Expanded(
                child: _MethodologyOption(
                  label: 'Inherit',
                  icon: Icons.family_restroom_rounded,
                  selected: _selectedMethodology == null,
                  onTap: () => setState(() => _selectedMethodology = null),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Live Preview ─────────────────────────────────────────────────────
  Widget _buildLivePreview() {
    final name = _nameCtrl.text.trim();
    final hasName = name.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFDE68A).withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: LightModeColors.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.visibility_outlined,
              size: 16,
              color: Color(0xFF92700C),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LIVE PREVIEW',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92700C),
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasName
                      ? name
                      : 'Your ${widget.levelLabel.toLowerCase()} name will appear here…',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: hasName
                        ? const Color(0xFF2A1F00)
                        : const Color(0xFFB89854),
                    fontStyle:
                        hasName ? FontStyle.normal : FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFFFDE68A).withValues(alpha: 0.8),
              ),
            ),
            child: Text(
              'L${widget.level}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF92700C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Footer ───────────────────────────────────────────────────────────
  Widget _buildFooter() {
    final canSubmit = _nameCtrl.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF9),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFE4E7EC).withValues(alpha: 0.7),
          ),
        ),
      ),
      child: Row(
        children: [
          // Left-side meta hint
          Expanded(
            child: Row(
              children: [
                Icon(
                  widget.mode == _WBSNodeDialogMode.edit
                      ? Icons.history_edu_rounded
                      : Icons.auto_awesome_rounded,
                  size: 13,
                  color: const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.mode == _WBSNodeDialogMode.edit
                        ? 'Changes are saved to your WBS instantly.'
                        : 'Added to your WBS tree instantly.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Cancel button — ghost
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Primary action — yellow gradient
          _PrimaryActionButton(
            label: _primaryActionLabel,
            icon: widget.mode == _WBSNodeDialogMode.edit
                ? Icons.check_rounded
                : Icons.arrow_forward_rounded,
            enabled: canSubmit,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ────────────────────────────────────────────────────────────────────────

class _SuggestionChip extends StatefulWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_SuggestionChip> createState() => _SuggestionChipState();
}

class _SuggestionChipState extends State<_SuggestionChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hover
                ? const Color(0xFFFFF4CC)
                : const Color(0xFFFAFAF9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hover
                  ? const Color(0xFFFFC812)
                  : const Color(0xFFE4E7EC),
              width: _hover ? 1.2 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_rounded,
                size: 12,
                color: _hover
                    ? const Color(0xFF92700C)
                    : const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _hover
                      ? const Color(0xFF2A1F00)
                      : const Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodologyOption extends StatelessWidget {
  const _MethodologyOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? LightModeColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? const Color(0xFF2A1F00)
                  : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected
                    ? const Color(0xFF2A1F00)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharCounter extends StatelessWidget {
  const _CharCounter({required this.controller, required this.max});

  final TextEditingController controller;
  final int max;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final len = value.text.length;
        final over = len > max;
        final near = len > max * 0.85 && !over;
        return Text(
          '$len / $max',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: over
                ? const Color(0xFFDC2626)
                : near
                    ? const Color(0xFFD97706)
                    : const Color(0xFF9CA3AF),
          ),
        );
      },
    );
  }
}

class _PrimaryActionButton extends StatefulWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
  bool _hover = false;
  bool _press = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return MouseRegion(
      onEnter: enabled ? (_) => setState(() => _hover = true) : null,
      onExit: enabled ? (_) => setState(() => _hover = false) : null,
      child: GestureDetector(
        onTapDown: enabled
            ? (_) => setState(() => _press = true)
            : null,
        onTapUp: enabled
            ? (_) => setState(() => _press = false)
            : null,
        onTapCancel: enabled
            ? () => setState(() => _press = false)
            : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _hover
                        ? [const Color(0xFFFFD34D), const Color(0xFFFFC812)]
                        : [const Color(0xFFFFC812), const Color(0xFFE0A800)],
                  )
                : null,
            color: enabled ? null : const Color(0xFFE4E7EC),
            borderRadius: BorderRadius.circular(11),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFC812)
                          .withValues(alpha: _press ? 0.15 : 0.35),
                      blurRadius: _press ? 4 : 10,
                      offset: Offset(0, _press ? 1 : 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: enabled
                      ? const Color(0xFF2A1F00)
                      : const Color(0xFF9CA3AF),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                widget.icon,
                size: 16,
                color: enabled
                    ? const Color(0xFF2A1F00)
                    : const Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
