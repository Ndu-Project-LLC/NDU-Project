import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';

/// The Cost Estimate used to persist under one global SharedPreferences key, so
/// every project in the workspace read back whichever project's estimate was
/// saved last — cost lines, BOE and stakeholders from another project.
///
/// Storage is now scoped per project, and a pre-scoping record is adopted by
/// the project it belongs to exactly once.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// A fresh provider already bootstrapped against the mock preferences.
  Future<CostEstimateProvider> provider() async {
    final p = CostEstimateProvider();
    // Let the constructor's bootstrap read settle.
    await Future<void>.delayed(Duration.zero);
    return p;
  }

  void setupFor(CostEstimateProvider p, String projectId, String name) {
    p.setup(
      projectId: projectId,
      projectName: name,
      className: EstimateClass.class3,
      deliveryModel: DeliveryModel.waterfall,
    );
  }

  void addLine(CostEstimateProvider p, String description, double total) {
    p.addLine(CostLine(
      id: 'line_${description.hashCode}',
      category: CostCategory.materials,
      subCategory: 'Test',
      description: description,
      total: total,
      inSchedule: false,
      basisSource: CostSourceType.historical,
      aiGenerated: false,
    ));
  }

  List<String> descriptions(CostEstimateProvider p) =>
      p.estimate?.lines.map((l) => l.description).toList() ?? const [];

  test('switching projects loads that project\'s own estimate', () async {
    final p = await provider();

    setupFor(p, 'proj-a', 'Chipata Road');
    addLine(p, 'Road works', 480000);
    expect(p.estimate!.projectId, 'proj-a');
    expect(descriptions(p), ['Road works']);

    // Open project B — nothing from A may survive the switch.
    await p.ensureProjectLoaded('proj-b', projectName: 'Lusaka Bridge');
    expect(p.estimate, isNull);
    expect(p.setupComplete, isFalse);
    expect(p.activeProjectId, 'proj-b');

    setupFor(p, 'proj-b', 'Lusaka Bridge');
    addLine(p, 'Bridge deck', 900000);
    expect(descriptions(p), ['Bridge deck']);

    // Back to project A — its own estimate comes back, not B's.
    await p.ensureProjectLoaded('proj-a', projectName: 'Chipata Road');
    expect(p.estimate!.projectId, 'proj-a');
    expect(p.estimate!.projectName, 'Chipata Road');
    expect(descriptions(p), ['Road works']);
    expect(
      p.estimate!.totals.costBaseline,
      480000,
      reason: 'project A keeps only its own cost lines',
    );
  });

  test('a project with no estimate starts empty instead of borrowing one',
      () async {
    final p = await provider();
    setupFor(p, 'proj-a', 'Chipata Road');
    addLine(p, 'Road works', 480000);

    await p.ensureProjectLoaded('proj-b', projectName: 'Lusaka Bridge');
    expect(p.estimate, isNull,
        reason: 'project B has no estimate of its own — not project A\'s');
    expect(p.setupComplete, isFalse);
  });

  test('an empty project id scopes to default, never another project',
      () async {
    final p = await provider();
    setupFor(p, 'proj-a', 'Chipata Road');
    addLine(p, 'Road works', 480000);

    await p.ensureProjectLoaded('');
    expect(p.activeProjectId, 'default');
    expect(p.estimate, isNull,
        reason: 'with no active project nothing may be shown');
  });

  test('adopts a pre-scoping record once, for the project it belongs to',
      () async {
    // What the old global key looked like: every record said `projectId:
    // 'default'`, and the captured project name is the only surviving signal.
    SharedPreferences.setMockInitialValues({
      'ndu_cost_estimate_v1': '''
{"state":{"setupComplete":true,"estimate":{"id":"e1","projectId":"default",
"projectName":"Chipata Road","className":"class3","deliveryModel":"waterfall",
"status":"draft","currency":"USD","lines":[],"totals":{"direct":0,"indirect":0,
"sherQuality":0,"riskAllowances":0,"contingency":0,"escalation":0,"taxes":0,
"managementReserve":0,"costBaseline":0,"totalAuthorizedBudget":0},
"access":[],"stakeholders":[],"aiSuggestions":[],
"createdAt":"2026-01-01T00:00:00.000","updatedAt":"2026-01-01T00:00:00.000"}}}
''',
    });

    final p = await provider();
    await p.ensureProjectLoaded('proj-a', projectName: 'Chipata Road');
    expect(p.estimate, isNotNull, reason: 'the legacy record is adopted');
    expect(p.estimate!.projectId, 'proj-a',
        reason: 'and re-homed onto the project that owns it');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ndu_cost_estimate_v1'), isNull,
        reason: 'the legacy entry is claimed, so it can never be adopted again');
    expect(prefs.getString('ndu_cost_estimate_v2_project_proj-a'), isNotNull,
        reason: 'it now lives under the project\'s own key');

    // A different project must NOT pick it up.
    final other = CostEstimateProvider();
    await Future<void>.delayed(Duration.zero);
    await other.ensureProjectLoaded('proj-b', projectName: 'Lusaka Bridge');
    expect(other.estimate, isNull,
        reason: 'another project never inherits the legacy record');
  });

  test('does not adopt a legacy record that names a different project',
      () async {
    SharedPreferences.setMockInitialValues({
      'ndu_cost_estimate_v1': '''
{"state":{"setupComplete":true,"estimate":{"id":"e1","projectId":"proj-other",
"projectName":"Somewhere Else","className":"class3","deliveryModel":"waterfall",
"status":"draft","currency":"USD","lines":[],
"totals":{"costBaseline":0,"totalAuthorizedBudget":0},"access":[],
"stakeholders":[],"aiSuggestions":[],
"createdAt":"2026-01-01T00:00:00.000","updatedAt":"2026-01-01T00:00:00.000"}}}
''',
    });

    final p = await provider();
    await p.ensureProjectLoaded('proj-a', projectName: 'Chipata Road');
    expect(p.estimate, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ndu_cost_estimate_v1'), isNotNull,
        reason: 'an unattributable record is left for its own project');
  });
}
