// Lusaka 25 (copy) review, on the Design Planning Next button:
//
//   "so now it says next design planning, but that design planning needs to be
//    grayed out"
//   "I think originally design was in front of technology so that wasn't changed
//    … it says next technology planning so there I need to swap this next and
//    make sure that it says the right thing"
//
// The label is not written by hand — `PlanningPhaseNavigation.nextLabel` reads it
// out of the sidebar order — so a label bug here is always an *order* bug. These
// tests pin the order itself, which is the thing that actually got swapped, so
// the same swap cannot come back silently and mislabel the button again.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';

/// Index of the first sidebar item whose checkpoint matches, or -1.
int _sidebarIndex(String checkpoint) => SidebarNavigationService.allItems
    .toList()
    .indexWhere((item) => item.checkpoint == checkpoint);

void main() {
  group('the planning order the Next labels are read from', () {
    test('Design Planning sits directly before Technology Planning', () {
      final design = _sidebarIndex('design');
      final technology = _sidebarIndex('technology');

      expect(design, isNot(-1), reason: 'design must be in the sidebar order');
      expect(technology, isNot(-1),
          reason: 'technology must be in the sidebar order');
      // Adjacent and in this order: Design Planning's Next is Technology
      // Planning, which is what the owner expects to see on the button.
      expect(technology, design + 1);
    });

    test('Quality comes before Design Planning', () {
      // The owner read "next design planning" off the Quality screen. That is
      // correct only while quality precedes design.
      expect(_sidebarIndex('quality_management'),
          lessThan(_sidebarIndex('design')));
    });
  });

  group('what the buttons actually say', () {
    test('Quality moves on to Design Planning', () {
      expect(PlanningPhaseNavigation.nextLabel('quality_management'),
          'Next: Design Planning');
    });

    test('Design Planning moves on to Technology Planning', () {
      expect(PlanningPhaseNavigation.nextLabel('design'),
          'Next: Technology Planning');
    });

    test('the screen registry agrees with the sidebar order', () {
      // Two orderings exist (`PlanningPhaseNavigation.pages` and the sidebar).
      // If they disagree, a page can show the right label and navigate to a
      // different screen, which is worse than a wrong label.
      final design = PlanningPhaseNavigation.getPageIndex('design');
      final technology = PlanningPhaseNavigation.getPageIndex('technology');

      expect(design, isNot(-1));
      expect(technology, design + 1);
      expect(PlanningPhaseNavigation.getPageIndex('quality_management'),
          lessThan(design));
    });
  });
}
