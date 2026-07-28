import 'package:ndu_project/widgets/voice_text_field.dart';
// ignore_for_file: unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ndu_project/screens/long_lead_equipment_ordering_screen.dart';
import 'package:ndu_project/screens/technical_development_screen.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/activity_log_service.dart';
import 'package:ndu_project/services/design_phase_service.dart';
import 'package:ndu_project/models/design_phase_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/widgets/csv_table_import_button.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/services/openai_service_secure.dart';

class SpecializedDesignScreen extends StatefulWidget {
 const SpecializedDesignScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const SpecializedDesignScreen()),
 );
 }

 @override
 State<SpecializedDesignScreen> createState() =>
 _SpecializedDesignScreenState();
}

class _SpecializedDesignScreenState extends State<SpecializedDesignScreen> {
 final _Debouncer _saveDebouncer = _Debouncer();
 bool _isLoading = false;
 String? _loadError;

 // Registers
 List<SecurityPatternRow> _securityRows = [];
 List<PerformancePatternRow> _performanceRows = [];
 List<IntegrationFlowRow> _integrationRows = [];
 List<_ComplianceRow> _complianceRows = [];
 List<_ReviewGateRow> _reviewGates = [];
 bool _frameworkGuideExpanded = false;
 String? _isKazAiLoadingRowId;

 static const List<String> _statusOptions = [
 'Ready',
 'In review',
 'Draft',
 'Pending',
 'In progress',
 'Deprecated',
 ];

 static const List<String> _complianceStatusOptions = [
 'Compliant',
 'Non-compliant',
 'In progress',
 'Not assessed',
 'Partial',
 ];

 static const List<String> _reviewGateStatusOptions = [
 'Pending',
 'In Review',
 'Approved',
 'Rejected',
 'Waived',
 'Not Started',
 ];

 String _normalizeStatus(String value) {
 final normalized = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
 if (normalized.isEmpty) return 'Draft';
 for (final option in _statusOptions) {
 if (option.toLowerCase().replaceAll(RegExp(r'\s+'), ' ') == normalized) return option;
 }
 const aliases = <String, String>{
 'recommended': 'In review', 'under review': 'In review',
 'complete': 'Ready', 'completed': 'Ready', 'done': 'Ready',
 'todo': 'Draft', 'not started': 'Draft',
 };
 return aliases[normalized] ?? 'Draft';
 }

 String? get _projectId {
 try {
 final provider = ProjectDataInherited.maybeOf(context);
 return provider?.projectData.projectId;
 } catch (e) {
 return null;
 }
 }

 @override
 void initState() {
 super.initState();
 _securityRows = _defaultSecurityRows();
 _performanceRows = _defaultPerformanceRows();
 _integrationRows = _defaultIntegrationRows();
 _complianceRows = _defaultComplianceRows();
 _reviewGates = _defaultReviewGates();
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
 }

 
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Specialized Design',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['specialized_design_screen'] ?? 'No data recorded.'),
 ],
 );
 }
