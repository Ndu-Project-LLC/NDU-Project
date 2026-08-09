/// Framework Picker Screen — 2-step setup for a new WBS.
///
/// Step 1: Project methodology (Waterfall, Agile, Hybrid)
/// Step 2: Framework selection (Agile + 5 Waterfall variations with ratings)
///
/// The methodology determines the default framework and the depth structure.
///
/// Rendered inside a [ResponsiveScaffold] so the standard app sidebar stays
/// visible during setup. Light-mode (white) theme.
///
/// This screen is designed to a world-class standard: refined typography,
/// a connected step-progress bar, color-coded methodology cards with depth
/// visualization, signature framework cards that render the level hierarchy
/// as chevron-separated chips, and polished micro-interactions throughout.

library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

class FrameworkPickerScreen extends StatefulWidget {
  const FrameworkPickerScreen({super.key});

  @override
  State<FrameworkPickerScreen> createState() => _FrameworkPickerScreenState();
}

class _FrameworkPickerScreenState extends State<FrameworkPickerScreen> {
  int _step = 0;
  ProjectMethodology? _methodology;
  WBSFramework? _framework;

  // ── Design tokens ─────────────────────────────────────────────────────
  // Centralised palette so every element draws from the same source of truth.
  // These are intentionally tuned for a premium, "studio-grade" feel.
  static const Color _ink = Color(0xFF0F172A); // slate-900 — headlines
  static const Color _body = Color(0xFF475569); // slate-600 — body text
  static const Color _muted = Color(0xFF94A3B8); // slate-400 — meta text
  static const Color _hairline = Color(0xFFE2E8F0); // slate-200 — borders
  static const Color _canvas = Color(0xFFFAFBFC); // warm off-white background
  static const Color _accent = Color(0xFFF59E0B); // amber-500 — primary accent
  static const Color _accentDeep = Color(0xFFD97706); // amber-600 — pressed
  static const Color _accentSoft = Color(0xFFFFFBEB); // amber-50 — soft fill

  @override
  Widget build(BuildContext context) {
    const totalSteps = 2;
    return ResponsiveScaffold(
      activeItemLabel: 'Work Breakdown Structure',
      appBarTitle: 'Work Breakdown Structure',
      breadcrumbPhase: 'Planning Phase',
      breadcrumbTitle: 'WBS Setup',
      backgroundColor: _canvas,
      body: Stack(
        children: [
          // Ambient depth layer: a very subtle radial wash at the top that
          // gives the canvas dimension without distracting from content.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -1.2),
                    radius: 1.4,
                    colors: [
                      _accent.withValues(alpha: 0.06),
                      _canvas.withValues(alpha: 0),
                    ],
                    stops: const [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),
          // Main content
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 880),
              padding: const EdgeInsets.fromLTRB(40, 48, 40, 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBrandHeader(),
                  const SizedBox(height: 36),
                  _buildStepBar(totalSteps),
                  const SizedBox(height: 40),
                  _buildStepHeader(),
                  const SizedBox(height: 24),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) {
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.04),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: _buildStepContent(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildFooter(totalSteps),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Brand header ──────────────────────────────────────────────────────
  Widget _buildBrandHeader() {
    return Column(
      children: [
        // Logo lockup
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.folder_open_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('NDU',
                style: TextStyle(
                    color: _ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3)),
            const Text(' PROJECT',
                style: TextStyle(
                    color: _accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3)),
          ],
        ),
        const SizedBox(height: 10),
        // Eyebrow / subtitle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: _accentSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _accent.withValues(alpha: 0.15)),
          ),
          child: const Text('WBS SETUP WIZARD',
              style: TextStyle(
                  color: _accentDeep,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2)),
        ),
      ],
    );
  }

