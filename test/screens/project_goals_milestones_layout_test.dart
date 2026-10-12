// Lusaka 15: the Goals & Milestones landing page was reordered, the milestones
// area became tabbed and readable, the goals stopped being creatable here, and
// the milestone list is validated before it is mapped.
//
//   "I think this project goals has to be at the top. … And then the milestones
//    has to be under it. And then the mapping has to happen."
//   "I think we need tabs here."
//   "The milestone timeline … it should be chronological … starting from
//    December, 2026. This is the first milestone."
//   "they should not be able to add any goal here. … The WBS is the source of
//    truth for the project goals because they are just the second layer of the
//    WBS."
//   "validate the milestones … Before they then go to the goals and then they
//    should be able to open each goal up and map the applicable milestones."
//
// Firebase is mocked because the page's header reads the signed-in user.

// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/app_content_provider.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/project_framework_next_screen.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';

/// Milestones deliberately not in date order, using the loose formats the FEP
/// form accepts ("e.g. 2026-09-15 or Q3 2026").
const List<String> _chronologicalNames = <String>[
  'Kickoff', // 2026-09-15
  'Design freeze', // December 2026
  'Phase 2 review', // 2027-02-15
  'Undated check', // no readable date → last
];

List<Milestone> _milestones() => <Milestone>[
      Milestone(id: 'm3', name: 'Phase 2 review', dueDate: '2027-02-15'),
      Milestone(id: 'm2', name: 'Design freeze', dueDate: 'December 2026'),
      Milestone(id: 'm1', name: 'Kickoff', dueDate: '2026-09-15'),
      Milestone(id: 'm4', name: 'Undated check', dueDate: 'To be confirmed'),
    ];

