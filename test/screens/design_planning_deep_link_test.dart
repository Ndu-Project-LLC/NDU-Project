// Lusaka 14: clicking the sidebar's "Design Planning - Work Packages" entry
// opened the Design Planning page but left the user at the top, so they had to
// scroll to the last section to find the tab they had just clicked. The screen
// already accepted `initialSectionId` and expanded that section; it just never
// scrolled to it.

// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/design_planning_screen.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

const double _viewportWidth = 1400;
const double _viewportHeight = 700;

/// Where the page body starts, i.e. just right of the inline sidebar. Any
/// matching text left of this belongs to the sidebar, not the section.
const double _pageLeft = 330;

/// The Work Packages section card title. The sidebar entry is labelled "Work
/// Packages", so the finder is deliberately the page's own title.
const String _sectionTitle = 'Design Work Packages';

Future<void> _pumpScreen(WidgetTester tester, {String? initialSectionId}) async {
  tester.view.physicalSize = const Size(_viewportWidth, _viewportHeight);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final provider = ProjectDataProvider();
  provider.updateProjectData(ProjectDataModel(
    projectName: 'Agility Platform',
    solutionTitle: 'Delivery platform',
  ));

  await tester.pumpWidget(
    ProjectDataInherited(
      provider: provider,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<ProjectDataProvider>.value(value: provider),
          ChangeNotifierProvider<WBSProvider>.value(value: WBSProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DesignPlanningScreen(initialSectionId: initialSectionId),
          ),
        ),
      ),
    ),
  );
  // The deep-link scroll is animated (40ms + 320ms + 260ms + 180ms) and the
  // provider debounces a 2s auto-save, so pump fixed frames past both instead
  // of settling on an animation.
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  await tester.pump(const Duration(seconds: 1));
}

/// The y positions of the section title laid out inside the page viewport
/// (excluding the sidebar's own label).
List<double> _sectionY(WidgetTester tester) {
  final ys = <double>[];
  for (final element in find.text(_sectionTitle).evaluate()) {
    final box = element.renderObject as RenderBox?;
    if (box == null || !box.hasSize) continue;
    final origin = box.localToGlobal(Offset.zero);
    if (origin.dx < _pageLeft) continue;
    if (origin.dy < 0 || origin.dy > _viewportHeight) continue;
    ys.add(origin.dy);
  }
  return ys;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('deep-linking to Work Packages scrolls that section into view',
      (tester) async {
    await _pumpScreen(tester, initialSectionId: 'work_packages');

    expect(_sectionY(tester), isNotEmpty,
        reason: 'the Work Packages section is not inside the viewport after a '
            'sidebar deep-link — the page opened at the top');
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a deep-link the page still opens at the top',
      (tester) async {
    await _pumpScreen(tester);

    expect(_sectionY(tester), isEmpty,
        reason: 'the last section should not be on screen when nothing was '
            'deep-linked');
    expect(tester.takeException(), isNull);
  });
}
