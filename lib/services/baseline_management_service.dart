import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ndu_project/models/baseline_version_model.dart';
import 'package:ndu_project/models/control_account_model.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/cbs_element_model.dart';
import 'package:ndu_project/models/obs_element_model.dart';
import 'package:ndu_project/models/scope_tracking_item.dart';
import 'package:ndu_project/services/control_account_service.dart';

class BaselineManagementService {
  static CollectionReference<Map<String, dynamic>>? _tryCollection() {
    try {
      return FirebaseFirestore.instance.collection('project_baselines');
    } catch (e, st) {
      debugPrint('BaselineManagementService: Firestore not ready ($e)\n$st');
      return null;
    }
  }

  static CollectionReference<Map<String, dynamic>> _requireCollection() {
    final col = _tryCollection();
    if (col == null) {
      throw StateError('Firestore is not initialized');
    }
    return col;
  }

  /// Create a baseline snapshot from the current project data.
  static Future<String> createBaseline({
    required String projectId,
    required String author,
    required String label,
    String description = '',
    String triggerSource = 'manual',
    String approvedBy = '',
  }) async {
    final existingVersions = await _requireCollection()
        .where('projectId', isEqualTo: projectId)
        .get();
    final versionNumber = existingVersions.size + 1;

    final baseline = BaselineVersion(
      versionNumber: versionNumber,
      label: label,
      description: description,
      author: author,
      approvedBy: approvedBy,
      triggerSource: triggerSource,
    );

    await _requireCollection().doc(projectId).collection('versions').add({
      ...baseline.toJson(),
      'projectId': projectId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return baseline.id;
  }

  /// Retrieve all baselines for a project, ordered by creation date descending.
  static Stream<List<BaselineVersion>> streamBaselines(String projectId) {
    final col = _tryCollection();
    if (col == null) {
      return Stream.value([]);
    }
    return col
        .doc(projectId)
        .collection('versions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return BaselineVersion.fromJson(data);
          })
          .toList();
    });
  }

  /// Compute schedule variance between current and baseline.
  static double computeScheduleVarianceDays({
    required List<ScheduleActivity> currentActivities,
    required List<ScheduleActivity> baselineActivities,
  }) {
    double totalVariance = 0;
    int count = 0;

    for (final current in currentActivities) {
      final baseline = baselineActivities.where((b) => b.id == current.id).firstOrNull;
      if (baseline == null) continue;
      if (current.dueDate.isEmpty || baseline.dueDate.isEmpty) continue;

      final currentDate = DateTime.tryParse(current.dueDate);
      final baselineDate = DateTime.tryParse(baseline.dueDate);
      if (currentDate == null || baselineDate == null) continue;

      totalVariance += currentDate.difference(baselineDate).inDays;
      count++;
    }

    return count > 0 ? totalVariance / count : 0;
  }

  /// Compute cost variance between current and baseline.
  static double computeCostVariance({
    required List<WorkPackage> currentPackages,
    required List<WorkPackage> baselinePackages,
  }) {
    final currentTotal =
        currentPackages.fold<double>(0, (s, wp) => s + wp.budgetedCost);
    final baselineTotal =
        baselinePackages.fold<double>(0, (s, wp) => s + wp.budgetedCost);
    return currentTotal - baselineTotal;
  }

  /// ── P2.1: Build a FULL snapshot with structural data and EVM metrics ──
  /// Captures control accounts, WBS, CBS, OBS, schedule activities, and
  /// work packages as point-in-time snapshots for baseline comparison/restore.
  static Future<String> captureSnapshot({
    required String projectId,
    required String author,
    required ProjectDataModel projectData,
    List<ScopeTrackingItem>? scopeItems,
    String label = '',
    String description = '',
    String triggerSource = 'manual',
    String approvedBy = '',
  }) async {
    final existingVersions = await _requireCollection()
        .doc(projectId)
        .collection('versions')
        .get();
    final versionNumber = existingVersions.size + 1;

    // Schedule variance
    final svDays = computeScheduleVarianceDays(
      currentActivities: projectData.scheduleActivities,
      baselineActivities: projectData.scheduleBaselineActivities,
    );

    // Cost variance
    final costVar = computeCostVariance(
      currentPackages: projectData.workPackages,
      baselinePackages: [], // Empty baseline list — first baseline has no prior
    );

    // Activity counts
    final totalWps = projectData.workPackages.length;
    final totalActs = projectData.scheduleActivities.length;
    final completedActs = projectData.scheduleActivities
        .where((a) => a.status == 'complete')
        .length;

    // ── P2.1: Compute aggregate EVM metrics from control accounts ──
    final controlAccounts = projectData.controlAccounts;
    double aggBac = 0, aggEv = 0, aggAc = 0, aggPv = 0;
    for (final ca in controlAccounts) {
      aggBac += ca.budgetAtCompletion;
      aggEv += ca.earnedValue;
      aggAc += ca.actualCost;
      aggPv += ControlAccountService.computePlannedValueToDate(ca.plannedValueByPeriod);
    }
    final aggCpi = aggAc > 0 ? aggEv / aggAc : 1.0;
    final aggSpi = aggPv > 0 ? aggEv / aggPv : 1.0;
    final aggEac = aggCpi > 0 ? aggBac / aggCpi : aggBac;
    final aggEtc = aggEac - aggAc;
    final aggVac = aggBac - aggEac;
    final aggCv = aggEv - aggAc;
    final aggSv = aggEv - aggPv;
    final aggTcpii = (aggBac - aggAc) > 0 ? (aggBac - aggEv) / (aggBac - aggAc) : 1.0;

    // ── P2.1: Scope tracking metrics ──
    final effectiveScopeItems = scopeItems ?? <ScopeTrackingItem>[];
    final totalScopeItems = effectiveScopeItems.length;
    final baselineScopeItems =
        effectiveScopeItems.where((s) => s.isBaseline).length;
    final scopeCreepItems =
        effectiveScopeItems.where((s) => !s.isBaseline).length;
    final scopeGrowthPercent = baselineScopeItems > 0
        ? (scopeCreepItems / baselineScopeItems) * 100.0
        : 0.0;

    // ── P2.1: Capture structural snapshots ──
    // Control Account snapshots include full EVM + period data for diff/restore
    final caSnapshots = controlAccounts.map((ca) => <String, dynamic>{
      'id': ca.id,
      'wbsId': ca.wbsId,
      'obsId': ca.obsId,
      'cbsId': ca.cbsId,
      'title': ca.title,
      'bac': ca.budgetAtCompletion,
      'earnedValue': ca.earnedValue,
      'actualCost': ca.actualCost,
      'cpi': ca.cpi,
      'spi': ca.spi,
      'eac': ca.eac,
      'etc': ca.etc,
      'vac': ca.vac,
      'cv': ca.cv,
      'sv': ca.sv,
      'tcpii': ca.tcpii,
      'tcpis': ca.tcpis,
      'riskAdjustment': ca.riskAdjustment,
      'plannedValueByPeriod': ca.plannedValueByPeriod,
      'earnedValueByPeriod': ca.earnedValueByPeriod,
      'actualCostByPeriod': ca.actualCostByPeriod,
      'affectedChangeRequestIds': ca.affectedChangeRequestIds,
      'baselineVersionId': ca.baselineVersionId,
    }).toList();

    // WBS snapshots include WBS Dictionary fields for full traceability
    final wbsSnapshots = _flattenWbsTree(projectData.wbsTree);
    // CBS snapshots include full financial data for budget baseline comparison
    final cbsSnapshots = projectData.cbsElements.map((cbs) => <String, dynamic>{
      'id': cbs.id,
      'code': cbs.code,
      'name': cbs.name,
      'parentCbsId': cbs.parentCbsId,
      'budgetAmount': cbs.budgetAmount,
      'committedAmount': cbs.committedAmount,
      'spentAmount': cbs.spentAmount,
      'contingencyAmount': cbs.contingencyAmount,
      'isManagementReserve': cbs.isManagementReserve,
      'currency': cbs.currency,
      'wbsId': cbs.wbsId,
      'obsId': cbs.obsId,
      'controlAccountId': cbs.controlAccountId,
    }).toList();
    // OBS snapshots include org structure and capacity for resource baseline
    final obsSnapshots = projectData.obsElements.map((obs) => <String, dynamic>{
      'id': obs.id,
      'name': obs.name,
      'parentObsId': obs.parentObsId,
      'manager': obs.manager,
      'role': obs.role,
      'department': obs.department,
      'responsibility': obs.responsibility,
      'costCenter': obs.costCenter,
      'budgetAuthority': obs.budgetAuthority,
      'capacityFte': obs.capacityFte,
      'allocatedFte': obs.allocatedFte,
      'wbsId': obs.wbsId,
      'cbsId': obs.cbsId,
      'controlAccountId': obs.controlAccountId,
    }).toList();
    final scheduleSnapshots = projectData.scheduleActivities.map((a) => {
      'id': a.id,
      'title': a.title,
      'startDate': a.startDate.toString() ?? '',
      'dueDate': a.dueDate,
      'status': a.status,
      'isCriticalPath': a.isCriticalPath,
    }).toList();
    final wpSnapshots = projectData.workPackages.map((wp) => {
      'id': wp.id,
      'title': wp.title,
      'budgetedCost': wp.budgetedCost,
      'actualCost': wp.actualCost,
      'status': wp.status,
      'percentComplete': wp.percentComplete,
    }).toList();

    final baseline = BaselineVersion(
      versionNumber: versionNumber,
      label: label.isNotEmpty ? label : 'Baseline v$versionNumber',
      description: description,
      author: author,
      approvedBy: approvedBy,
      triggerSource: triggerSource,
      scheduleVarianceDays: svDays,
      costVariance: costVar,
      budgetAtCompletion: aggBac,
      totalActivities: totalActs,
      completedActivities: completedActs,
      totalWorkPackages: totalWps,
      // EVM snapshot
      plannedValue: aggPv,
      earnedValue: aggEv,
      actualCost: aggAc,
      cpi: aggCpi,
      spi: aggSpi,
      eac: aggEac,
      etc: aggEtc,
      vac: aggVac,
      cv: aggCv,
      sv: aggSv,
      tcpii: aggTcpii,
      // Scope snapshot
      totalScopeItems: totalScopeItems,
      baselineScopeItems: baselineScopeItems,
      scopeCreepItems: scopeCreepItems,
      scopeGrowthPercent: scopeGrowthPercent,
      // Structural snapshots
      controlAccountSnapshots: caSnapshots,
      wbsSnapshots: wbsSnapshots,
      cbsSnapshots: cbsSnapshots,
      obsSnapshots: obsSnapshots,
      scheduleActivitySnapshots: scheduleSnapshots,
      workPackageSnapshots: wpSnapshots,
      isCurrent: true,
    );

    // Mark all previous versions as not current
    final batch = FirebaseFirestore.instance.batch();
    final prevVersions = await _requireCollection()
        .doc(projectId)
        .collection('versions')
        .where('isCurrent', isEqualTo: true)
        .get();
    for (final doc in prevVersions.docs) {
      batch.update(doc.reference, {'isCurrent': false});
    }
    await batch.commit();

    await _requireCollection().doc(projectId).collection('versions').add({
      ...baseline.toJson(),
      'projectId': projectId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return baseline.id;
  }

  /// Flatten the WBS tree into a list of snapshots for storage.
  /// Includes WBS Dictionary fields (P1.1) for full traceability on restore.
  static List<Map<String, dynamic>> _flattenWbsTree(List<WorkItem> tree) {
    final result = <Map<String, dynamic>>[];
    void walk(List<WorkItem> items) {
      for (final item in items) {
        result.add({
          'id': item.id,
          'wbsCode': item.wbsCode,
          'title': item.title,
          'parentId': item.parentId,
          'status': item.status,
          'weight': item.weight,
          'cbsId': item.cbsId,
          'obsId': item.obsId,
          'deliverableDescription': item.deliverableDescription,
          'acceptanceCriteria': item.acceptanceCriteria,
          'workPackageDefinition': item.workPackageDefinition,
        });
        walk(item.children);
      }
    }
    walk(tree);
    return result;
  }

  /// Compare two baseline versions and return the differences.
  /// Returns a map of field names to {previous, current, delta} for numeric fields,
  /// and lists of added/removed/modified items for structural snapshots.
  static Map<String, dynamic> compareBaselines({
    required BaselineVersion previous,
    required BaselineVersion current,
  }) {
    final diffs = <String, dynamic>{};

    // Numeric field comparisons
    final numericFields = {
      'budgetAtCompletion': [previous.budgetAtCompletion, current.budgetAtCompletion],
      'plannedValue': [previous.plannedValue, current.plannedValue],
      'earnedValue': [previous.earnedValue, current.earnedValue],
      'actualCost': [previous.actualCost, current.actualCost],
      'cpi': [previous.cpi, current.cpi],
      'spi': [previous.spi, current.spi],
      'eac': [previous.eac, current.eac],
      'scheduleVarianceDays': [previous.scheduleVarianceDays, current.scheduleVarianceDays],
      'costVariance': [previous.costVariance, current.costVariance],
      'totalScopeItems': [previous.totalScopeItems.toDouble(), current.totalScopeItems.toDouble()],
      'scopeCreepItems': [previous.scopeCreepItems.toDouble(), current.scopeCreepItems.toDouble()],
    };

    for (final entry in numericFields.entries) {
      final prev = entry.value[0];
      final curr = entry.value[1];
      final delta = curr - prev;
      if (delta != 0) {
        diffs[entry.key] = {
          'previous': prev,
          'current': curr,
          'delta': delta,
          'percentChange': prev != 0 ? (delta / prev) * 100 : 0,
        };
      }
    }

    // ── Structural change detection ──

    // WBS items added/removed
    final prevWbsIds = previous.wbsSnapshots.map((e) => e['id']?.toString()).toSet();
    final currWbsIds = current.wbsSnapshots.map((e) => e['id']?.toString()).toSet();
    final addedWbs = currWbsIds.difference(prevWbsIds).length;
    final removedWbs = prevWbsIds.difference(currWbsIds).length;
    if (addedWbs > 0 || removedWbs > 0) {
      diffs['wbsChanges'] = {'added': addedWbs, 'removed': removedWbs};
    }

    // Work package changes
    final prevWpIds = previous.workPackageSnapshots.map((e) => e['id']?.toString()).toSet();
    final currWpIds = current.workPackageSnapshots.map((e) => e['id']?.toString()).toSet();
    final addedWps = currWpIds.difference(prevWpIds).length;
    final removedWps = prevWpIds.difference(currWpIds).length;
    if (addedWps > 0 || removedWps > 0) {
      diffs['workPackageChanges'] = {'added': addedWps, 'removed': removedWps};
    }

    // Control Account changes (budget/EVM changes)
    final prevCaMap = <String, Map<String, dynamic>>{};
    for (final ca in previous.controlAccountSnapshots) {
      final key = ca['id']?.toString();
      if (key != null) prevCaMap[key] = ca;
    }
    final currCaMap = <String, Map<String, dynamic>>{};
    for (final ca in current.controlAccountSnapshots) {
      final key = ca['id']?.toString();
      if (key != null) currCaMap[key] = ca;
    }
    final caChanges = <String, dynamic>{};
    for (final id in currCaMap.keys) {
      final prev = prevCaMap[id];
      if (prev == null) continue;
      final curr = currCaMap[id]!;
      final prevBac = (prev['bac'] as num?)?.toDouble() ?? 0;
      final currBac = (curr['bac'] as num?)?.toDouble() ?? 0;
      if (prevBac != currBac) {
        caChanges[id] = {
          'bacChange': currBac - prevBac,
          'previous': prevBac,
          'current': currBac,
        };
      }
    }
    final addedCas = currCaMap.keys.toSet().difference(prevCaMap.keys.toSet()).length;
    final removedCas = prevCaMap.keys.toSet().difference(currCaMap.keys.toSet()).length;
    if (caChanges.isNotEmpty || addedCas > 0 || removedCas > 0) {
      diffs['controlAccountChanges'] = {
        'added': addedCas,
        'removed': removedCas,
        'modified': caChanges.length,
        'details': caChanges,
      };
    }

    // CBS budget changes
    final prevCbsMap = {for (final cbs in previous.cbsSnapshots)
      cbs['id']?.toString(): cbs};
    final currCbsMap = {for (final cbs in current.cbsSnapshots)
      cbs['id']?.toString(): cbs};
    double cbsBudgetDelta = 0;
    for (final id in currCbsMap.keys) {
      final prev = prevCbsMap[id];
      if (prev == null) continue;
      final prevBudget = (prev['budgetAmount'] as num?)?.toDouble() ?? 0;
      final currBudget = (currCbsMap[id]!['budgetAmount'] as num?)?.toDouble() ?? 0;
      cbsBudgetDelta += currBudget - prevBudget;
    }
    final addedCbs = currCbsMap.keys.toSet().difference(prevCbsMap.keys.toSet()).length;
    final removedCbs = prevCbsMap.keys.toSet().difference(currCbsMap.keys.toSet()).length;
    if (cbsBudgetDelta != 0 || addedCbs > 0 || removedCbs > 0) {
      diffs['cbsChanges'] = {
        'added': addedCbs,
        'removed': removedCbs,
        'budgetDelta': cbsBudgetDelta,
      };
    }

    // OBS changes
    final prevObsIds = previous.obsSnapshots.map((e) => e['id']?.toString()).toSet();
    final currObsIds = current.obsSnapshots.map((e) => e['id']?.toString()).toSet();
    final addedObs = currObsIds.difference(prevObsIds).length;
    final removedObs = prevObsIds.difference(currObsIds).length;
    if (addedObs > 0 || removedObs > 0) {
      diffs['obsChanges'] = {'added': addedObs, 'removed': removedObs};
    }

    return diffs;
  }

  /// ── P2.1: Restore project data from a baseline snapshot ──
  /// Reconstructs control accounts, CBS/OBS elements, and WBS data from
  /// a stored [BaselineVersion] snapshot. Returns a map of lists that can
  /// be applied to [ProjectDataModel] to roll back to a prior baseline.
  ///
  /// The caller is responsible for persisting the restored data to Firestore.
  static Map<String, dynamic> restoreFromSnapshot(BaselineVersion baseline) {
    // Reconstruct ControlAccount list from snapshots
    final restoredControlAccounts = baseline.controlAccountSnapshots.map((ca) {
      return ControlAccount(
        id: ca['id']?.toString() ?? '',
        wbsId: ca['wbsId']?.toString() ?? '',
        obsId: ca['obsId']?.toString() ?? '',
        cbsId: ca['cbsId']?.toString() ?? '',
        title: ca['title']?.toString() ?? '',
        budgetAtCompletion: (ca['bac'] as num?)?.toDouble() ?? 0,
        earnedValue: (ca['earnedValue'] as num?)?.toDouble() ?? 0,
        actualCost: (ca['actualCost'] as num?)?.toDouble() ?? 0,
        cpi: (ca['cpi'] as num?)?.toDouble() ?? 1.0,
        spi: (ca['spi'] as num?)?.toDouble() ?? 1.0,
        eac: (ca['eac'] as num?)?.toDouble() ?? 0,
        etc: (ca['etc'] as num?)?.toDouble() ?? 0,
        vac: (ca['vac'] as num?)?.toDouble() ?? 0,
        cv: (ca['cv'] as num?)?.toDouble() ?? 0,
        sv: (ca['sv'] as num?)?.toDouble() ?? 0,
        tcpii: (ca['tcpii'] as num?)?.toDouble() ?? 0,
        tcpis: (ca['tcpis'] as num?)?.toDouble() ?? 0,
        riskAdjustment: (ca['riskAdjustment'] as num?)?.toDouble() ?? 0,
        plannedValueByPeriod: _parsePeriodMap(ca['plannedValueByPeriod']),
        earnedValueByPeriod: _parsePeriodMap(ca['earnedValueByPeriod']),
        actualCostByPeriod: _parsePeriodMap(ca['actualCostByPeriod']),
        affectedChangeRequestIds:
            (ca['affectedChangeRequestIds'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
                [],
        baselineVersionId: ca['baselineVersionId']?.toString() ?? '',
      );
    }).toList();

    // Reconstruct CbsElement list from snapshots
    final restoredCbsElements = baseline.cbsSnapshots.map((cbs) {
      return CbsElement(
        id: cbs['id']?.toString() ?? '',
        code: cbs['code']?.toString() ?? '',
        name: cbs['name']?.toString() ?? '',
        parentCbsId: cbs['parentCbsId']?.toString() ?? '',
        budgetAmount: (cbs['budgetAmount'] as num?)?.toDouble() ?? 0,
        committedAmount: (cbs['committedAmount'] as num?)?.toDouble() ?? 0,
        spentAmount: (cbs['spentAmount'] as num?)?.toDouble() ?? 0,
        contingencyAmount: (cbs['contingencyAmount'] as num?)?.toDouble() ?? 0,
        isManagementReserve: cbs['isManagementReserve'] == true,
        currency: cbs['currency']?.toString() ?? 'USD',
        wbsId: cbs['wbsId']?.toString() ?? '',
        obsId: cbs['obsId']?.toString() ?? '',
        controlAccountId: cbs['controlAccountId']?.toString() ?? '',
      );
    }).toList();

    // Reconstruct ObsElement list from snapshots
    final restoredObsElements = baseline.obsSnapshots.map((obs) {
      return ObsElement(
        id: obs['id']?.toString() ?? '',
        name: obs['name']?.toString() ?? '',
        parentObsId: obs['parentObsId']?.toString() ?? '',
        manager: obs['manager']?.toString() ?? '',
        role: obs['role']?.toString() ?? '',
        department: obs['department']?.toString() ?? '',
        responsibility: obs['responsibility']?.toString() ?? '',
        costCenter: obs['costCenter']?.toString() ?? '',
        budgetAuthority: (obs['budgetAuthority'] as num?)?.toDouble() ?? 0,
        capacityFte: (obs['capacityFte'] as num?)?.toDouble() ?? 0,
        allocatedFte: (obs['allocatedFte'] as num?)?.toDouble() ?? 0,
        wbsId: obs['wbsId']?.toString() ?? '',
        cbsId: obs['cbsId']?.toString() ?? '',
        controlAccountId: obs['controlAccountId']?.toString() ?? '',
      );
    }).toList();

    // Reconstruct WorkPackage list from snapshots
    final restoredWorkPackages = baseline.workPackageSnapshots.map((wp) {
      return WorkPackage(
        id: wp['id']?.toString() ?? '',
        title: wp['title']?.toString() ?? '',
        budgetedCost: (wp['budgetedCost'] as num?)?.toDouble() ?? 0,
        actualCost: (wp['actualCost'] as num?)?.toDouble() ?? 0,
        status: wp['status']?.toString() ?? 'planned',
        percentComplete: (wp['percentComplete'] as num?)?.toDouble() ?? 0,
      );
    }).toList();

    // Reconstruct ScheduleActivity list from snapshots
    final restoredScheduleActivities = baseline.scheduleActivitySnapshots.map((a) {
      return ScheduleActivity(
        id: a['id']?.toString() ?? '',
        title: a['title']?.toString() ?? '',
        startDate: a['startDate']?.toString() ?? '',
        dueDate: a['dueDate']?.toString() ?? '',
        status: a['status']?.toString() ?? 'not_started',
        isCriticalPath: a['isCriticalPath'] == true,
      );
    }).toList();

    return {
      'controlAccounts': restoredControlAccounts,
      'cbsElements': restoredCbsElements,
      'obsElements': restoredObsElements,
      'workPackages': restoredWorkPackages,
      'scheduleActivities': restoredScheduleActivities,
      'wbsSnapshots': baseline.wbsSnapshots,
      // Aggregate EVM from baseline
      'aggregateBac': baseline.budgetAtCompletion,
      'aggregateCpi': baseline.cpi,
      'aggregateSpi': baseline.spi,
      'aggregateEac': baseline.eac,
    };
  }

  /// Parse a period map (e.g. {'2024-01': 5000.0}) from a JSON snapshot.
  static Map<String, double> _parsePeriodMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(
            k.toString(),
            v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0,
          ));
    }
    return {};
  }
}
