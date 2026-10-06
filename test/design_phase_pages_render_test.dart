import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/design_phase_models.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/design_phase_screen.dart';
import 'package:ndu_project/screens/requirements_implementation_screen.dart';
import 'package:ndu_project/screens/technical_alignment_screen.dart';

/// Regression guard for the three Design Phase pages rendering a blank body.
///
/// Each page lays its content out inside a vertical scroll view, which hands
/// its children an unbounded height. When such a child was an `Expanded` in a
/// `Column`, layout threw `RenderFlex children have non-zero flex but incoming
/// height constraints are unbounded`. That poisons the entire render subtree:
/// the sidebar and header still drew, so the page looked alive, but the body
/// came up empty — with nothing on the page to explain it.
///
/// These pages also emit unrelated cosmetic `RenderFlex overflowed` warnings,
/// which are tolerated. Any other layout error is treated as a failure.
const _pages = <String, Widget>{
  'Design Management': DesignPhaseScreen(),
  'Design Specifications': RequirementsImplementationScreen(),
  'Technical Alignment': TechnicalAlignmentScreen(),
};

/// The bug was width-sensitive — the broken `Column` branches only activate
/// below the responsive breakpoints — so sweep across them.
const _widths = <double>[700, 900, 1100, 1400, 1920, 2560];

/// Runs [body] while collecting every Flutter error, then restores the
/// original handler.
///
/// Errors must be collected through [FlutterError.onError] rather than
/// [WidgetTester.takeException]: the binding collapses a burst of layout errors
/// into a single `Multiple exceptions (N)` report that carries no detail, so
/// the fatal failure cannot be told apart from the overflow noise by polling.
Future<List<String>> collectFlutterErrors(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final errors = <String>[];
  final prior = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());
  try {
    await body();
  } finally {
    // Restore before any expect(): the test binding asserts that the handler
    // is back in place by the time the test body finishes.
    FlutterError.onError = prior;
  }
  await tester.pump();
  return errors;
}

/// Errors we deliberately ignore. Overflow is cosmetic — a striped edge the
/// user can still read — and these pages have always had some.
bool _isTolerated(String message) => message.contains('overflowed');

/// A project with real content in every collection these pages read.
///
/// The screens resolve their data through [ProjectDataInherited], NOT the
/// `provider` package. Wiring only a `ChangeNotifierProvider` leaves them with
/// no project at all, so the page would render its empty shell and the test
/// would pass without touching any of the data-dependent code.
ProjectDataModel populatedProject() {
  List<String> many(int n, String prefix) =>
      [for (var i = 1; i <= n; i++) '$prefix item $i with a long label'];

  return ProjectDataModel(
    projectName: 'Zala connect - Zambia Youth Agri-Fintech platform',
    solutionTitle: 'Agri-Fintech Platform',
    opportunities: many(40, 'Opportunity'),
    teamMembers: [
      for (var i = 1; i <= 20; i++)
        TeamMember(
          name: 'Team Member $i',
          role: 'Role $i',
          email: 'member$i@example.com',
          responsibilities: 'Responsible for workstream $i.',
        ),
    ],
    designManagementData: DesignManagementData(
      applicableStandards: const ['ISO 29148', 'IEEE 830', 'PMBOK 7'],
      inheritedRisks: many(30, 'Risk'),
      inheritedConstraints: many(30, 'Constraint'),
      inheritedScope: many(30, 'Scope item'),
      specifications: [
        for (var i = 1; i <= 40; i++)
          DesignSpecification(description: 'Specification $i statement.'),
      ],
      documents: [
        for (var i = 1; i <= 40; i++)
          DesignDocument(
              title: 'Design Document $i',
              type: 'Output',
              url: 'https://example.com/doc$i'),
      ],
      tools: [
        for (var i = 1; i <= 25; i++)
          DesignToolLink(name: 'Tool $i', url: 'https://example.com/$i'),
      ],
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final entry in _pages.entries) {
    for (final width in _widths) {
      testWidgets('${entry.key} lays out its body at ${width.toInt()}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final provider = ProjectDataProvider();
        provider.updateProjectData(populatedProject());

        final errors = await collectFlutterErrors(tester, () async {
          // ProjectDataInherited, NOT ChangeNotifierProvider: these screens
          // read their data through the inherited widget, so provider-package
          // wiring alone leaves them with no project and the test would pass
          // without touching any data-dependent code.
          await tester.pumpWidget(
            ProjectDataInherited(
              provider: provider,
              child: MaterialApp(home: Scaffold(body: entry.value)),
            ),
          );
          await tester.pump();
        });

        // Drain anything the binding itself queued on top of what we captured.
        for (var i = 0; i < 200; i++) {
          final extra = tester.takeException();
          if (extra == null) break;
          errors.add(extra.toString());
        }

        expect(
          errors.where((message) => !_isTolerated(message)).toList(),
          isEmpty,
          reason: 'A fatal layout error poisons the render subtree and blanks '
              'the page body while the shell still draws. Errors seen: '
              '${errors.take(3).toList()}',
        );
        expect(
          find.byType(Text),
          findsWidgets,
          reason: 'The page body should render content, not stay empty.',
        );

        // updateProjectData arms a 2s auto-save debounce; let it drain so the
        // binding does not fail the test on a pending timer.
        await tester.pump(const Duration(seconds: 3));
        await provider.flushAutoSave();
      });
    }
  }
}
