// Lusaka 27 review, on the Planning-phase Execution Plan:
//
//   "there should be no execution plan for the agile delivery. The execution
//    plan is mostly so if the waterfall project is going to be blanked out,
//    they cannot click on it, they cannot access it."
//
// So the delivery model the project already carries (`'AGILE' | 'WATERFALL' |
// 'HYBRID'`) gates two whole sections: an Agile project keeps no Execution
// Plan, and a Waterfall project keeps no Agile Delivery flow. Everything else —
// including the Agile Project Hub in the Execution *phase* — is untouched.
//
// The gate is a pure rule (`DeliveryModelNavGate`) applied by
// `SidebarNavigationService`, the sidebar widget and the on-page Next/Back, so
// it is pinned here rather than left to the widget code. The checkpoints the
// gate knows about are pinned against the real flow (the contiguous block each
// section occupies), so a later addition to either section fails loudly instead
// of silently staying visible on the wrong delivery model.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/utils/delivery_model_nav_gate.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

List<String> get _sidebarCheckpoints =>
    SidebarNavigationService.allItems.map((i) => i.checkpoint).toList();

/// The sidebar checkpoints of one section, taken from the flow itself: the
/// contiguous run from [first] to [last].
List<String> _sidebarRange(String first, String last) =>
    SidebarNavigationService.instance
        .itemsBetween(first, last)
        .map((i) => i.checkpoint)
        .toList();

Set<String> get _planningPageIds =>
    PlanningPhaseNavigation.pages.map((p) => p.id).toSet();

