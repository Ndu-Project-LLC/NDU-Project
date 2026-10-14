import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/risk/risk_assessment_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Risk planning is split into four tabs', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProjectDataProvider>(
        create: (_) => ProjectDataProvider(),
        child: const MaterialApp(home: RiskAssessmentScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(TabBarView), findsOneWidget);
    for (final label in [
      'Overview',
      'Risk Log',
      'Mitigation & Sign-off',
      'Risk Register',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    // The Overview tab is shown first and carries the top-risks card.
    expect(find.text('Top Risks & Mitigation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