Future<void> _pumpScreen(
  WidgetTester tester, {
  bool withWbsGoals = true,
  WBSProvider? wbsProvider,
  List<PlanningGoal>? planningGoals,
  List<Milestone>? milestones,
  bool confirmMilestones = false,
}) async {
  tester.view.physicalSize = const Size(2200, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final model = ProjectDataModel().copyWith(projectId: 'p1');
  if (withWbsGoals) {
    // Level 1 of the WBS *is* the goal list.
    model.wbsTree = <WorkItem>[
      WorkItem(id: 'n1', title: 'WBS goal one', wbsCode: 'G1'),
      WorkItem(id: 'n2', title: 'WBS goal two', wbsCode: 'G2'),
    ];
  }
  model.keyMilestones = milestones ?? _milestones();
  if (planningGoals != null) model.planningGoals = planningGoals;

  final provider = ProjectDataProvider();
  provider.updateProjectData(model);

  await tester.pumpWidget(
    ProjectDataInherited(
      provider: provider,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<ProjectDataProvider>.value(value: provider),
          ChangeNotifierProvider<WBSProvider>.value(
              value: wbsProvider ?? WBSProvider()),
          ChangeNotifierProvider<AppContentProvider>.value(
              value: AppContentProvider()),
        ],
        child: const MaterialApp(home: ProjectFrameworkNextScreen()),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }

  if (confirmMilestones) await _confirmMilestones(tester);
}

/// Walks the validate step, which the mapping sits behind.
Future<void> _confirmMilestones(WidgetTester tester) async {
  final button = find.text('Confirm milestone list');
  expect(button, findsOneWidget, reason: 'the validate step should be offered');
  // The step sits under the milestone table, which can push it past the
  // viewport — bring it into view so the tap actually lands on it.
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  expect(find.text('Confirm milestone list'), findsNothing,
      reason: 'the tap must have confirmed the list, not missed it');
}

double _topOf(WidgetTester tester, String text) {
  final finder = find.text(text);
  expect(finder, findsWidgets, reason: '"$text" should be on the page');
  return tester.getTopLeft(finder.first).dy;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('lands on Project Goals, then the milestones, then the mapping',
      (tester) async {
    await _pumpScreen(tester, confirmMilestones: true);

    // A unique anchor inside each of the three sections.
    final goals = _topOf(tester, 'WBS goal one');
    final milestones = _topOf(tester, 'Milestones');
    final mapping = _topOf(tester, 'Project Goals → Milestones');

    expect(goals, lessThan(milestones),
        reason: 'Project Goals must come before the milestone table');
    expect(milestones, lessThan(mapping),
        reason: 'the milestone table must come before the mapping');

    // The mapping itself (each goal's milestone picker) sits in the mapping
    // section, not inside the goal cards above.
    expect(find.text('Mapped FEP Milestones'), findsWidgets);
    expect(_topOf(tester, 'Mapped FEP Milestones'), greaterThan(milestones));

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('goals are read-only and cannot be created on this page',
      (tester) async {
    await _pumpScreen(tester);

    // The old create affordance is gone; the WBS is offered instead.
    expect(find.text('Add Goal'), findsNothing);
    expect(find.text('Open Work Breakdown Structure'), findsOneWidget);
    expect(
      find.textContaining('These goals come from the Work Breakdown Structure'),
      findsOneWidget,
    );

    // The goal title is a read-only field, not something to type a new goal
    // into.
    final titleField = tester.widget<VoiceTextField>(
      find
          .ancestor(
            of: find.text('WBS goal one').first,
            matching: find.byType(VoiceTextField),
          )
          .first,
    );
    expect(titleField.readOnly, isTrue);
    expect(titleField.enabled, isFalse);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('with no WBS goals the page points at the WBS, not an add form',
      (tester) async {
    await _pumpScreen(tester, withWbsGoals: false);

    expect(find.text('Add Goal'), findsNothing);
    expect(find.textContaining('No goals are defined yet'), findsOneWidget);
    expect(find.text('Open Work Breakdown Structure'), findsOneWidget);
    expect(find.textContaining('No goals to map yet'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('goals come from the live WBS when it has Level 1 items',
      (tester) async {
    final wbsProvider = WBSProvider();
    // The provider reads its storage asynchronously and setup() refuses a WBS
    // until that has settled. runAsync lets that real work finish without
    // mounting (and then swapping out) a throwaway widget tree.
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && wbsProvider.isLoadingFromStorage; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    expect(wbsProvider.isLoadingFromStorage, isFalse,
        reason: 'the WBS provider must finish its storage load before setup()');

    wbsProvider.setup(
      projectName: 'Live WBS project',
      framework: WBSFramework.waterfallDeliverable,
    );
    final rootId = wbsProvider.wbs!.level0.id;
    wbsProvider.addChildNode(rootId, 'Live goal A');
    wbsProvider.addChildNode(rootId, 'Live goal B');

    // The page reads the live WBS, not the saved tree.
    await _pumpScreen(
      tester,
      withWbsGoals: false,
      wbsProvider: wbsProvider,
      confirmMilestones: true,
    );

    expect(find.text('Live goal A'), findsWidgets);
    expect(find.text('Live goal B'), findsWidgets);
    // ... and the WBS items are the goals the mapping is offered for.
    expect(find.text('Mapped FEP Milestones'), findsNWidgets(2));
    expect(find.text('Add Goal'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('an Agile WBS calls its Level-1 items epics, not goals',
      (tester) async {
    // "For waterfall, we are calling them goals … for agile … that is the
    // epic." The page follows the WBS's methodology, so an Agile project
    // never reads "goals" here.
    final wbsProvider = WBSProvider();
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && wbsProvider.isLoadingFromStorage; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    wbsProvider.setup(
      projectName: 'Agile project',
      framework: WBSFramework.agile,
      methodology: ProjectMethodology.agile,
    );
    final rootId = wbsProvider.wbs!.level0.id;
    wbsProvider.addChildNode(rootId, 'Epic alpha');

    await _pumpScreen(
      tester,
      withWbsGoals: false,
      wbsProvider: wbsProvider,
      confirmMilestones: true,
    );

    expect(
      find.textContaining(
        'Project Epics (The second level of the Work Breakdown Structure)',
        findRichText: true,
      ),
      findsOneWidget,
      reason: 'the page heading follows the WBS methodology',
    );
    expect(find.text('Epic alpha'), findsWidgets);
    expect(find.text('Epic 1'), findsWidgets);
    expect(find.text('Goal 1'), findsNothing);
    expect(find.text('Project Epics → Milestones'), findsOneWidget);
    expect(find.text('Mapped Epics'), findsOneWidget);
    expect(find.textContaining('These epics come from'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a goal added to the WBS while the page is open appears',
      (tester) async {
    final wbsProvider = WBSProvider();
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && wbsProvider.isLoadingFromStorage; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    wbsProvider.setup(
      projectName: 'Live WBS project',
      framework: WBSFramework.waterfallDeliverable,
    );
    final rootId = wbsProvider.wbs!.level0.id;
    wbsProvider.addChildNode(rootId, 'First live goal');

    await _pumpScreen(
      tester,
      withWbsGoals: false,
      wbsProvider: wbsProvider,
      confirmMilestones: true,
    );
    expect(find.text('First live goal'), findsWidgets);
    expect(find.text('Late goal'), findsNothing);

    // The WBS changes underneath the page — no reload.
    wbsProvider.addChildNode(rootId, 'Late goal');
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Late goal'), findsWidgets,
        reason: 'the goals are the WBS, so a new one shows up live');

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the milestone list is validated before the mapping opens',
      (tester) async {
    await _pumpScreen(tester);

    // Not validated yet: the mapping is gated.
    expect(find.text('Confirm milestone list'), findsOneWidget);
    expect(find.text('Mapped FEP Milestones'), findsNothing);
    expect(find.textContaining('Confirm the milestone list in the Milestones'),
        findsOneWidget);

    await _confirmMilestones(tester);

    // Confirmed: the mapping opens, and the step says so.
    expect(find.text('Mapped FEP Milestones'), findsWidgets);
    expect(find.text('Change milestones'), findsOneWidget);
    expect(
      find.textContaining('Milestone list validated'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a mapping survives the goal being re-created in the WBS',
      (tester) async {
    // The goal was mapped when it had a different WBS node id; the list it is
    // matched against carries the WBS code.
    await _pumpScreen(
      tester,
      milestones: <Milestone>[
        Milestone(id: 'm1', name: 'Kickoff', dueDate: '2026-09-15'),
        Milestone(id: 'm2', name: 'Design freeze', dueDate: 'December 2026'),
      ],
      planningGoals: <PlanningGoal>[
        PlanningGoal(
          goalNumber: 1,
          id: 'old-node-id',
          title: 'Old goal title',
          wbsCode: 'G1',
          milestoneIds: const ['m1'],
        ),
      ],
      confirmMilestones: true,
    );

    await tester.tap(find.text('Timeline'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Kickoff is still mapped to the (renamed, re-created) goal.
    expect(find.text('1 goal'), findsOneWidget);
    expect(find.text('Unmapped'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the milestones section is tabbed and lists the table by default',
      (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Table'), findsOneWidget);
    expect(find.text('Timeline'), findsOneWidget);

    // The table view is the default: its column headers are showing.
    expect(find.text('Mapped Goals'), findsOneWidget);

    // ... and its rows are chronological, undated last.
    final ys = _chronologicalNames
        .map((name) => _topOf(tester, name))
        .toList(growable: false);
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i], greaterThan(ys[i - 1]),
          reason: '${_chronologicalNames[i]} should follow '
              '${_chronologicalNames[i - 1]}');
    }

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the Timeline tab is chronological and says so', (tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('Timeline'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The table is replaced by the timeline, which labels its order, count and
    // date range.
    expect(find.text('Mapped Goals'), findsNothing);
    expect(find.textContaining('Earliest first'), findsOneWidget);
    expect(find.textContaining('4 milestones'), findsOneWidget);

    final xs = _chronologicalNames
        .map((name) => tester.getTopLeft(find.text(name).first).dx)
        .toList(growable: false);
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i], greaterThan(xs[i - 1]),
          reason: '${_chronologicalNames[i]} should sit to the right of '
              '${_chronologicalNames[i - 1]}');
    }

    await tester.pump(const Duration(seconds: 2));
  });
}
