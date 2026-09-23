// Lusaka 25 (copy) review, on skipping a section's inner flow:
//
//   "that design planning needs to be grayed out. So please take this action for
//    every single section that has more than one tab … The next must be grayed
//    out and if you try to click on it, you should tell them to finish the flow
//    within that section."
//
//   "they really might not know, so they might click next and they'll skip
//    everything else here."
//
// The gate has one job and two ways to fail it. If it is too eager it locks the
// user out of a section they have actually finished, or out of a section that has
// a single tab and therefore no inner flow at all. If it is too lax the whole
// point is lost and the tabs get skipped again. Both directions are pinned here,
// plus the message, because "finish the section" is useless to someone who did
// not know the other tabs existed — it has to name them.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/utils/section_flow_gate.dart';

void main() {
  group('what counts as a multi-tab section', () {
    test('the sections the owner walked are modelled', () {
      expect(isMultiTabSection('ssher'), isTrue);
      expect(isMultiTabSection('quality_management'), isTrue);
      expect(isMultiTabSection('technology'), isTrue);
      expect(isMultiTabSection('design'), isTrue);
    });

    test('a section with no inner flow is never gated', () {
      // Cost Estimate and the rest are single-surface: there is nothing inside
      // them to finish, so their Next must stay free.
      expect(sectionFlowFor('cost_estimate'), isNull);
      expect(unvisitedTabs('cost_estimate', const []), isEmpty);
      expect(sectionFlowComplete('cost_estimate', const []), isTrue);
    });

    test('SSHER keeps the five categories it already tracks', () {
      final flow = sectionFlowFor('ssher')!;
      expect(flow.tabs.map((t) => t.id).toList(),
          ['safety', 'security', 'health', 'environment', 'regulatory']);
    });

    test('Quality matches the tabs the screen actually renders', () {
      // If a tab is added to the screen and not here, the gate would open early;
      // if one is renamed here and not there, it would never open. These ids are
      // the `_QualityTab` enum names, and the screen records `tab.name` — this
      // list is that contract, which used to be broken (the screen recorded AI
      // category keys instead) and left the gate permanently shut.
      final flow = sectionFlowFor('quality_management')!;
      expect(flow.tabs.map((t) => t.id).toList(), [
        'plan',
        'targets',
        'qaTracking',
        'qcTracking',
        'metrics',
        'register',
        'costOfQuality',
      ]);
    });

    test('Design Planning models every guided section of the screen', () {
      // These ids are `_sectionOrder` in `design_planning_screen.dart`. A section
      // added to the screen and not here would let Next skip it — exactly the
      // skipping the owner asked to stop.
      final flow = sectionFlowFor('design')!;
      expect(flow.sectionTitle, 'Design Planning');
      expect(flow.tabs.map((t) => t.id).toList(), [
        'overview',
        'design_overview',
        'design_specifications_workspace',
        'deviations',
        'requirements',
        'architecture',
        'uiux',
        'technical',
        'constraints',
        'risks',
        'dependencies',
        'decisions',
        'validation',
        'approvals',
        'work_packages',
      ]);
    });
  });

  group('the gate itself', () {
    test('a section with nothing seen yet stays shut', () {
      expect(sectionFlowComplete('quality_management', const []), isFalse);
      expect(unvisitedTabs('quality_management', const []), hasLength(7));
    });

    test('Design Planning opens only once every guided section is resolved',
        () {
      const resolved = [
        'overview',
        'design_overview',
        'design_specifications_workspace',
        'deviations',
        'requirements',
        'architecture',
        'uiux',
        'technical',
        'constraints',
        'risks',
        'dependencies',
        'decisions',
        'validation',
        'approvals',
      ];
      // One section short — the gate must still hold.
      expect(sectionFlowComplete('design', resolved), isFalse);
      expect(unvisitedTabs('design', resolved).single.label, 'Work Packages');

      // A section marked Not applicable counts as resolved, so it is passed in
      // the same list and does not have to be "finished" to move on.
      expect(sectionFlowComplete('design', [...resolved, 'work_packages']), isTrue);
    });

    test('seeing some tabs is not seeing all of them', () {
      // The exact case the owner hit: they worked through the plan and never
      // realised there were five more tabs behind it.
      final seen = ['plan', 'targets'];
      expect(sectionFlowComplete('quality_management', seen), isFalse);
      expect(
        unvisitedTabs('quality_management', seen).map((t) => t.id).toList(),
        ['qaTracking', 'qcTracking', 'metrics', 'register', 'costOfQuality'],
      );
    });

    test('the gate opens only once every tab has been seen', () {
      final all = sectionFlowFor('quality_management')!.tabs.map((t) => t.id);
      expect(sectionFlowComplete('quality_management', all), isTrue);
      expect(sectionFlowComplete('quality_management', all.toList()..remove('metrics')),
          isFalse);
    });

    test('unknown ids in the visit record cannot open or close the gate', () {
      final all = sectionFlowFor('quality_management')!.tabs.map((t) => t.id);
      expect(
        sectionFlowComplete('quality_management', [...all, 'not_a_tab']),
        isTrue,
      );
    });

    test('remaining tabs come back in declaration order', () {
      expect(
        unvisitedTabs('ssher', const ['safety']).map((t) => t.label).toList(),
        ['Security', 'Health', 'Environment', 'Regulatory'],
      );
    });
  });

  group('sections a methodology does not have', () {
    test('agile is not asked for a design work package', () {
      // "for agile projects there wouldn't necessarily be a design work package
      // … design is part of the iteration anyways" (Lusaka 25 (copy) ask 22).
      expect(sectionStartsNotApplicable('agile', 'work_packages'), isTrue);
    });

    test('every other methodology still gets the section', () {
      expect(sectionStartsNotApplicable('waterfall', 'work_packages'), isFalse);
      expect(sectionStartsNotApplicable('hybrid', 'work_packages'), isFalse);
    });

    test('agile only skips the sections it actually lacks', () {
      // Agile still plans specifications, risks and approvals.
      for (final section in ['overview', 'design_specifications', 'risks']) {
        expect(sectionStartsNotApplicable('agile', section), isFalse,
            reason: '$section applies to agile too');
      }
    });

    test('an unknown methodology never silently skips work', () {
      expect(sectionStartsNotApplicable('', 'work_packages'), isFalse);
      expect(sectionStartsNotApplicable('kanban-ish', 'work_packages'), isFalse);
    });

    test('the name is matched case- and space-insensitively', () {
      expect(sectionStartsNotApplicable(' Agile ', 'work_packages'), isTrue);
    });
  });

  group('the message when a gated Next is pressed', () {
    test('names the section and the tabs still to review', () {
      final missing = unvisitedTabs('quality_management', const ['plan']);
      final message =
          sectionIncompleteMessage('quality_management', missing);

      expect(message, contains('Quality Management'));
      expect(message, contains('finish the flow'));
      // The whole reason the user is being stopped: they did not know these
      // existed, so name them.
      expect(message, contains('Targets'));
      expect(message, contains('Register'));
      expect(message, isNot(contains('Plan,')));
    });

    test('an open gate has nothing to say', () {
      expect(sectionIncompleteMessage('quality_management', const []), isEmpty);
    });

    test('an unmapped section still produces a usable sentence', () {
      expect(
        sectionIncompleteMessage('cost_estimate', const [SectionTab('x', 'X')]),
        contains('X'),
      );
    });
  });
}
