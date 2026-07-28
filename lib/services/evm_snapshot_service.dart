import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ndu_project/models/evm_snapshot_model.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/control_account_service.dart';
import 'package:ndu_project/services/forecast_service.dart';

class EvmSnapshotService {
  static CollectionReference<Map<String, dynamic>>? _tryCollection() {
    try {
      return FirebaseFirestore.instance.collection('evm_snapshots');
    } catch (e, st) {
      debugPrint('EvmSnapshotService: Firestore not ready ($e)\n$st');
      return null;
    }
  }

  static CollectionReference<Map<String, dynamic>> _requireCollection() {
    final col = _tryCollection();
    if (col == null) throw StateError('Firestore is not initialized');
    return col;
  }

  /// Compute and persist an EVM snapshot from current project data.
  static Future<String> captureSnapshot({
    required String projectId,
    required ProjectDataModel data,
    String source = 'manual',
  }) async {
    final workPackages = data.workPackages;

    final double bac =
        workPackages.fold<double>(0, (s, wp) => s + wp.budgetedCost);
    final double ac =
        workPackages.fold<double>(0, (s, wp) => s + wp.actualCost);

    // ── P1.5 Fix: Use standard EV = percentComplete × budgetedCost ──
    // Previously used actualCost/budgetedCost which conflates cost with value.
    double ev = 0;
    for (final wp in workPackages) {
      if (wp.status == 'complete') {
        ev += wp.budgetedCost;
      } else if (wp.status == 'in_progress') {
        if (wp.percentComplete > 0) {
          ev += wp.percentComplete.clamp(0, 1) * wp.budgetedCost;
        } else {
          // 50/50 rule: 50% earned when started
          ev += wp.budgetedCost * 0.5;
        }
      }
    }

    final double pv = ControlAccountService.computeAggregatePlannedValueToDate(data.controlAccounts);

    final forecast = ForecastService.calculateEac(
      bac: bac,
      ev: ev,
      ac: ac,
      pv: pv,
    );

    final totalActivities = data.scheduleActivities.length;
    final completedActivities =
        data.scheduleActivities.where((a) => a.status == 'complete').length;

    final snapshot = EvmSnapshot(
      snapshotDate: DateTime.now(),
      projectId: projectId,
      budgetAtCompletion: bac,
      plannedValue: pv,
      earnedValue: ev,
      actualCost: ac,
      cpi: forecast.eac > 0 ? ev / ac : 1.0,
      spi: pv > 0 ? ev / pv : 1.0,
      cv: ev - ac,
      sv: ev - pv,
      eac: forecast.eac,
      etc: forecast.etc,
      vac: forecast.vac,
      tcpii: forecast.tcpii,
      completedActivities: completedActivities,
      totalActivities: totalActivities,
      source: source,
    );

    await _requireCollection().add({
      ...snapshot.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return snapshot.id;
  }

  /// Stream EVM snapshots for trend charts (most recent first).
  static Stream<List<EvmSnapshot>> streamSnapshots(String projectId) {
    final col = _tryCollection();
    if (col == null) return Stream.value([]);

    return col
        .where('projectId', isEqualTo: projectId)
        .orderBy('snapshotDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => EvmSnapshot.fromJson(doc.data()))
            .toList());
  }

}
