import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/widgets/launch_phase_table_tabs.dart';

/// Regression guard for the Launch Phase tab bar: the active indicator must
/// fully contain its own label.
///
/// The shipped bar painted a white indicator narrower than the label text, so
/// "Post-Delivery Risks" spilled outside the pill it was sitting in. This test
/// measures the painted indicator against the label's own box and fails if the
/// label is not fully enclosed.
void main() {
  const labels = [
    'Overview',
    'Scope Acceptance',
    'Delivery Milestones',
    'Outstanding Items',
    'Post-Delivery Risks',
  ];

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LaunchPhaseTableTabs(
              overview: const Text('overview body'),
              tabs: [
                for (final l in labels.skip(1))
                  LaunchPhaseTableTab(label: l),
              ],
              builders: {
                for (final l in labels.skip(1)) l: () => Text('$l body'),
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('every active tab label sits fully inside its indicator',
      (tester) async {
    // The widths from the reported screenshot, plus narrower/larger viewports
    // so the check is not tuned to one screen size.
    for (final width in [900.0, 1200.0, 1600.0, 2000.0]) {
      await pumpAt(tester, Size(width, 1000));

      for (final label in labels) {
        await tester.tap(
          find.byKey(ValueKey<String>('launch-phase-tab-$label')),
        );
        await tester.pumpAndSettle();

        // The Tab itself is the box the indicator is painted to fill.
        final tabRect = tester.getRect(
          find.byKey(ValueKey<String>('launch-phase-tab-$label')),
        );
        final labelRect = tester.getRect(
          find.descendant(
            of: find.byKey(ValueKey<String>('launch-phase-tab-$label')),
            matching: find.text(label),
            matchRoot: true,
          ),
        );

        expect(
          tabRect.width,
          greaterThan(0),
          reason: 'tab "$label" has no width at viewport $width',
        );

        // The label must not spill outside the tab box on either side.
        expect(
          labelRect.left,
          greaterThanOrEqualTo(tabRect.left - 0.5),
          reason:
              'label "$label" starts ${labelRect.left - tabRect.left}px left '
              'of its tab at viewport $width',
        );
        expect(
          labelRect.right,
          lessThanOrEqualTo(tabRect.right + 0.5),
          reason:
              'label "$label" ends ${labelRect.right - tabRect.right}px right '
              'of its tab at viewport $width',
        );
      }
    }
  });

  testWidgets('tab bar reports no layout overflow', (tester) async {
    await pumpAt(tester, const Size(1600, 1000));

    // Every label active in turn; a RenderFlex/Text overflow surfaces here.
    for (final label in labels) {
      await tester.tap(find.byKey(ValueKey<String>('launch-phase-tab-$label')));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'overflow while "$label" was active',
      );
    }
  });
}