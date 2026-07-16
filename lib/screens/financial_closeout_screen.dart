import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:ndu_project/screens/benefits_realization_screen.dart';
import 'package:ndu_project/screens/commerce_viability_screen.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_notes_section.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';

/// Section 7 — Financial Closeout
///
/// Finalize all financial activities and reconcile project costs with accounting.
///
/// Subsections:
///   1. Financial Summary
///   2. Accounting Reconciliation
///   3. Financial Analysis
class FinancialCloseoutScreen extends StatefulWidget {
  const FinancialCloseoutScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FinancialCloseoutScreen()),
    );
  }

  @override
  State<FinancialCloseoutScreen> createState() =>
      _FinancialCloseoutScreenState();
}

class _FinancialCloseoutScreenState extends State<FinancialCloseoutScreen> {
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _reconciliationController = TextEditingController();
  final TextEditingController _analysisController = TextEditingController();

  bool _isLoading = true;
  bool _hasLoaded = false;
  bool _suspendSave = false;

  @override
  void initState() {
    super.initState();
    _notesController.addListener(_scheduleSave);
    _summaryController.addListener(_scheduleSave);
    _reconciliationController.addListener(_scheduleSave);
    _analysisController.addListener(_scheduleSave);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _notesController.dispose();
    _summaryController.dispose();
    _reconciliationController.dispose();
    _analysisController.dispose();
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
          .doc('financial_closeout')
          .get();
      final data = doc.data() ?? {};

      if (!mounted) return;
      setState(() {
        _summaryController.text = data['summary']?.toString() ?? '';
        _reconciliationController.text = data['reconciliation']?.toString() ?? '';
        _analysisController.text = data['analysis']?.toString() ?? '';
        _notesController.text = data['notes']?.toString() ?? '';
        _isLoading = false;
        _hasLoaded = true;
      });
    } catch (e) {
      debugPrint('Financial Closeout load error: $e');
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
          .doc('financial_closeout')
          .set({
        'summary': _summaryController.text.trim(),
        'reconciliation': _reconciliationController.text.trim(),
        'analysis': _analysisController.text.trim(),
        'notes': _notesController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Financial Closeout save error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.sizeOf(context).width < 980;

    return ResponsiveScaffold(
      activeItemLabel: '7. Financial Closeout',
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
              title: 'Financial Closeout',
              showNavigationButtons: false,
              showActivityLogAction: false,
            ),
            const SizedBox(height: 12),
            _buildIntroPanel(),
            const SizedBox(height: 16),
            _buildSubsectionCard(
              title: 'Financial Summary',
              description:
                  'Finalize the project financial summary including approved budget, actual cost, cost variance, forecast accuracy, final cost performance, CPI, and cost breakdown.',
              hintItems: const [
                'Approved Budget',
                'Actual Cost',
                'Cost Variance',
                'Forecast Accuracy',
                'Final Cost Performance',
                'CPI',
                'Cost Breakdown',
              ],
              controller: _summaryController,
            ),
            const SizedBox(height: 16),
            _buildSubsectionCard(
              title: 'Accounting Reconciliation',
              description:
                  'Reconcile all accounting records including invoice status, purchase orders, capitalization, expense reconciliation, GL coding, accounting approval, and audit package.',
              hintItems: const [
                'Invoice Status',
                'Purchase Orders',
                'Capitalization',
                'Expense Reconciliation',
                'GL Coding',
                'Accounting Approval',
                'Audit Package',
              ],
              controller: _reconciliationController,
            ),
            const SizedBox(height: 16),
            _buildSubsectionCard(
              title: 'Financial Analysis',
              description:
                  'Capture the final financial analysis including earned value summary, ROI, cash flow summary, budget utilization, and financial lessons learned.',
              hintItems: const [
                'Earned Value Summary',
                'ROI',
                'Cash Flow Summary',
                'Budget Utilization',
                'Financial Lessons Learned',
              ],
              controller: _analysisController,
            ),
            const SizedBox(height: 16),
            LaunchNotesSection(
              controller: _notesController,
              onChanged: (v) {},
            ),
            const SizedBox(height: 24),
            LaunchPhaseNavigation(
              backLabel: 'Back: Hypercare & Warranty Support',
              nextLabel: 'Next: Project Performance Review',
              onBack: () => CommerceViabilityScreen.open(context),
              onNext: () => BenefitsRealizationScreen.open(context),
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
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Color(0xFF1D4ED8), size: 22),
              SizedBox(width: 10),
              Text(
                'Finalize all financial activities',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Finalize all financial activities and reconcile project costs with accounting. '
            'This section captures the financial summary, accounting reconciliation, and the final financial analysis '
            'including earned value, ROI, and lessons learned.',
            style: TextStyle(fontSize: 13, color: Color(0xFF1E40AF), height: 1.5),
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
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        h,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
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
                borderSide: BorderSide(color: Color(0xFF3B82F6)),
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
