// ═══════════════════════════════════════════════════════════════════════════
// INTEGRATED SCHEDULE METHODOLOGY
// ═══════════════════════════════════════════════════════════════════════════
// World-class 12-step methodology surface for the Schedule Builder page.
// Showcases the integrated Engineering → Procurement → Execution flow with
// NDU-specific scoping notes (WBS to Level 2; EWPs/Procurement at Level 3;
// CWPs cascading from Level 2 down to 8 where needed).
//
// Companion widgets:
//   • EstimateBasisCard        — assumptions / methods / data sources
//   • ScheduleReadinessRules   — pre-CWP gate checklist
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import 'package:ndu_project/cost_estimate/widgets/treasury_components.dart';

// ═══════════════════════════════════════════════════════════════════════════
// METHODLOGY PHASE / STEP MODELS
// ═══════════════════════════════════════════════════════════════════════════

enum _MethodologyPhase {
  scope, // Steps 1–4 — Scope Definition
  network, // Steps 5–6 — Network & Durations
  build, // Steps 7–10 — Schedule Build
  control, // Steps 11–12 — Control & Baseline
}

extension _MethodologyPhaseX on _MethodologyPhase {
  String get label {
    switch (this) {
      case _MethodologyPhase.scope:
        return 'PHASE 1 · SCOPE DEFINITION';
      case _MethodologyPhase.network:
        return 'PHASE 2 · NETWORK & DURATIONS';
      case _MethodologyPhase.build:
        return 'PHASE 3 · SCHEDULE BUILD';
      case _MethodologyPhase.control:
        return 'PHASE 4 · BASELINE & CONTROL';
    }
  }

  String get subtitle {
    switch (this) {
      case _MethodologyPhase.scope:
        return 'Translate deliverables into WBS → EWPs → Procurement → CWPs';
      case _MethodologyPhase.network:
        return 'Sequence integrated logic and estimate durations';
      case _MethodologyPhase.build:
        return 'CPM, contract alignment, resource load, time-phased plan';
      case _MethodologyPhase.control:
        return 'Readiness rules, baseline, and progress tracking';
    }
  }

  Color get accent {
    switch (this) {
      case _MethodologyPhase.scope:
        return TreasuryTokens.brandDeep; // amber
      case _MethodologyPhase.network:
        return const Color(0xFF2563EB); // blue
      case _MethodologyPhase.build:
        return TreasuryTokens.success; // green
      case _MethodologyPhase.control:
        return const Color(0xFF7C3AED); // purple
    }
  }

  Color get accentSoft {
    switch (this) {
      case _MethodologyPhase.scope:
        return TreasuryTokens.brandSoft;
      case _MethodologyPhase.network:
        return const Color(0xFFEFF6FF);
      case _MethodologyPhase.build:
        return TreasuryTokens.successSoft;
      case _MethodologyPhase.control:
        return const Color(0xFFEDE9FE);
    }
  }
}

class _StepStatus {
  const _StepStatus({
    required this.label,
    required this.color,
    required this.soft,
  });
  final String label;
  final Color color;
  final Color soft;

  static const notStarted = _StepStatus(
    label: 'NOT STARTED',
    color: Color(0xFF94A3B8),
    soft: Color(0xFFF1F5F9),
  );
  static const inProgress = _StepStatus(
    label: 'IN PROGRESS',
    color: TreasuryTokens.brandDeep,
    soft: TreasuryTokens.warningSoft,
  );
  static const complete = _StepStatus(
    label: 'COMPLETE',
    color: TreasuryTokens.success,
    soft: TreasuryTokens.successSoft,
  );
}

class _MethodologyStep {
  const _MethodologyStep({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.phase,
    this.nduNote,
    this.deliverables = const [],
  }) : status = _StepStatus.notStarted;

  final int number;
  final String title;
  final String description;
  final IconData icon;
  final _MethodologyPhase phase;
  final String? nduNote; // NDU-specific scoping note
  final _StepStatus status;
  final List<String> deliverables; // tangible outputs of this step
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN WIDGET — INTEGRATED SCHEDULE METHODOLOGY
// ═══════════════════════════════════════════════════════════════════════════

class IntegratedScheduleMethodology extends StatefulWidget {
  const IntegratedScheduleMethodology({
    super.key,
    this.wbsDepth = 2,
    this.ewpLevel = 3,
    this.procurementLevel = 3,
    this.cwpDepthFrom = 2,
    this.cwpDepthTo = 8,
    this.deliveryModel = 'WATERFALL',
  });