  // ── Step progress bar (replaces dots) ────────────────────────────────
  Widget _buildStepBar(int totalSteps) {
    const labels = ['Methodology', 'Framework'];
    return Row(
      children: List.generate(totalSteps * 2 - 1, (idx) {
        if (idx.isOdd) {
          // Connector segment
          final completed = _step > idx ~/ 2;
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: completed ? _accent : _hairline,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        }
        final i = idx ~/ 2;
        final active = i == _step;
        final completed = i < _step;
        return _StepNode(
          label: labels[i],
          index: i + 1,
          active: active,
          completed: completed,
        );
      }),
    );
  }

  // ── Step header (title + description) ────────────────────────────────
  Widget _buildStepHeader() {
    return Column(
      children: [
        Text(
          'Step ${_step + 1} of 2',
          style: const TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5),
        ),
        const SizedBox(height: 10),
        Text(
          _step == 0
              ? 'Choose delivery methodology'
              : 'Pick a WBS framework',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: _ink,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.1),
        ),
        const SizedBox(height: 10),
        Text(
          _step == 0
              ? 'The methodology determines how your WBS is structured and decomposed.'
              : 'The framework determines how your${_methodology != null ? ' ${_methodology!.label}' : ''} project is decomposed into levels.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _body, fontSize: 14, height: 1.5),
        ),
      ],
    );
  }

  // ── Footer (Back / Continue) ─────────────────────────────────────────
  Widget _buildFooter(int totalSteps) {
    final canProceed = _canProceed();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_step > 0)
          TextButton.icon(
            onPressed: () => setState(() => _step--),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Back',
                style: TextStyle(
                    color: _body,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          )
        else
          const SizedBox(width: 80),
        _PrimaryButton(
          label: _step == totalSteps - 1 ? 'Create WBS' : 'Continue',
          icon: _step == totalSteps - 1
              ? Icons.check_rounded
              : Icons.arrow_forward_rounded,
          onPressed: canProceed ? _handleNext : null,
        ),
      ],
    );
  }

  // ── Logic (unchanged from original) ──────────────────────────────────
  bool _canProceed() {
    switch (_step) {
      case 0:
        return _methodology != null;
      case 1:
        return _framework != null;
    }
    return false;
  }

  void _handleNext() {
    if (_step == 0 && _methodology != null) {
      _framework ??= switch (_methodology!) {
        ProjectMethodology.agile => WBSFramework.agile,
        ProjectMethodology.waterfall => WBSFramework.waterfallDeliverable,
        ProjectMethodology.hybrid => WBSFramework.waterfallDeliverable,
      };
      setState(() => _step = 1);
    } else if (_step == 1 && _framework != null) {
      final projectData = ProjectDataHelper.getData(context);
      final resolvedProjectName =
          projectData.projectName.trim().isNotEmpty
              ? projectData.projectName.trim()
              : 'Untitled Project';
      context.read<WBSProvider>().setup(
            projectName: resolvedProjectName,
            framework: _framework!,
            methodology: _methodology!,
          );
    }
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildMethodologyStep();
      case 1:
        return _buildFrameworkStep();
    }
    return const SizedBox();
  }

  // ══════════════════════════════════════════════════════════════════════
  // STEP 1: METHODOLOGY
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildMethodologyStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: ProjectMethodology.values.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) {
              final m = ProjectMethodology.values[i];
              return _MethodologyCard(
                methodology: m,
                selected: _methodology == m,
                onTap: () => setState(() => _methodology = m),
              );
            },
          ),
        ),
        // Insight banner appears when a methodology is chosen
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _methodology != null
              ? _MethodologyInsightBanner(methodology: _methodology!)
              : const SizedBox(height: 0),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // STEP 2: FRAMEWORK
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildFrameworkStep() {
    final frameworks = WBSFramework.values
        .where((f) =>
            _methodology == ProjectMethodology.agile
                ? f == WBSFramework.agile
                : true)
        .toList();
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: frameworks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final f = frameworks[i];
        return _FrameworkCard(
          framework: f,
          selected: _framework == f,
          onTap: () => setState(() => _framework = f),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// STEP NODE — a single node in the step progress bar
// ══════════════════════════════════════════════════════════════════════════
class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.label,
    required this.index,
    required this.active,
    required this.completed,
  });

  final String label;
  final int index;
  final bool active;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFF59E0B);
    const ink = Color(0xFF0F172A);
    const muted = Color(0xFF94A3B8);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: completed || active ? accent : Colors.white,
            border: Border.all(
              color: completed || active ? accent : const Color(0xFFE2E8F0),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: completed
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
              : active
                  ? Text('$index',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800))
                  : Text('$index',
                      style: const TextStyle(
                          color: muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                color: active || completed ? ink : muted,
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// PRIMARY BUTTON — the Continue / Create WBS button
// ══════════════════════════════════════════════════════════════════════════
class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hover = false;
  bool _press = false;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFF59E0B);
    const accentDeep = Color(0xFFD97706);
    const disabledBg = Color(0xFFF1F5F9);
    const disabledFg = Color(0xFF94A3B8);
    final enabled = widget.onPressed != null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _press = true),
        onTapUp: (_) => setState(() => _press = false),
        onTapCancel: () => setState(() => _press = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: _press && enabled
              ? Matrix4.diagonal3Values(0.97, 0.97, 1.0)
              : Matrix4.identity(),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _hover
                        ? [accentDeep, accent]
                        : [accent, accentDeep],
                  )
                : null,
            color: enabled ? null : disabledBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: _hover ? 0.45 : 0.30),
                      blurRadius: _hover ? 18 : 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.label,
                  style: TextStyle(
                      color: enabled ? Colors.white : disabledFg,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2)),
              const SizedBox(width: 8),
              Icon(widget.icon,
                  size: 17,
                  color: enabled ? Colors.white : disabledFg),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// METHODOLOGY CARD
