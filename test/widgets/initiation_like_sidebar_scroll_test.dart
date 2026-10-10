// Opening a page whose sidebar entry sits below the fold must scroll the menu
// to that entry. Before this, the menu was a lazy ListView that never scrolled
// to the highlighted item, so the user had to scroll down to find where they
// were.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/widgets/initiation_like_sidebar.dart';

void main() {
  testWidgets(
      'a highlighted sub-page far down the menu is scrolled into view on open',
      (tester) async {
    // A short surface, so the Design Planning entries start below the fold.
    tester.view.physicalSize = const Size(1400, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InitiationLikeSidebar(
            activeItemLabel: 'Design Planning - Work Packages',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final label = find.text('Work Packages');
    expect(label, findsOneWidget);

    final top = tester.getTopLeft(label).dy;
    final bottom = tester.getBottomLeft(label).dy;
    expect(top, greaterThanOrEqualTo(0),
        reason: 'the active sub-page is scrolled above the viewport');
    expect(bottom, lessThanOrEqualTo(600),
        reason: 'the active sub-page is still below the viewport');
  });
}
