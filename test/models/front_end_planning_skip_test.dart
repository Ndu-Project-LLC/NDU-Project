import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/models/project_data_model.dart';

void main() {
  group('FrontEndPlanningData skip flags', () {
    test('both skip flags default to false', () {
      final data = FrontEndPlanningData();

      expect(data.skippedBusinessCase, isFalse);
      expect(data.skippedFrontEndPlanning, isFalse);
    });

    test('copyWith can mark FEP as skipped without disturbing the BC flag', () {
      final data = FrontEndPlanningData(
        skippedBusinessCase: true,
      ).copyWith(skippedFrontEndPlanning: true);

      expect(data.skippedBusinessCase, isTrue);
      expect(data.skippedFrontEndPlanning, isTrue);
    });

    test('copyWith leaves the FEP flag untouched when it is not passed', () {
      final data = FrontEndPlanningData(
        skippedFrontEndPlanning: true,
      ).copyWith(summary: 'Charter objective');

      expect(data.skippedFrontEndPlanning, isTrue);
      expect(data.summary, 'Charter objective');
    });

    test('toJson emits the FEP skip flag', () {
      final json = FrontEndPlanningData(
        skippedBusinessCase: true,
        skippedFrontEndPlanning: true,
      ).toJson();

      expect(json['skippedBusinessCase'], isTrue);
      expect(json['skippedFrontEndPlanning'], isTrue);
    });

    test('fromJson reads the FEP skip flag', () {
      final data = FrontEndPlanningData.fromJson({
        'skippedBusinessCase': true,
        'skippedFrontEndPlanning': true,
      });

      expect(data.skippedBusinessCase, isTrue);
      expect(data.skippedFrontEndPlanning, isTrue);
    });

    test('fromJson defaults the flags to false when absent', () {
      final data = FrontEndPlanningData.fromJson(<String, dynamic>{});

      expect(data.skippedBusinessCase, isFalse);
      expect(data.skippedFrontEndPlanning, isFalse);
    });

    test('a skipped-both project survives a JSON round trip', () {
      final original = FrontEndPlanningData(
        skippedBusinessCase: true,
        skippedFrontEndPlanning: true,
        businessCaseLocked: true,
        detailsConfirmed: true,
        summary: 'Replace the manual register',
        requirements: 'In scope: reconciliation',
        requirementsPlan: 'Deliver reconciled ledger',
      );

      final restored = FrontEndPlanningData.fromJson(original.toJson());

      expect(restored.skippedFrontEndPlanning, isTrue);
      expect(restored.skippedBusinessCase, isTrue);
      expect(restored.businessCaseLocked, isTrue);
      expect(restored.detailsConfirmed, isTrue);
      expect(restored.summary, 'Replace the manual register');
      expect(restored.requirements, 'In scope: reconciliation');
      expect(restored.requirementsPlan, 'Deliver reconciled ledger');
    });
  });
}
