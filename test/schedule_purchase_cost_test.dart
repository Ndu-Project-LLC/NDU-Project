import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/utils/schedule_purchase_cost.dart';

ScheduleActivity _act(
  String id,
  String name,
  ScheduleDomain domain,
  ActivityType type, {
  List<ScheduleActivity> children = const [],
  String? code,
}) {
  return ScheduleActivity(
    id: id,
    level: 1,
    code: code ?? id,
    name: name,
    type: type,
    domain: domain,
    dependencies: const [],
    aiGenerated: false,
    children: children,
  );
}

void main() {
  group('isScheduledPurchaseActivity', () {
    test('procurement domain and procurementPackage type both qualify', () {
      expect(isScheduledPurchaseActivity(_act(
              'a', 'Buy CPE Pumps', ScheduleDomain.procurement,
              ActivityType.activity)),
          isTrue);
      expect(isScheduledPurchaseActivity(_act(
              'b', 'Steel package', ScheduleDomain.engineering,
              ActivityType.procurementPackage)),
          isTrue);
      expect(isScheduledPurchaseActivity(_act(
              'c', 'Design basis', ScheduleDomain.engineering,
              ActivityType.ewp)),
          isFalse);
    });
  });

  group('collectPullablePurchases', () {
    test('pulls leaf purchases anywhere in the tree', () {
      final root = _act('root', 'Project', ScheduleDomain.execution,
          ActivityType.summary, children: [
        _act('eng', 'Design', ScheduleDomain.engineering, ActivityType.ewp),
        _act('buy', 'Buy CPE Pumps', ScheduleDomain.procurement,
            ActivityType.activity),
        _act('exec', 'Execute', ScheduleDomain.execution,
            ActivityType.cwp, children: [
          _act('subbuy', 'Buy paint', ScheduleDomain.procurement,
              ActivityType.activity),
        ]),
      ]);

      final pulls = collectPullablePurchases([root]);
      expect(pulls.map((a) => a.id).toSet(), {'buy', 'subbuy'});
    });

    test('purchase container with purchase leaves pulls only the leaves', () {
      final root = _act('root', 'Project', ScheduleDomain.execution,
          ActivityType.summary, children: [
        _act('proc', 'Procurement group', ScheduleDomain.procurement,
            ActivityType.summary, children: [
          _act('leaf1', 'Buy Steel', ScheduleDomain.procurement,
              ActivityType.activity),
          _act('leaf2', 'Buy Valves', ScheduleDomain.procurement,
              ActivityType.activity),
        ]),
      ]);

      final pulls = collectPullablePurchases([root]);
      expect(pulls.map((a) => a.id).toSet(), {'leaf1', 'leaf2'});
    });

    test('procurement package with non-purchase steps is pulled whole', () {
      final root = _act('root', 'Project', ScheduleDomain.execution,
          ActivityType.summary, children: [
        _act('pkg', 'HVAC equipment package', ScheduleDomain.engineering,
            ActivityType.procurementPackage, children: [
          _act('step1', 'Issue PO', ScheduleDomain.execution,
              ActivityType.task),
          _act('step2', 'Receive', ScheduleDomain.execution,
              ActivityType.task),
        ]),
      ]);

      final pulls = collectPullablePurchases([root]);
      expect(pulls.map((a) => a.id).toSet(), {'pkg'});
    });
  });

  group('findActivityById', () {
    test('finds nested activities', () {
      final root = _act('root', 'Project', ScheduleDomain.execution,
          ActivityType.summary, children: [
        _act('l1', 'Level one', ScheduleDomain.engineering, ActivityType.ewp,
            children: [
          _act('deep', 'Deep activity', ScheduleDomain.engineering,
              ActivityType.activity),
        ]),
      ]);
      final found = findActivityById([root], 'deep');
      expect(found, isNotNull);
      expect(found!.name, 'Deep activity');
      expect(findActivityById([root], 'missing'), isNull);
    });
  });
}
