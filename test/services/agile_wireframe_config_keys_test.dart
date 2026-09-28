// The owner was asked whether Metrics Planning and Backlog Governance are
// duplicates and answered "keep them as they are". They are not duplicates in
// data — each writes its own sub-map of the shared `agile_wireframe` document
// with `merge: true` — and these tests pin the part that makes "as they are"
// safe: the two screens must never write the same key, or one screen saving
// would blank the other's fields the next time the document is merged.
//
// A true save-then-read round trip needs Firestore (the suite has no
// fake_cloud_firestore dependency), so this checks the two payloads the service
// builds for those saves instead.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/services/agile_wireframe_service.dart';
import 'package:ndu_project/utils/agile_gate_definitions.dart';

void main() {
  Map<String, dynamic> metricsPayload() =>
      AgileWireframeService.metricsConfigData(
        selectedMetrics: const ['velocity', 'sprint_predictability'],
        notes: 'Review every second sprint.',
      );

  Map<String, dynamic> governancePayload() =>
      AgileWireframeService.backlogGovernanceData(
        fields: const {
          'prioritization_framework': 'MoSCoW',
          'refinement_cadence': 'weekly',
          'estimation_framework': 'Fibonacci',
          'ownership': 'Product Owner',
          'grooming_rules': 'No stale items older than 3 sprints',
        },
        readyProse: 'Ready means refined and estimated.',
        doneProse: 'Done means deployed and approved.',
        readyChecklist: const [
          {'id': 'r1', 'label': 'Refined', 'checked': true},
        ],
        doneChecklist: const [
          {'id': 'd1', 'label': 'Deployed', 'checked': false},
        ],
        workingAgreements: const [
          {'id': 'w1', 'label': 'No meetings before 10am', 'checked': true},
        ],
        readyChecklistMode: true,
        doneChecklistMode: false,
      );

  group('the two screens share a document but not a key', () {
    test('they persist under different sub-map keys', () {
      expect(
        AgileWireframeService.metricsConfigKey,
        isNot(AgileWireframeService.backlogGovernanceKey),
      );
    });

    test('their payloads share no key at all', () {
      final metrics = metricsPayload().keys.toSet();
      final governance = governancePayload().keys.toSet();

      expect(
        metrics.intersection(governance),
        isEmpty,
        reason: 'a shared key would let one screen blank the other',
      );
    });
  });

  group('each payload carries everything its screen reads back', () {
    test('metrics planning: the selection and the notes', () {
      final payload = metricsPayload();

      expect(payload['selectedMetrics'], ['velocity', 'sprint_predictability']);
      expect(payload['notes'], 'Review every second sprint.');
      expect(payload.keys.toSet(), {'selectedMetrics', 'notes'});
    });

    test('backlog governance: the rules, both gates, and the agreements', () {
      final payload = governancePayload();

      expect(payload['prioritization_framework'], 'MoSCoW');
      expect(payload[AgileGateDefinitions.readyFreeTextKey],
          'Ready means refined and estimated.');
      expect(payload[AgileGateDefinitions.doneFreeTextKey],
          'Done means deployed and approved.');
      expect(payload[AgileGateDefinitions.readyChecklistKey], hasLength(1));
      expect(payload[AgileGateDefinitions.doneChecklistKey], hasLength(1));
      expect(payload['working_agreements'], hasLength(1));
      expect(payload[AgileGateDefinitions.readyChecklistModeKey], isTrue);
      expect(payload[AgileGateDefinitions.doneChecklistModeKey], isFalse);
    });

    test('the gate keys the Acceptance Criteria page echoes are present', () {
      // Task 5 renders Definition of Ready/Done read-only from governance, so a
      // payload that dropped these would silently break that page too.
      final payload = governancePayload();

      expect(payload.containsKey(AgileGateDefinitions.readyChecklistKey), isTrue);
      expect(
          payload.containsKey(AgileGateDefinitions.readyChecklistModeKey), isTrue);
      expect(
          payload.containsKey(AgileGateDefinitions.readyFreeTextKey), isTrue);
      expect(payload.containsKey(AgileGateDefinitions.doneChecklistKey), isTrue);
      expect(
          payload.containsKey(AgileGateDefinitions.doneChecklistModeKey), isTrue);
      expect(payload.containsKey(AgileGateDefinitions.doneFreeTextKey), isTrue);
    });
  });
}