// ══════════════════════════════════════════════════════════════════════════
class _MethodologyCard extends StatefulWidget {
  const _MethodologyCard({
    required this.methodology,
    required this.selected,
    required this.onTap,
  });

  final ProjectMethodology methodology;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_MethodologyCard> createState() => _MethodologyCardState();
}

class _MethodologyCardState extends State<_MethodologyCard> {
  bool _hover = false;

  // Trait chip text — a single-word essence of each methodology
  String get _trait => switch (widget.methodology) {
        ProjectMethodology.waterfall => 'Sequential',
        ProjectMethodology.agile => 'Iterative',
        ProjectMethodology.hybrid => 'Blended',
      };

  @override
  Widget build(BuildContext context) {
    final m = widget.methodology;
    final selected = widget.selected;
    final color = m.color;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? color : const Color(0xFFE2E8F0),
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: selected ? 0.10 : 0.04),
                  blurRadius: selected ? 24 : (_hover ? 14 : 8),
                  offset: const Offset(0, 6),
                ),
                if (selected)
                  BoxShadow(
                    color: color.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon tile with methodology color
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: selected
                          ? [color, Color.lerp(color, Colors.black, 0.15)!]
                          : [
                              color.withValues(alpha: 0.10),
                              color.withValues(alpha: 0.06),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(m.icon,
                      color: selected ? Colors.white : color, size: 26),
                ),
                const SizedBox(width: 18),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row + trait chip
                      Row(
                        children: [
                          Text(m.label,
                              style: TextStyle(
                                  color: selected
                                      ? color
                                      : const Color(0xFF0F172A),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3)),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(_trait,
                                style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4)),
                          ),
                          const Spacer(),
                          // Selection indicator
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: selected
                                ? Container(
                                    key: const ValueKey('check'),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.check_rounded,
                                        color: Colors.white, size: 16),
                                  )
                                : SizedBox(
                                    key: const ValueKey('empty'),
                                    width: 24,
                                    height: 24,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: const Color(0xFFCBD5E1),
                                            width: 1.5),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Description
                      Text(m.description,
                          style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 13.5,
                              height: 1.5)),
                      const SizedBox(height: 14),
                      // Depth visualization: 8 dots, all filled for methodologies (max depth 8)
                      _DepthIndicator(color: color, depth: 8),
                    ],
                  ),
                ),
              ],
            ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// DEPTH INDICATOR — visualises the WBS level depth as a row of dots
