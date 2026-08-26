import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/schedule/screens/schedule_module_screen.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ScheduleProvider>(
              create: (_) => ScheduleProvider()),
          ChangeNotifierProvider<WBSProvider>(create: (_) => WBSProvider()),
          ChangeNotifierProvider<CostEstimateProvider>(
              create: (_) => CostEstimateProvider()),
          ChangeNotifierProvider<ProjectDataProvider>(
              create: (_) => ProjectDataProvider()),
        ],
        child: const MaterialApp(home: ScheduleModuleScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
      'Schedule module screen renders tab content while navigator is collapsed',
      (tester) async {
    await pumpScreen(tester);

    // Navigator header visible and collapsed…
    expect(find.text('Schedule Navigation'), findsOneWidget);

    // …and the Builder tab content must be rendered below it.
    expect(find.byType(ScheduleModuleScreen), findsOneWidget);
    expect(find.text('Loading schedule…'), findsNothing);

    // The Builder tab's hero band should be present.
    expect(
      find.textContaining('SCHEDULE'),
      findsWidgets,
      reason: 'Builder tab content should render below the collapsed navigator',
    );
  });
}
