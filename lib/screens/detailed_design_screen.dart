import 'package:flutter/material.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/screens/agile_development_iterations_screen.dart';
import 'package:ndu_project/screens/vendor_tracking_screen.dart';
import 'package:ndu_project/models/design_component.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/utils/execution_phase_ai_seed.dart';
import 'package:ndu_project/utils/auto_bullet_text_controller.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/launch_modal.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/detailed_design_table_widget.dart';
import 'package:ndu_project/widgets/execution_phase_ui.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/csv_table_import_button.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:go_router/go_router.dart';

/// ────────────────────────────────────────────────────────────────
/// Design Specifications Screen
///
/// A world-class, methodology-aware design specification workspace
/// conforming to IEEE 1016-2009, ISO/IEC/IEEE 12207, and industry
/// best practices for Waterfall, Hybrid, and Agile project delivery.
/// ────────────────────────────────────────────────────────────────
class DetailedDesignScreen extends StatefulWidget {
  const DetailedDesignScreen({super.key});

  static void open(BuildContext context) {
    context.push('/detailed-design');
  }

  @override
  State<DetailedDesignScreen> createState() => _DetailedDesignScreenState();
}

class _DetailedDesignScreenState extends State<DetailedDesignScreen> {
  final Set<String> _selectedFilters = {'All'};
  List<DesignComponent> _components = [];
  bool _isLoading = false;
  bool _autoGenerationTriggered = false;
  bool _isAutoGenerating = false;
  String _methodology = 'Hybrid'; // Waterfall | Hybrid | Agile

  // ── Security & compliance controls ──
  final List<_SecurityControl> _securityControls = [
    _SecurityControl(
      id: 'SEC-001',
      requirement: 'Authentication & authorization controls',
      standard: 'ISO 27001 A.9',
      status: 'Defined',
    ),
    _SecurityControl(
      id: 'SEC-002',
      requirement: 'Data encryption at rest and in transit',
      standard: 'NIST SP 800-111',
      status: 'In Progress',
    ),
    _SecurityControl(
      id: 'SEC-003',
      requirement: 'Input validation and injection prevention',
      standard: 'OWASP Top 10',
      status: 'Pending',
    ),
    _SecurityControl(
      id: 'SEC-004',
      requirement: 'Audit logging and monitoring',
      standard: 'SOC 2 CC7',
      status: 'Defined',
    ),
  ];

  void _addSecurityControl() async {
    final result = await _showSecurityControlDialog();
    if (result == null) return;
    setState(() => _securityControls.add(result));
  }

  void _editSecurityControl(int index) async {
    final result = await _showSecurityControlDialog(_securityControls[index]);
    if (result == null) return;
    setState(() => _securityControls[index] = result);
  }

