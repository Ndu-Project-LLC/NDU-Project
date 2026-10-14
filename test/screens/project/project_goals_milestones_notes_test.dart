// Lusaka 15: on Planning → Project Goals & Milestones the owner asked for the
// Notes box to stay hidden so the page opens on usable content:
//
//   "we talked about the notes being hidden … it's great to have the notes at
//    the top where it needs to be hidden. So that is not happening now."
//
// The Notes editor is now wrapped in the shared `CollapsibleNotesSection`,
// which starts collapsed. This test guards that it does not silently revert to
// an always-open notes box.

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
import 'package:ndu_project/screens/project/project_framework_next_screen.dart';
import 'package:ndu_project/widgets/collapsible_notes_section.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('Notes section starts collapsed on Goals & Milestones',
      (tester) async {
    tester.view.physicalSize = const Size(2000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = ProjectDataProvider();
    provider.updateProjectData(ProjectDataModel().copyWith(projectId: 'p1'));

    await tester.pumpWidget(
      ProjectDataInherited(
        provider: provider,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<ProjectDataProvider>.value(value: provider),
            ChangeNotifierProvider<WBSProvider>.value(value: WBSProvider()),
            ChangeNotifierProvider<AppContentProvider>.value(
                value: AppContentProvider()),
          ],
          child: const MaterialApp(home: ProjectFrameworkNextScreen()),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // The Notes header is present, and it is the collapsing variant whose
    // default is closed.
    expect(find.byType(CollapsibleNotesSection), findsWidgets);
    final notes = tester.widget<CollapsibleNotesSection>(
      find.byType(CollapsibleNotesSection).first,
    );
    expect(notes.title, 'Notes');
    expect(notes.initiallyExpanded, isFalse);

    await tester.pump(const Duration(seconds: 2));
  });
}
