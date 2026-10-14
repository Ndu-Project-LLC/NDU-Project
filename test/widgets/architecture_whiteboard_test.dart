import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/utils/design_planning_document.dart';
import 'package:ndu_project/widgets/architecture_whiteboard.dart';

void main() {
  test('legacy modules load and diagram metadata round-trips in planning notes', () {
    final legacy = DesignPlanningWorkItem.fromJson({'id': 'a', 'name': 'API'});
    expect(legacy.diagramX, isNull);
    expect(legacy.connectedModuleIds, isEmpty);
    final document = DesignPlanningDocument(modules: [
      DesignPlanningWorkItem(id: 'a', name: 'API', diagramX: 82,
          diagramY: 135, connectedModuleIds: ['b']),
      DesignPlanningWorkItem(id: 'b', name: 'Database'),
    ]);
    final restored = DesignPlanningDocument.fromJson(document.toJson());
    expect(restored.modules.first.diagramX, 82);
    expect(restored.modules.first.diagramY, 135);
    expect(restored.modules.first.connectedModuleIds, ['b']);
    restored.removeArchitectureModule('b');
    expect(restored.modules, hasLength(1));
    expect(restored.modules.single.connectedModuleIds, isEmpty);
  });

  Future<void> pumpBoard(WidgetTester tester, DesignPlanningDocument document,
      VoidCallback onChanged) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      ArchitectureWhiteboard(document: document, onChanged: onChanged))));
  }

  testWidgets('connect, drag, disconnect and delete edit the same module data',
      (tester) async {
    final document = DesignPlanningDocument(modules: [
      DesignPlanningWorkItem(id: 'a', name: 'API', purpose: 'Serve requests'),
      DesignPlanningWorkItem(id: 'b', name: 'Database'),
    ]);
    var changes = 0;
    await pumpBoard(tester, document, () => changes++);
    await tester.tap(find.text('Connect').first);
    await tester.pump();
    await tester.tap(find.text('Database'));
    await tester.pump();
    expect(document.modules.first.connectedModuleIds, ['b']);
    await tester.drag(find.text('API'), const Offset(45, 30));
    await tester.pump();
    expect(document.modules.first.diagramX, greaterThan(40));
    expect(document.modules.first.diagramY, greaterThan(40));
    final chip = tester.widget<InputChip>(find.byType(InputChip));
    chip.onDeleted!();
    await tester.pump();
    expect(document.modules.first.connectedModuleIds, isEmpty);
    await tester.tap(find.byTooltip('Delete module').last);
    await tester.pump();
    expect(document.modules.map((module) => module.id), ['a']);
    expect(changes, greaterThanOrEqualTo(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('add and edit module names are shared with the cards', (tester) async {
    final document = DesignPlanningDocument();
    await pumpBoard(tester, document, () {});
    await tester.tap(find.text('Add module'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Payments');
    await tester.enterText(find.byType(TextField).last, 'Handle checkout');
    await tester.tap(find.text('Save module'));
    await tester.pumpAndSettle();
    expect(document.modules.single.name, 'Payments');
    expect(document.modules.single.purpose, 'Handle checkout');
    await tester.tap(find.byTooltip('Edit module'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Payments API');
    await tester.tap(find.text('Save module'));
    await tester.pumpAndSettle();
    expect(document.modules.single.name, 'Payments API');
    expect(tester.takeException(), isNull);
  });
}