void main() {
  group('the pure rule', () {
    test('an Agile project keeps no Execution Plan', () {
      expect(DeliveryModelNavGate.showsExecutionPlan('AGILE'), isFalse);
      expect(DeliveryModelNavGate.showsAgileDelivery('AGILE'), isTrue);
    });

    test('a Waterfall project keeps no Agile Delivery flow', () {
      expect(DeliveryModelNavGate.showsAgileDelivery('WATERFALL'), isFalse);
      expect(DeliveryModelNavGate.showsExecutionPlan('WATERFALL'), isTrue);
    });

    test('Hybrid keeps both — it uses both', () {
      expect(DeliveryModelNavGate.showsExecutionPlan('HYBRID'), isTrue);
      expect(DeliveryModelNavGate.showsAgileDelivery('HYBRID'), isTrue);
    });

    test(
        'an unset or blank model keeps both, so an unconfigured project is '
        'unchanged', () {
      for (final model in [null, '', '   ']) {
        expect(DeliveryModelNavGate.showsExecutionPlan(model), isTrue,
            reason: 'model: $model');
        expect(DeliveryModelNavGate.showsAgileDelivery(model), isTrue,
            reason: 'model: $model');
        expect(DeliveryModelNavGate.normalize(model), isNull);
      }
    });

    test('the model is matched case- and whitespace-insensitively', () {
      expect(DeliveryModelNavGate.showsExecutionPlan(' agile '), isFalse);
      expect(DeliveryModelNavGate.showsAgileDelivery('waterfall'), isFalse);
      expect(DeliveryModelNavGate.normalize(' hybrid '), 'HYBRID');
    });

    test('only the two gated sections are hidden', () {
      expect(DeliveryModelNavGate.hidesCheckpoint('execution_plan', 'AGILE'),
          isTrue);
      expect(DeliveryModelNavGate.hidesCheckpoint('agile_map_out', 'WATERFALL'),
          isTrue);
      expect(DeliveryModelNavGate.hidesCheckpoint('risk_assessment', 'AGILE'),
          isFalse);
      expect(DeliveryModelNavGate.hidesCheckpoint('technology', 'WATERFALL'),
          isFalse);
      // The Agile Project Hub lives in the Execution *phase*, not the Planning
      // Agile Delivery flow, so a Waterfall project still keeps it.
      expect(
          DeliveryModelNavGate.hidesCheckpoint(
              'agile_development_iterations', 'WATERFALL'),
          isFalse);
    });
  });

  group('the gate covers exactly the sections in the flow', () {
    test('its Execution Plan set is exactly the section the flow carries', () {
      final inFlow =
          _sidebarRange('execution_plan', 'execution_quality_tracking').toSet();

      expect(DeliveryModelNavGate.executionPlanCheckpoints, inFlow,
          reason: 'the gate must track the flow block, no more and no less');
      for (final id in DeliveryModelNavGate.executionPlanCheckpoints) {
        if (id == 'execution_work_packages') continue; // no page of its own
        expect(_planningPageIds, contains(id),
            reason: '$id is gated but has no planning page');
      }
    });

    test('its Agile Delivery set is the section plus the one row-less page',
        () {
      final inFlow =
          _sidebarRange('agile_delivery_model', 'agile_map_out').toSet();

      expect(
        DeliveryModelNavGate.agileDeliveryCheckpoints.difference(inFlow),
        {'agile_stories_backlog'},
        reason: 'Stories & Backlog Breakdown is the only row-less agile page',
      );
      expect(inFlow, isNot(contains('agile_stories_backlog')));
      for (final id in DeliveryModelNavGate.agileDeliveryCheckpoints) {
        expect(_planningPageIds, contains(id),
            reason: '$id is gated but has no planning page');
      }
    });
  });

  group('the sidebar flow it produces', () {
    test('an unset model leaves the order exactly as it is', () {
      expect(
        SidebarNavigationService.instance
            .itemsForDeliveryModel(null)
            .map((i) => i.checkpoint)
            .toList(),
        _sidebarCheckpoints,
      );
    });

    test('an Agile project loses every Execution Plan row', () {
      final left = SidebarNavigationService.instance
          .itemsForDeliveryModel('AGILE')
          .map((i) => i.checkpoint)
          .toSet();

      for (final hidden in DeliveryModelNavGate.executionPlanCheckpoints) {
        expect(left, isNot(contains(hidden)));
      }
      expect(left, contains('agile_map_out'));
      expect(_sidebarCheckpoints.length - left.length,
          DeliveryModelNavGate.executionPlanCheckpoints.length);
    });

    test('a Waterfall project loses every Agile Delivery row', () {
      final left = SidebarNavigationService.instance
          .itemsForDeliveryModel('WATERFALL')
          .map((i) => i.checkpoint)
          .toSet();

      for (final item in SidebarNavigationService.allItems) {
        if (DeliveryModelNavGate.agileDeliveryCheckpoints
            .contains(item.checkpoint)) {
          expect(left, isNot(contains(item.checkpoint)));
        }
      }
      expect(left, contains('execution_plan'));
      expect(left, contains('agile_development_iterations'),
          reason: 'the Execution-phase Agile Project Hub is not gated');
    });

    test('a Hybrid project keeps every row', () {
      expect(
        SidebarNavigationService.instance
            .itemsForDeliveryModel('HYBRID')
            .map((i) => i.checkpoint)
            .toList(),
        _sidebarCheckpoints,
      );
    });
  });

  group('the Next/Back flow skips the hidden section', () {
    test(
        'Agile: Agile Map Out moves on to the next section, not the '
        'Execution Plan', () {
      final next = SidebarNavigationService.instance.getNextAccessibleItem(
          'agile_map_out', false,
          deliveryModel: 'AGILE');
      // The block's 15 rows are gone, so the walk lands on the section that
      // followed the Execution Plan in the flow (Roadmap Overview).
      expect(next?.checkpoint, 'deliverables_roadmap_overview');
    });

    test('Waterfall: Technology Planning moves straight to the Execution Plan',
        () {
      expect(
        SidebarNavigationService.instance
            .getNextAccessibleItem('technology', false,
                deliveryModel: 'WATERFALL')
            ?.checkpoint,
        'execution_plan',
      );
      expect(
        SidebarNavigationService.instance
            .getPreviousAccessibleItem('execution_plan',
                deliveryModel: 'WATERFALL')
            ?.checkpoint,
        'technology',
      );
    });

    test('an unset model is unchanged, so nothing moves by accident', () {
      expect(
          SidebarNavigationService.instance
              .getNextItem('technology')
              ?.checkpoint,
          'agile_delivery_model');
      expect(
          SidebarNavigationService.instance
              .getNextItem('agile_map_out')
              ?.checkpoint,
          'execution_plan');
    });

    test('the button labels match the gated destination', () {
      // Waterfall: Technology Planning no longer says "Next: Agile Delivery
      // Model" while its Next action opens the Execution Plan.
      expect(
        PlanningPhaseNavigation.nextLabel('technology',
            deliveryModel: 'WATERFALL'),
        'Next: Execution Plan Overview',
      );
      expect(
        PlanningPhaseNavigation.backLabel('execution_plan',
            deliveryModel: 'WATERFALL'),
        'Back: Technology Planning',
      );
      // Agile: the label on the last Agile Delivery screen must not promise an
      // Execution Plan that is not there.
      expect(
        PlanningPhaseNavigation.nextLabel('agile_map_out',
            deliveryModel: 'AGILE'),
        isNot(contains('Execution Plan')),
      );
    });
  });

  group('the project data gives the gate its model', () {
    test('a project with no framework reports no model', () {
      expect(ProjectDataHelper.deliveryModelOrNull(ProjectDataModel()), isNull);
    });

    test('the chosen framework becomes the delivery model', () {
      expect(
        ProjectDataHelper.deliveryModelOrNull(
            ProjectDataModel().copyWith(overallFramework: 'Agile')),
        'AGILE',
      );
      expect(
        ProjectDataHelper.deliveryModelOrNull(
            ProjectDataModel().copyWith(overallFramework: 'Waterfall')),
        'WATERFALL',
      );
    });
  });
}
