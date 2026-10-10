import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/schedule/providers/schedule_provider.dart';

/// The Schedule used to persist under one global SharedPreferences key, so
/// every project in the workspace read back whichever project's schedule was
/// saved last — activities, basis and reviewers from another project.
///
/// Storage is now scoped per project, and a pre-scoping record is adopted by
/// the project it belongs to exactly once.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ScheduleProvider> provider() async {
    final p = ScheduleProvider();
    await Future<void>.delayed(Duration.zero);
    return p;
  }

  test('switching projects loads that project\'s own schedule', () async {
    final p = await provider();

    p.setup(
      projectId: 'proj-a',
      projectName: 'Chipata Road',
      deliveryModel: 'WATERFALL',
    );
    expect(p.schedule!.projectId, 'proj-a');
    expect(p.schedule!.activities.first.name, 'Chipata Road');

    // Open project B — nothing from A may survive the switch.
    await p.ensureProjectLoaded('proj-b', projectName: 'Lusaka Bridge');
    expect(p.schedule, isNull);
    expect(p.setupComplete, isFalse);

    p.setup(
      projectId: 'proj-b',
      projectName: 'Lusaka Bridge',
      deliveryModel: 'AGILE',
    );
    expect(p.schedule!.projectId, 'proj-b');
    expect(p.schedule!.basis.deliveryModel, 'AGILE');
    expect(p.schedule!.activities.first.name, 'Lusaka Bridge');

    // Back to project A — its own schedule comes back, not B's.
    await p.ensureProjectLoaded('proj-a', projectName: 'Chipata Road');
    expect(p.schedule!.projectId, 'proj-a');
    expect(p.schedule!.projectName, 'Chipata Road');
    expect(p.schedule!.basis.deliveryModel, 'WATERFALL');
    expect(p.schedule!.activities.first.name, 'Chipata Road');
  });

  test('a project with no schedule starts empty instead of borrowing one',
      () async {
    final p = await provider();
    p.setup(
      projectId: 'proj-a',
      projectName: 'Chipata Road',
      deliveryModel: 'WATERFALL',
    );

    await p.ensureProjectLoaded('proj-b', projectName: 'Lusaka Bridge');
    expect(p.schedule, isNull,
        reason: 'project B has no schedule of its own — not project A\'s');
  });

  test('adopts a pre-scoping record once, for the project it belongs to',
      () async {
    SharedPreferences.setMockInitialValues({
      'ndu_schedule_v1': '''
{"state":{"setupComplete":true,"schedule":{"id":"s1","projectId":"default",
"projectName":"Chipata Road","deliveryModel":"WATERFALL","status":"draft",
"isLocked":false,"basis":{"deliveryModel":"WATERFALL"},
"activities":[{"id":"a0","level":0,"code":"0","name":"Chipata Road",
"type":"summary","domain":"engineering","dependencies":[],"aiGenerated":false,
"children":[]}]}}}
''',
    });

    final p = await provider();
    await p.ensureProjectLoaded('proj-a', projectName: 'Chipata Road');
    expect(p.schedule, isNotNull, reason: 'the legacy record is adopted');
    expect(p.schedule!.projectId, 'proj-a',
        reason: 'and re-homed onto the project that owns it');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ndu_schedule_v1'), isNull,
        reason: 'the legacy entry is claimed, so it can never be adopted again');
    expect(prefs.getString('ndu_schedule_v2_project_proj-a'), isNotNull);

    // A different project must NOT pick it up.
    final other = ScheduleProvider();
    await Future<void>.delayed(Duration.zero);
    await other.ensureProjectLoaded('proj-b', projectName: 'Lusaka Bridge');
    expect(other.schedule, isNull,
        reason: 'another project never inherits the legacy record');
  });
}