@override
 void dispose() {
 _saveDebouncer.dispose();
 super.dispose();
 }

 DocumentReference<Map<String, dynamic>> _docFor(String projectId) {
 return FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('design_phase_sections')
 .doc('specialized_design');
 }

 void _scheduleSave() {
 _saveDebouncer.run(_saveToFirestore);
 }

 Future<void> _loadData() async {
 final projectId = _projectId;
 if (projectId == null || projectId.isEmpty) return;
 if (!mounted) return;
 setState(() => _isLoading = true);
 try {
 final data = await DesignPhaseService.instance.loadSpecializedDesign(projectId);
 final doc = await _docFor(projectId).get();
 final extra = doc.data() ?? {};
 _suspendSave = true;
 if (!mounted) return;
 final complianceRows = _ComplianceRow.fromList(extra['complianceRows']);
 final reviewGates = _ReviewGateRow.fromList(extra['reviewGates']);
 setState(() {
 _securityRows = data.securityPatterns.isNotEmpty ? data.securityPatterns : _defaultSecurityRows();
 for (final row in _securityRows) { row.status = _normalizeStatus(row.status); }
 _performanceRows = data.performancePatterns.isNotEmpty ? data.performancePatterns : _defaultPerformanceRows();
 for (final row in _performanceRows) { row.status = _normalizeStatus(row.status); }
 _integrationRows = data.integrationFlows.isNotEmpty ? data.integrationFlows : _defaultIntegrationRows();
 for (final row in _integrationRows) { row.status = _normalizeStatus(row.status); }
 _complianceRows = complianceRows.isNotEmpty ? complianceRows : _defaultComplianceRows();
 _reviewGates = reviewGates.isNotEmpty ? reviewGates : _defaultReviewGates();
 });
 } catch (e) {
 debugPrint('Error loading specialized design: $e');
 setState(() => _loadError = 'Unable to load specialized design data.');
 } finally {
 _suspendSave = false;
 if (mounted) setState(() => _isLoading = false);
 }
 }

 bool _suspendSave = false;

 Future<void> _saveToFirestore() async {
 final projectId = _projectId;
 if (projectId == null || projectId.isEmpty) return;
 try {
 final data = SpecializedDesignData(
 securityPatterns: _dedupeSecurityRows(_securityRows),
 performancePatterns: _dedupePerformanceRows(_performanceRows),
 integrationFlows: _dedupeIntegrationRows(_integrationRows),
 );
 await DesignPhaseService.instance.saveSpecializedDesign(projectId, data);
 await _docFor(projectId).set({
 'complianceRows': _complianceRows.map((e) => e.toMap()).toList(),
 'reviewGates': _reviewGates.map((e) => e.toMap()).toList(),
 'updatedAt': FieldValue.serverTimestamp(),
 }, SetOptions(merge: true));
 _logActivity('Updated Specialized Design data');
 } catch (e) {
 debugPrint('Error saving specialized design: $e');
 }
 }

 List<SecurityPatternRow> _dedupeSecurityRows(Iterable<SecurityPatternRow> rows) {
 final seen = <String>{};
 return rows.where((r) {
 final key = '${r.pattern}|${r.decision}|${r.owner}|${r.status}';
 if (key == '|||' || !seen.add(key)) return false;
 return true;
 }).toList();
 }

 List<PerformancePatternRow> _dedupePerformanceRows(Iterable<PerformancePatternRow> rows) {
 final seen = <String>{};
 return rows.where((r) {
 final key = '${r.hotspot}|${r.focus}|${r.sla}|${r.status}';
 if (key == '|||' || !seen.add(key)) return false;
 return true;
 }).toList();
 }

 List<IntegrationFlowRow> _dedupeIntegrationRows(Iterable<IntegrationFlowRow> rows) {
 final seen = <String>{};
 return rows.where((r) {
 final key = '${r.flow}|${r.owner}|${r.system}|${r.status}';
 if (key == '|||' || !seen.add(key)) return false;
 return true;
 }).toList();
 }

 void _logActivity(String action, {Map<String, dynamic>? details}) {
 final projectId = _projectId;
 if (projectId == null) return;
 unawaited(ActivityLogService.instance.logActivity(
 projectId: projectId, phase: 'Design Phase', page: 'Specialized Design',
 action: action, details: details,
 ));
 }

 // ─── Default Data ────────────────────────────────────────────────

 List<SecurityPatternRow> _defaultSecurityRows() {
 return [
 SecurityPatternRow(pattern: 'Zero Trust Network Architecture', decision: 'Implement micro-segmentation with identity-based access control. Every request must be authenticated, authorized, and encrypted regardless of network location. Aligns with NIST SP 800-207 Zero Trust Architecture.', owner: 'Security Architect', status: 'In review'),
 SecurityPatternRow(pattern: 'Data-at-Rest Encryption (AES-256)', decision: 'All persistent storage encrypted using AES-256-GCM with customer-managed keys (CMK). Key rotation every 90 days. Aligns with SOC 2 Type II and GDPR Article 32.', owner: 'Security Lead', status: 'Ready'),
 SecurityPatternRow(pattern: 'Multi-Factor Authentication (MFA)', decision: 'Hardware-backed MFA required for all privileged accounts. FIDO2/WebAuthn as primary, TOTP as fallback. Session timeout 15 minutes for admin roles, 4 hours for standard users.', owner: 'Identity Lead', status: 'Ready'),
 SecurityPatternRow(pattern: 'API Gateway Rate Limiting & Throttling', decision: 'Implement tiered rate limiting: 100 req/min standard, 1000 req/min premium. DDoS protection via WAF with OWASP Top 10 rule set. Circuit breaker pattern for downstream services.', owner: 'Platform Engineer', status: 'Draft'),
 SecurityPatternRow(pattern: 'Audit Logging & SIEM Integration', decision: 'Centralized audit trail for all data access and configuration changes. Forward to SIEM with real-time alerting on anomaly detection. Retention period 7 years per regulatory requirement.', owner: 'Compliance Officer', status: 'In progress'),
 ];
 }

 List<PerformancePatternRow> _defaultPerformanceRows() {
 return [
 PerformancePatternRow(hotspot: 'Database query optimization', focus: 'Implement read replicas for reporting queries. Add composite indexes on frequently filtered columns. Query timeout 30s with automatic EXPLAIN analysis on slow queries.', sla: 'p99 < 200ms', status: 'In progress'),
 PerformancePatternRow(hotspot: 'API response latency', focus: 'Implement response caching with 5-minute TTL for reference data. Use GraphQL for selective field retrieval. Add connection pooling with max 100 concurrent connections per service.', sla: 'p95 < 150ms', status: 'Draft'),
 PerformancePatternRow(hotspot: 'File upload throughput', focus: 'Implement chunked upload (5MB chunks) with resume capability. Use pre-signed URLs for direct-to-S3 uploads. Parallel chunk upload with 4 concurrent streams per client.', sla: '> 50 MB/s', status: 'Draft'),
 PerformancePatternRow(hotspot: 'Real-time notification delivery', focus: 'WebSocket connection pooling with auto-reconnect. Message queue (Kafka/RabbitMQ) for guaranteed delivery. Batch push notifications every 30 seconds for non-critical alerts.', sla: '< 500ms latency', status: 'Pending'),
 PerformancePatternRow(hotspot: 'Report generation', focus: 'Asynchronous report generation with progress polling. Pre-compute daily aggregates for standard reports. PDF export offloaded to dedicated worker pool with 4 vCPU / 8GB RAM.', sla: '< 30s for 10K rows', status: 'Draft'),
 ];
 }

 List<IntegrationFlowRow> _defaultIntegrationRows() {
 return [
 IntegrationFlowRow(flow: 'Identity Provider SSO (SAML 2.0 / OIDC)', owner: 'Identity Lead', system: 'Azure AD / Okta', status: 'Ready'),
 IntegrationFlowRow(flow: 'ERP bi-directional sync (SAP / Oracle)', owner: 'Integration Architect', system: 'SAP S/4HANA', status: 'In review'),
 IntegrationFlowRow(flow: 'Payment gateway (Stripe / Adyen)', owner: 'Fintech Lead', system: 'Stripe API v2024', status: 'Draft'),
 IntegrationFlowRow(flow: 'CI/CD pipeline integration (GitHub Actions)', owner: 'DevOps Lead', system: 'GitHub Enterprise', status: 'Ready'),
 IntegrationFlowRow(flow: 'Monitoring & observability (Datadog / Grafana)', owner: 'SRE Lead', system: 'Datadog APM', status: 'In progress'),
 ];
 }

 List<_ComplianceRow> _defaultComplianceRows() {
 return [
 _ComplianceRow(id: _newId(), standard: 'SOC 2 Type II', description: 'Service Organization Control audit covering security, availability, processing integrity, confidentiality, and privacy. Annual audit cycle with quarterly readiness assessments.', status: 'Compliant', owner: 'Compliance Officer', evidence: 'Audit report Q3 2025'),
 _ComplianceRow(id: _newId(), standard: 'GDPR (EU Data Protection)', description: 'General Data Protection Regulation compliance including data residency, right to erasure, data portability, and privacy impact assessments for EU data subjects.', status: 'In progress', owner: 'DPO', evidence: 'DPIA v2.1 in review'),
 _ComplianceRow(id: _newId(), standard: 'ISO 27001 Annex A', description: 'Information Security Management System controls covering 93 security controls across organizational, people, physical, and technological domains.', status: 'Partial', owner: 'CISO', evidence: 'Gap assessment 78% complete'),
 _ComplianceRow(id: _newId(), standard: 'PCI DSS v4.0', description: 'Payment Card Industry Data Security Standard for handling cardholder data. Requirements for network segmentation, encryption, access control, and regular penetration testing.', status: 'Not assessed', owner: 'Security Architect', evidence: 'Scope assessment pending'),
 _ComplianceRow(id: _newId(), standard: 'WCAG 2.1 AA', description: 'Web Content Accessibility Guidelines ensuring digital interfaces are perceivable, operable, understandable, and robust for users with disabilities.', status: 'In progress', owner: 'UX Lead', evidence: 'Automated scan: 92% pass rate'),
 ];
 }

 List<_ReviewGateRow> _defaultReviewGates() {
 return [
 _ReviewGateRow(id: _newId(), gate: 'Security Architecture Review', description: 'Validate security patterns, threat model, encryption standards, and access control architecture against NIST CSF and organizational security policies.', approver: 'CISO', department: 'Security', priority: 'Critical', status: 'In Review', targetDate: 'TBD'),
 _ReviewGateRow(id: _newId(), gate: 'Performance Baseline Acceptance', description: 'Confirm performance SLA targets are achievable under load testing. Validate caching strategy, database query performance, and auto-scaling thresholds.', approver: 'VP Engineering', department: 'Engineering', priority: 'Critical', status: 'Pending', targetDate: 'TBD'),
 _ReviewGateRow(id: _newId(), gate: 'Integration Contract Sign-off', description: 'Validate API contracts, data schemas, authentication flows, and error handling patterns for all external system integrations before development begins.', approver: 'Integration Architect', department: 'Architecture', priority: 'High', status: 'Pending', targetDate: 'TBD'),
 _ReviewGateRow(id: _newId(), gate: 'Compliance Readiness Review', description: 'Verify all applicable regulatory standards (SOC 2, GDPR, PCI DSS) have documented controls, evidence collection processes, and remediation plans for gaps.', approver: 'Compliance Officer', department: 'Legal/Compliance', priority: 'High', status: 'Not Started', targetDate: 'TBD'),
 _ReviewGateRow(id: _newId(), gate: 'Disaster Recovery Validation', description: 'Test failover procedures, confirm RTO (4 hours) and RPO (1 hour) targets are achievable, and validate backup integrity and restoration procedures.', approver: 'SRE Lead', department: 'Operations', priority: 'Critical', status: 'Not Started', targetDate: 'TBD'),
 _ReviewGateRow(id: _newId(), gate: 'Specialized Design Handoff', description: 'Final review confirming all specialized design decisions are documented, implementation-ready, and accepted by engineering leads for build phase entry.', approver: 'Technical Lead', department: 'Engineering', priority: 'High', status: 'Not Started', targetDate: 'TBD'),
 ];
 }

 String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

 // ─── Build ────────────────────────────────────────────────────────

 @override
 Widget build(BuildContext context) {
 final padding = AppBreakpoints.pagePadding(context);

 return ResponsiveScaffold(
 activeItemLabel: 'Specialized Design',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: Column(
 children: [
 PlanningPhaseHeader(
 title: 'Specialized Design',
showNavigationButtons: false, onExportPdf: _exportPdf),
 Expanded(
 child: SingleChildScrollView(
 padding: EdgeInsets.all(padding),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (_isLoading) const LinearProgressIndicator(minHeight: 2),
 if (_isLoading) const SizedBox(height: 16),
 _buildHeader(),
 const SizedBox(height: 20),
 _buildFrameworkGuide(),
 const SizedBox(height: 24),
 _buildSecurityRegister(),
 const SizedBox(height: 20),
 _buildPerformanceRegister(),
 const SizedBox(height: 20),
 _buildIntegrationRegister(),
 const SizedBox(height: 20),
 _buildComplianceRegister(),
 const SizedBox(height: 20),
 _buildReviewGatesPanel(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Technical Development',
 nextLabel: 'Next: Long Lead Equipment Ordering',
 onBack: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TechnicalDevelopmentScreen())),
 onNext: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LongLeadEquipmentOrderingScreen())),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }

 // ─── Header ────────────────────────────────────────────────────────

 Widget _buildHeader() {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFFFFC812),
 borderRadius: BorderRadius.circular(6),
 ),
 child: const Text(
 'SPECIALIZED TRACKS',
 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black),
 ),
 ),
 const SizedBox(height: 10),
 const Text('Specialized Design', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
 const SizedBox(height: 6),
 const Text(
 'Manage security patterns, performance engineering, integration contracts, and compliance requirements for the project. '
 'Aligned with NIST Cybersecurity Framework, ISO 27001, SOC 2 Type II, and PCI DSS standards. '
 'This register ensures specialized design decisions remain traceable, validated, and reviewable throughout the design phase.',
 style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
 ),
 ],
 );
 }

 // ─── Framework Guide ────────────────────────────────────────────────

 Widget _buildFrameworkGuide() {
 return Container(
 decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))]),
 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 // Clickable header row
 InkWell(
 onTap: () => setState(() => _frameworkGuideExpanded = !_frameworkGuideExpanded),
 borderRadius: BorderRadius.circular(16),
 child: Padding(
 padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
 child: Row(
 children: [
 const Expanded(
 child: Text('Specialized design framework', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
 ),
 AnimatedRotation(
 duration: const Duration(milliseconds: 200),
 turns: _frameworkGuideExpanded ? 0.5 : 0,
 child: Icon(Icons.expand_more, size: 22, color: const Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 ),
 // Collapsible content
 AnimatedCrossFade(
 firstChild: const SizedBox(width: double.infinity, height: 0),
 secondChild: Padding(
 padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 const Text(
 'Grounded in NIST Cybersecurity Framework (CSF), ISO/IEC 27001:2022 Annex A controls, '
 'SOC 2 Type II trust service criteria, and PCI DSS v4.0 requirements. Effective specialized '
 'design ensures that security controls, performance targets, integration contracts, and regulatory '
 'compliance obligations remain validated, testable, and auditable throughout the project lifecycle.',
 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B7280), height: 1.5),
 ),
 const SizedBox(height: 18),
 _buildGuideCard(Icons.shield_outlined, 'Security & Access Control', 'Implement defense-in-depth with Zero Trust architecture, encryption at rest and in transit, MFA enforcement, and continuous audit logging. Align with NIST SP 800-207 and CIS Controls v8.', const Color(0xFF2563EB)),
 const SizedBox(height: 12),
 _buildGuideCard(Icons.speed_outlined, 'Performance & Scalability', 'Define SLA targets, implement caching strategies, optimize database queries, and establish auto-scaling thresholds. Validate under load testing with p95/p99 latency benchmarks.', const Color(0xFF10B981)),
 const SizedBox(height: 12),
 _buildGuideCard(Icons.hub_outlined, 'Integration Contracts', 'Formalize API contracts, authentication flows, error handling patterns, and data schemas for all external system integrations before development begins. Use OpenAPI 3.1 specifications.', const Color(0xFFF59E0B)),
 const SizedBox(height: 12),
 _buildGuideCard(Icons.verified_user_outlined, 'Compliance & Certification', 'Map design decisions to regulatory requirements (SOC 2, GDPR, PCI DSS, ISO 27001). Maintain evidence trails, conduct gap assessments, and schedule certification audits.', const Color(0xFFEF4444)),
 ]),
 ),
 crossFadeState: _frameworkGuideExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
 duration: const Duration(milliseconds: 250),
 sizeCurve: Curves.easeInOut,
 ),
 ]),
 );
 }

 Widget _buildGuideCard(IconData icon, String title, String description, Color color) {
 return Container(
 width: double.infinity, padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(color: color.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.12))),
 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Row(children: [
 Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: color)),
 const SizedBox(width: 10),
 Expanded(child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))),
 ]),
 const SizedBox(height: 10),
 Text(description, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF4B5563), height: 1.5)),
 ]),
 );
 }

 // ─── Panel Shell ────────────────────────────────────────────────

 Widget _buildPanelShell({required String title, required String subtitle, Widget? trailing, required Widget child}) {
 return Container(
 decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))]),
 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Padding(padding: const EdgeInsets.all(20), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
 const SizedBox(height: 4),
 Text(subtitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6B7280), height: 1.45)),
 ])),
 if (trailing != null) ...[const SizedBox(width: 12), trailing],
 ])),
 const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
 child,
 ]),
 );
 }

 // ─── Table Helpers ────────────────────────────────────────────────

 Widget _buildTableHeader(List<_ColDef> columns) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
 child: Row(children: columns.map((col) {
 if (col.flex != null) return Expanded(flex: col.flex!, child: Text(col.label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8)));
 return SizedBox(width: col.width, child: Text(col.label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8), textAlign: TextAlign.center));
 }).toList()),
 );
 }

 Widget _buildTableRow({required List<Widget> cells, required bool isLast}) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
 child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells),
 );
 }

 Widget _buildStatusTag(String status) {
 Color color;
 switch (status) {
 case 'Ready': color = const Color(0xFF10B981); break;
 case 'In review': color = const Color(0xFF0EA5E9); break;
 case 'In progress': color = const Color(0xFF8B5CF6); break;
 case 'Draft': case 'Pending': color = const Color(0xFFF59E0B); break;
 case 'Deprecated': color = const Color(0xFF9CA3AF); break;
 default: color = const Color(0xFF6B7280);
 }
 return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
 child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)));
 }

 Widget _buildPriorityTag(String priority) {
 Color color;
 switch (priority) {
 case 'Critical': color = const Color(0xFFEF4444); break;
 case 'High': color = const Color(0xFFF97316); break;
 case 'Medium': color = const Color(0xFFF59E0B); break;
 default: color = const Color(0xFF6B7280);
 }
 return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
 child: Text(priority, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)));
 }

 Widget _buildComplianceStatusTag(String status) {
 Color color;
 switch (status) {
 case 'Compliant': color = const Color(0xFF10B981); break;
 case 'Non-compliant': color = const Color(0xFFEF4444); break;
 case 'In progress': color = const Color(0xFF0EA5E9); break;
 case 'Partial': color = const Color(0xFFF59E0B); break;
 case 'Not assessed': color = const Color(0xFF9CA3AF); break;
 default: color = const Color(0xFF6B7280);
 }
 return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
 child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)));
 }

 Widget _buildReviewGateStatusTag(String status) {
 Color color;
 switch (status) {
 case 'Approved': color = const Color(0xFF10B981); break;
 case 'In Review': color = const Color(0xFF0EA5E9); break;
 case 'Pending': color = const Color(0xFFF59E0B); break;
 case 'Rejected': color = const Color(0xFFEF4444); break;
 case 'Waived': color = const Color(0xFF8B5CF6); break;
 case 'Not Started': color = const Color(0xFF9CA3AF); break;
 default: color = const Color(0xFF6B7280);
 }
 return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
 child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)));
 }

 Widget _crudButtons(VoidCallback onEdit, VoidCallback onDelete, {VoidCallback? onKazAi, String? kazAiRowId}) {
 return SizedBox(width: 88, child: Row(mainAxisSize: MainAxisSize.min, children: [
 Tooltip(
 message: 'KAZ AI – Auto-fill this row',
 child: InkWell(
 onTap: onKazAi,
 child: kazAiRowId != null && _isKazAiLoadingRowId == kazAiRowId
 ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFF59E0B)))
 : const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFF59E0B)),
 ),
 ),
 const SizedBox(width: 4),
 IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: onEdit, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
 IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)), onPressed: onDelete, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
 IconButton(
   onPressed: () {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('KAZ AI: Generating suggestions...'), duration: Duration(seconds: 2)),
     );
   },
   icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFF59E0B)),
   tooltip: 'KAZ AI',
   padding: EdgeInsets.zero,
   constraints: const BoxConstraints(minWidth: 28),
 ),
 ]));
 }

 // ─── KAZ AI helpers ─────────────────────────────────────────────

 Future<void> _kazAiAutoFillRow({
 required String rowId,
 required String label,
 required String contextHint,
 required void Function(String field, String value) onResult,
 }) async {
 if (_isKazAiLoadingRowId != null) return;
 setState(() => _isKazAiLoadingRowId = rowId);
 try {
 final ai = OpenAiServiceSecure();
 final result = await ai.generateCompletion(
 'Based on this project context, generate a $label for a specialized design $contextHint.\n\nProvide a concise, specific, actionable response (1-2 sentences). Return ONLY the text content (no JSON, no markdown headers).',
 maxTokens: 200,
 temperature: 0.6,
 );
 final cleaned = result.trim();
 if (cleaned.isNotEmpty && mounted) {
 onResult(label, cleaned);
 _scheduleSave();
 }
 } catch (e) {
 debugPrint('KAZ AI row generation failed: $e');
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('KAZ AI generation failed: $e'), backgroundColor: const Color(0xFFDC2626)),
 );
 }
 } finally {
 if (mounted) setState(() => _isKazAiLoadingRowId = null);
 }
 }

 Future<void> _kazAiGenerateField({
 required String label,
 required TextEditingController controller,
 required StateSetter setDialogState,
 String? contextHint,
 }) async {
 try {
 final ai = OpenAiServiceSecure();
 final result = await ai.generateCompletion(
 'Based on this project context, generate a $label for a specialized design element.\n\nContext: ${contextHint ?? 'Specialized Design page'}\n\nProvide a concise, specific, actionable response (1-2 sentences). Return ONLY the text content (no JSON, no markdown headers).',
 maxTokens: 200,
 temperature: 0.6,
 );
 final cleaned = result.trim();
 if (cleaned.isNotEmpty) {
 setDialogState(() => controller.text = cleaned);
 }
 } catch (e) {
 debugPrint('KAZ AI field generation failed: $e');
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('KAZ AI failed: $e'), backgroundColor: const Color(0xFFDC2626)),
 );
 }
 }
 }

 Widget _buildKazAiPillButton({
 required String label,
 required TextEditingController controller,
 required StateSetter setDialogState,
 }) {
 bool isLoading = false;
 return StatefulBuilder(
 builder: (context, setLocalState) => InkWell(
 onTap: isLoading ? null : () async {
 setLocalState(() => isLoading = true);
 await _kazAiGenerateField(label: label, controller: controller, setDialogState: setDialogState);
 if (context.mounted) setLocalState(() => isLoading = false);
 },
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: const Color(0xFFF59E0B).withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 isLoading
 ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFF59E0B)))
 : const Icon(Icons.auto_awesome, size: 10, color: Color(0xFFF59E0B)),
 const SizedBox(width: 3),
 const Text('KAZ AI', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B))),
 ],
 ),
 ),
 ),
 );
 }

 // ─── Security Register ──────────────────────────────────────────

 Widget _buildSecurityRegister() {
 return _buildPanelShell(
 title: 'Security & compliance patterns register',
 subtitle: 'Track security controls, access patterns, and encryption decisions aligned with NIST CSF and ISO 27001 Annex A controls.',
 trailing: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 compact: true,
 tableTitle: 'Security & Compliance Patterns',
 columns: [
 CsvColumnSpec(key: 'pattern', label: 'PATTERN', required: true),
 CsvColumnSpec(key: 'decision', label: 'DECISION & SCOPE', required: true),
 CsvColumnSpec(key: 'owner', label: 'OWNER'),
 CsvColumnSpec(key: 'status', label: 'STATUS', allowedValues: ['Planned', 'In Review', 'Implemented', 'Compliant', 'Non-Compliant'], defaultValue: 'Planned'),
 ],
 onImport: (rows) {
 setState(() {
 for (final row in rows) {
 _securityRows.add(SecurityPatternRow(
 pattern: row['pattern'] ?? '',
 decision: row['decision'] ?? '',
 owner: row['owner'] ?? '',
 status: row['status'] ?? 'Planned',
 ));
 }
 });
 _scheduleSave();
 },
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () => _showSecurityDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add control', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF475569), side: const BorderSide(color: Color(0xFFE2E8F0)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
 ),
 ],
 ),
 child: _securityRows.isEmpty
 ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No security patterns defined. Add a control to start tracking.', style: TextStyle(color: Color(0xFF64748B)))))
 : Column(children: [
 _buildTableHeader([_ColDef('PATTERN', flex: 3), _ColDef('DECISION & SCOPE', flex: 5), _ColDef('OWNER', width: 120), _ColDef('STATUS', width: 100), _ColDef('', width: 60)]),
 ...List.generate(_securityRows.length, (i) {
 final row = _securityRows[i];
 return _buildTableRow(isLast: i == _securityRows.length - 1, cells: [
 Expanded(flex: 3, child: Text(row.pattern, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827)))),
 Expanded(flex: 5, child: Text(row.decision, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.4))),
 SizedBox(width: 120, child: Text(row.owner, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
 SizedBox(width: 130, child: _buildStatusTag(row.status)),
 _crudButtons(() => _showSecurityDialog(existing: row), () => _confirmDelete(() { setState(() => _securityRows.remove(row)); _scheduleSave(); }), onKazAi: () => _kazAiAutoFillRow(
 rowId: row.pattern, label: 'security pattern', contextHint: 'security control',
 onResult: (field, value) {
 final idx = _securityRows.indexOf(row);
 if (idx != -1) setState(() { _securityRows[idx].decision = value; });
 },
 ), kazAiRowId: row.pattern),
 ]);
 }),
 ]),
 );
 }

 // ─── Performance Register ────────────────────────────────────────

 Widget _buildPerformanceRegister() {
 return _buildPanelShell(
 title: 'Performance & scale patterns register',
 subtitle: 'Track performance hotspots, SLA targets, and scaling decisions aligned with SRE best practices and Google SRE handbook principles.',
 trailing: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 compact: true,
 tableTitle: 'Performance & Scale Patterns',
 columns: [
 CsvColumnSpec(key: 'hotspot', label: 'HOTSPOT', required: true),
 CsvColumnSpec(key: 'focus', label: 'DESIGN FOCUS', required: true),
 CsvColumnSpec(key: 'sla', label: 'SLA'),
 CsvColumnSpec(key: 'status', label: 'STATUS', allowedValues: ['Planned', 'In Review', 'Implemented', 'Compliant', 'Non-Compliant'], defaultValue: 'Draft'),
 ],
 onImport: (rows) {
 setState(() {
 for (final row in rows) {
 _performanceRows.add(PerformancePatternRow(
 hotspot: row['hotspot'] ?? '',
 focus: row['focus'] ?? '',
 sla: row['sla'] ?? '',
 status: row['status'] ?? 'Draft',
 ));
 }
 });
 _scheduleSave();
 },
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () => _showPerformanceDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add hotspot', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF475569), side: const BorderSide(color: Color(0xFFE2E8F0)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
 ),
 ],
 ),
 child: _performanceRows.isEmpty
 ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No performance hotspots defined. Add a scaling decision to start tracking.', style: TextStyle(color: Color(0xFF64748B)))))
 : Column(children: [
 _buildTableHeader([_ColDef('HOTSPOT', flex: 3), _ColDef('DESIGN FOCUS', flex: 5), _ColDef('SLA', width: 130), _ColDef('STATUS', width: 100), _ColDef('', width: 60)]),
 ...List.generate(_performanceRows.length, (i) {
 final row = _performanceRows[i];
 return _buildTableRow(isLast: i == _performanceRows.length - 1, cells: [
 Expanded(flex: 3, child: Text(row.hotspot, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827)))),
 Expanded(flex: 5, child: Text(row.focus, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.4))),
 SizedBox(width: 130, child: Text(row.sla, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0EA5E9)))),
 SizedBox(width: 130, child: _buildStatusTag(row.status)),
 _crudButtons(() => _showPerformanceDialog(existing: row), () => _confirmDelete(() { setState(() => _performanceRows.remove(row)); _scheduleSave(); }), onKazAi: () => _kazAiAutoFillRow(
 rowId: row.hotspot, label: 'performance focus', contextHint: 'performance hotspot',
 onResult: (field, value) {
 final idx = _performanceRows.indexOf(row);
 if (idx != -1) setState(() { _performanceRows[idx].focus = value; });
 },
 ), kazAiRowId: row.hotspot),
 ]);
 }),
 ]),
 );
 }

 // ─── Integration Register ────────────────────────────────────────

 Widget _buildIntegrationRegister() {
 return _buildPanelShell(
 title: 'Integration contracts register',
 subtitle: 'Track integration flows, API contracts, and system connections aligned with OpenAPI 3.1 and event-driven architecture patterns.',
 trailing: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 compact: true,
 tableTitle: 'Integration Contracts',
 columns: [
 CsvColumnSpec(key: 'flow', label: 'FLOW', required: true),
 CsvColumnSpec(key: 'system', label: 'SYSTEM'),
 CsvColumnSpec(key: 'owner', label: 'OWNER'),
 CsvColumnSpec(key: 'status', label: 'STATUS', allowedValues: ['Planned', 'In Review', 'Implemented', 'Compliant', 'Non-Compliant'], defaultValue: 'Draft'),
 ],
 onImport: (rows) {
 setState(() {
 for (final row in rows) {
 _integrationRows.add(IntegrationFlowRow(
 flow: row['flow'] ?? '',
 owner: row['owner'] ?? '',
 system: row['system'] ?? '',
 status: row['status'] ?? 'Draft',
 ));
 }
 });
 _scheduleSave();
 },
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () => _showIntegrationDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add flow', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF475569), side: const BorderSide(color: Color(0xFFE2E8F0)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
 ),
 ],
 ),
 child: _integrationRows.isEmpty
 ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No integration flows defined. Add an integration contract to start tracking.', style: TextStyle(color: Color(0xFF64748B)))))
 : Column(children: [
 _buildTableHeader([_ColDef('FLOW', flex: 4), _ColDef('SYSTEM', width: 150), _ColDef('OWNER', width: 120), _ColDef('STATUS', width: 100), _ColDef('', width: 60)]),
 ...List.generate(_integrationRows.length, (i) {
 final row = _integrationRows[i];
 return _buildTableRow(isLast: i == _integrationRows.length - 1, cells: [
 Expanded(flex: 4, child: Text(row.flow, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827)))),
 SizedBox(width: 150, child: Text(row.system, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
 SizedBox(width: 120, child: Text(row.owner, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
 SizedBox(width: 130, child: _buildStatusTag(row.status)),
 _crudButtons(() => _showIntegrationDialog(existing: row), () => _confirmDelete(() { setState(() => _integrationRows.remove(row)); _scheduleSave(); }), onKazAi: () => _kazAiAutoFillRow(
 rowId: row.flow, label: 'integration system', contextHint: 'integration flow',
 onResult: (field, value) {
 final idx = _integrationRows.indexOf(row);
 if (idx != -1) setState(() { _integrationRows[idx].system = value; });
 },
 ), kazAiRowId: row.flow),
 ]);
 }),
 ]),
 );
 }

 // ─── Compliance Register ────────────────────────────────────────

 Widget _buildComplianceRegister() {
 return _buildPanelShell(
 title: 'Compliance & certification register',
 subtitle: 'Track regulatory compliance status, certification progress, and evidence collection aligned with SOC 2, GDPR, PCI DSS, and ISO 27001 requirements.',
 trailing: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 compact: true,
 tableTitle: 'Compliance & Certification',
 columns: [
 CsvColumnSpec(key: 'standard', label: 'STANDARD', required: true),
 CsvColumnSpec(key: 'description', label: 'DESCRIPTION'),
 CsvColumnSpec(key: 'owner', label: 'OWNER'),
 CsvColumnSpec(key: 'status', label: 'STATUS', allowedValues: ['Compliant', 'Non-Compliant', 'In Progress', 'Not Assessed', 'Partial'], defaultValue: 'Not assessed'),
 ],
 onImport: (rows) {
 setState(() {
 for (final row in rows) {
 _complianceRows.add(_ComplianceRow(
 id: _newId(),
 standard: row['standard'] ?? '',
 description: row['description'] ?? '',
 owner: row['owner'] ?? '',
 status: row['status'] ?? 'Not assessed',
 evidence: '',
 ));
 }
 });
 _scheduleSave();
 },
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () => _showComplianceDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add standard', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF475569), side: const BorderSide(color: Color(0xFFE2E8F0)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
 ),
 ],
 ),
 child: _complianceRows.isEmpty
 ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No compliance standards defined. Add a standard to start tracking.', style: TextStyle(color: Color(0xFF64748B)))))
 : Column(children: [
 _buildTableHeader([_ColDef('STANDARD', flex: 3), _ColDef('DESCRIPTION', flex: 4), _ColDef('OWNER', width: 120), _ColDef('STATUS', width: 110), _ColDef('', width: 60)]),
 ...List.generate(_complianceRows.length, (i) {
 final row = _complianceRows[i];
 return _buildTableRow(isLast: i == _complianceRows.length - 1, cells: [
 Expanded(flex: 3, child: Text(row.standard, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827)))),
 Expanded(flex: 4, child: Text(row.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.4))),
 SizedBox(width: 120, child: Text(row.owner, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
 SizedBox(width: 130, child: _buildComplianceStatusTag(row.status)),
 _crudButtons(() => _showComplianceDialog(existing: row), () => _confirmDelete(() { setState(() => _complianceRows.removeWhere((r) => r.id == row.id)); _scheduleSave(); }), onKazAi: () => _kazAiAutoFillRow(
 rowId: row.id, label: 'compliance description', contextHint: 'compliance standard',
 onResult: (field, value) {
 final idx = _complianceRows.indexWhere((r) => r.id == row.id);
 if (idx != -1) setState(() { _complianceRows[idx].description = value; });
 },
 ), kazAiRowId: row.id),
 ]);
 }),
 ]),
 );
 }

 // ─── Review Gates ────────────────────────────────────────────────

 Widget _buildReviewGatesPanel() {
 return _buildPanelShell(
 title: 'Specialized design review gates',
 subtitle: 'Approval checkpoints aligned with NIST CSF and ISO 27001 design review cycles. Each gate must be cleared before proceeding to the next specialized design maturity level.',
 trailing: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 compact: true,
 tableTitle: 'Review Gates',
 columns: [
 CsvColumnSpec(key: 'gate', label: 'GATE', required: true),
 CsvColumnSpec(key: 'description', label: 'DESCRIPTION'),
 CsvColumnSpec(key: 'approver', label: 'APPROVER'),
 CsvColumnSpec(key: 'department', label: 'DEPT'),
 CsvColumnSpec(key: 'priority', label: 'PRIORITY', allowedValues: ['High', 'Medium', 'Low'], defaultValue: 'High'),
 CsvColumnSpec(key: 'status', label: 'STATUS', allowedValues: ['Not Started', 'In Progress', 'Complete', 'Overdue'], defaultValue: 'Not Started'),
 CsvColumnSpec(key: 'targetDate', label: 'TARGET DATE', defaultValue: 'TBD'),
 ],
 onImport: (rows) {
 setState(() {
 for (final row in rows) {
 _reviewGates.add(_ReviewGateRow(
 id: _newId(),
 gate: row['gate'] ?? '',
 description: row['description'] ?? '',
 approver: row['approver'] ?? '',
 department: row['department'] ?? '',
 priority: row['priority'] ?? 'High',
 status: row['status'] ?? 'Not Started',
 targetDate: row['targetDate'] ?? 'TBD',
 ));
 }
 });
 _scheduleSave();
 },
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () => _showReviewGateDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add gate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF475569), side: const BorderSide(color: Color(0xFFE2E8F0)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
 ),
 ],
 ),
 child: _reviewGates.isEmpty
 ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No review gates defined. Add a gate to start tracking specialized design reviews.', style: TextStyle(color: Color(0xFF64748B)))))
 : Column(children: [
 _buildTableHeader([_ColDef('GATE', flex: 4), _ColDef('APPROVER', width: 130), _ColDef('PRIORITY', width: 80), _ColDef('STATUS', width: 100), _ColDef('', width: 60)]),
 ...List.generate(_reviewGates.length, (i) {
 final row = _reviewGates[i];
 return _buildTableRow(isLast: i == _reviewGates.length - 1, cells: [
 Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Text(row.gate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
 const SizedBox(height: 2),
 Text(row.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.4)),
 ])),
 SizedBox(width: 130, child: Text(row.approver, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
 SizedBox(width: 110, child: _buildPriorityTag(row.priority)),
 SizedBox(width: 130, child: _buildReviewGateStatusTag(row.status)),
 _crudButtons(() => _showReviewGateDialog(existing: row), () => _confirmDelete(() { setState(() => _reviewGates.removeWhere((g) => g.id == row.id)); _scheduleSave(); }), onKazAi: () => _kazAiAutoFillRow(
 rowId: row.id, label: 'review gate description', contextHint: 'review gate',
 onResult: (field, value) {
 final idx = _reviewGates.indexWhere((g) => g.id == row.id);
 if (idx != -1) setState(() { _reviewGates[idx].description = value; });
 },
 ), kazAiRowId: row.id),
 ]);
 }),
 ]),
 );
 }

 // ─── CRUD Dialogs ─────────────────────────────────────────────────

 Future<void> _showSecurityDialog({SecurityPatternRow? existing}) async {
 final patternCtrl = TextEditingController(text: existing?.pattern ?? '');
 final decisionCtrl = TextEditingController(text: existing?.decision ?? '');
 final ownerCtrl = TextEditingController(text: existing?.owner ?? '');
 String status = existing?.status ?? 'Draft';

 final saved = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setModalState) => AlertDialog(
 title: Text(existing == null ? 'Add security control' : 'Edit security control'),
 content: SizedBox(width: 560, child: Column(mainAxisSize: MainAxisSize.min, children: [
 _buildKazAiPillButton(label: 'Pattern name', controller: patternCtrl, setDialogState: setModalState),
 const SizedBox(height: 4),
 VoiceTextField(controller: patternCtrl, decoration: const InputDecoration(labelText: 'Pattern name', border: OutlineInputBorder())),
 const SizedBox(height: 12),
 _buildKazAiPillButton(label: 'Decision and scope', controller: decisionCtrl, setDialogState: setModalState),
 const SizedBox(height: 4),
 VoiceTextField(controller: decisionCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Decision & scope', border: OutlineInputBorder())),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(child: VoiceTextField(controller: ownerCtrl, decoration: const InputDecoration(labelText: 'Owner', border: OutlineInputBorder()))),
 const SizedBox(width: 12),
 Expanded(child: DropdownButtonFormField<String>(value: status, items: _statusOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
 onChanged: (v) { if (v != null) setModalState(() => status = v); }, decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()))),
 ]),
 ])),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
 ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(existing == null ? 'Add control' : 'Save')),
 ],
 )));
 if (saved != true) return;
 setState(() {
 if (existing == null) {
 _securityRows.add(SecurityPatternRow(pattern: patternCtrl.text.trim(), decision: decisionCtrl.text.trim(), owner: ownerCtrl.text.trim(), status: status));
 } else {
 existing.pattern = patternCtrl.text.trim();
 existing.decision = decisionCtrl.text.trim();
 existing.owner = ownerCtrl.text.trim();
 existing.status = status;
 }
 });
 _scheduleSave();
 }

 Future<void> _showPerformanceDialog({PerformancePatternRow? existing}) async {
 final hotspotCtrl = TextEditingController(text: existing?.hotspot ?? '');
 final focusCtrl = TextEditingController(text: existing?.focus ?? '');
 final slaCtrl = TextEditingController(text: existing?.sla ?? '');
 String status = existing?.status ?? 'Draft';

 final saved = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setModalState) => AlertDialog(
 title: Text(existing == null ? 'Add performance hotspot' : 'Edit performance hotspot'),
 content: SizedBox(width: 560, child: Column(mainAxisSize: MainAxisSize.min, children: [
 _buildKazAiPillButton(label: 'Service hotspot name', controller: hotspotCtrl, setDialogState: setModalState),
 const SizedBox(height: 4),
 VoiceTextField(controller: hotspotCtrl, decoration: const InputDecoration(labelText: 'Service hotspot', border: OutlineInputBorder())),
 const SizedBox(height: 12),
 _buildKazAiPillButton(label: 'Design focus', controller: focusCtrl, setDialogState: setModalState),
 const SizedBox(height: 4),
 VoiceTextField(controller: focusCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Design focus', border: OutlineInputBorder())),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(child: VoiceTextField(controller: slaCtrl, decoration: const InputDecoration(labelText: 'SLA target', border: OutlineInputBorder()))),
 const SizedBox(width: 12),
 Expanded(child: DropdownButtonFormField<String>(value: status, items: _statusOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
 onChanged: (v) { if (v != null) setModalState(() => status = v); }, decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()))),
 ]),
 ])),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
 ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(existing == null ? 'Add hotspot' : 'Save')),
 ],
 )));
 if (saved != true) return;
 setState(() {
 if (existing == null) {
 _performanceRows.add(PerformancePatternRow(hotspot: hotspotCtrl.text.trim(), focus: focusCtrl.text.trim(), sla: slaCtrl.text.trim(), status: status));
 } else {
 existing.hotspot = hotspotCtrl.text.trim();
 existing.focus = focusCtrl.text.trim();
 existing.sla = slaCtrl.text.trim();
 existing.status = status;
 }
 });
 _scheduleSave();
 }

 Future<void> _showIntegrationDialog({IntegrationFlowRow? existing}) async {
 final flowCtrl = TextEditingController(text: existing?.flow ?? '');
 final systemCtrl = TextEditingController(text: existing?.system ?? '');
 final ownerCtrl = TextEditingController(text: existing?.owner ?? '');
 String status = existing?.status ?? 'Draft';

 final saved = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setModalState) => AlertDialog(
 title: Text(existing == null ? 'Add integration flow' : 'Edit integration flow'),
 content: SizedBox(width: 560, child: Column(mainAxisSize: MainAxisSize.min, children: [
 _buildKazAiPillButton(label: 'Flow name', controller: flowCtrl, setDialogState: setModalState),
 const SizedBox(height: 4),
 VoiceTextField(controller: flowCtrl, decoration: const InputDecoration(labelText: 'Flow name', border: OutlineInputBorder())),
 const SizedBox(height: 12),
 _buildKazAiPillButton(label: 'External system', controller: systemCtrl, setDialogState: setModalState),
 const SizedBox(height: 4),
 VoiceTextField(controller: systemCtrl, decoration: const InputDecoration(labelText: 'External system', border: OutlineInputBorder())),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(child: VoiceTextField(controller: ownerCtrl, decoration: const InputDecoration(labelText: 'Owner', border: OutlineInputBorder()))),
 const SizedBox(width: 12),
 Expanded(child: DropdownButtonFormField<String>(value: status, items: _statusOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
 onChanged: (v) { if (v != null) setModalState(() => status = v); }, decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()))),
 ]),
 ])),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
 ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(existing == null ? 'Add flow' : 'Save')),
 ],
 )));
 if (saved != true) return;
 setState(() {
 if (existing == null) {
 _integrationRows.add(IntegrationFlowRow(flow: flowCtrl.text.trim(), owner: ownerCtrl.text.trim(), system: systemCtrl.text.trim(), status: status));
 } else {
 existing.flow = flowCtrl.text.trim();
 existing.owner = ownerCtrl.text.trim();
 existing.system = systemCtrl.text.trim();
 existing.status = status;
 }
 });
 _scheduleSave();
 }

 Future<void> _showComplianceDialog({_ComplianceRow? existing}) async {
 final standardCtrl = TextEditingController(text: existing?.standard ?? '');
 final descCtrl = TextEditingController(text: existing?.description ?? '');
 final ownerCtrl = TextEditingController(text: existing?.owner ?? '');
 final evidenceCtrl = TextEditingController(text: existing?.evidence ?? '');
 String status = existing?.status ?? 'Not assessed';

 final saved = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setModalState) => AlertDialog(
 title: Text(existing == null ? 'Add compliance standard' : 'Edit compliance standard'),
 content: SizedBox(width: 560, child: Column(mainAxisSize: MainAxisSize.min, children: [
 _buildKazAiPillButton(label: 'Standard name', controller: standardCtrl, setDialogState: setModalState),
 const SizedBox(height: 4),
 VoiceTextField(controller: standardCtrl, decoration: const InputDecoration(labelText: 'Standard', border: OutlineInputBorder())),
 const SizedBox(height: 12),
 _buildKazAiPillButton(label: 'Description', controller: descCtrl, setDialogState: setModalState),
 const SizedBox(height: 4),
 VoiceTextField(controller: descCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(child: VoiceTextField(controller: ownerCtrl, decoration: const InputDecoration(labelText: 'Owner', border: OutlineInputBorder()))),
 const SizedBox(width: 12),
 Expanded(child: DropdownButtonFormField<String>(value: status, items: _complianceStatusOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
 onChanged: (v) { if (v != null) setModalState(() => status = v); }, decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()))),
 ]),
 const SizedBox(height: 12),
 VoiceTextField(controller: evidenceCtrl, decoration: const InputDecoration(labelText: 'Evidence / notes', border: OutlineInputBorder())),
 ])),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
 ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(existing == null ? 'Add standard' : 'Save')),
 ],
 )));
 if (saved != true) return;
 setState(() {
 if (existing == null) {
 _complianceRows.add(_ComplianceRow(id: _newId(), standard: standardCtrl.text.trim(), description: descCtrl.text.trim(), owner: ownerCtrl.text.trim(), status: status, evidence: evidenceCtrl.text.trim()));
 } else {
 existing.standard = standardCtrl.text.trim();
 existing.description = descCtrl.text.trim();
 existing.owner = ownerCtrl.text.trim();
 existing.status = status;
 existing.evidence = evidenceCtrl.text.trim();
 }
 });
 _scheduleSave();
 }

 Future<void> _showReviewGateDialog({_ReviewGateRow? existing}) async {
 final gateCtrl = TextEditingController(text: existing?.gate ?? '');
 final descCtrl = TextEditingController(text: existing?.description ?? '');
 final approverCtrl = TextEditingController(text: existing?.approver ?? '');
 final deptCtrl = TextEditingController(text: existing?.department ?? '');
 String priority = existing?.priority ?? 'High';
 String status = existing?.status ?? 'Pending';

 final saved = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setModalState) => AlertDialog(
 title: Text(existing == null ? 'Add review gate' : 'Edit review gate'),
 content: SizedBox(width: 560, child: Column(mainAxisSize: MainAxisSize.min, children: [
 _buildKazAiPillButton(label: 'Gate name', controller: gateCtrl, setDialogState: setModalState),
 const SizedBox(height: 4),
 VoiceTextField(controller: gateCtrl, decoration: const InputDecoration(labelText: 'Gate name', border: OutlineInputBorder())),
 const SizedBox(height: 12),
 _buildKazAiPillButton(label: 'Gate description', controller: descCtrl, setDialogState: setModalState),
 const SizedBox(height: 4),
 VoiceTextField(controller: descCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(child: VoiceTextField(controller: approverCtrl, decoration: const InputDecoration(labelText: 'Approver', border: OutlineInputBorder()))),
 const SizedBox(width: 12),
 Expanded(child: VoiceTextField(controller: deptCtrl, decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()))),
 ]),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(child: DropdownButtonFormField<String>(value: priority, items: ['Critical', 'High', 'Medium', 'Low'].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
 onChanged: (v) { if (v != null) setModalState(() => priority = v); }, decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()))),
 const SizedBox(width: 12),
 Expanded(child: DropdownButtonFormField<String>(value: status, items: _reviewGateStatusOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
 onChanged: (v) { if (v != null) setModalState(() => status = v); }, decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()))),
 ]),
 ])),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
 ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(existing == null ? 'Add gate' : 'Save')),
 ],
 )));
 if (saved != true) return;
 setState(() {
 if (existing == null) {
 _reviewGates.add(_ReviewGateRow(id: _newId(), gate: gateCtrl.text.trim(), description: descCtrl.text.trim(), approver: approverCtrl.text.trim(), department: deptCtrl.text.trim(), priority: priority, status: status, targetDate: 'TBD'));
 } else {
 existing.gate = gateCtrl.text.trim();
 existing.description = descCtrl.text.trim();
 existing.approver = approverCtrl.text.trim();
 existing.department = deptCtrl.text.trim();
 existing.priority = priority;
 existing.status = status;
 }
 });
 _scheduleSave();
 }

 void _confirmDelete(VoidCallback onDelete) {
 showDialog(context: context, builder: (ctx) => AlertDialog(
 title: const Text('Confirm delete'),
 content: const Text('Are you sure you want to delete this item? This action cannot be undone.'),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
 ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
 onPressed: () { Navigator.of(ctx).pop(); onDelete(); }, child: const Text('Delete')),
 ],
 ));
 }
}

