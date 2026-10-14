// Tests for the shared change-request scope-impact picker.
//
// The owner's ask (voice note, 2026-09-10):
//
//   "on the scope impact, you should be able to choose which scope is attached
//    to that change that you are making. So it's supposed to draw things that
//    are also on the work breakdown structures."
//
// The picker is shared by every change-request entry point — including the
// register's one-tap "Quick CR", which previously offered no scope impact at
// all. These tests hold it to the WBS: the packages offered are the ones the
// WBS module decomposed, and nothing is invented when there is no WBS.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/project_controls/widgets/change_request_scope_picker.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

/// A WBS provider with storage loaded, so `setup()` is no longer gated. The
/// read is real async, so it has to be awaited outside the fake-async zone a
/// `testWidgets` body runs in.
Future<WBSProvider> newWbsProvider(WidgetTester tester) async {
  final provider = WBSProvider();
  await tester.runAsync(() async {
    for (var i = 0; i < 200 && provider.isLoadingFromStorage; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });
  provider.setup(
    projectName: 'Lusaka',
    framework: WBSFramework.waterfallDeliverable,
  );
  return provider;
}

Future<void> pumpPicker(
  WidgetTester tester, {
  required WBSProvider wbs,
  required Set<String> selected,
  required ValueChanged<Set<String>> onChanged,
}) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WBSProvider>.value(value: wbs),
        ChangeNotifierProvider<ProjectDataProvider>(
            create: (_) => ProjectDataProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChangeRequestScopePicker(
              selected: selected,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('offers the packages the WBS actually decomposed', (tester) async {
    final wbs = await newWbsProvider(tester);
    final engineering = wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');
    wbs.addChildNode(engineering, 'Process Design');
    wbs.addChildNode(wbs.wbs!.level0.id, 'Procurement');

    await pumpPicker(
      tester,
      wbs: wbs,
      selected: <String>{},
      onChanged: (_) {},
    );

    expect(find.textContaining('Engineering'), findsWidgets);
    expect(find.textContaining('Process Design'), findsWidgets);
    expect(find.textContaining('Procurement'), findsWidgets);
    // It says where the scope came from.
    expect(find.textContaining('from the WBS'), findsOneWidget);
  });

  testWidgets('invents nothing when there is no WBS to draw on',
      (tester) async {
    final wbs = await newWbsProvider(tester);

    await pumpPicker(
      tester,
      wbs: wbs,
      selected: <String>{},
      onChanged: (_) {},
    );

    expect(
      find.textContaining('No work packages yet'),
      findsOneWidget,
    );
    // No representative stand-in packages.
    expect(find.textContaining('WP-1.1'), findsNothing);
  });

  testWidgets('toggling a package reports the new selection', (tester) async {
    final wbs = await newWbsProvider(tester);
    wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');
    wbs.addChildNode(wbs.wbs!.level0.id, 'Procurement');

    Set<String>? latest;
    await pumpPicker(
      tester,
      wbs: wbs,
      selected: <String>{},
      onChanged: (next) => latest = next,
    );

    await tester.tap(find.byType(FilterChip).first);
    await tester.pump();

    expect(latest, isNotNull);
    expect(latest, hasLength(1));
    expect(latest!.single, contains('Engineering'));
  });

  testWidgets('Select all attaches every WBS package', (tester) async {
    final wbs = await newWbsProvider(tester);
    wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');
    wbs.addChildNode(wbs.wbs!.level0.id, 'Procurement');
    wbs.addChildNode(wbs.wbs!.level0.id, 'Construction');

    Set<String>? latest;
    await pumpPicker(
      tester,
      wbs: wbs,
      selected: <String>{},
      onChanged: (next) => latest = next,
    );

    await tester.tap(find.text('Select all'));
    await tester.pump();

    expect(latest, hasLength(3));
  });

  testWidgets('search narrows the packages on offer', (tester) async {
    final wbs = await newWbsProvider(tester);
    wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');
    wbs.addChildNode(wbs.wbs!.level0.id, 'Procurement');

    await pumpPicker(
      tester,
      wbs: wbs,
      selected: <String>{},
      onChanged: (_) {},
    );

    await tester.enterText(find.byType(TextField), 'procure');
    await tester.pump();

    expect(find.byType(FilterChip), findsOneWidget);
    expect(
      tester.widget<FilterChip>(find.byType(FilterChip)).label,
      isA<Text>().having((t) => t.data, 'label', contains('Procurement')),
    );
  });

  testWidgets('reports how many packages are attached', (tester) async {
    final wbs = await newWbsProvider(tester);
    wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');
    wbs.addChildNode(wbs.wbs!.level0.id, 'Procurement');

    await pumpPicker(
      tester,
      wbs: wbs,
      selected: {'1 — Engineering'},
      onChanged: (_) {},
    );

    expect(find.text('1 selected'), findsOneWidget);
  });
}
