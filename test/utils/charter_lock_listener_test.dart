// The Front End Planning Requirements page used to read the charter lock with
// `ProjectDataHelper.isCharterApproved(context, listen: true)`. That subscribed
// the whole page — a large editable requirements table — to every
// ProjectDataProvider notification, and the provider notifies on each autosave
// debounce (and again when the Firestore write lands). Every one of those
// notifications rebuilt the entire table, which is the lag felt while scrolling
// and while typing.
//
// The page now reads the lock through a `Selector`, so it rebuilds only when the
// lock itself flips. These tests pin both halves: the helper's semantics, and
// the rebuild behaviour of each subscription shape.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

void main() {
  group('isCharterApprovedIn', () {
    test('is false while the charter is unapproved', () {
      expect(
        ProjectDataHelper.isCharterApprovedIn(ProjectDataModel()),
        isFalse,
      );
    });

    test('is true once frontEndPlanning.charterApproved is set', () {
      expect(
        ProjectDataHelper.isCharterApprovedIn(
          ProjectDataModel(
            frontEndPlanning: FrontEndPlanningData(charterApproved: true),
          ),
        ),
        isTrue,
      );
    });

    test('is true when only the legacy charterApprovalDate is set', () {
      expect(
        ProjectDataHelper.isCharterApprovedIn(
          ProjectDataModel(charterApprovalDate: DateTime(2026, 9, 16)),
        ),
        isTrue,
      );
    });
  });

  group('reading the charter lock', () {
    testWidgets('listening rebuilds the page for every provider notification',
        (tester) async {
      final provider = ProjectDataProvider();
      var builds = 0;

      await tester.pumpWidget(
        ChangeNotifierProvider<ProjectDataProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                builds++;
                ProjectDataHelper.isCharterApproved(context, listen: true);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(builds, 1);

      // An edit on an unrelated field — what an autosave debounce does while
      // the user is scrolling or typing elsewhere on the project.
      provider.updateField((data) => data.copyWith(projectName: 'Unrelated'));
      await tester.pump();

      expect(
        builds,
        2,
        reason: 'the listening shape rebuilds on any provider notification',
      );

      // Unmount before disposing so the widget drops its listener first, and
      // the autosave debounce timer the edit scheduled is cancelled.
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });

    testWidgets('a Selector rebuilds only when the lock itself flips',
        (tester) async {
      final provider = ProjectDataProvider();
      var builds = 0;

      await tester.pumpWidget(
        ChangeNotifierProvider<ProjectDataProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Selector<ProjectDataProvider, bool>(
              selector: (_, provider) =>
                  ProjectDataHelper.isCharterApprovedIn(provider.projectData),
              builder: (context, locked, _) {
                builds++;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(builds, 1);

      provider.updateField((data) => data.copyWith(projectName: 'Unrelated'));
      await tester.pump();
      expect(
        builds,
        1,
        reason: 'an unrelated notification must not rebuild the page',
      );
      // Still no rebuild after the autosave debounce window elapses.
      await tester.pump(const Duration(seconds: 1));
      expect(builds, 1);

      // Approving the charter is the one change this page does react to.
      provider.updateField(
        (data) => data.copyWith(
          frontEndPlanning: data.frontEndPlanning.copyWith(
            charterApproved: true,
          ),
        ),
      );
      await tester.pump();
      expect(builds, 2);

      // Unmount before disposing so the widget drops its listener first, and
      // the autosave debounce timer the edits scheduled is cancelled.
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });
  });
}
