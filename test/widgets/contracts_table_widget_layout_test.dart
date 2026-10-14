import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/services/contract_service.dart';
import 'package:ndu_project/widgets/contracts_table_widget.dart';

const String _longName =
    'Commissioning and Handover Contractor for the Northern Substation Expansion Programme';
const String _longType =
    'Lump Sum (Fixed Price) Contract with Performance Incentives and Milestones';

ContractModel _contract() => ContractModel(
      id: 'c1',
      projectId: 'p1',
      name: _longName,
      description: '',
      contractType: _longType,
      paymentType: '',
      status: 'Draft',
      estimatedValue: 185000,
      startDate: DateTime(2026, 9, 24),
      endDate: DateTime(2027, 4, 23),
      scope: '',
      discipline: '',
      notes: '',
      createdById: '',
      createdByEmail: '',
      createdByName: '',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: 760,
            child: ContractsTableWidget(
              contracts: [_contract()],
              onContractUpdated: (_) {},
              onContractDeleted: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('long contract names and types wrap instead of truncating',
      (tester) async {
    await _pump(tester);

    // The name has no line limit, so it is checked by its rendered height.
    // Any overflow would fail the test separately.
    final name = tester.renderObject<RenderParagraph>(find.text(_longName));
    expect(name.size.height, greaterThan(20),
        reason: 'the name should span more than one line');

    // The dropdown text has no line limit, so it is checked by its height.
    final type = tester.renderObject<RenderParagraph>(find.text(_longType));
    expect(type.size.height, greaterThan(20),
        reason: 'the contract type should span more than one line');
  });

  testWidgets('header titles are centred over their body columns',
      (tester) async {
    await _pump(tester);

    // Each pair is a header title and the body value in the same column.
    final pairs = <String, String>{
      'Status': 'Draft',
      'Expiry': 'Apr 23, 2027',
      'Total Value': '\$185K',
    };
    for (final entry in pairs.entries) {
      final headerX = tester.getCenter(find.text(entry.key)).dx;
      final bodyX = tester.getCenter(find.text(entry.value)).dx;
      expect(headerX, closeTo(bodyX, 1.0),
          reason: '"${entry.key}" should sit over "${entry.value}"');
    }
  });
}
