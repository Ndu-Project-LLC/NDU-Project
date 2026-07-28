import 'package:flutterflow_ai/flutterflow_ai.dart';
import 'package:test/test.dart';

import '../dsl/create.dart' as starter;

void main() {
  test('starter DSL app compiles', () {
    final app = buildApp(starter.buildStarterCreateFlow);
    final project = compileApp(app).project;

    final starterPage = findPage(project, name: 'StarterPage');
    expect(starterPage, isNotNull);
    expect(starterPage!.node.type, FFWidgetType.Scaffold);
  });
}