  /// WBS depth for NDU project (default: Level 2 per user spec)
  final int wbsDepth;
  /// EWPs sit at this WBS level (default: Level 3)
  final int ewpLevel;
  /// Procurement packages sit at this WBS level (default: Level 3)
  final int procurementLevel;
  /// CWPs cascade from this level (default: Level 2)
  final int cwpDepthFrom;
  /// CWPs cascade down to this level if needed (default: Level 8)
  final int cwpDepthTo;
  /// 'WATERFALL', 'AGILE', or 'HYBRID'
  final String deliveryModel;

  @override
  State<IntegratedScheduleMethodology> createState() =>
      _IntegratedScheduleMethodologyState();
}

class _IntegratedScheduleMethodologyState
    extends State<IntegratedScheduleMethodology> {
  late List<_MethodologyStep> _steps;
  int _expandedStep = -1;

  @override
  void initState() {
    super.initState();
    _steps = _buildSteps();
  }

  @override
  void didUpdateWidget(covariant IntegratedScheduleMethodology oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deliveryModel != widget.deliveryModel ||
        oldWidget.wbsDepth != widget.wbsDepth) {
      _steps = _buildSteps();
    }
  }

  List<_MethodologyStep> _buildSteps() {
    final isAgile = widget.deliveryModel.toUpperCase() == 'AGILE';
    return [
      // ─── PHASE 1: SCOPE DEFINITION ───────────────────────────────────────
      const _MethodologyStep(
        number: 1,
        title: 'Deliverable-Based WBS',
        description:
            'Build a Level 2–4 WBS structured around physical deliverables or systems — not departments. Typical top levels: Facility → Civil works → Structural → Mechanical systems → Electrical systems. This becomes the backbone for everything else.',
        nduNote:
            'For NDU Project, the WBS goes to the second level (Level 2).',
        icon: Icons.account_tree_rounded,
        phase: _MethodologyPhase.scope,
        deliverables: [
          'WBS dictionary',
          'Level 1 control accounts',
          'Level 2 deliverable accounts',
        ],
      ),
      const _MethodologyStep(
        number: 2,
        title: 'Engineering Work Packages (EWPs)',
        description:
            'From each WBS element, define EWPs that produce the design outputs needed for execution: drawings, specifications, calculations, bill of materials, codes, requirements. EWPs must be complete enough to release for execution or construction (waterfall).',
        nduNote:
            'For NDU Project, these are the design packages that align with all requirements and applicable specifications. They sit at the 3rd level of the WBS to identify all design and engineering work needed for each scope element.',
        icon: Icons.design_services_rounded,
        phase: _MethodologyPhase.scope,
        deliverables: [
          'Drawing register',
          'Specification index',
          'Calculation set',
          'Bill of materials (BOM)',
          'Code & standards matrix',
        ],
      ),
      const _MethodologyStep(
        number: 3,
        title: 'Procurement & Contracting Breakdown',
        description:
            'From EWPs, identify all items that must be purchased or contracted. Break into long-lead equipment, bulk materials, and subcontracts. For each item, define procurement activities: scope definition → RFQ/RFP → bid evaluation → award → fabrication → delivery. Creates a Procurement Breakdown Structure (PBS) aligned to the WBS.',
        nduNote:
            'For NDU Project, any design that needs to feed into a procured item is identified in its package so that its scope is complete for sending to the vendor to build (mostly for waterfall but could apply to agile sometimes). Sits at the 3rd level of the WBS.',
        icon: Icons.inventory_2_outlined,
        phase: _MethodologyPhase.scope,
        deliverables: [
          'Procurement Breakdown Structure (PBS)',
          'Long-lead register',
          'Vendor scope packages',
          'RFQ/RFP plan',
        ],
      ),
      const _MethodologyStep(
        number: 4,
        title: 'Execution Work Packages (EWPs) / Construction (CWPs)',
        description:
            'Translate WBS + EWPs into CWPs — executable field scopes. Each EWP/CWP should be tied to a specific area/system, executable by one crew or contractor, and have all prerequisites defined: approved IFC drawings, materials available, permits approved, access and site readiness.',
        nduNote:
            'For NDU Project, execution work packages are called CWPs when there is construction work for that scope; otherwise EWP, especially for Agile. They cascade from the WBS second level all the way to the lowest level possible — up to 8 levels if needed, until reaching the hours-of-work level. These work packages usually combine design and procurement or contract scope, especially at the 3rd to 5th levels.',
        icon: Icons.construction_rounded,
        phase: _MethodologyPhase.scope,
        deliverables: [
          'CWP register',
          'EWP register',
          'Prerequisites matrix per package',
          'Crew assignments',
        ],
      ),

      // ─── PHASE 2: NETWORK & DURATIONS ────────────────────────────────────
      _MethodologyStep(
        number: 5,
        title: 'Sequence All Activities (Integrated Logic)',
        description:
            'Connect engineering → procurement → execution/construction in one network. Typical waterfall logic chain: engineering complete → procurement start → procurement delivery → construction start → construction complete → commissioning. Example: EWP (pipe design) → procure pipe → deliver pipe → install pipe (CWP). This is where most schedules fail if logic is weak.',
        nduNote: isAgile
            ? 'For Agile NDU work, packages are iteration-based. EPICs should have a general estimation based on project duration. The duration basis (number of iterations) comes from historical data or extrapolation. Each estimated hours/block needs to be backed up in the estimate basis.'
            : 'For Waterfall NDU work, every EWP → Procurement → CWP chain must be logically tied with finish-to-start relationships wherever practical.',
        icon: Icons.linear_scale_rounded,
        phase: _MethodologyPhase.network,
        deliverables: const [
          'Integrated logic network',
          'Engineering → Procurement → Execution ties',
          'Agile iteration map (if applicable)',
        ],
      ),
      const _MethodologyStep(
        number: 6,
        title: 'Estimate Durations Across All Domains',
        description:
            'Estimate durations for engineering (design cycles, reviews), procurement (lead times, vendor timelines), and construction (crew productivity rates). Use consistent methods across all three to avoid mismatch.',
        nduNote:
            'For NDU Project, all three domains (Engineering, Procurement, Execution) must use a single, documented estimation method. See the Estimate Basis card below for the assumptions and data sources.',
        icon: Icons.timelapse_rounded,
        phase: _MethodologyPhase.network,
        deliverables: [
          'Engineering duration basis',
          'Procurement lead-time register',
          'Construction productivity rates',
        ],
      ),

      // ─── PHASE 3: SCHEDULE BUILD ─────────────────────────────────────────
      const _MethodologyStep(
        number: 7,
        title: 'Build the Integrated Schedule Network (CPM)',
        description:
            'Use the Critical Path Method (CPM) to calculate the full timeline. Key outputs: critical path across engineering, procurement, and construction; total project duration; float on non-critical paths. This step ensures procurement delays or design bottlenecks are visible early.',
        nduNote:
            'For NDU Project, CPM is run from the Schedule Builder via the "Run CPM" action above. Critical path drives staging decisions and forecast reporting.',
        icon: Icons.route_rounded,
        phase: _MethodologyPhase.build,
        deliverables: [
          'Critical path diagram',
          'Total project duration',
          'Float report on non-critical paths',
        ],
      ),
      const _MethodologyStep(
        number: 8,
        title: 'Align Contracts to Work Packages',
        description:
            'Contracts should map cleanly to CWPs and procurement packages: each major CWP → contract or subcontract; each procurement package → vendor contract. Avoid contracts that cut across multiple CWPs (creates coordination chaos).',
        nduNote:
            'For NDU Project, the Contract Register should be filterable by CWP id so the team can trace every contract back to a single executable scope.',
        icon: Icons.handshake_outlined,
        phase: _MethodologyPhase.build,
        deliverables: [
          'Contract → CWP mapping',
          'Vendor contract register',
          'Subcontractor scope sheets',
        ],
      ),
      const _MethodologyStep(
        number: 9,
        title: 'Resource Load and Validate',
        description:
            'Check labor availability, equipment constraints, and vendor capacity. Apply resource leveling and conduct a constructability review. Validate that peaks in demand can be met by the assigned crews and vendors.',
        nduNote:
            'For NDU Project, the Resource Plan should be cross-checked against the Team Management roster before each CWP release.',
        icon: Icons.groups_2_outlined,
        phase: _MethodologyPhase.build,
        deliverables: [
          'Resource-loaded schedule',
          'Resource leveling report',
          'Constructability review log',
        ],
      ),
      const _MethodologyStep(
        number: 10,
        title: 'Develop the Time-Phased Schedule',
        description:
            'Convert into a Gantt chart showing EWPs, procurement activities, and CWPs. Add milestones: design complete, contract awarded, equipment delivered, construction complete, commissioning start.',
        nduNote:
            'For NDU Project, the Gantt tab (next to this Builder tab) renders the time-phased view and the milestone register.',
        icon: Icons.view_timeline_rounded,
        phase: _MethodologyPhase.build,
        deliverables: [
          'Gantt chart (EWPs + Procurement + CWPs)',
          'Milestone register',
          'Baseline start/finish dates',
        ],
      ),

      // ─── PHASE 4: BASELINE & CONTROL ──────────────────────────────────────
      const _MethodologyStep(
        number: 11,
        title: 'Establish Schedule Readiness Rules',
        description:
            'A CWP should not start unless all constraints are cleared: engineering complete, materials on site, permits approved, predecessors finished. This is the core of reliable execution planning.',
        nduNote:
            'For NDU Project, see the Schedule Readiness Rules card below — each gate must be cleared before a CWP moves from "Planned" to "In Progress".',
        icon: Icons.checklist_rounded,
        phase: _MethodologyPhase.control,
        deliverables: [
          'CWP release gate checklist',
          'Permit & access register',
          'Predecessor completion log',
        ],
      ),
      const _MethodologyStep(
        number: 12,
        title: 'Baseline and Control',
        description:
            'Baseline the integrated schedule and track engineering progress vs release dates, procurement expediting vs delivery dates, and construction progress vs planned sequence.',
        nduNote:
            'For NDU Project, the baseline is locked from the Builder page. Variance reporting is then run from the Project Controls dashboards.',
        icon: Icons.fact_check_outlined,
        phase: _MethodologyPhase.control,
        deliverables: [
          'Baseline schedule (locked)',
          'Engineering progress S-curve',
          'Procurement expediting dashboard',
          'Construction progress vs plan',
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return TreasurySectionCard(
      title: 'Integrated Schedule Methodology',
      subtitle:
          '12-step process · ${widget.deliveryModel} delivery · WBS to Level ${widget.wbsDepth} · EWPs & Procurement at Level ${widget.ewpLevel} · CWPs cascade L${widget.cwpDepthFrom}–L${widget.cwpDepthTo}',
      trailing: _MethodologyProgressPill(steps: _steps),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Core insight banner ─────────────────────────────────────────
          _CoreInsightBanner(),
          const SizedBox(height: 18),
          // ── 4 phase groups, each containing its steps ───────────────────
          for (final phase in _MethodologyPhase.values) ...[
            _PhaseHeader(phase: phase),
            const SizedBox(height: 8),
            ..._steps
                .where((s) => s.phase == phase)
                .map((step) => _StepCard(
                      step: step,
                      expanded: _expandedStep == step.number,
                      onTap: () => setState(() {
                        _expandedStep =
                            _expandedStep == step.number ? -1 : step.number;
                      }),
                    )),
            const SizedBox(height: 14),
          ],
          // ── Legend strip ────────────────────────────────────────────────
          const _MethodologyLegend(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CORE INSIGHT BANNER
// ═══════════════════════════════════════════════════════════════════════════

class _CoreInsightBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF7E0), Color(0xFFFFE4B5)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TreasuryTokens.brand.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: TreasuryTokens.brand,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.lightbulb_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CORE INSIGHT',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: TreasuryTokens.brandDeep,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'The quality of a schedule is only as strong as its estimate basis. Weak or undocumented assumptions lead to unrealistic timelines and execution failure.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: TreasuryTokens.ink,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
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

// ═══════════════════════════════════════════════════════════════════════════
// PHASE HEADER
// ═══════════════════════════════════════════════════════════════════════════

class _PhaseHeader extends StatelessWidget {
  const _PhaseHeader({required this.phase});
  final _MethodologyPhase phase;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 2),
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: phase.accentSoft,
        border: Border(
          left: BorderSide(color: phase.accent, width: 3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: phase.accent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              phase.label,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              phase.subtitle,
              style: const TextStyle(
                fontSize: 11.5,
                color: TreasuryTokens.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STEP CARD
// ═══════════════════════════════════════════════════════════════════════════

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.expanded,
    required this.onTap,
  });

  final _MethodologyStep step;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4, bottom: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Number badge + connector rail ──────────────────────────────
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: step.phase.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: step.phase.accent.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${step.number}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: step.phase.accent.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // ── Card body ──────────────────────────────────────────────────
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(11),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: expanded
                          ? step.phase.accentSoft
                          : TreasuryTokens.surface,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: expanded
                            ? step.phase.accent.withValues(alpha: 0.6)
                            : TreasuryTokens.hairline,
                      ),
                      boxShadow: expanded
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.025),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Top row: icon + title + status pill ─────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: step.phase.accentSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(step.icon,
                                  size: 16, color: step.phase.accent),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step.title,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: TreasuryTokens.ink,
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    step.description,
                                    maxLines: expanded ? null : 2,
                                    overflow: expanded
                                        ? TextOverflow.visible
                                        : TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: TreasuryTokens.inkSoft,
                                      height: 1.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusPill(status: step.status),
                          ],
                        ),
                        // ── NDU note (always visible) ──────────────────────
                        if (step.nduNote != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                            decoration: BoxDecoration(
                              color: TreasuryTokens.brandSoft,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: TreasuryTokens.brand
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.flag_rounded,
                                    size: 12,
                                    color: TreasuryTokens.brandDeep),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    step.nduNote!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: TreasuryTokens.ink,
                                      height: 1.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // ── Expanded deliverables ─────────────────────────
                        if (expanded && step.deliverables.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'TANGIBLE OUTPUTS',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: TreasuryTokens.muted,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: step.deliverables
                                .map((d) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: TreasuryTokens.surfaceAlt,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                            color: TreasuryTokens.hairline),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle_outline,
                                              size: 11,
                                              color: step.phase.accent),
                                          const SizedBox(width: 5),
                                          Text(
                                            d,
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: TreasuryTokens.inkSoft,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                        // ── Expand hint ──────────────────────────────────
                        if (step.deliverables.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                expanded ? 'Hide details' : 'View deliverables',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: step.phase.accent,
                                ),
                              ),
                              Icon(
                                expanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 14,
                                color: step.phase.accent,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STATUS PILL
// ═══════════════════════════════════════════════════════════════════════════

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final _StepStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.soft,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: status.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: status.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              color: status.color,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// METHODOLOGY LEGEND
// ═══════════════════════════════════════════════════════════════════════════

class _MethodologyLegend extends StatelessWidget {
  const _MethodologyLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: TreasuryTokens.canvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TreasuryTokens.hairline),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'PHASE KEY:',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: TreasuryTokens.muted,
              letterSpacing: 1.0,
            ),
          ),
          for (final phase in _MethodologyPhase.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: phase.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  phase.label.split(' · ').last,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: TreasuryTokens.inkSoft,
                  ),
                ),
              ],
            ),
          const SizedBox(width: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'STATUS:',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: TreasuryTokens.muted,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              for (final s in [
                _StepStatus.notStarted,
                _StepStatus.inProgress,
                _StepStatus.complete,
              ]) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: s.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: s.color,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// METHODOLOGY PROGRESS PILL (top-right trailing widget)
// ═══════════════════════════════════════════════════════════════════════════

class _MethodologyProgressPill extends StatelessWidget {
  const _MethodologyProgressPill({required this.steps});
  final List<_MethodologyStep> steps;

  @override
  Widget build(BuildContext context) {
    final done = steps.where((s) => s.status == _StepStatus.complete).length;
    final inProg =
        steps.where((s) => s.status == _StepStatus.inProgress).length;
    final pct = (done / steps.length * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: TreasuryTokens.brandSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TreasuryTokens.brand.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timeline_rounded,
              size: 13, color: TreasuryTokens.brandDeep),
          const SizedBox(width: 6),
          Text(
            '$done/${steps.length} done · $inProg in progress · $pct%',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: TreasuryTokens.brandDeep,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ESTIMATE BASIS CARD
// ═══════════════════════════════════════════════════════════════════════════

class _BasisItem {
  const _BasisItem({
    required this.title,
    required this.bullets,
    required this.icon,
  });
  final String title;
  final List<String> bullets;
  final IconData icon;
}

class EstimateBasisCard extends StatelessWidget {
  const EstimateBasisCard({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_BasisItem>[
      const _BasisItem(
        title: 'Scope alignment',
        icon: Icons.account_tree_outlined,
        bullets: [
          'Estimates tied directly to WBS elements, EWPs, and CWPs',
          'Every duration reflects a clearly defined deliverable or work package',
        ],
      ),
      const _BasisItem(
        title: 'Estimation methods',
        icon: Icons.calculate_outlined,
        bullets: [
          'Expert judgment',
          'Historical project data',
          'Parametric or productivity-based rates',
          'Three-point estimating where uncertainty is high',
        ],
      ),
      const _BasisItem(
        title: 'Key assumptions',
        icon: Icons.tune_rounded,
        bullets: [
          'Resource availability and crew sizes',
          'Productivity rates and learning curves',
          'Working calendars and shift patterns',
          'Site conditions and access',
        ],
      ),
      const _BasisItem(
        title: 'Procurement considerations',
        icon: Icons.local_shipping_outlined,
        bullets: [
          'Vendor lead times',
          'Fabrication durations',
          'Logistics and delivery constraints',
          'Contract award timelines',
        ],
      ),
      const _BasisItem(
        title: 'Engineering considerations',
        icon: Icons.design_services_outlined,
        bullets: [
          'Design complexity',
          'Review and approval cycles',
          'Iteration and rework allowances',
        ],
      ),
      const _BasisItem(
        title: 'Constraints and risks',
        icon: Icons.warning_amber_rounded,
        bullets: [
          'Dependencies between engineering, procurement, and construction',
          'Long-lead or critical items',
          'External approvals and permits',
          'Known uncertainties and contingency assumptions',
        ],
      ),
      const _BasisItem(
        title: 'Validation and benchmarking',
        icon: Icons.verified_outlined,
        bullets: [
          'Comparison against similar projects',
          'Cross-functional review of durations',
          'Alignment with the Critical Path Method to ensure logical consistency',
        ],
      ),
      const _BasisItem(
        title: 'Documentation',
        icon: Icons.description_outlined,
        bullets: [
          'Clearly recorded assumptions, exclusions, and confidence levels',
          'Provides transparency and supports future updates',
        ],
      ),
    ];

    return TreasurySectionCard(
      title: 'Estimate Basis',
      subtitle:
          'Assumptions, methods, and data sources used to determine activity durations across engineering, procurement, and execution',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: TreasuryTokens.infoSoft,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: TreasuryTokens.info.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fact_check_outlined,
                size: 12, color: TreasuryTokens.info),
            const SizedBox(width: 5),
            Text(
              '${items.length} CATEGORIES',
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: TreasuryTokens.info,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Intro line
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            decoration: BoxDecoration(
              color: TreasuryTokens.canvas,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: TreasuryTokens.hairline),
            ),
            child: const Text(
              'The Estimate Basis defines the assumptions, methods, and data sources used to determine activity durations across engineering, procurement, and execution. It is the foundation beneath every duration in the schedule.',
              style: TextStyle(
                fontSize: 11.5,
                color: TreasuryTokens.inkSoft,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Grid of basis cards
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items
                .map((item) => _BasisTile(item: item))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _BasisTile extends StatelessWidget {
  const _BasisTile({required this.item});
  final _BasisItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: TreasuryTokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TreasuryTokens.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: TreasuryTokens.brandSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(item.icon,
                    size: 14, color: TreasuryTokens.brandDeep),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: TreasuryTokens.ink,
                    letterSpacing: -0.05,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final b in item.bullets) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: TreasuryTokens.brandDeep,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    b,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: TreasuryTokens.inkSoft,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SCHEDULE READINESS RULES
// ═══════════════════════════════════════════════════════════════════════════

class _ReadinessGate {
  const _ReadinessGate({
    required this.label,
    required this.description,
    required this.icon,
    this.cleared = false,
  });
  final String label;
  final String description;
  final IconData icon;
  final bool cleared;
}

class ScheduleReadinessRules extends StatefulWidget {
  const ScheduleReadinessRules({super.key, this.clearedGates = const []});

  /// Labels of gates that are cleared (e.g., ['engineering', 'materials'])
  final List<String> clearedGates;

  @override
  State<ScheduleReadinessRules> createState() => _ScheduleReadinessRulesState();
}

class _ScheduleReadinessRulesState extends State<ScheduleReadinessRules> {
  late final Map<String, bool> _cleared;

  @override
  void initState() {
    super.initState();
    _cleared = {
      'engineering': widget.clearedGates.contains('engineering'),
      'materials': widget.clearedGates.contains('materials'),
      'permits': widget.clearedGates.contains('permits'),
      'predecessors': widget.clearedGates.contains('predecessors'),
    };
  }

  void _toggle(String key) {
    setState(() => _cleared[key] = !(_cleared[key] ?? false));
  }

  @override
  Widget build(BuildContext context) {
    final gates = <_ReadinessGate>[
      _ReadinessGate(
        label: 'engineering',
        description: 'All IFC drawings, specs, and calculations released',
        icon: Icons.design_services_outlined,
        cleared: _cleared['engineering'] ?? false,
      ),
      _ReadinessGate(
        label: 'materials',
        description: 'Long-lead and bulk materials delivered to site',
        icon: Icons.inventory_2_outlined,
        cleared: _cleared['materials'] ?? false,
      ),
      _ReadinessGate(
        label: 'permits',
        description: 'Construction permits and access approvals in hand',
        icon: Icons.assignment_turned_in_outlined,
        cleared: _cleared['permits'] ?? false,
      ),
      _ReadinessGate(
        label: 'predecessors',
        description: 'All predecessor CWPs marked complete',
        icon: Icons.link_rounded,
        cleared: _cleared['predecessors'] ?? false,
      ),
    ];
    final clearedCount = gates.where((g) => g.cleared).length;
    final allCleared = clearedCount == gates.length;

    return TreasurySectionCard(
      title: 'Schedule Readiness Rules',
      subtitle:
          'A CWP should not start unless all constraints are cleared — the core of reliable execution planning',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: allCleared
              ? TreasuryTokens.successSoft
              : TreasuryTokens.warningSoft,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: (allCleared
                    ? TreasuryTokens.success
                    : TreasuryTokens.warning)
                .withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              allCleared ? Icons.check_circle : Icons.lock_clock_outlined,
              size: 13,
              color: allCleared
                  ? TreasuryTokens.success
                  : TreasuryTokens.warning,
            ),
            const SizedBox(width: 5),
            Text(
              allCleared ? 'READY TO START' : '$clearedCount/${gates.length} GATES',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: allCleared
                    ? TreasuryTokens.success
                    : TreasuryTokens.warning,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            decoration: BoxDecoration(
              color: allCleared
                  ? TreasuryTokens.successSoft
                  : TreasuryTokens.warningSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (allCleared
                        ? TreasuryTokens.success
                        : TreasuryTokens.warning)
                    .withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  allCleared
                      ? Icons.verified_rounded
                      : Icons.gpp_maybe_outlined,
                  size: 16,
                  color: allCleared
                      ? TreasuryTokens.success
                      : TreasuryTokens.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    allCleared
                        ? 'All gates cleared — CWP may be released to "In Progress".'
                        : 'CWP release blocked — clear the remaining gates below before moving from "Planned" to "In Progress".',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: TreasuryTokens.ink,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: gates
                .map((g) => _ReadinessGateTile(
                      gate: g,
                      onToggle: () => _toggle(g.label),
                    ))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _ReadinessGateTile extends StatelessWidget {
  const _ReadinessGateTile({
    required this.gate,
    required this.onToggle,
  });
  final _ReadinessGate gate;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = gate.cleared
        ? TreasuryTokens.success
        : TreasuryTokens.mutedSoft;
    final soft = gate.cleared
        ? TreasuryTokens.successSoft
        : TreasuryTokens.canvas;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 290,
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: TreasuryTokens.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: gate.cleared
                  ? TreasuryTokens.success.withValues(alpha: 0.5)
                  : TreasuryTokens.hairline,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: soft,
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.45)),
                ),
                child: Icon(gate.icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            gate.label[0].toUpperCase() +
                                gate.label.substring(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: TreasuryTokens.ink,
                              letterSpacing: -0.05,
                            ),
                          ),
                        ),
                        Icon(
                          gate.cleared
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 18,
                          color: color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      gate.description,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: TreasuryTokens.inkSoft,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
