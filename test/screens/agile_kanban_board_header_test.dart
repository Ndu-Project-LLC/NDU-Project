// The kanban column headers carry the workflow state names plus a count and a
// WIP badge. The name used to sit in a Flexible next to a Spacer, and those two
// share the free space equally — so "In Progress" was cut to "In Pr…" while the
// header still looked half empty. These tests pin the fix: the name gets every
// pixel the badges do not need, and on a narrow panel the header stacks rather
// than shortening it.
//
// Truncation is measured rather than guessed: a Text given less width than it
// needs lays out at the smaller width and paints an ellipsis, so comparing the
// rendered width against the string's own intrinsic width detects it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/agile_kanban_board_screen.dart';

/// The width of [label] as laid out on screen.
double _renderedWidth(WidgetTester tester, String label) =>
    tester.getSize(find.text(label).first).width;

/// The width [label] needs to be painted in full, in the style it is using.
double _intrinsicWidth(WidgetTester tester, String label) {
  final text = tester.widget<Text>(find.text(label).first);
  final painter = TextPainter(
    text: TextSpan(text: label, style: text.style),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

/// Pumps the board inside [panelWidth] on a desktop-sized surface, so the
/// five-across board (not the phone stack) is the layout under test.
Future<void> _pumpBoard(WidgetTester tester, {required double panelWidth}) async {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  // The board reads the project from the provider; with no project id it still
  // renders the default workflow columns, which is the header under test.
  await tester.pumpWidget(
    ChangeNotifierProvider<ProjectDataProvider>.value(
      value: ProjectDataProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: panelWidth, child: const KanbanBoardPanel()),
          ),
        ),
      ),
    ),
  );
  // Fixed pumps rather than pumpAndSettle: the panel's loading strip animates
  // forever, so settling would never finish.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('every workflow column is on the board', (tester) async {
    await _pumpBoard(tester, panelWidth: 1600);

    for (final name in const [
      'Backlog',
      'Ready',
      'In Progress',
      'In Review',
      'Done',
    ]) {
      expect(find.text(name), findsWidgets, reason: '$name column is missing');
    }
    // The WIP badges for the limited columns, as in the screenshot.
    expect(find.text('WIP 5'), findsOneWidget);
    expect(find.text('WIP 3'), findsOneWidget);
  });

  testWidgets('the column name is not cut off while the badges are shown',
      (tester) async {
    await _pumpBoard(tester, panelWidth: 1600);

    for (final name in const ['In Progress', 'In Review']) {
      expect(
        _renderedWidth(tester, name),
        greaterThanOrEqualTo(_intrinsicWidth(tester, name) - 0.5),
        reason: '"$name" is truncated: it needs more room than the header '
            'gave it while the count and WIP badges take their space first.',
      );
    }
  });

  testWidgets('a narrow panel stacks the header instead of shortening the name',
      (tester) async {
    // 900 wide is 180 per column: too little for the name beside the badges
    // (which would cut it short) but plenty once the header stacks.
    await _pumpBoard(tester, panelWidth: 900);

    for (final name in const ['In Progress', 'In Review']) {
      expect(
        _renderedWidth(tester, name),
        greaterThanOrEqualTo(_intrinsicWidth(tester, name) - 0.5),
        reason: '"$name" should be given a full line of its own on a narrow '
            'panel.',
      );
    }
    // The badges are still there — stacking must not hide them.
    expect(find.text('WIP 5'), findsOneWidget);
    expect(find.text('WIP 3'), findsOneWidget);
  });
}
