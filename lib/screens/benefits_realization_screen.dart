import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:ndu_project/screens/demobilize_team_screen.dart';
import 'package:ndu_project/screens/financial_closeout_screen.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_notes_section.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';

/// Section 9 — Benefits Realization
///
/// Measure whether the project achieved its intended business outcomes.
///
/// Subsections:
///   1. Benefits Dashboard
///   2. Benefits Quantification
///   3. Continuous Benefits Tracking
class BenefitsRealizationScreen extends StatefulWidget {
  const BenefitsRealizationScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BenefitsRealizationScreen()),
    );
  }

  @override
  State<BenefitsRealizationScreen> createState() =>
      _BenefitsRealizationScreenState();
}

class _BenefitsRealizationScreenState extends State<BenefitsRealizationScreen> {
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _dashboardController = TextEditingController();
  final TextEditingController _quantificationController = TextEditingController();
  final TextEditingController _continuousTrackingController =
      TextEditingController();

  bool _isLoading = true;
  bool _hasLoaded = false;
  bool _suspendSave = false;

  @override
  void initState() {
    super.initState();
    _notesController.addListener(_scheduleSave);
    _dashboardController.addListener(_scheduleSave);
    _quantificationController.addListener(_scheduleSave);
    _continuousTrackingController.addListener(_scheduleSave);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _notesController.dispose();
    _dashboardController.dispose();
    _quantificationController.dispose();
    _continuousTrackingController.dispose();
    super.dispose();
  }

  String? get _projectId => ProjectDataHelper.getData(context).projectId;

  void _scheduleSave() {
    if (_suspendSave || !_hasLoaded) return;
    Future.microtask(() {
      if (mounted) _persistData();
    });
  }

  Future<void> _loadData() async {
    if (_hasLoaded || _projectId == null) return;
    _suspendSave = true;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(_projectId!)
          .collection('execution_phase_sections')
          .doc('benefits_realization')
          .get();
      final data = doc.data() ?? {};

      if (!mounted) return;
      setState(() {
        _dashboardController.text = data['dashboard']?.toString() ?? '';
        _quantificationController.text =
            data['quantification']?.toString() ?? '';
        _continuousTrackingController.text =
            data['continuousTracking']?.toString() ?? '';
        _notesController.text = data['notes']?.toString() ?? '';
        _isLoading = false;
        _hasLoaded = true;
      });
    } catch (e) {
      debugPrint('Benefits Realization load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLoaded = true;
        });
      }
    }
    _suspendSave = false;
  }

  Future<void> _persistData() async {
    if (_projectId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(_projectId!)
          .collection('execution_phase_sections')
          .doc('benefits_realization')
          .set({
        'dashboard': _dashboardController.text.trim(),
        'quantification': _quantificationController.text.trim(),
        'continuousTracking': _continuousTrackingController.text.trim(),
        'notes': _notesController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Benefits Realization save error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.sizeOf(context).width < 980;

    return ResponsiveScaffold(
      activeItemLabel: '9. Benefits Realization',
      backgroundColor: Colors.white,
      floatingActionButton: const KazAiChatBubble(positioned: false),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 32,
          vertical: isMobile ? 16 : 28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading) const LinearProgressIndicator(minHeight: 2),
            const PlanningPhaseHeader(
              title: 'Benefits Realization',
              showNavigationButtons: false,
              showActivityLogAction: false,
            ),
            const SizedBox(height: 12),
            _buildIntroPanel(),
            const SizedBox(height: 16),
            _buildSubsectionCard(
              title: 'Benefits Dashboard',
              description:
                  'Track planned versus actual benefits across six categories: Financial, Operational, Customer, Strategic, Sustainability, and Innovation.',
              hintItems: const [
                'Financial (ROI, cost savings, revenue)',
                'Operational (cycle time, productivity, quality)',
                'Customer (satisfaction, adoption)',
                'Strategic (market share, compliance, capability)',
                'Sustainability (energy, waste, emissions)',
                'Innovation (new products, IP, process improvements)',
              ],
              controller: _dashboardController,
            ),
            const SizedBox(height: 16),
            _buildSubsectionCard(
              title: 'Benefits Quantification',
              description:
                  'Capture measurable value including planned value, actual value, variance, benefit realization %, benefit owner, measurement method, validation evidence, and realization timeline.',
              hintItems: const [
                'Planned Value',
                'Actual Value',
                'Variance',
                'Benefit Realization %',
                'Benefit Owner',
                'Measurement Method',
                'Validation Evidence',
                'Realization Timeline',
              ],
              controller: _quantificationController,
            ),
            const SizedBox(height: 16),
            _buildSubsectionCard(
              title: 'Continuous Benefits Tracking',
              description:
                  'For benefits that extend beyond project completion, capture future review dates, operational KPIs, benefit sustainability, and ongoing improvement actions.',
              hintItems: const [
                'Future Review Dates',
                'Operational KPIs',
                'Benefit Sustainability',
                'Ongoing Improvement Actions',
              ],
              controller: _continuousTrackingController,
            ),
            const SizedBox(height: 16),
            LaunchNotesSection(
              controller: _notesController,
              onChanged: (v) {},
            ),
            const SizedBox(height: 24),
            LaunchPhaseNavigation(
              backLabel: 'Back: Project Performance Review',
              nextLabel:
                  'Next: Team Demobilization & Operations/Production Transition',
              onBack: () => FinancialCloseoutScreen.open(context),
              onNext: () => DemobilizeTeamScreen.open(context),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: Color(0xFF047857), size: 22),
              SizedBox(width: 10),
              Text(
                'Measure business outcomes',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF064E3B),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Measure whether the project achieved its intended business outcomes. '
            'This section tracks planned versus actual benefits across financial, operational, customer, strategic, '
            'sustainability, and innovation dimensions, and supports continuous tracking for benefits that extend beyond project completion.',
            style: TextStyle(fontSize: 13, color: Color(0xFF065F46), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSubsectionCard({
    required String title,
    required String description,
    required List<String> hintItems,
    required TextEditingController controller,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: hintItems
                .map((h) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Text(
                        h,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF065F46)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Enter details for this subsection...',
              hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: Color(0xFF10B981)),
              ),
              contentPadding: EdgeInsets.all(12),
            ),
            style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
          ),
        ],
      ),
    );
  }
}