  Future<_SecurityControl?> _showSecurityControlDialog([
    _SecurityControl? existing,
  ]) async {
    final id = TextEditingController(text: existing?.id ?? '');
    final requirement =
        TextEditingController(text: existing?.requirement ?? '');
    final standard = TextEditingController(text: existing?.standard ?? '');
    var status = existing?.status ?? 'Pending';
    final result = await showDialog<_SecurityControl>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null
              ? 'Add security control'
              : 'Edit security control'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: id,
                    decoration: const InputDecoration(labelText: 'Control ID')),
                TextField(
                    controller: requirement,
                    decoration:
                        const InputDecoration(labelText: 'Requirement')),
                TextField(
                    controller: standard,
                    decoration: const InputDecoration(
                        labelText: 'Standard / reference')),
                DropdownButtonFormField<String>(
                  initialValue: _safeDropdownValue(status,
                      const ['Defined', 'In Progress', 'Pending', 'Verified']),
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const ['Defined', 'In Progress', 'Pending', 'Verified']
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? status),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (requirement.text.trim().isEmpty) return;
                Navigator.pop(
                    dialogContext,
                    _SecurityControl(
                      id: id.text.trim().isEmpty
                          ? 'SEC-${_securityControls.length + 1}'
                              .padLeft(7, '0')
                          : id.text.trim(),
                      requirement: requirement.text.trim(),
                      standard: standard.text.trim(),
                      status: status,
                    ));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    id.dispose();
    requirement.dispose();
    standard.dispose();
    return result;
  }

  // ── Non-functional requirements (local) ──
  final List<_NFRItem> _nfrItems = const [
    _NFRItem(
      id: 'NFR-001',
      category: 'Performance',
      requirement: 'API response time < 200ms at P95',
      target: '< 200ms',
      status: 'Specified',
    ),
    _NFRItem(
      id: 'NFR-002',
      category: 'Scalability',
      requirement: 'System supports 10x baseline concurrent users',
      target: '10x baseline',
      status: 'Specified',
    ),
    _NFRItem(
      id: 'NFR-003',
      category: 'Availability',
      requirement: '99.9% uptime SLA for production services',
      target: '99.9%',
      status: 'Draft',
    ),
    _NFRItem(
      id: 'NFR-004',
      category: 'Recoverability',
      requirement: 'RTO < 4 hours, RPO < 1 hour',
      target: 'RTO 4h / RPO 1h',
      status: 'Draft',
    ),
    _NFRItem(
      id: 'NFR-005',
      category: 'Maintainability',
      requirement: 'Zero-downtime deployments for stateless services',
      target: 'Zero-downtime',
      status: 'Specified',
    ),
  ];

  // ── Design decisions / ADRs (local) ──
  final List<_ADRecord> _adrRecords = const [
    _ADRecord(
      id: 'ADR-001',
      title: 'Adopt event-driven architecture',
      context:
          'Services must communicate asynchronously to support peak event loads and decouple downstream processing.',
      decision:
          'Use message broker (Kafka/RabbitMQ) for inter-service communication with event sourcing for critical flows.',
      status: 'Accepted',
    ),
    _ADRecord(
      id: 'ADR-002',
      title: 'API-first design with OpenAPI contracts',
      context:
          'Multiple consumer types (web, mobile, partner integrations) need consistent, versioned API access.',
      decision:
          'Define all service interfaces using OpenAPI 3.1 specs before implementation. Version APIs with URL path prefix.',
      status: 'Accepted',
    ),
    _ADRecord(
      id: 'ADR-003',
      title: 'Database-per-service pattern',
      context:
          'Monolithic data stores create tight coupling and deployment bottlenecks across teams.',
      decision:
          'Each bounded context owns its data store. Cross-service queries go through API composition or CQRS read models.',
      status: 'Proposed',
    ),
  ];

  // ── Architecture patterns (local) ──
  final List<_ArchitecturePattern> _archPatterns = [
    _ArchitecturePattern(
      name: 'Event-Driven Microservices',
      description:
          'Asynchronous inter-service communication via message broker with event sourcing for audit-critical flows.',
      status: 'Baseline',
      icon: Icons.hub_outlined,
      color: const Color(0xFFB8860B),
    ),
    _ArchitecturePattern(
      name: 'API Gateway',
      description:
          'Centralized entry point for routing, rate-limiting, and authentication. Terminates TLS and enforces policies.',
      status: 'Defined',
      icon: Icons.router_outlined,
      color: const Color(0xFFFFC812),
    ),
    _ArchitecturePattern(
      name: 'CQRS + Read Replicas',
      description:
          'Separate command and query models for high-throughput reads. Read replicas scale independently from writes.',
      status: 'Proposed',
      icon: Icons.call_split_outlined,
      color: const Color(0xFFD97706),
    ),
    _ArchitecturePattern(
      name: 'Observability Stack',
      description:
          'Distributed tracing (OpenTelemetry), structured logging, and metrics dashboards for end-to-end visibility.',
      status: 'Defined',
      icon: Icons.monitor_heart_outlined,
      color: const Color(0xFF059669),
    ),
  ];

  // ── Artifact readiness (local) ──
  final List<_ArtifactReadinessItem> _artifacts = const [
    _ArtifactReadinessItem(
      name: 'API schema v4 (OpenAPI 3.1)',
      status: 'Ready for build',
      ready: true,
    ),
    _ArtifactReadinessItem(
      name: 'Sequence diagrams (core flows)',
      status: 'Review pending',
      ready: false,
    ),
    _ArtifactReadinessItem(
      name: 'Observability & alerting plan',
      status: 'Ready for build',
      ready: true,
    ),
    _ArtifactReadinessItem(
      name: 'Data classification register',
      status: 'Draft',
      ready: false,
    ),
    _ArtifactReadinessItem(
      name: 'Infrastructure-as-code templates',
      status: 'Ready for build',
      ready: true,
    ),
    _ArtifactReadinessItem(
      name: 'Security threat model (STRIDE)',
      status: 'In progress',
      ready: false,
    ),
  ];

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadComponents());
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Detailed Design',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName ?? 'N/A'},
        ]),
        PdfSection.text(
            'Notes',
            projectData.planningNotes['detailed_design_screen'] ??
                'No data recorded.'),
      ],
    );
  }

  Future<void> _loadComponents() async {
    final projectId = _projectId;
    if (projectId == null) return;

    setState(() => _isLoading = true);
    try {
      final components = await ExecutionPhaseService.loadDesignComponents(
        projectId: projectId,
      );
      if (mounted) {
        setState(() {
          _components = components;
          _isLoading = false;
        });
        // Load saved methodology
        final projectData = ProjectDataHelper.getData(context);
        final savedMethodology =
            projectData.planningNotes['detailed_design_methodology'];
        if (savedMethodology != null &&
            savedMethodology.isNotEmpty &&
            mounted) {
          setState(() => _methodology = savedMethodology);
        }
      }
      await _autoGenerateIfNeeded();
    } catch (e) {
      debugPrint('Error loading design components: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _autoGenerateIfNeeded() async {
    if (!mounted || _autoGenerationTriggered || _isAutoGenerating) return;
    if (_components.isNotEmpty) return;

    _autoGenerationTriggered = true;
    _isAutoGenerating = true;
    try {
      final generated = await ExecutionPhaseAiSeed.generateEntries(
        context: context,
        section: 'Design Specifications',
        sections: const {
          'designComponents':
              'Key design specifications covering architecture, interface, data, component, security, and NFR elements',
        },
        itemsPerSection: 6,
      );

      final entries = generated['designComponents'] ?? const [];
      if (entries.isEmpty) return;

      const typeRotation = DesignComponent.specificationTypes;
      const priorityRotation = DesignComponent.priorities;
      const ownerRotation = DesignComponent.ownerRoles;

      final newComponents = <DesignComponent>[];
      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final specType = _inferSpecType('${entry.title} ${entry.details}');
        newComponents.add(DesignComponent(
          specId: 'DS-${(i + 1).toString().padLeft(3, '0')}',
          componentName: entry.title,
          specificationType: specType,
          category: specType,
          specificationDetails:
              entry.details.isNotEmpty ? '. ${entry.details}' : '',
          integrationPoint: _inferIntegration(specType),
          priority: priorityRotation[i % priorityRotation.length],
          methodologyPhase: _getDefaultPhase(),
          owner: ownerRotation[i % ownerRotation.length],
          traceability: 'REQ-${(i + 1).toString().padLeft(3, '0')}',
          status: 'Draft',
          designNotes: entry.details,
        ));
      }

      if (!mounted) return;
      setState(() => _components = newComponents);
      final projectId = _projectId;
      if (projectId != null) {
        await ExecutionPhaseService.saveDesignComponents(
          projectId: projectId,
          components: newComponents,
        );
      }
    } catch (e) {
      debugPrint('Error auto-generating design components: $e');
    } finally {
      _isAutoGenerating = false;
    }
  }

  String _inferSpecType(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('architecture') || lower.contains('decompos')) {
      return 'Architecture';
    }
    if (lower.contains('interface') ||
        lower.contains('api') ||
        lower.contains('contract')) {
      return 'Interface';
    }
    if (lower.contains('data') ||
        lower.contains('schema') ||
        lower.contains('database')) {
      return 'Data';
    }
    if (lower.contains('security') ||
        lower.contains('auth') ||
        lower.contains('compliance')) {
      return 'Security';
    }
    if (lower.contains('performance') ||
        lower.contains('scalab') ||
        lower.contains('availab')) {
      return 'NFR';
    }
    if (lower.contains('ui') ||
        lower.contains('ux') ||
        lower.contains('design system')) {
      return 'UI/UX';
    }
    if (lower.contains('infra') ||
        lower.contains('deploy') ||
        lower.contains('cloud')) {
      return 'Infrastructure';
    }
    return 'Component';
  }

  String _inferIntegration(String specType) {
    return switch (specType) {
      'Architecture' => 'System boundary',
      'Interface' => 'Service contract',
      'Data' => 'Data store / schema',
      'Security' => 'Auth provider / IAM',
      'NFR' => 'Cross-cutting concern',
      'UI/UX' => 'Design system / component library',
      'Infrastructure' => 'Cloud platform / CI-CD',
      _ => 'TBD',
    };
  }

  String _getDefaultPhase() {
    return switch (_methodology) {
      'Waterfall' => 'Detailed Design',
      'Agile' => 'Backlog',
      _ => 'Architecture Baseline',
    };
  }

  List<DesignComponent> _filterComponents(List<DesignComponent> components) {
    if (_selectedFilters.contains('All')) return components;
    return components.where((c) {
      if (_selectedFilters.contains('Approved') && c.status == 'Approved') {
        return true;
      }
      if (_selectedFilters.contains('In Review') && c.status == 'In Review') {
        return true;
      }
      if (_selectedFilters.contains('Reviewed') && c.status == 'Reviewed') {
        return true;
      }
      if (_selectedFilters.contains('Baseline') && c.status == 'Baseline') {
        return true;
      }
      if (_selectedFilters.contains('Draft') && c.status == 'Draft') {
        return true;
      }
      if (_selectedFilters.contains('Must Have') && c.priority == 'Must Have') {
        return true;
      }
      return false;
    }).toList();
  }

  // ════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 980;
    final padding = AppBreakpoints.pagePadding(context);

    return ResponsiveScaffold(
      activeItemLabel: 'Design Specifications',
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: const KazAiChatBubble(positioned: false),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlanningPhaseHeader(
                title: 'Detailed Design',
                showNavigationButtons: false,
                onExportPdf: _exportPdf),
            const SizedBox(height: 20),
            _buildMetricsGrid(),
            const SizedBox(height: 24),
            // ── Collapsible Sections ──
            _buildArchitectureSection(),
            const SizedBox(height: 20),
            _buildSpecificationRegister(),
            const SizedBox(height: 20),
            _buildSecuritySection(),
            const SizedBox(height: 20),
            _buildNFRSection(),
            const SizedBox(height: 20),
            _buildADRSection(),
            const SizedBox(height: 20),
            _buildArtifactReadiness(),
            const SizedBox(height: 24),
            LaunchPhaseNavigation(
              backLabel: PlanningPhaseNavigation.backLabel('detailed_design'),
              nextLabel: PlanningPhaseNavigation.nextLabel('detailed_design'),
              onBack: () => PlanningPhaseNavigation.goToPrevious(
                  context, 'detailed_design'),
              onNext: () =>
                  PlanningPhaseNavigation.goToNext(context, 'detailed_design'),
            ),
          ],
        ),
      ),
    );
  }

  // ── METRICS GRID ──────────────────────────────────────────────

  Widget _buildMetricsGrid() {
    final totalSpecs = _components.length;
    final mustHave = _components.where((c) => c.priority == 'Must Have').length;
    final approved = _components
        .where((c) => c.status == 'Approved' || c.status == 'Baseline')
        .length;
    final secDefined =
        _securityControls.where((s) => s.status == 'Defined').length;
    final nfrSpecified = _nfrItems.where((n) => n.status == 'Specified').length;
    final artifactsReady = _artifacts.where((a) => a.ready).length;
    final readiness =
        totalSpecs > 0 ? ((approved / totalSpecs) * 100).round() : 0;

    final metrics = [
      ExecutionMetricData(
        label: 'Total Specifications',
        value: '$totalSpecs',
        icon: Icons.description_outlined,
        helper:
            'Across ${DesignComponent.specificationTypes.length} spec types',
        emphasisColor: const Color(0xFFFFC812),
      ),
      ExecutionMetricData(
        label: 'Must-Have Items',
        value: '$mustHave',
        icon: Icons.flag_rounded,
        helper: 'MoSCoW critical path',
        emphasisColor: const Color(0xFFDC2626),
      ),
      ExecutionMetricData(
        label: 'Design Readiness',
        value: '$readiness%',
        icon: Icons.verified_outlined,
        helper: '$approved of $totalSpecs approved/baselined',
        emphasisColor: const Color(0xFF059669),
      ),
      ExecutionMetricData(
        label: 'Security Controls',
        value: '$secDefined/${_securityControls.length}',
        icon: Icons.shield_outlined,
        helper: 'ISO 27001 / NIST / SOC 2',
        emphasisColor: const Color(0xFFB8860B),
      ),
      ExecutionMetricData(
        label: 'NFRs Specified',
        value: '$nfrSpecified/${_nfrItems.length}',
        icon: Icons.speed_outlined,
        helper: 'Performance, scalability, availability',
        emphasisColor: const Color(0xFFD97706),
      ),
      ExecutionMetricData(
        label: 'Artifacts Ready',
        value: '$artifactsReady/${_artifacts.length}',
        icon: Icons.inventory_2_outlined,
        helper: 'Staged for build handoff',
        emphasisColor: const Color(0xFFD97706),
      ),
    ];

    return ExecutionMetricsGrid(metrics: metrics, minTileWidth: 140);
  }

  // ── ARCHITECTURE & SYSTEM DESIGN SECTION ──────────────────────

  Widget _buildArchitectureSection() {
    return ExecutionPanelShell(
      title: 'Architecture & System Design',
      subtitle:
          'Decomposition view per IEEE 1016 — architectural patterns, service boundaries, and integration topology',
      collapsible: true,
      initiallyExpanded: true,
      headerIcon: Icons.account_tree_outlined,
      headerIconColor: const Color(0xFFB8860B),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: _showArchPatternEditor,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Pattern'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB8860B),
              side: const BorderSide(color: Color(0xFFB8860B)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossCount = constraints.maxWidth >= 900 ? 2 : 1;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: _archPatterns.asMap().entries.map((entry) {
              final index = entry.key;
              final pattern = entry.value;
              return SizedBox(
                width: (constraints.maxWidth - (14 * (crossCount - 1))) /
                    crossCount,
                child: _ArchitecturePatternCard(
                  pattern: pattern,
                  onEdit: () =>
                      _showArchPatternEditor(entry: pattern, index: index),
                  onDelete: () async {
                    if (!await _confirmDelete('architecture pattern')) return;
                    if (!mounted) return;
                    setState(() {
                      _archPatterns.removeAt(index);
                    });
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ── Architecture pattern editor dialog ──

  static const List<String> _archStatusOptions = [
    'Proposed',
    'Defined',
    'Baseline',
    'Deprecated',
  ];

  static String _safeDropdownValue(String? value, List<String> options) {
    return value != null && options.contains(value) ? value : options.first;
  }

  static const List<MapEntry<IconData, Color>> _archIconOptions = [
    MapEntry(Icons.hub_outlined, Color(0xFFB8860B)),
    MapEntry(Icons.router_outlined, Color(0xFFFFC812)),
    MapEntry(Icons.call_split_outlined, Color(0xFFD97706)),
    MapEntry(Icons.monitor_heart_outlined, Color(0xFF059669)),
    MapEntry(Icons.layers_outlined, Color(0xFFD97706)),
    MapEntry(Icons.security_outlined, Color(0xFFDC2626)),
    MapEntry(Icons.storage_outlined, Color(0xFFB8860B)),
    MapEntry(Icons.cloud_outlined, Color(0xFFFFC812)),
    MapEntry(Icons.dns_outlined, Color(0xFFB8860B)),
    MapEntry(Icons.memory_outlined, Color(0xFFD97706)),
  ];

  Future<void> _showArchPatternEditor(
      {_ArchitecturePattern? entry, int? index}) async {
    final nameController = TextEditingController(text: entry?.name ?? '');
    final descController =
        TextEditingController(text: entry?.description ?? '');
    var selectedStatus = _safeDropdownValue(entry?.status, _archStatusOptions);
    var selectedIconIndex = 0;
    if (entry != null) {
      final match = _archIconOptions.indexWhere(
        (opt) => opt.key == entry.icon && opt.value == entry.color,
      );
      if (match != -1) selectedIconIndex = match;
    }

    final saved = await showDialog<_ArchitecturePattern>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(entry != null
                  ? 'Edit Architecture Pattern'
                  : 'Add Architecture Pattern'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      VoiceTextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Pattern name *',
                          hintText: 'e.g. Event-Driven Microservices',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      VoiceTextField(
                        controller: descController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Describe the architectural pattern',
                          isDense: true,
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          isDense: true,
                        ),
                        items: _archStatusOptions
                            .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s,
                                    style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => selectedStatus = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      Text('Icon & Color',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _archIconOptions.asMap().entries.map((e) {
                          final isSelected = e.key == selectedIconIndex;
                          return GestureDetector(
                            onTap: () =>
                                setDialogState(() => selectedIconIndex = e.key),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? e.value.value.withValues(alpha: 0.15)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? e.value.value
                                      : const Color(0xFFE5E7EB),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Icon(e.value.key,
                                  size: 18, color: e.value.value),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Pattern name is required.')),
                      );
                      return;
                    }
                    final iconOpt = _archIconOptions[selectedIconIndex];
                    Navigator.of(dialogContext).pop(
                      _ArchitecturePattern(
                        name: nameController.text.trim(),
                        description: descController.text.trim(),
                        status: selectedStatus,
                        icon: iconOpt.key,
                        color: iconOpt.value,
                      ),
                    );
                  },
                  child: Text(entry != null ? 'Save changes' : 'Add pattern'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descController.dispose();

    if (saved == null) return;
    setState(() {
      if (index != null && index < _archPatterns.length) {
        _archPatterns[index] = saved;
      } else {
        _archPatterns.add(saved);
      }
    });
  }

  // ── DESIGN SPECIFICATION REGISTER (MAIN TABLE) ────────────────

  Widget _buildSpecificationRegister() {
    if (_isLoading) {
      return const ExecutionPanelShell(
        title: 'Design Specification Register',
        subtitle:
            'Traceable specifications with MoSCoW prioritization, methodology phasing, and requirements traceability',
        collapsible: true,
        initiallyExpanded: true,
        headerIcon: Icons.folder_special_outlined,
        headerIconColor: Color(0xFFFFC812),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final filteredComponents = _filterComponents(_components);

    return ExecutionPanelShell(
      title: 'Design Specification Register',
      subtitle:
          'Traceable specifications with MoSCoW prioritization, methodology phasing, and requirements traceability',
      collapsible: true,
      initiallyExpanded: true,
      headerIcon: Icons.folder_special_outlined,
      headerIconColor: const Color(0xFFFFC812),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CsvTableImportButton(
            compact: true,
            tableTitle: 'Design Specification Register',
            columns: const [
              CsvColumnSpec(
                  key: 'specId', label: 'Spec ID', hint: 'e.g. DS-001'),
              CsvColumnSpec(
                  key: 'componentName',
                  label: 'Design Element',
                  required: true,
                  hint: 'Design element name'),
              CsvColumnSpec(
                  key: 'specificationType',
                  label: 'Type',
                  allowedValues: [
                    'Functional',
                    'Non-Functional',
                    'Interface',
                    'Data',
                    'Security',
                    'Performance'
                  ],
                  defaultValue: 'Functional'),
              CsvColumnSpec(
                  key: 'specificationDetails',
                  label: 'Specification',
                  hint: 'Specification details'),
              CsvColumnSpec(
                  key: 'priority',
                  label: 'Priority',
                  allowedValues: ['Critical', 'High', 'Medium', 'Low'],
                  defaultValue: 'Medium'),
              CsvColumnSpec(
                  key: 'methodologyPhase',
                  label: 'Phase',
                  hint: 'Methodology phase'),
              CsvColumnSpec(
                  key: 'owner', label: 'Owner', hint: 'Specification owner'),
              CsvColumnSpec(
                  key: 'traceability',
                  label: 'Traceability',
                  hint: 'e.g. REQ-001'),
              CsvColumnSpec(
                  key: 'status',
                  label: 'Status',
                  allowedValues: [
                    'Draft',
                    'In Review',
                    'Approved',
                    'Implemented',
                    'Verified'
                  ],
                  defaultValue: 'Draft'),
            ],
            onImport: (rows) {
              setState(() {
                for (final row in rows) {
                  _components.add(DesignComponent(
                    specId: row['specId'] ??
                        'DS-${(_components.length + 1).toString().padLeft(3, '0')}',
                    componentName: row['componentName'] ?? '',
                    specificationType: row['specificationType'] ?? 'Component',
                    category: row['specificationType'] ?? 'Backend',
                    specificationDetails: row['specificationDetails'] ?? '',
                    priority: row['priority'] ?? 'Should Have',
                    methodologyPhase:
                        row['methodologyPhase'] ?? _getDefaultPhase(),
                    owner: row['owner'] ?? '',
                    traceability: row['traceability'] ?? '',
                    status: row['status'] ?? 'Draft',
                    designNotes: '',
                  ));
                }
              });
              final projectId = _projectId;
              if (projectId != null) {
                ExecutionPhaseService.saveDesignComponents(
                  projectId: projectId,
                  components: _components,
                );
              }
            },
          ),
          const SizedBox(width: 8),
          _buildSpecTypeLegend(),
        ],
      ),
      child: DetailedDesignTableWidget(
        components: filteredComponents,
        methodology: _methodology,
        onUpdated: (component) {
          setState(() {
            final index = _components.indexWhere((c) => c.id == component.id);
            if (index != -1) {
              _components[index] = component;
            } else {
              _components.add(component);
            }
          });
        },
        onDeleted: (component) {
          setState(() {
            _components.removeWhere((c) => c.id == component.id);
          });
        },
      ),
    );
  }

  Widget _buildSpecTypeLegend() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: DesignComponent.specificationTypes.take(5).map((type) {
        final color = _getTypeColor(type);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Text(
            type,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getTypeColor(String type) {
    return switch (type) {
      'Architecture' => const Color(0xFFB8860B),
      'Interface' => const Color(0xFFFFC812),
      'Data' => const Color(0xFFD97706),
      'Component' => const Color(0xFF059669),
      'Security' => const Color(0xFFDC2626),
      'NFR' => const Color(0xFFD97706),
      'Infrastructure' => const Color(0xFF475569),
      'UI/UX' => const Color(0xFFD97706),
      _ => const Color(0xFF6B7280),
    };
  }

  // ── SECURITY & COMPLIANCE SECTION ─────────────────────────────

  Widget _buildSecuritySection() {
    return ExecutionPanelShell(
      title: 'Security & Compliance Controls',
      subtitle:
          'Controls mapped to ISO 27001, NIST Cybersecurity Framework, OWASP, and SOC 2 trust criteria',
      collapsible: true,
      initiallyExpanded: true,
      headerIcon: Icons.shield_outlined,
      headerIconColor: const Color(0xFFDC2626),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _addSecurityControl,
              icon: const Icon(Icons.add),
              label: const Text('Add control'),
            ),
          ),
          const SizedBox(height: 12),
          ..._securityControls.asMap().entries.map((entry) {
            return _SecurityControlCard(
              control: entry.value,
              onEdit: () => _editSecurityControl(entry.key),
              onDelete: () =>
                  setState(() => _securityControls.removeAt(entry.key)),
            );
          }),
        ],
      ),
    );
  }

  // ── NON-FUNCTIONAL REQUIREMENTS SECTION ───────────────────────

  void _addNfrItem() async {
    final result = await _showNfrDialog();
    if (result == null) return;
    setState(() => _nfrItems.add(result));
  }

  void _editNfrItem(int index) async {
    final result = await _showNfrDialog(_nfrItems[index]);
    if (result == null) return;
    setState(() => _nfrItems[index] = result);
  }

  Future<_NFRItem?> _showNfrDialog([_NFRItem? existing]) async {
    final id = TextEditingController(text: existing?.id ?? '');
    final requirement =
        TextEditingController(text: existing?.requirement ?? '');
    final target = TextEditingController(text: existing?.target ?? '');
    var category = existing?.category ?? 'Performance';
    var status = existing?.status ?? 'Draft';
    final result = await showDialog<_NFRItem>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add NFR' : 'Edit NFR'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: id,
                    decoration: const InputDecoration(labelText: 'NFR ID')),
                DropdownButtonFormField<String>(
                  initialValue: _safeDropdownValue(category, const [
                    'Performance',
                    'Scalability',
                    'Availability',
                    'Recoverability',
                    'Maintainability'
                  ]),
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    'Performance',
                    'Scalability',
                    'Availability',
                    'Recoverability',
                    'Maintainability'
                  ]
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => category = value ?? category),
                ),
                TextField(
                    controller: requirement,
                    decoration:
                        const InputDecoration(labelText: 'Requirement')),
                TextField(
                    controller: target,
                    decoration: const InputDecoration(labelText: 'Target')),
                DropdownButtonFormField<String>(
                  initialValue: _safeDropdownValue(
                      status, const ['Draft', 'Specified', 'Verified']),
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const ['Draft', 'Specified', 'Verified']
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? status),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (requirement.text.trim().isEmpty) return;
                Navigator.pop(
                    dialogContext,
                    _NFRItem(
                      id: id.text.trim().isEmpty
                          ? 'NFR-${_nfrItems.length + 1}'.padLeft(8, '0')
                          : id.text.trim(),
                      category: category,
                      requirement: requirement.text.trim(),
                      target: target.text.trim(),
                      status: status,
                    ));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    id.dispose();
    requirement.dispose();
    target.dispose();
    return result;
  }

  Widget _buildNFRSection() {
    return ExecutionPanelShell(
      title: 'Non-Functional Requirements (NFRs)',
      subtitle:
          'Quantifiable quality attributes — performance, scalability, availability, recoverability, and maintainability targets',
      collapsible: true,
      initiallyExpanded: true,
      headerIcon: Icons.speed_outlined,
      headerIconColor: const Color(0xFFD97706),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _addNfrItem,
              icon: const Icon(Icons.add),
              label: const Text('Add NFR'),
            ),
          ),
          const SizedBox(height: 12),
          ..._nfrItems.asMap().entries.map((entry) => _NFRCard(
                item: entry.value,
                onEdit: () => _editNfrItem(entry.key),
                onDelete: () async {
                  if (!await _confirmDelete('NFR')) return;
                  if (!mounted) return;
                  setState(() => _nfrItems.removeAt(entry.key));
                },
              )),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(String itemType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => LaunchModalShell(
        icon: Icons.delete_outline_rounded,
        accent: const Color(0xFFDC2626),
        title: 'Delete $itemType?',
        subtitle: 'This action cannot be undone.',
        body: Text(
          'Are you sure you want to remove this $itemType? Any unsaved content will be permanently lost.',
          style: const TextStyle(
              fontSize: 14, color: Color(0xFF4B5563), height: 1.5),
        ),
        actions: [
          LaunchModalCancelButton(
            label: 'Keep it',
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          LaunchModalDangerButton(
            label: 'Delete',
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _addAdrRecord() async {
    final result = await _showAdrDialog();
    if (result == null) return;
    setState(() => _adrRecords.add(result));
  }

  void _editAdrRecord(int index) async {
    final result = await _showAdrDialog(_adrRecords[index]);
    if (result == null) return;
    setState(() => _adrRecords[index] = result);
  }

  Future<_ADRecord?> _showAdrDialog([_ADRecord? existing]) async {
    final id = TextEditingController(text: existing?.id ?? '');
    final title = TextEditingController(text: existing?.title ?? '');
    final contextController =
        TextEditingController(text: existing?.context ?? '');
    final decision = TextEditingController(text: existing?.decision ?? '');
    var status = existing?.status ?? 'Proposed';
    String? titleError;
    final result = await showDialog<_ADRecord>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => LaunchModalShell(
          icon: Icons.gavel_outlined,
          accent: const Color(0xFFD97706),
          title: existing == null
              ? 'Add architecture decision'
              : 'Edit architecture decision',
          subtitle: 'Capture the decision, rationale, and lifecycle status.',
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LaunchModalTextField(
                label: 'ADR ID',
                controller: id,
                hint: 'e.g. ADR-0001',
              ),
              const LaunchModalFieldGap(),
              LaunchModalTextField(
                label: 'Decision Title',
                controller: title,
                hint: 'What decision is being recorded?',
              ),
              if (titleError != null) ...[
                const SizedBox(height: 4),
                Text(titleError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
              const LaunchModalFieldGap(),
              LaunchModalTextField(
                label: 'Context',
                controller: contextController,
                maxLines: 3,
                hint: 'Why was this decision needed?',
              ),
              const LaunchModalFieldGap(),
              LaunchModalTextField(
                label: 'Decision',
                controller: decision,
                maxLines: 3,
                hint: 'What was decided and why?',
              ),
              const LaunchModalFieldGap(),
              LaunchModalDropdown<String>(
                label: 'Status',
                value: _safeDropdownValue(status,
                    const ['Proposed', 'Accepted', 'Deprecated', 'Superseded']),
                items: const [
                  'Proposed',
                  'Accepted',
                  'Deprecated',
                  'Superseded'
                ],
                onChanged: (value) =>
                    setDialogState(() => status = value ?? status),
              ),
            ],
          ),
          actions: [
            LaunchModalCancelButton(
              label: 'Cancel',
              onPressed: () => Navigator.pop(dialogContext),
            ),
            LaunchModalPrimaryButton(
              label: 'Save',
              icon: Icons.check,
              onPressed: () {
                final trimmedTitle = title.text.trim();
                if (trimmedTitle.isEmpty) {
                  setDialogState(() => titleError = 'Enter a decision title.');
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  _ADRecord(
                    id: id.text.trim().isEmpty
                        ? 'ADR-${_adrRecords.length + 1}'.padLeft(8, '0')
                        : id.text.trim(),
                    title: trimmedTitle,
                    context: contextController.text.trim(),
                    decision: decision.text.trim(),
                    status: status,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
    id.dispose();
    title.dispose();
    contextController.dispose();
    decision.dispose();
    return result;
  }

  // ── DESIGN DECISION LOG / ADR SECTION ─────────────────────────

  Widget _buildADRSection() {
    return ExecutionPanelShell(
      title: 'Design Decision Log (ADRs)',
      subtitle:
          'Architecture Decision Records documenting context, rationale, and consequences of key design choices',
      collapsible: true,
      initiallyExpanded: true,
      headerIcon: Icons.gavel_outlined,
      headerIconColor: const Color(0xFFB8860B),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _addAdrRecord,
              icon: const Icon(Icons.add),
              label: const Text('Add ADR'),
            ),
          ),
          const SizedBox(height: 12),
          ..._adrRecords.asMap().entries.map((entry) => _ADRecordCard(
                record: entry.value,
                onEdit: () => _editAdrRecord(entry.key),
                onDelete: () async {
                  if (!await _confirmDelete('architecture decision')) return;
                  if (!mounted) return;
                  setState(() => _adrRecords.removeAt(entry.key));
                },
              )),
        ],
      ),
    );
  }

  // ── ARTIFACT READINESS SECTION ────────────────────────────────

  Widget _buildArtifactReadiness() {
    final readyCount = _artifacts.where((a) => a.ready).length;
    return ExecutionPanelShell(
      title: 'Artifact Readiness',
      subtitle:
          '$readyCount/${_artifacts.length} design assets staged for build handoff and construction readiness gate',
      collapsible: true,
      initiallyExpanded: true,
      headerIcon: Icons.inventory_2_outlined,
      headerIconColor: const Color(0xFFD97706),
      child: Column(
        children: _artifacts.map((artifact) {
          final color = artifact.ready
              ? const Color(0xFF10B981)
              : const Color(0xFFF59E0B);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    artifact.ready
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    size: 16,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(artifact.name,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(artifact.status,
                          style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── ADD SPECIFICATION DIALOG ──────────────────────────────────

  Future<void> _showAddComponentDialog(BuildContext context) async {
    final projectId = _projectId;
    if (projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No project selected. Please open a project first.')),
      );
      return;
    }

    final specIdController = TextEditingController(
      text: 'DS-${(_components.length + 1).toString().padLeft(3, '0')}',
    );
    final componentNameController = TextEditingController();
    var selectedType = 'Component';
    final specificationController = AutoBulletTextController(text: '');
    var selectedPriority = 'Should Have';
    var selectedPhase = _getDefaultPhase();
    var selectedOwner = 'Engineering';
    final traceabilityController = TextEditingController();
    var selectedStatus = 'Draft';
    final notesController = TextEditingController();

    try {
      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC812).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_rounded,
                      size: 20, color: Color(0xFFFFC812)),
                ),
                const SizedBox(width: 12),
                const Text('Add Design Specification',
                    style: TextStyle(fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: 640,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Spec ID + Priority
                    Row(
                      children: [
                        Expanded(
                          child: VoiceTextField(
                            controller: specIdController,
                            decoration: const InputDecoration(
                              labelText: 'Spec ID *',
                              hintText: 'e.g., DS-007',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedPriority,
                            decoration: const InputDecoration(
                                labelText: 'Priority *', isDense: true),
                            items: DesignComponent.priorities
                                .map((p) =>
                                    DropdownMenuItem(value: p, child: Text(p)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setDialogState(() => selectedPriority = v);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Row 2: Name + Type
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: VoiceTextField(
                            controller: componentNameController,
                            decoration: const InputDecoration(
                              labelText: 'Design Element Name *',
                              hintText: 'e.g., API Gateway, Auth Service',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedType,
                            decoration: const InputDecoration(
                                labelText: 'Type *', isDense: true),
                            items: DesignComponent.specificationTypes
                                .map((t) =>
                                    DropdownMenuItem(value: t, child: Text(t)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setDialogState(() => selectedType = v);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Row 3: Phase + Owner + Status
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedPhase,
                            decoration: const InputDecoration(
                                labelText: 'Phase', isDense: true),
                            items: _getPhaseOptionsForDialog()
                                .map((p) =>
                                    DropdownMenuItem(value: p, child: Text(p)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setDialogState(() => selectedPhase = v);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedOwner,
                            decoration: const InputDecoration(
                                labelText: 'Owner', isDense: true),
                            items: DesignComponent.ownerRoles
                                .map((r) =>
                                    DropdownMenuItem(value: r, child: Text(r)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setDialogState(() => selectedOwner = v);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedStatus,
                            decoration: const InputDecoration(
                                labelText: 'Status *', isDense: true),
                            items: DesignComponent.statuses
                                .map((s) =>
                                    DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setDialogState(() => selectedStatus = v);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    VoiceTextField(
                      controller: specificationController,
                      decoration: const InputDecoration(
                        labelText: 'Specification Details',
                        hintText: 'Use "." bullet format for list items',
                        isDense: true,
                      ),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: VoiceTextField(
                            controller: traceabilityController,
                            decoration: const InputDecoration(
                              labelText: 'Traceability (Req ID)',
                              hintText: 'e.g., REQ-001',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    VoiceTextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Design Notes / Rationale',
                        hintText: 'Prose description of design decisions',
                        isDense: true,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (componentNameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter a design element name')),
                    );
                    return;
                  }

                  try {
                    final newComponent = DesignComponent(
                      specId: specIdController.text.trim(),
                      componentName: componentNameController.text.trim(),
                      specificationType: selectedType,
                      category: selectedType,
                      specificationDetails: specificationController.text.trim(),
                      integrationPoint: _inferIntegration(selectedType),
                      priority: selectedPriority,
                      methodologyPhase: selectedPhase,
                      owner: selectedOwner,
                      traceability: traceabilityController.text.trim(),
                      status: selectedStatus,
                      designNotes: notesController.text.trim(),
                    );

                    setState(() {
                      _components.add(newComponent);
                    });

                    await ExecutionPhaseService.saveDesignComponents(
                      projectId: projectId,
                      components: _components,
                    );

                    if (context.mounted) {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Design specification added successfully')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Error adding specification: $e')),
                      );
                    }
                  }
                },
                child: const Text('Add Specification'),
              ),
            ],
          ),
        ),
      );
    } finally {
      specIdController.dispose();
      componentNameController.dispose();
      specificationController.dispose();
      traceabilityController.dispose();
      notesController.dispose();
    }
  }

  List<String> _getPhaseOptionsForDialog() {
    return switch (_methodology) {
      'Waterfall' => DesignComponent.waterfallPhases,
      'Agile' => DesignComponent.agilePhases,
      _ => DesignComponent.hybridPhases,
    };
  }
}

// ══════════════════════════════════════════════════════════════════
// HELPER WIDGETS & DATA CLASSES
// ══════════════════════════════════════════════════════════════════

class _ArchitecturePatternCard extends StatelessWidget {
  const _ArchitecturePatternCard({
    required this.pattern,
    this.onEdit,
    this.onDelete,
  });
  final _ArchitecturePattern pattern;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: pattern.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(pattern.icon, size: 18, color: pattern.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pattern.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              ExecutionStatusBadge(label: pattern.status),
              if (onEdit != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  tooltip: 'Edit pattern',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                  ),
                ),
              ],
              if (onDelete != null) ...[
                const SizedBox(width: 2),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  tooltip: 'Delete pattern',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            pattern.description,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityControlCard extends StatelessWidget {
  const _SecurityControlCard({
    required this.control,
    required this.onEdit,
    required this.onDelete,
  });
  final _SecurityControl control;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (control.status) {
      'Defined' => const Color(0xFF10B981),
      'In Progress' => const Color(0xFFFFC812),
      'Pending' => const Color(0xFFF59E0B),
      _ => const Color(0xFF9CA3AF),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.security_rounded, size: 16, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(control.id,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        )),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(control.requirement,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(control.standard,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit control',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: 'Delete control',
            onPressed: onDelete,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(control.status,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor)),
          ),
        ],
      ),
    );
  }
}

class _NFRCard extends StatelessWidget {
  const _NFRCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });
  final _NFRItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final categoryColor = switch (item.category) {
      'Performance' => const Color(0xFFDC2626),
      'Scalability' => const Color(0xFFB8860B),
      'Availability' => const Color(0xFF059669),
      'Recoverability' => const Color(0xFFFFC812),
      'Maintainability' => const Color(0xFFD97706),
      _ => const Color(0xFF6B7280),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.speed_rounded, size: 16, color: categoryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(item.id,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: categoryColor,
                        )),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(item.category,
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: categoryColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(item.requirement,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Target: ${item.target}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit NFR',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: 'Delete NFR',
            onPressed: onDelete,
          ),
          ExecutionStatusBadge(label: item.status),
        ],
      ),
    );
  }
}

class _ADRecordCard extends StatelessWidget {
  const _ADRecordCard({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });
  final _ADRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (record.status) {
      'Accepted' => const Color(0xFF10B981),
      'Proposed' => const Color(0xFFD97706),
      'Deprecated' => const Color(0xFFEF4444),
      'Superseded' => const Color(0xFF6B7280),
      _ => const Color(0xFF9CA3AF),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(record.id,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  )),
              const SizedBox(width: 8),
              Expanded(
                child: Text(record.title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit ADR',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: 'Delete ADR',
                onPressed: onDelete,
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(record.status,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildADRow('Context', record.context, const Color(0xFFFFC812)),
          const SizedBox(height: 8),
          _buildADRow('Decision', record.decision, const Color(0xFF059669)),
        ],
      ),
    );
  }

  Widget _buildADRow(String label, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w800, color: color)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF4B5563), height: 1.5)),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// DATA CLASSES
// ══════════════════════════════════════════════════════════════════

class _ArchitecturePattern {
  final String name;
  final String description;
  final String status;
  final IconData icon;
  final Color color;
  _ArchitecturePattern({
    required this.name,
    required this.description,
    required this.status,
    required this.icon,
    required this.color,
  });

  _ArchitecturePattern copyWith({
    String? name,
    String? description,
    String? status,
    IconData? icon,
    Color? color,
  }) {
    return _ArchitecturePattern(
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }
}

class _SecurityControl {
  final String id;
  final String requirement;
  final String standard;
  final String status;
  const _SecurityControl({
    required this.id,
    required this.requirement,
    required this.standard,
    required this.status,
  });
}

class _NFRItem {
  final String id;
  final String category;
  final String requirement;
  final String target;
  final String status;
  const _NFRItem({
    required this.id,
    required this.category,
    required this.requirement,
    required this.target,
    required this.status,
  });
}

class _ADRecord {
  final String id;
  final String title;
  final String context;
  final String decision;
  final String status;
  const _ADRecord({
    required this.id,
    required this.title,
    required this.context,
    required this.decision,
    required this.status,
  });
}

class _ArtifactReadinessItem {
  final String name;
  final String status;
  final bool ready;
  const _ArtifactReadinessItem({
    required this.name,
    required this.status,
    required this.ready,
  });
}
