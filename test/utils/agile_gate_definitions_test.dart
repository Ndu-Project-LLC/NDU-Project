// The review asked for two things on Acceptance Criteria Planning: acceptance
// criteria must sit *above* definition of done in the gate, and definition of
// ready / done must not be maintained twice. These tests pin the order and pin
// that the reader returns exactly what Backlog Governance saved — the same keys,
// the same shapes, the same defaults — so the page can only ever echo it.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/acceptance_criteria.dart';
import 'package:ndu_project/utils/agile_gate_definitions.dart';

/// A governance payload written the way `agile_backlog_governance_screen.dart`
/// writes it. Anything this reader needs must survive this shape.
Map<String, dynamic> _governancePayload({
  List<Map<String, dynamic>>? ready,
  List<Map<String, dynamic>>? done,
  bool readyChecklist = true,
  bool doneChecklist = true,
  String readyProse = '',
  String doneProse = '',
}) =>
    {
      'prioritization_framework': 'MoSCoW',
      'definition_of_ready': readyProse,
      'definition_of_done': doneProse,
      'dor_checklist': ready ??
          const [
            {'id': 'a', 'label': 'Story written', 'checked': false},
            {'id': 'b', 'label': 'Dependencies identified', 'checked': false},
          ],
      'dod_checklist': done ??
          const [
            {'id': 'c', 'label': 'Code complete', 'checked': true},
            {'id': 'd', 'label': 'Peer reviewed', 'checked': true},
          ],
      'working_agreements': const <Map<String, dynamic>>[],
      'dor_use_checklist': readyChecklist,
      'dod_use_checklist': doneChecklist,
    };

void main() {
  group('gate order', () {
    test('ready comes first, acceptance criteria second, done last', () {
      expect(AgileGateDefinitions.order, [
        AgileGateStage.definitionOfReady,
        AgileGateStage.acceptanceCriteria,
        AgileGateStage.definitionOfDone,
      ]);
    });

    test('acceptance criteria sits above definition of done', () {
      final order = AgileGateDefinitions.order;
      expect(
        order.indexOf(AgileGateStage.acceptanceCriteria),
        lessThan(order.indexOf(AgileGateStage.definitionOfDone)),
      );
    });

    test('only the middle gate is owned by this section', () {
      expect(AgileGateStage.acceptanceCriteria.ownedByAcceptanceCriteria, isTrue);
      expect(AgileGateStage.definitionOfDone.ownedByAcceptanceCriteria, isFalse);
      expect(AgileGateStage.definitionOfReady.ownedByAcceptanceCriteria, isFalse);
    });
  });

  group('reading the governed gates', () {
    test('the saved checklist is what the page shows', () {
      final governance = _governancePayload(
        ready: const [
          {'label': 'Business approval obtained', 'checked': false},
          {'label': 'Edge cases documented', 'checked': false},
        ],
      );

      final ready = AgileGateDefinitions.ready(governance);

      expect(ready.items,
          ['Business approval obtained', 'Edge cases documented']);
      expect(ready.isCustom, isTrue);
      expect(ready.stage, AgileGateStage.definitionOfReady);
      expect(ready.label, 'Definition of Ready');
    });

    test('a project that never customised the gate shows the seed items', () {
      final ready = AgileGateDefinitions.ready(const {});

      expect(ready.items, AgileGateDefinitions.defaultReadyItems);
      expect(ready.isCustom, isFalse);
      expect(ready.items, contains('Acceptance criteria defined'));
    });

    test('the Done gate reads its own keys, not the Ready ones', () {
      final governance = _governancePayload(
        done: const [
          {'label': 'Product Owner approved', 'checked': true},
        ],
      );

      expect(AgileGateDefinitions.done(governance).items,
          ['Product Owner approved']);
      expect(AgileGateDefinitions.ready(governance).items,
          isNot(contains('Product Owner approved')));
    });

    test('junk entries are dropped rather than rendered blank', () {
      // Deliberately malformed: blank labels, a map with no label, and a
      // non-map, all of which the board-hygiene list must survive.
      const governance = <String, dynamic>{
        'dor_checklist': [
          {'label': '   '},
          {'checked': true},
          'not-a-map',
          {'label': 'Real item'},
        ],
      };

      expect(AgileGateDefinitions.ready(governance).items, ['Real item']);
    });

    test('checklist-off mode shows the prose the user maintains', () {
      final governance = _governancePayload(
        readyChecklist: false,
        readyProse: 'Story is sized, dependencies known, and PO has approved.',
      );

      final ready = AgileGateDefinitions.ready(governance);

      expect(ready.usesChecklist, isFalse);
      expect(ready.displayLines,
          ['Story is sized, dependencies known, and PO has approved.']);
      expect(ready.summary, contains('dependencies known'));
    });

    test('checklist-off with no prose falls back to the list, not to blank',
        () {
      final ready =
          AgileGateDefinitions.ready(_governancePayload(readyChecklist: false));

      expect(ready.usesChecklist, isFalse);
      expect(ready.displayLines, ready.items);
      expect(ready.displayLines, isNotEmpty);
    });

    test('forStage returns the governed gate, and nothing for the middle one',
        () {
      final governance = _governancePayload();

      expect(
        AgileGateDefinitions.forStage(
                AgileGateStage.definitionOfDone, governance)
            ?.items,
        ['Code complete', 'Peer reviewed'],
      );
      expect(
        AgileGateDefinitions.forStage(
            AgileGateStage.acceptanceCriteria, governance),
        isNull,
        reason: 'criteria are owned here, not echoed from governance',
      );
    });
  });

  group('one definition only', () {
    test('the section stores no ready/done copy of its own', () {
      // If the acceptance criteria config ever grows its own definition of
      // done, the two screens can disagree — the exact duplication the review
      // called out.
      final keys = AcceptanceCriteriaConfig().toJson().keys.toSet();

      expect(keys, isNot(contains('definitionOfDone')));
      expect(keys, isNot(contains('definitionOfReady')));
      expect(keys, isNot(contains('dod_checklist')));
      expect(keys, isNot(contains('dor_checklist')));
      expect(keys, contains('templates'));
    });

    test('the same saved gate is read identically wherever it is asked for',
        () {
      final governance = _governancePayload(
        done: const [
          {'label': 'Acceptance criteria met', 'checked': true},
        ],
      );

      expect(AgileGateDefinitions.done(governance).items,
          AgileGateDefinitions.forStage(
                  AgileGateStage.definitionOfDone, governance)!
              .items);
    });
  });
}