// ─── Data Models ──────────────────────────────────────────────────────

class _ComplianceRow {
 String id;
 String standard;
 String description;
 String status;
 String owner;
 String evidence;

 _ComplianceRow({required this.id, required this.standard, required this.description, required this.status, required this.owner, required this.evidence});

 Map<String, dynamic> toMap() => {'id': id, 'standard': standard, 'description': description, 'status': status, 'owner': owner, 'evidence': evidence};

 static List<_ComplianceRow> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((e) {
 final m = e as Map<String, dynamic>;
 return _ComplianceRow(id: m['id'] ?? '', standard: m['standard'] ?? '', description: m['description'] ?? '', status: m['status'] ?? 'Not assessed', owner: m['owner'] ?? '', evidence: m['evidence'] ?? '');
 }).toList();
 }
}

class _ReviewGateRow {
 String id;
 String gate;
 String description;
 String approver;
 String department;
 String priority;
 String status;
 String targetDate;

 _ReviewGateRow({required this.id, required this.gate, required this.description, required this.approver, required this.department, required this.priority, required this.status, required this.targetDate});

 Map<String, dynamic> toMap() => {'id': id, 'gate': gate, 'description': description, 'approver': approver, 'department': department, 'priority': priority, 'status': status, 'targetDate': targetDate};

 static List<_ReviewGateRow> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((e) {
 final m = e as Map<String, dynamic>;
 return _ReviewGateRow(id: m['id'] ?? '', gate: m['gate'] ?? '', description: m['description'] ?? '', approver: m['approver'] ?? '', department: m['department'] ?? '', priority: m['priority'] ?? 'High', status: m['status'] ?? 'Pending', targetDate: m['targetDate'] ?? 'TBD');
 }).toList();
 }
}

class _ColDef {
 final String label;
 final int? flex;
 final double? width;
 _ColDef(this.label, {this.flex, this.width});
}

class _Debouncer {
 Timer? _timer;
 void run(VoidCallback action) { _timer?.cancel(); _timer = Timer(const Duration(milliseconds: 600), action); }
 void dispose() => _timer?.cancel();
}
