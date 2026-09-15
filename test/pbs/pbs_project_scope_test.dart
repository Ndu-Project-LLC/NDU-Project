import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/pbs/providers/pbs_provider.dart';

/// The PBS used to persist under one global SharedPreferences key — and the
/// module screen always initialized it as `('default', 'Project Products')` —
/// so every project in the workspace read back whichever product breakdown was
/// created last.
///
/// Storage is now scoped per project, and a pre-scoping record is adopted by
/// the project it belongs to exactly once.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<PBSProvider> provider() async {
    final p = PBSProvider();
    await Future<void>.delayed(Duration.zero);
    return p;
  }

  test('switching projects loads that project\'s own PBS', () async {
    final p = await provider();

    p.initPBS('proj-a', 'Chipata Road');
    expect(p.pbs!.projectId, 'proj-a');
    expect(p.pbs!.root.name, 'Chipata Road');

    // Open project B — nothing from A may survive the switch.
    await p.ensureProjectLoaded('proj-b', projectName: 'Lusaka Bridge');
    expect(p.pbs, isNull);
    expect(p.setupComplete, isFalse);
    expect(p.activeProjectId, 'proj-b');

    p.initPBS('proj-b', 'Lusaka Bridge');
    expect(p.pbs!.root.name, 'Lusaka Bridge');

    // Back to project A — its own PBS comes back, not B's.
    await p.ensureProjectLoaded('proj-a', projectName: 'Chipata Road');
    expect(p.pbs!.projectId, 'proj-a');
    expect(p.pbs!.projectName, 'Chipata Road');
    expect(p.pbs!.root.name, 'Chipata Road');
  });

  test('a project with no PBS starts empty instead of borrowing one',
      () async {
    final p = await provider();
    p.initPBS('proj-a', 'Chipata Road');

    await p.ensureProjectLoaded('proj-b', projectName: 'Lusaka Bridge');
    expect(p.pbs, isNull,
        reason: 'project B has no PBS of its own — not project A\'s');
    expect(p.setupComplete, isFalse);
  });

  test('an empty project id scopes to default, never another project',
      () async {
    final p = await provider();
    p.initPBS('proj-a', 'Chipata Road');

    await p.ensureProjectLoaded('');
    expect(p.activeProjectId, 'default');
    expect(p.pbs, isNull);
  });

  test('adopts a pre-scoping record once, for the project it belongs to',
      () async {
    // What the old global key looked like: the screen always wrote
    // `projectId: 'default'` plus the project name it was showing.
    SharedPreferences.setMockInitialValues({
      'ndu_pbs_v1': '''
{"state":{"setupComplete":true,"pbs":{"id":"p1","projectId":"default",
"projectName":"Chipata Road","root":{"id":"root","code":"PBS.0",
"name":"Chipata Road","productType":"system","status":"planned"}}}}
''',
    });

    final p = await provider();
    await p.ensureProjectLoaded('proj-a', projectName: 'Chipata Road');
    expect(p.pbs, isNotNull, reason: 'the legacy record is adopted');
    expect(p.pbs!.projectId, 'proj-a',
        reason: 'and re-homed onto the project that owns it');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ndu_pbs_v1'), isNull,
        reason: 'the legacy entry is claimed, so it can never be adopted again');
    expect(prefs.getString('ndu_pbs_v2_project_proj-a'), isNotNull);

    // A different project must NOT pick it up.
    final other = PBSProvider();
    await Future<void>.delayed(Duration.zero);
    await other.ensureProjectLoaded('proj-b', projectName: 'Lusaka Bridge');
    expect(other.pbs, isNull,
        reason: 'another project never inherits the legacy record');
  });

  test('does not adopt a legacy record that names a different project',
      () async {
    SharedPreferences.setMockInitialValues({
      'ndu_pbs_v1': '''
{"state":{"setupComplete":true,"pbs":{"id":"p1","projectId":"proj-other",
"projectName":"Somewhere Else","root":{"id":"root","code":"PBS.0",
"name":"Somewhere Else","productType":"system","status":"planned"}}}}
''',
    });

    final p = await provider();
    await p.ensureProjectLoaded('proj-a', projectName: 'Chipata Road');
    expect(p.pbs, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ndu_pbs_v1'), isNotNull,
        reason: 'an unattributable record is left for its own project');
  });
}