// ══════════════════════════════════════════════════════════════════════════
class _DepthIndicator extends StatelessWidget {
  const _DepthIndicator({required this.color, required this.depth});
  final Color color;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('DEPTH',
            style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
        const SizedBox(width: 10),
        ...List.generate(8, (i) {
          final filled = i < depth;
          return Container(
            margin: const EdgeInsets.only(right: 5),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: filled ? color : const Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
          );
        }),
        const SizedBox(width: 8),
        Text('L0–L$depth',
            style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// METHODOLOGY INSIGHT BANNER — appears below cards when a methodology is picked
// ══════════════════════════════════════════════════════════════════════════
class _MethodologyInsightBanner extends StatelessWidget {
  const _MethodologyInsightBanner({required this.methodology});
  final ProjectMethodology methodology;

  @override
  Widget build(BuildContext context) {
    final m = methodology;
    final color = m.color;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.lightbulb_outline_rounded,
                color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 12.5,
                    height: 1.4),
                children: [
                  TextSpan(
                      text: '${m.label} projects ',
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.w700)),
                  const TextSpan(
                      text:
                          'support up to 8 levels of decomposition — from the project root down to hours-of-work granularity. You can refine this in the next step.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// FRAMEWORK CARD — the signature element of Step 2
// Renders the level hierarchy as chevron-separated chips.
// ══════════════════════════════════════════════════════════════════════════
class _FrameworkCard extends StatefulWidget {
  const _FrameworkCard({
    required this.framework,
    required this.selected,
    required this.onTap,
  });

  final WBSFramework framework;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FrameworkCard> createState() => _FrameworkCardState();
}

class _FrameworkCardState extends State<_FrameworkCard> {
  bool _hover = false;

  // Build the level hierarchy path (skips L0 which is always "Project")
  List<String> get _path {
    final f = widget.framework;
    return [
      f.level1Label,
      f.level2Label,
      f.level3Label,
      f.level4Label,
      if (f.maxDepth >= 5) f.level5Label,
      if (f.maxDepth >= 6) f.level6Label,
      if (f.maxDepth >= 7) f.level7Label,
      if (f.maxDepth >= 8) f.level8Label,
    ];
  }

  bool get _isLeastPreferred =>
      widget.framework == WBSFramework.waterfallPhase;

  bool get _isRecommended => widget.framework.rating >= 5 && !_isLeastPreferred;

  @override
  Widget build(BuildContext context) {
    final f = widget.framework;
    final selected = widget.selected;
    const accent = Color(0xFFF59E0B);
    const ink = Color(0xFF0F172A);
    const body = Color(0xFF475569);
    const muted = Color(0xFF94A3B8);
    const hairline = Color(0xFFE2E8F0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? accent : hairline,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: selected ? 0.08 : (_hover ? 0.06 : 0.03)),
                blurRadius: selected ? 24 : (_hover ? 14 : 8),
                offset: const Offset(0, 5),
              ),
              if (selected)
                BoxShadow(
                  color: accent.withValues(alpha: 0.16),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: icon + title + badges + selection
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon tile
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: selected
                            ? [accent, const Color(0xFFD97706)]
                            : [
                                const Color(0xFFF1F5F9),
                                const Color(0xFFE2E8F0),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(f.iconData,
                        color: selected ? Colors.white : const Color(0xFF475569),
                        size: 22),
                  ),
                  const SizedBox(width: 14),
                  // Title + badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(f.label,
                                  style: const TextStyle(
                                      color: ink,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2)),
                            ),
                            if (_isRecommended) ...[
                              const SizedBox(width: 8),
                              _Badge(
                                text: 'RECOMMENDED',
                                color: const Color(0xFF16A34A),
                                bgColor: const Color(0xFFD1FAE5),
                              ),
                            ],
                            if (_isLeastPreferred) ...[
                              const SizedBox(width: 8),
                              _Badge(
                                text: 'LEAST PREFERRED',
                                color: const Color(0xFFD97706),
                                bgColor: const Color(0xFFFFFBEB),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Star rating + depth badge
                        Row(
                          children: [
                            _StarRating(rating: f.rating),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text('L0–L${f.maxDepth}',
                                  style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const Spacer(),
                            // Selection indicator
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: selected
                                  ? Container(
                                      key: const ValueKey('check'),
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        color: accent,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(0x66F59E0B),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.check_rounded,
                                          color: Colors.white, size: 14),
                                    )
                                  : SizedBox(
                                      key: const ValueKey('empty'),
                                      width: 22,
                                      height: 22,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: const Color(0xFFCBD5E1),
                                              width: 1.5),
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Description
              Text(f.description,
                  style: const TextStyle(color: body, fontSize: 12.5, height: 1.5)),
              const SizedBox(height: 14),
              // Hierarchy path — the signature element
              _HierarchyPath(path: _path, selected: selected),
              const SizedBox(height: 12),
              // Best-for row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BEST FOR',
                      style: TextStyle(
                          color: muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(f.bestFor,
                        style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
              // Warning box for Phase-Based
              if (_isLeastPreferred) ...[
                const SizedBox(height: 14),
                _WarningBox(
                  text:
                      'Least preferred — mixes deliverables and activities. Consider Deliverable-Based for cleaner decomposition.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// STAR RATING — real star icons, not text characters
// ══════════════════════════════════════════════════════════════════════════
class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating});
  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating;
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            size: 14,
            color: filled
                ? const Color(0xFFF59E0B)
                : const Color(0xFFCBD5E1),
          ),
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// BADGE — small pill for RECOMMENDED / LEAST PREFERRED
// ══════════════════════════════════════════════════════════════════════════
class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.color,
    required this.bgColor,
  });
  final String text;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// HIERARCHY PATH — chevron-separated level chips
// The signature visual element that makes "L0–L8" concrete and beautiful.
// ══════════════════════════════════════════════════════════════════════════
class _HierarchyPath extends StatelessWidget {
  const _HierarchyPath({required this.path, required this.selected});
  final List<String> path;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFF59E0B);
    const muted = Color(0xFF94A3B8);
    const hairline = Color(0xFFE2E8F0);
    final chipColor = selected
        ? accent.withValues(alpha: 0.10)
        : const Color(0xFFF8FAFC);
    final chipBorder = selected
        ? accent.withValues(alpha: 0.30)
        : hairline;
    final textColor = selected
        ? const Color(0xFF92400E)
        : const Color(0xFF475569);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: chipBorder),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Root chip
          _PathChip('Project',
              highlight: true,
              color: accent,
              textColor: Colors.white),
          ...path.expand((label) => [
                Icon(Icons.chevron_right_rounded,
                    size: 14, color: muted),
                _PathChip(label,
                    color: chipColor,
                    borderColor: chipBorder,
                    textColor: textColor),
              ]),
        ],
      ),
    );
  }
}

class _PathChip extends StatelessWidget {
  const _PathChip(this.label,
      {required this.color,
      this.borderColor,
      this.textColor,
      this.highlight = false});
  final String label;
  final Color color;
  final Color? borderColor;
  final Color? textColor;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: highlight ? null : Border.all(color: borderColor ?? const Color(0xFFE2E8F0)),
      ),
      child: Text(label,
          style: TextStyle(
              color: textColor ?? (highlight ? Colors.white : const Color(0xFF475569)),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// WARNING BOX — for the Phase-Based framework
// ══════════════════════════════════════════════════════════════════════════
class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCD34D).withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: Color(0xFFD97706)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 11.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
