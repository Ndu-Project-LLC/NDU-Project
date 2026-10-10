// Tests for the merged Integration Dashboard.
//
// The Integration Dashboard absorbed the old standalone Regular Projects
// dashboard: `/regular-project-dashboard` and `/integration-dashboard` now
// resolve to the same screen, differing only in which view opens first. These
// tests pin the things that could silently regress:
//
//   1. Both deep-link paths stay registered (the `/dashboard` stat card and
//      the mobile shell both navigate to `/regular-project-dashboard`, and
//      the mobile shell links to `/integration-dashboard`).
//   2. The dashboard's design tokens actually respond to the ambient theme —
//      the previous implementations hard-coded `Colors.white` surfaces, which
//      silently produced unreadable dark-mode output.
//   3. The responsive KPI grid never overflows, at any width.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/screens/integration_dashboard_screen.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/utils/dashboard_palette.dart';
import 'package:ndu_project/widgets/integration_dashboard/_integration_tokens.dart';
import 'package:ndu_project/widgets/integration_dashboard/integration_dashboard_parts.dart';
import 'package:ndu_project/widgets/integration_dashboard/integration_workspaces_view.dart';

import 'app_test.dart' show collectRegisteredPaths;

/// Resolves the dashboard tokens against [theme] using a real element tree,
/// so the assertions exercise the same resolver the screen uses.
Future<IntegrationTokens> resolveTokens(
  WidgetTester tester,
  ThemeData theme,
) async {
  late IntegrationTokens resolved;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) {
          resolved = IntegrationTokens.of(
            context,
            DashboardPalette.forPlan(true),
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return resolved;
}

void main() {
  group('Integration Dashboard routes', () {
    test('both the workspace and baseline deep links stay registered', () {
      final registered = collectRegisteredPaths(AppRouter.main);

      expect(
        registered,
        contains('/${AppRoutes.regularProjectDashboard}'),
        reason: 'The /dashboard stat card and mobile shell both deep-link '
            'here, so the path must stay valid.',
      );
      expect(
        registered,
        contains('/${AppRoutes.integrationDashboard}'),
        reason: 'The mobile shell links here.',
      );
    });

    test('the screen defaults to the baseline view', () {
      // `/integration-dashboard` constructs the screen without arguments, so
      // the default is what that route actually gets.
      expect(
        const IntegrationDashboardScreen().initialView,
        IntegrationDashboardView.baseline,
      );
    });
  });

  group('IntegrationTokens', () {
    testWidgets('light mode resolves light surfaces and dark text',
        (tester) async {
      final tokens = await resolveTokens(tester, lightTheme);
      expect(tokens.ink, const Color(0xFF0F172A));
      expect(tokens.surface, Colors.white);
      expect(tokens.canvas.computeLuminance(), greaterThan(0.8));
    });

    testWidgets('dark mode resolves dark surfaces and light text',
        (tester) async {
      final tokens = await resolveTokens(tester, darkTheme);
      expect(tokens.ink, DarkModeColors.textPrimary);
      expect(tokens.canvas.computeLuminance(), lessThan(0.2));
      // The card surface must sit above the canvas, otherwise cards vanish
      // into the background in dark mode.
      expect(
        tokens.surface.computeLuminance(),
        greaterThan(tokens.canvas.computeLuminance()),
      );
    });

    testWidgets('body text keeps readable contrast against cards',
        (tester) async {
      for (final theme in [lightTheme, darkTheme]) {
        final tokens = await resolveTokens(tester, theme);
        final lighter = tokens.ink.computeLuminance() >
                tokens.surface.computeLuminance()
            ? tokens.ink.computeLuminance()
            : tokens.surface.computeLuminance();
        final darker = tokens.ink.computeLuminance() <
                tokens.surface.computeLuminance()
            ? tokens.ink.computeLuminance()
            : tokens.surface.computeLuminance();
        final contrast = (lighter + 0.05) / (darker + 0.05);
        expect(
          contrast,
          greaterThan(4.0),
          reason: 'Ink on card surface must stay legible.',
        );
      }
    });

    testWidgets('health status maps to the semantic colour set',
        (tester) async {
      final tokens = await resolveTokens(tester, lightTheme);
      expect(tokens.health('on_track'), tokens.good);
      expect(tokens.health('at_risk'), tokens.warn);
      expect(tokens.health('off_track'), tokens.bad);
      // Anything unrecognised degrades to neutral rather than guessing green.
      expect(tokens.health('unknown'), tokens.neutral);
    });
  });

  group('workspace card helpers', () {
    test('phase is derived from progress', () {
      expect(phaseLabelFor(0), 'Initiation');
      expect(phaseLabelFor(0.24), 'Planning');
      expect(phaseLabelFor(0.5), 'Execution');
      expect(phaseLabelFor(0.99), 'Closure');
    });

    test('health labels match the rollup vocabulary', () {
      expect(healthLabel('on_track'), 'On Track');
      expect(healthLabel('at_risk'), 'At Risk');
      expect(healthLabel('off_track'), 'Off Track');
      expect(healthLabel('unknown'), 'Unknown');
    });

    test('relative time degrades from minutes to an absolute date', () {
      final now = DateTime.now();
      expect(relativeTime(now), 'just now');
      expect(relativeTime(now.subtract(const Duration(minutes: 8))), '8m ago');
      expect(relativeTime(now.subtract(const Duration(hours: 5))), '5h ago');
      expect(relativeTime(now.subtract(const Duration(days: 3))), '3d ago');
      // The epoch is what an unparsed Firestore timestamp collapses to; it
      // must never render as "55y ago".
      expect(relativeTime(DateTime.fromMillisecondsSinceEpoch(0)), 'recently');
    });
  });

  group('IntegrationTileGrid', () {
    testWidgets('renders every child without overflow when constrained',
        (tester) async {
      tester.view.physicalSize = const Size(300, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(8),
              child: IntegrationTileGrid(
                minTileWidth: 200,
                children: [
                  Text('a'),
                  Text('b'),
                  Text('c'),
                  Text('d'),
                  Text('e'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      for (final label in ['a', 'b', 'c', 'd', 'e']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('wraps into multiple columns on a wide viewport',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(8),
              child: IntegrationTileGrid(
                minTileWidth: 200,
                children: [Text('a'), Text('b'), Text('c'), Text('d')],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // Four 200px-minimum tiles across ~1384px must all land on one row.
      final topA = tester.getTopLeft(find.text('a')).dy;
      final topD = tester.getTopLeft(find.text('d')).dy;
      expect(topD, topA);
    });
  });
}