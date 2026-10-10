// Lusaka 14: a requirement also records the codes / standards it must satisfy
// so the Design → Work Packages traceability can list them. The field must
// survive a JSON round-trip (Firestore / provider persistence) and default to
// empty on records written before it existed.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/project_data_model.dart';

void main() {
  test('codesStandards round-trips through toJson/fromJson', () {
    final item = RequirementItem(
      description: 'Encrypt data at rest',
      wbsGoalId: 'G1',
      wbsElementIds: const ['G1.1'],
      codesStandards: const ['ISO 9001', 'ISO/IEC 25010'],
    );

    final restored = RequirementItem.fromJson(item.toJson());

    expect(restored.codesStandards, ['ISO 9001', 'ISO/IEC 25010']);
    expect(restored.wbsGoalId, 'G1');
    expect(restored.wbsElementIds, ['G1.1']);
  });

  test('codesStandards defaults to empty for legacy records', () {
    expect(RequirementItem().codesStandards, isEmpty);
    expect(RequirementItem.fromJson(const {}).codesStandards, isEmpty);
  });
}
