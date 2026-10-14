// Lusaka 27 review, on the Planning-phase Execution Plan section:
//
//   "I see a petition issue management but there should be just one issue
//    management for the entire project so which is in the planning"
//   "We have lessons learned … I don't think we need an execution-specific one."
//   "the stakeholder identification we've already done that in the beginning so
//    … it's going to be handled the same way for the entire project"
//
// So the Execution Plan keeps its own work (construction, infrastructure, agile
// delivery, best practices, interface management, …) but no longer carries a
// second Issue Management, Lessons Learned or Stakeholder Identification. Those
// three exist once, project-wide, earlier in the same planning flow.
//
// The screens and their routes are deliberately left in place — only the *flow*
// entries are gone — so this test pins the flow, not the route table.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';

/// The Execution-specific duplicates that were removed, paired with the
/// project-wide checkpoint that already covers each one.
const _removed = {
  'execution_issue_management': 'issue_management',
  'execution_plan_lessons_learned': 'lessons_learned',
  'execution_plan_stakeholder_identification': 'stakeholder_management',
};

Set<String> get _sidebarCheckpoints =>
    SidebarNavigationService.allItems.map((item) => item.checkpoint).toSet();

Set<String> get _pageIds =>
    PlanningPhaseNavigation.pages.map((page) => page.id).toSet();

void main() {
  group('the Execution Plan does not repeat a project-wide section', () {
    _removed.forEach((removed, projectWide) {
      test('$removed is not in the sidebar flow', () {
        expect(_sidebarCheckpoints, isNot(contains(removed)),
            reason: '$removed duplicates the project-wide $projectWide section');
      });

      test('$removed is not a planning page', () {
        expect(_pageIds, isNot(contains(removed)),
            reason: '$removed duplicates the project-wide $projectWide section');
      });
    });
  });

  group('the project-wide section each duplicate pointed at is still there', () {
    _removed.forEach((removed, projectWide) {
      test('$projectWide is still in the sidebar flow', () {
        expect(_sidebarCheckpoints, contains(projectWide),
            reason: 'removing $removed must not take away its project-wide '
                'counterpart too');
      });
    });

    test('each project-wide section appears exactly once in the flow', () {
      // The whole point of the ask is that these are not duplicated, so a
      // second copy anywhere in the order is the failure mode to catch.
      final checkpoints = SidebarNavigationService.allItems
          .map((item) => item.checkpoint)
          .toList();
      for (final projectWide in _removed.values) {
        expect(checkpoints.where((c) => c == projectWide).length, 1,
            reason: '$projectWide should exist once, project-wide');
      }
    });
  });

  group('the rest of the Execution Plan is untouched', () {
    test('its own sections are still in the flow', () {
      for (final checkpoint in const [
        'execution_plan',
        'execution_work_packages',
        'execution_plan_strategy',
        'execution_plan_details',
        'execution_plan_construction_plan',
        'execution_plan_infrastructure_plan',
        'execution_plan_agile_delivery_plan',
        'execution_plan_best_practices',
        'execution_plan_interface_management',
        'execution_plan_communication_plan',
      ]) {
        expect(_sidebarCheckpoints, contains(checkpoint));
      }
    });
  });
}
