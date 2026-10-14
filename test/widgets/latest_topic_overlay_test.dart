import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

void main() {
  test('planning goals supersede initiation goals in the overlay', () {
    final data = ProjectDataModel()
      ..projectGoals = [
        ProjectGoal(name: 'Cut commute', description: 'old initiation framing'),
      ]
      ..planningGoals = [
        PlanningGoal(
          goalNumber: 1,
          title: 'Deliver bus corridor',
          description: 'planning version of the goal',
          targetYear: '2027',
          priority: 'High',
          milestoneIds: const [],
          milestones: const [],
        ),
      ];

    final overlay = ProjectDataHelper.buildLatestTopicOverlay(data);

    expect(overlay, contains('Goals (latest: Planning)'));
    expect(overlay, contains('Deliver bus corridor'));
    // The stale initiation copy must NOT be re-emitted as current.
    expect(overlay, isNot(contains('old initiation framing')));
  });

  test('initiation-only goal stays as the latest version', () {
    final data = ProjectDataModel()
      ..projectGoals = [
        ProjectGoal(name: 'Cut commute', description: 'only ever in initiation'),
      ]
      ..planningGoals = <PlanningGoal>[];

    final overlay = ProjectDataHelper.buildLatestTopicOverlay(data);

    expect(overlay, contains('Goals (latest: Initiation)'));
    expect(overlay, contains('only ever in initiation'));
  });

  test('no goals at all → empty overlay (no invented topics)', () {
    final data = ProjectDataModel()
      ..projectGoals = <ProjectGoal>[]
      ..planningGoals = <PlanningGoal>[];
    expect(ProjectDataHelper.buildLatestTopicOverlay(data), isEmpty);
  });
}
