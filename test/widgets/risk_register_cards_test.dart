// Tests for the Risk Register's Cards/Table view switch and card grid.
//
// The register was table-only, so a reader had to scroll a wide grid sideways
// to see a risk's owner or status. Cards give the same rows a second reading
// that fits the width, without changing the table view.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/widgets/risk_register_cards.dart';

RiskCardModel _risk({
  String id = 'R-001',
  String description = 'Vendor dependency may delay releases',
  String category = 'External',
  String probability = 'High',
  String impact = 'Medium',
  String score = 'High',
  String discipline = '',
  String role = '',
  String owner = 'Ada Lovelace',
  String status = 'Open',
}) {
  return RiskCardModel(
    id: id,
    description: description,
    category: category,
    probability: probability,
    impact: impact,
    score: score,
    discipline: discipline,
    role: role,
    owner: owner,
    status: status,
  );
}

Widget _host({required Widget child}) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('RiskRegisterViewToggle', () {
    testWidgets('offers both Cards and Table', (tester) async {
      await tester.pumpWidget(
        _host(
            child: RiskRegisterViewToggle(
          view: RiskRegisterView.table,
          onChanged: (_) {},
        )),
      );

      expect(find.text('Cards'), findsOneWidget);
      expect(find.text('Table'), findsOneWidget);
    });

    testWidgets('reports the view the user picks', (tester) async {
      RiskRegisterView? picked;
      await tester.pumpWidget(
        _host(
          child: RiskRegisterViewToggle(
            view: RiskRegisterView.table,
            onChanged: (next) => picked = next,
          ),
        ),
      );

      await tester.tap(find.text('Cards'));
      await tester.pump();
      expect(picked, RiskRegisterView.cards);

      await tester.tap(find.text('Table'));
      await tester.pump();
      expect(picked, RiskRegisterView.table);
    });

    testWidgets('marks only the active view as selected', (tester) async {
      await tester.pumpWidget(
        _host(
          child: RiskRegisterViewToggle(
            view: RiskRegisterView.cards,
            onChanged: (_) {},
          ),
        ),
      );

      final semantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.label != null)
          .map((s) => s.properties.label)
          .toList();

      expect(semantics, containsAll(['Cards view', 'Table view']));
    });
  });

  group('RiskCardGrid', () {
    testWidgets('shows every risk', (tester) async {
      await tester.pumpWidget(
        _host(
          child: RiskCardGrid(
            risks: [
              _risk(id: 'R-001', description: 'First risk'),
              _risk(id: 'R-002', description: 'Second risk'),
              _risk(id: 'R-003', description: 'Third risk'),
            ],
            onView: (_) {},
            onEdit: (_) {},
          ),
        ),
      );

      expect(find.text('First risk'), findsOneWidget);
      expect(find.text('Second risk'), findsOneWidget);
      expect(find.text('Third risk'), findsOneWidget);
    });

    testWidgets('surfaces the detail the table has to truncate',
        (tester) async {
      await tester.pumpWidget(
        _host(
          child: RiskCardGrid(
            risks: [
              _risk(
                owner: 'Grace Hopper',
                discipline: 'Platform',
                role: 'Architect',
              ),
            ],
            onView: (_) {},
            onEdit: (_) {},
          ),
        ),
      );

      expect(find.text('Grace Hopper'), findsOneWidget);
      expect(find.text('Platform'), findsOneWidget);
      expect(find.text('Architect'), findsOneWidget);
      // The overall scale, which the card gives its own labelled row.
      expect(find.text('Risk Score'), findsOneWidget);
      expect(find.text('High'), findsWidgets);
    });

    testWidgets('omits metadata rows a risk does not carry', (tester) async {
      await tester.pumpWidget(
        _host(
          child: RiskCardGrid(
            risks: [_risk(discipline: '', role: '', owner: '')],
            onView: (_) {},
            onEdit: (_) {},
          ),
        ),
      );

      // No empty "Discipline"/"Owner" labels for a sparse risk.
      expect(find.textContaining('Discipline'), findsNothing);
      expect(find.textContaining('Owner'), findsNothing);
      expect(find.text('Risk Score'), findsOneWidget);
    });

    testWidgets('reports the tapped risk to view and to edit', (tester) async {
      final viewed = <String>[];
      final edited = <String>[];

      await tester.pumpWidget(
        _host(
          child: RiskCardGrid(
            risks: [
              _risk(id: 'R-001', description: 'First'),
              _risk(id: 'R-002', description: 'Second'),
            ],
            onView: (r) => viewed.add(r.id),
            onEdit: (r) => edited.add(r.id),
          ),
        ),
      );

      await tester.tap(find.text('View').last);
      await tester.pump();
      await tester.tap(find.text('Edit').last);
      await tester.pump();

      expect(viewed, hasLength(1));
      expect(edited, hasLength(1));
      // Both point at the same row, the one the card belongs to.
      expect(viewed.single, edited.single);
    });

    testWidgets('stacks cards on a narrow viewport', (tester) async {
      tester.view.physicalSize = const Size(500, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RiskCardGrid(
                risks: [
                  _risk(description: 'First'),
                  _risk(description: 'Second'),
                ],
                onView: (_) {},
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );

      final first = tester.getTopLeft(find.text('First'));
      final second = tester.getTopLeft(find.text('Second'));
      // One per row: the second card starts below the first, not beside it.
      expect(second.dy, greaterThan(first.dy));
      expect((second.dx - first.dx).abs(), lessThan(1));
    });

    testWidgets('places cards side by side on a wide viewport', (tester) async {
      tester.view.physicalSize = const Size(2000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RiskCardGrid(
                risks: [
                  _risk(description: 'First'),
                  _risk(description: 'Second'),
                ],
                onView: (_) {},
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );

      final first = tester.getTopLeft(find.text('First'));
      final second = tester.getTopLeft(find.text('Second'));
      // Side by side on the same row.
      expect(second.dx, greaterThan(first.dx));
      expect((second.dy - first.dy).abs(), lessThan(1));
    });

    testWidgets('lays out a populated card without overflowing',
        (tester) async {
      // A one-column card on a phone is the narrowest the grid gets; long
      // labels and a full set of tags used to overflow here.
      tester.view.physicalSize = const Size(360, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RiskCardGrid(
                risks: [
                  _risk(
                    description:
                        'Instructure restructuring may exceed capacity planning estimates',
                    probability: 'High',
                    impact: 'Medium',
                    discipline: 'Long Programme Management',
                    role: 'Programme Director',
                    owner: 'Grace Hopper',
                    status: 'In Progress',
                  ),
                ],
                onView: (_) {},
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Grace Hopper'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
    });

    testWidgets('lays out at desktop width without overflowing',
        (tester) async {
      tester.view.physicalSize = const Size(2200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RiskCardGrid(
                risks: [
                  _risk(description: 'One'),
                  _risk(description: 'Two'),
                  _risk(description: 'Three'),
                ],
                onView: (_) {},
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('statusColors', () {
    test('keeps the register table palette per status', () {
      expect(statusColors('Open').background, const Color(0xFFE5E7EB));
      expect(statusColors('In Progress').background, const Color(0xFFFFF7E6));
      expect(statusColors('Monitoring').background, const Color(0xFFE0F2F1));
      // An unknown status falls back rather than rendering an unstyled pill.
      expect(statusColors('anything else').background, const Color(0xFFE5E7EB));
    });
  });

  group('RiskLevelTag', () {
    Color backgroundOf(WidgetTester tester, String label) {
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(RiskLevelTag),
              matching: find.byType(Container),
            )
            .first,
      );
      return (container.decoration! as BoxDecoration).color!;
    }

    testWidgets('keeps the register table scale colours', (tester) async {
      await tester.pumpWidget(_host(child: const RiskLevelTag(label: 'High')));
      expect(backgroundOf(tester, 'High'), const Color(0xFFFEE2E2));

      await tester.pumpWidget(
        _host(child: const RiskLevelTag(label: 'Medium')),
      );
      expect(backgroundOf(tester, 'Medium'), const Color(0xFFFEF3C7));

      await tester.pumpWidget(_host(child: const RiskLevelTag(label: 'Low')));
      expect(backgroundOf(tester, 'Low'), const Color(0xFFDCFCE7));
    });

    testWidgets('treats an unrecognised level as the low end', (tester) async {
      await tester.pumpWidget(
        _host(child: const RiskLevelTag(label: 'unknown')),
      );
      expect(backgroundOf(tester, 'unknown'), const Color(0xFFDCFCE7));
    });
  });
}
