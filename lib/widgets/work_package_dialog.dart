import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/milestone_item_linkage_service.dart';
import 'package:ndu_project/widgets/milestone_picker_dialog.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
class WorkPackageDialog extends StatefulWidget {
  const WorkPackageDialog({
    super.key,
    this.initialWorkPackage,
    this.wbsLevel2Options = const [],
  });

  final WorkPackage? initialWorkPackage;
  final List<Map<String, String>> wbsLevel2Options;

  @override
  State<WorkPackageDialog> createState() => _WorkPackageDialogState();
}

class _WorkPackageDialogState extends State<WorkPackageDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _ownerController;
  late final TextEditingController _disciplineController;
  late final TextEditingController _budgetController;
  late final TextEditingController _acceptingCriteriaController;
  late final TextEditingController _notesController;
  late final TextEditingController _packageCodeController;
  late final TextEditingController _sourceWbsLevel3IdController;
  late final TextEditingController _sourceWbsLevel3TitleController;
  late final TextEditingController _areaOrSystemController;
  late final TextEditingController _contractorOrCrewController;
  late final TextEditingController _estimateMethodController;
  late final TextEditingController _estimateSourceController;
  late final TextEditingController _estimateAssumptionsController;
  late final TextEditingController _estimateConfidenceController;
  late final TextEditingController _procurementCategoryController;
  late final TextEditingController _procurementScopeController;
  late final TextEditingController _procurementLeadTimeController;
  late final TextEditingController _contractIdsController;
  late final TextEditingController _vendorIdsController;

  String _type = 'design';
  String _phase = 'design';
  String _status = 'planned';
  String _packageClassification = '';
  String _releaseStatus = 'draft';
  String? _wbsLevel2Id;
  String? _plannedStart;
  String? _plannedEnd;
  late PackageReadinessChecklist _readiness;
  List<String> _milestoneIds = [];

  @override
  void initState() {
    super.initState();
    final wp = widget.initialWorkPackage;
    _milestoneIds = List<String>.from(wp?.milestoneIds ?? []);
    _titleController = TextEditingController(text: wp?.title ?? '');
    _descriptionController = TextEditingController(text: wp?.description ?? '');
    _ownerController = TextEditingController(text: wp?.owner ?? '');
    _disciplineController = TextEditingController(text: wp?.discipline ?? '');
    _budgetController = TextEditingController(
        text: wp != null && wp.budgetedCost > 0
            ? wp.budgetedCost.toString()
            : '');
    _acceptingCriteriaController =
        TextEditingController(text: wp?.acceptingCriteria ?? '');
    _notesController = TextEditingController(text: wp?.notes ?? '');
    _packageCodeController = TextEditingController(text: wp?.packageCode ?? '');
    _sourceWbsLevel3IdController =
        TextEditingController(text: wp?.sourceWbsLevel3Id ?? '');
    _sourceWbsLevel3TitleController =
        TextEditingController(text: wp?.sourceWbsLevel3Title ?? '');
    _areaOrSystemController =
        TextEditingController(text: wp?.areaOrSystem ?? '');
    _contractorOrCrewController =
        TextEditingController(text: wp?.contractorOrCrew ?? '');
    _estimateMethodController =
        TextEditingController(text: wp?.estimateBasis.method ?? '');
    _estimateSourceController =
        TextEditingController(text: wp?.estimateBasis.sourceData ?? '');
    _estimateAssumptionsController = TextEditingController(
      text: wp?.estimateBasis.assumptions.join('\n') ?? '',
    );
    _estimateConfidenceController =
        TextEditingController(text: wp?.estimateBasis.confidenceLevel ?? '');
    _procurementCategoryController =
        TextEditingController(text: wp?.procurementBreakdown.category ?? '');
    _procurementScopeController = TextEditingController(
        text: wp?.procurementBreakdown.scopeDefinition ?? '');
    _procurementLeadTimeController = TextEditingController(
      text: wp != null && wp.procurementBreakdown.leadTimeDays > 0
          ? wp.procurementBreakdown.leadTimeDays.toString()
          : '',
    );
    _contractIdsController =
        TextEditingController(text: wp?.contractIds.join(', ') ?? '');
    _vendorIdsController =
        TextEditingController(text: wp?.vendorIds.join(', ') ?? '');
    _readiness = PackageReadinessChecklist.fromJson(
      wp?.readiness.toJson() ?? PackageReadinessChecklist().toJson(),
    );

    if (wp != null) {
      _type = wp.type;
      _phase = wp.phase;
      _status = wp.status;
      _packageClassification = wp.packageClassification;
      _releaseStatus = wp.releaseStatus;
      _wbsLevel2Id = wp.wbsLevel2Id.isNotEmpty ? wp.wbsLevel2Id : null;
      _plannedStart = wp.plannedStart;
      _plannedEnd = wp.plannedEnd;
    }

    // Validate dropdown values against their allowed items to prevent
    // DropdownButton assertion failures ("There should be exactly one item
    // with [DropdownButton]'s value"). Stale data from deleted WBS items
    // or changed enum values can cause this.
    const allowedTypes = {
      'design', 'construction', 'execution', 'agile', 'procurement', 'delivery'
    };
    const allowedPhases = {'design', 'execution', 'launch'};
    const allowedStatuses = {
      'planned', 'in_progress', 'complete', 'blocked', 'on_hold'
    };
    const allowedClassifications = {
      'engineeringEwp', 'procurementPackage', 'constructionCwp',
      'deliveryPackage', 'implementationWorkPackage', 'agileIterationPackage',
      'preCommissioningPackage', 'commissioningPackage', ''
    };
    const allowedReleaseStatuses = {
      'draft', 'ready_for_review', 'released', 'blocked'
    };
    if (!allowedTypes.contains(_type)) _type = 'design';
    if (!allowedPhases.contains(_phase)) _phase = 'design';
    if (!allowedStatuses.contains(_status)) _status = 'planned';
    if (!allowedClassifications.contains(_packageClassification)) {
      _packageClassification = '';
    }
    if (!allowedReleaseStatuses.contains(_releaseStatus)) {
      _releaseStatus = 'draft';
    }
    // Validate WBS Level 2 ID against available options
    if (_wbsLevel2Id != null && _wbsLevel2Id!.isNotEmpty) {
      final wbsIds = widget.wbsLevel2Options
          .map((opt) => opt['id'] ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      if (!wbsIds.contains(_wbsLevel2Id)) {
        _wbsLevel2Id = '';
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _ownerController.dispose();
    _disciplineController.dispose();
    _budgetController.dispose();
    _acceptingCriteriaController.dispose();
    _notesController.dispose();
    _packageCodeController.dispose();
    _sourceWbsLevel3IdController.dispose();
    _sourceWbsLevel3TitleController.dispose();
    _areaOrSystemController.dispose();
    _contractorOrCrewController.dispose();
    _estimateMethodController.dispose();
    _estimateSourceController.dispose();
    _estimateAssumptionsController.dispose();
    _estimateConfidenceController.dispose();
    _procurementCategoryController.dispose();
    _procurementScopeController.dispose();
    _procurementLeadTimeController.dispose();
    _contractIdsController.dispose();
    _vendorIdsController.dispose();
    super.dispose();
  }

  List<String> _splitCsv(String value) {
    return value
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _pickDate(bool isStart) async {
    final current = isStart ? _plannedStart : _plannedEnd;
    final initialDate = DateTime.tryParse(current ?? '') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _plannedStart = picked.toIso8601String().split('T').first;
        } else {
          _plannedEnd = picked.toIso8601String().split('T').first;
        }
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final wp = widget.initialWorkPackage;
    final estimateBasis = PackageEstimateBasis(
      method: _estimateMethodController.text.trim(),
      sourceData: _estimateSourceController.text.trim(),
      assumptions: _estimateAssumptionsController.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(),
      confidenceLevel: _estimateConfidenceController.text.trim(),
      productivityBasis: wp?.estimateBasis.productivityBasis ?? '',
      resourceBasis: wp?.estimateBasis.resourceBasis ?? '',
      workingCalendar: wp?.estimateBasis.workingCalendar ?? '',
      procurementLeadTimeBasis:
          wp?.estimateBasis.procurementLeadTimeBasis ?? '',
      reviewAllowance: wp?.estimateBasis.reviewAllowance ?? '',
      exclusions: wp?.estimateBasis.exclusions ?? const [],
      risksAndContingency: wp?.estimateBasis.risksAndContingency ?? '',
    );
    final procurementBreakdown = PackageProcurementBreakdown(
      category: _procurementCategoryController.text.trim(),
      scopeDefinition: _procurementScopeController.text.trim(),
      leadTimeDays:
          int.tryParse(_procurementLeadTimeController.text.trim()) ?? 0,
      rfqDate: wp?.procurementBreakdown.rfqDate ?? '',
      awardDate: wp?.procurementBreakdown.awardDate ?? '',
      deliveryDate: wp?.procurementBreakdown.deliveryDate ?? '',
      requiredByMilestoneId:
          wp?.procurementBreakdown.requiredByMilestoneId ?? '',
      vendorScope: wp?.procurementBreakdown.vendorScope ?? '',
      activities: wp?.procurementBreakdown.activities ?? const [],
    );
    final result = WorkPackage(
      id: wp?.id,
      wbsItemId: wp?.wbsItemId ?? '',
      wbsLevel2Id: _wbsLevel2Id ?? '',
      wbsLevel2Title: widget.wbsLevel2Options.firstWhere(
            (opt) => opt['id'] == _wbsLevel2Id,
            orElse: () => {'title': ''},
          )['title'] ??
          '',
      sourceWbsLevel3Id: _sourceWbsLevel3IdController.text.trim(),
      sourceWbsLevel3Title: _sourceWbsLevel3TitleController.text.trim(),
      packageLevel: wp?.packageLevel ?? 3,
      packageCode: _packageCodeController.text.trim(),
      packageClassification: _packageClassification,
      parentPackageId: wp?.parentPackageId ?? '',
      childPackageIds: wp?.childPackageIds ?? const [],
      linkedEngineeringPackageIds: wp?.linkedEngineeringPackageIds ?? const [],
      linkedProcurementPackageIds: wp?.linkedProcurementPackageIds ?? const [],
      linkedExecutionPackageIds: wp?.linkedExecutionPackageIds ?? const [],
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _type,
      phase: _phase,
      status: _status,
      owner: _ownerController.text.trim(),
      discipline: _disciplineController.text.trim(),
      plannedStart: _plannedStart,
      plannedEnd: _plannedEnd,
      actualStart: wp?.actualStart,
      actualEnd: wp?.actualEnd,
      budgetedCost: double.tryParse(_budgetController.text.trim()) ?? 0,
      actualCost: wp?.actualCost ?? 0,
      scheduleActivityIds: wp?.scheduleActivityIds ?? const [],
      contractIds: _splitCsv(_contractIdsController.text),
      vendorIds: _splitCsv(_vendorIdsController.text),
      requirementIds: wp?.requirementIds ?? const [],
      deliverables: wp?.deliverables ?? const [],
      acceptingCriteria: _acceptingCriteriaController.text.trim(),
      designPackageId: wp?.designPackageId ?? '',
      procurementItemIds: wp?.procurementItemIds ?? const [],
      milestoneIds: _milestoneIds,
      areaOrSystem: _areaOrSystemController.text.trim(),
      contractorOrCrew: _contractorOrCrewController.text.trim(),
      releaseStatus: _releaseStatus,
      readiness: _readiness,
      estimateBasis: estimateBasis,
      procurementBreakdown: procurementBreakdown,
      readinessWarnings: wp?.readinessWarnings ?? const [],
      notes: _notesController.text.trim(),
    );

    Navigator.of(context).pop(result);
  }

  Future<void> _pickMilestones() async {
    List<Milestone> allMilestones;
    try {
      allMilestones = MilestoneItemLinkageService.loadMilestones(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load milestones: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (allMilestones.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No milestones available. Add them in Front End Planning > Milestone.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    try {
      final picked = await showDialog<List<String>>(
        context: context,
        builder: (ctx) => MilestonePickerDialog(
          title: 'Link Milestones',
          allMilestones: allMilestones,
          selectedIds: _milestoneIds,
        ),
      );
      if (picked != null && mounted) {
        setState(() => _milestoneIds = picked);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialWorkPackage != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Work Package' : 'Create Work Package'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: 720,
          maxWidth: MediaQuery.of(context).size.width * 0.85,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                VoiceTextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title *'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Title is required'
                      : null,
                ),
                VoiceTextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                // Deduplicate WBS Level 2 options and filter out empty IDs
                // to prevent DropdownButton assertion failures.
                ...() {
                  final seenIds = <String>{};
                  final uniqueOpts = <Map<String, String>>[];
                  for (final opt in widget.wbsLevel2Options) {
                    final id = (opt['id'] ?? '').trim();
                    if (id.isEmpty || seenIds.contains(id)) continue;
                    seenIds.add(id);
                    uniqueOpts.add(opt);
                  }
                  if (uniqueOpts.isEmpty) return <Widget>[];
                  return [
                    DropdownButtonFormField<String>(
                      value: (_wbsLevel2Id != null &&
                              _wbsLevel2Id!.isNotEmpty &&
                              seenIds.contains(_wbsLevel2Id))
                          ? _wbsLevel2Id
                          : '',
                      decoration:
                          const InputDecoration(labelText: 'WBS Level 2'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('None'),
                        ),
                        for (final opt in uniqueOpts)
                          DropdownMenuItem<String>(
                            value: (opt['id'] ?? '').trim(),
                            child: Text(opt['title'] ?? ''),
                          ),
                      ],
                      onChanged: (v) => setState(() => _wbsLevel2Id = v),
                    ),
                  ];
                }(),
                Row(
                  children: [
                    Expanded(
                      child: VoiceTextFormField(
                        controller: _sourceWbsLevel3IdController,
                        decoration: const InputDecoration(
                          labelText: 'WBS Source Node ID',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: VoiceTextFormField(
                        controller: _sourceWbsLevel3TitleController,
                        decoration: const InputDecoration(
                          labelText: 'WBS Source Node',
                        ),
                      ),
                    ),
                  ],
                ),
                VoiceTextFormField(
                  controller: _contractIdsController,
                  decoration: const InputDecoration(
                    labelText: 'Contract IDs',
                    helperText: 'Comma-separated contract references',
                  ),
                ),
                VoiceTextFormField(
                  controller: _vendorIdsController,
                  decoration: const InputDecoration(
                    labelText: 'Vendor IDs',
                    helperText: 'Comma-separated vendor references',
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: VoiceTextFormField(
                        controller: _packageCodeController,
                        decoration:
                            const InputDecoration(labelText: 'Package Code'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _packageClassification.isEmpty
                            ? null
                            : _packageClassification,
                        decoration: const InputDecoration(
                            labelText: 'Package Classification'),
                        items: const [
                          DropdownMenuItem(
                              value: 'engineeringEwp',
                              child: Text('Engineering Work Package')),
                          DropdownMenuItem(
                              value: 'procurementPackage',
                              child: Text('Procurement Package')),
                          DropdownMenuItem(
                              value: 'constructionCwp',
                              child: Text('Construction Work Package')),
                          DropdownMenuItem(
                              value: 'deliveryPackage',
                              child: Text('Deliverable Work Package')),
                          DropdownMenuItem(
                              value: 'implementationWorkPackage',
                              child: Text('Implementation Work Package')),
                          DropdownMenuItem(
                              value: 'agileIterationPackage',
                              child: Text('Agile Iteration Package')),
                          DropdownMenuItem(
                              value: 'preCommissioningPackage',
                              child: Text('Pre-Commissioning Package')),
                          DropdownMenuItem(
                              value: 'commissioningPackage',
                              child: Text('Commissioning Package')),
                        ],
                        onChanged: (v) {
                          setState(() => _packageClassification = v ?? '');
                        },
                      ),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  value: _releaseStatus,
                  decoration:
                      const InputDecoration(labelText: 'Release Status'),
                  items: const [
                    DropdownMenuItem(
                        value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(
                        value: 'ready_for_review',
                        child: Text('Ready for Review')),
                    DropdownMenuItem(
                        value: 'released', child: Text('Released')),
                    DropdownMenuItem(
                        value: 'blocked', child: Text('Blocked')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _releaseStatus = v);
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _type,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: const [
                          DropdownMenuItem(
                              value: 'design', child: Text('Design')),
                          DropdownMenuItem(
                              value: 'construction',
                              child: Text('Construction')),
                          DropdownMenuItem(
                              value: 'execution', child: Text('Execution')),
                          DropdownMenuItem(
                              value: 'agile', child: Text('Agile')),
                          DropdownMenuItem(
                              value: 'procurement', child: Text('Procurement')),
                          DropdownMenuItem(
                              value: 'delivery', child: Text('Delivery')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _type = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _phase,
                        decoration: const InputDecoration(labelText: 'Phase'),
                        items: const [
                          DropdownMenuItem(
                              value: 'design', child: Text('Design')),
                          DropdownMenuItem(
                              value: 'execution', child: Text('Execution')),
                          DropdownMenuItem(
                              value: 'launch', child: Text('Launch')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _phase = v);
                        },
                      ),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(
                        value: 'planned', child: Text('Planned')),
                    DropdownMenuItem(
                        value: 'in_progress', child: Text('In Progress')),
                    DropdownMenuItem(
                        value: 'complete', child: Text('Complete')),
                    DropdownMenuItem(
                        value: 'blocked', child: Text('Blocked')),
                    DropdownMenuItem(
                        value: 'on_hold', child: Text('On Hold')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _status = v);
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: VoiceTextFormField(
                        controller: _ownerController,
                        decoration: const InputDecoration(labelText: 'Owner'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: VoiceTextFormField(
                        controller: _disciplineController,
                        decoration:
                            const InputDecoration(labelText: 'Discipline'),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: VoiceTextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Planned Start',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today, size: 18),
                            onPressed: () => _pickDate(true),
                          ),
                        ),
                        controller: TextEditingController(
                          text: _plannedStart ?? 'Select date',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: VoiceTextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Planned End',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today, size: 18),
                            onPressed: () => _pickDate(false),
                          ),
                        ),
                        controller: TextEditingController(
                          text: _plannedEnd ?? 'Select date',
                        ),
                      ),
                    ),
                  ],
                ),
                VoiceTextFormField(
                  controller: _budgetController,
                  decoration:
                      const InputDecoration(labelText: 'Budgeted Cost (\$)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                VoiceTextFormField(
                  controller: _acceptingCriteriaController,
                  decoration:
                      const InputDecoration(labelText: 'Accepting Criteria'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _Section(
                  title: 'Readiness Checklist',
                  children: _readinessFields(),
                ),
                _Section(
                  title: 'Estimate Basis',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: VoiceTextFormField(
                            controller: _estimateMethodController,
                            decoration: const InputDecoration(
                                labelText: 'Estimation Method'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: VoiceTextFormField(
                            controller: _estimateConfidenceController,
                            decoration: const InputDecoration(
                                labelText: 'Confidence Level'),
                          ),
                        ),
                      ],
                    ),
                    VoiceTextFormField(
                      controller: _estimateSourceController,
                      decoration:
                          const InputDecoration(labelText: 'Source Data'),
                    ),
                    VoiceTextFormField(
                      controller: _estimateAssumptionsController,
                      decoration: const InputDecoration(
                        labelText: 'Assumptions',
                        helperText: 'One assumption per line',
                      ),
                      minLines: 2,
                      maxLines: 4,
                    ),
                  ],
                ),
                _Section(
                  title: 'Procurement Breakdown',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: VoiceTextFormField(
                            controller: _procurementCategoryController,
                            decoration: const InputDecoration(
                                labelText: 'Procurement Category'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: VoiceTextFormField(
                            controller: _procurementLeadTimeController,
                            decoration: const InputDecoration(
                                labelText: 'Lead Time (days)'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    VoiceTextFormField(
                      controller: _procurementScopeController,
                      decoration: const InputDecoration(
                          labelText: 'Procurement Scope Definition'),
                      minLines: 2,
                      maxLines: 4,
                    ),
                  ],
                ),
                _Section(
                  title: 'Linked FEP Milestones',
                  children: [
                    _MilestoneLinkChip(
                      milestoneIds: _milestoneIds,
                      onPick: _pickMilestones,
                    ),
                  ],
                ),
                VoiceTextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(isEdit ? 'Save Changes' : 'Create'),
        ),
      ],
    );
  }

  List<Widget> _readinessFields() {
    return [
      _ReadinessCheckbox(
        label: 'Requirements traced',
        value: _readiness.requirementsTraced,
        onChanged: (v) => setState(() => _readiness.requirementsTraced = v),
      ),
      _ReadinessCheckbox(
        label: 'Drawings complete',
        value: _readiness.drawingsComplete,
        onChanged: (v) => setState(() => _readiness.drawingsComplete = v),
      ),
      _ReadinessCheckbox(
        label: 'Specifications complete',
        value: _readiness.specificationsComplete,
        onChanged: (v) => setState(() => _readiness.specificationsComplete = v),
      ),
      _ReadinessCheckbox(
        label: 'BOM complete',
        value: _readiness.billOfMaterialsComplete,
        onChanged: (v) =>
            setState(() => _readiness.billOfMaterialsComplete = v),
      ),
      _ReadinessCheckbox(
        label: 'Design review complete',
        value: _readiness.designReviewComplete,
        onChanged: (v) => setState(() => _readiness.designReviewComplete = v),
      ),
      _ReadinessCheckbox(
        label: 'IFC / design approved',
        value: _readiness.ifcApproved,
        onChanged: (v) => setState(() => _readiness.ifcApproved = v),
      ),
      _ReadinessCheckbox(
        label: 'Procurement scope defined',
        value: _readiness.procurementScopeDefined,
        onChanged: (v) =>
            setState(() => _readiness.procurementScopeDefined = v),
      ),
      _ReadinessCheckbox(
        label: 'RFQ/RFP issued',
        value: _readiness.rfqIssued,
        onChanged: (v) => setState(() => _readiness.rfqIssued = v),
      ),
      _ReadinessCheckbox(
        label: 'Bids evaluated',
        value: _readiness.bidsEvaluated,
        onChanged: (v) => setState(() => _readiness.bidsEvaluated = v),
      ),
      _ReadinessCheckbox(
        label: 'Contract awarded',
        value: _readiness.contractAwarded,
        onChanged: (v) => setState(() => _readiness.contractAwarded = v),
      ),
      _ReadinessCheckbox(
        label: 'Materials available',
        value: _readiness.materialsAvailable,
        onChanged: (v) => setState(() => _readiness.materialsAvailable = v),
      ),
      _ReadinessCheckbox(
        label: 'Permits approved',
        value: _readiness.permitsApproved,
        onChanged: (v) => setState(() => _readiness.permitsApproved = v),
      ),
      _ReadinessCheckbox(
        label: 'Access / site ready',
        value: _readiness.accessReady,
        onChanged: (v) => setState(() => _readiness.accessReady = v),
      ),
      _ReadinessCheckbox(
        label: 'Predecessors complete',
        value: _readiness.predecessorsComplete,
        onChanged: (v) => setState(() => _readiness.predecessorsComplete = v),
      ),
      _ReadinessCheckbox(
        label: 'Resources assigned',
        value: _readiness.resourcesAssigned,
        onChanged: (v) => setState(() => _readiness.resourcesAssigned = v),
      ),
    ];
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: children,
        ),
      ],
    );
  }
}

class _ReadinessCheckbox extends StatelessWidget {
  const _ReadinessCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(label, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: (v) => onChanged(v ?? false),
      ),
    );
  }
}

class _MilestoneLinkChip extends StatelessWidget {
  final List<String> milestoneIds;
  final VoidCallback onPick;

  const _MilestoneLinkChip({
    required this.milestoneIds,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: Row(
          children: [
            const Icon(Icons.flag_outlined,
                size: 16, color: Color(0xFFFFC107)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                milestoneIds.isEmpty
                    ? 'Tap to link FEP milestones...'
                    : '${milestoneIds.length} milestone${milestoneIds.length == 1 ? '' : 's'} linked',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: milestoneIds.isEmpty
                      ? const Color(0xFF64748B)
                      : const Color(0xFF1E293B),
                ),
              ),
            ),
            const Icon(Icons.edit_outlined,
                size: 14, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}
