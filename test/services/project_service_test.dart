// Regression tests for ProjectRecord / ProjectProgressSnapshot parsing.
//
// These tests guard against the RangeError (end): Invalid value: Not in
// inclusive range 0..N: -1 bug that was reported on staging. The error
// happens when a substring() call receives end = -1 (typically because an
// indexOf() returned -1 and was used as the end argument without a guard).
//
// The tests below exercise the parsing helpers with edge-case inputs:
//   * empty strings
//   * very long strings (60-120 chars, matching the N values seen in
//     production errors)
//   * strings with special characters, leading/trailing whitespace, etc.
//   * missing/null fields in the Firestore doc payload

// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/services/project_service.dart';

void main() {
  group('ProjectRecord.fromDoc', () {
    /// Helper that builds a fake DocumentSnapshot with the given data.
    DocumentSnapshot<Map<String, dynamic>> makeDoc({
      required String id,
      Map<String, dynamic>? data,
    }) {
      return _FakeDocSnapshot(id: id, data: data ?? const <String, dynamic>{});
    }

    test('parses a minimal project with empty data', () {
      final record = ProjectRecord.fromDoc(makeDoc(id: 'p1'));
      expect(record.id, 'p1');
      expect(record.name, '');
      expect(record.ownerName, '');
      expect(record.ownerEmail, '');
      expect(record.status, 'Initiation');
      expect(record.progress, 0.0);
      expect(record.tags, isEmpty);
    });

    test('parses a project with all fields populated', () {
      final record = ProjectRecord.fromDoc(makeDoc(
        id: 'p1',
        data: {
          'ownerId': 'uid-1',
          'ownerEmail': 'John.Doe@Example.com',
          'ownerName': 'John Doe',
          'name': 'My Project',
          'solutionTitle': 'Solution',
          'solutionDescription': 'Desc',
          'businessCase': 'Case',
          'notes': 'Notes',
          'status': 'Execution',
          'progress': 0.5,
          'investmentMillions': 12.5,
          'milestone': 'M1',
          'tags': ['a', 'b'],
          'isBasicPlanProject': true,
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 2)),
          'checkpointRoute': 'project_decision_summary',
        },
      ));
      expect(record.name, 'My Project');
      expect(record.ownerName, 'John Doe');
      expect(record.ownerEmail, 'John.Doe@Example.com');
      expect(record.status, 'Execution');
      expect(record.progress, 0.5);
      expect(record.investmentMillions, 12.5);
      expect(record.tags, ['a', 'b']);
      expect(record.isBasicPlanProject, isTrue);
    });

    test('parses a project with very long name (60-120 chars)', () {
      // These lengths match the N values seen in the production
      // RangeError (end): Not in inclusive range 0..N: -1 errors.
      for (final length in [58, 60, 66, 68, 75, 76, 77, 80, 81, 85, 89, 94, 95, 99, 107, 110, 113, 117]) {
        final longName = 'A' * length;
        final record = ProjectRecord.fromDoc(makeDoc(
          id: 'p1',
          data: {
            'ownerId': 'uid-1',
            'name': longName,
            'status': 'Initiation',
          },
        ));
        expect(record.name, longName);
        expect(record.name.length, length);
      }
    });

    test('parses a project with empty name and empty ownerName', () {
      final record = ProjectRecord.fromDoc(makeDoc(
        id: 'p1',
        data: {
          'ownerId': 'uid-1',
          'name': '',
          'ownerName': '',
          'ownerEmail': '',
          'status': '',
        },
      ));
      expect(record.name, '');
      expect(record.ownerName, '');
      expect(record.ownerEmail, '');
      expect(record.status, ''); // Empty status stays empty
    });

    test('parses a project with whitespace-only ownerName', () {
      final record = ProjectRecord.fromDoc(makeDoc(
        id: 'p1',
        data: {
          'ownerId': 'uid-1',
          'ownerName': '   ',
          'ownerEmail': 'john@example.com',
        },
      ));
      expect(record.ownerName, '   ');
      expect(record.ownerEmail, 'john@example.com');
    });

    test('parses a project with special characters in ownerName', () {
      final record = ProjectRecord.fromDoc(makeDoc(
        id: 'p1',
        data: {
          'ownerId': 'uid-1',
          'ownerName': 'José María Müller-Lübeck',
          'ownerEmail': 'john@example.com',
        },
      ));
      expect(record.ownerName, 'José María Müller-Lübeck');
    });

    test('parses a project with email containing consecutive dots', () {
      final record = ProjectRecord.fromDoc(makeDoc(
        id: 'p1',
        data: {
          'ownerId': 'uid-1',
          'ownerEmail': 'john..doe@example.com',
        },
      ));
      expect(record.ownerEmail, 'john..doe@example.com');
    });

    test('parses a project with null fields', () {
      final record = ProjectRecord.fromDoc(makeDoc(
        id: 'p1',
        data: {
          'ownerId': null,
          'name': null,
          'ownerName': null,
          'ownerEmail': null,
          'status': null,
          'progress': null,
          'tags': null,
        },
      ));
      expect(record.name, '');
      expect(record.ownerName, '');
      expect(record.ownerEmail, '');
      expect(record.status, 'Initiation');
      expect(record.progress, 0.0);
      expect(record.tags, isEmpty);
    });

    test('parses a project with malformed tags', () {
      final record = ProjectRecord.fromDoc(makeDoc(
        id: 'p1',
        data: {
          'ownerId': 'uid-1',
          'tags': 'not-a-list',
        },
      ));
      expect(record.tags, isEmpty);
    });
  });

  group('ProjectProgressSnapshot.fromRaw', () {
    ProjectProgressSnapshot snapshot(Map<String, dynamic> source,
        {String fallbackStatus = 'Initiation',
        double fallbackProgress = 0.0,
        String fallbackMilestone = '',
        String checkpointRoute = ''}) {
      return ProjectProgressSnapshot.fromRaw(
        source: source,
        fallbackStatus: fallbackStatus,
        fallbackProgress: fallbackProgress,
        fallbackMilestone: fallbackMilestone,
        checkpointRoute: checkpointRoute,
      );
    }

    test('handles empty source', () {
      final s = snapshot({});
      expect(s.totalActivities, 0);
      expect(s.completion, 0.0);
      expect(s.currentPhase, 'Initiation');
    });

    test('handles activities with empty title and description', () {
      final s = snapshot({
        'projectActivities': [
          {'title': '', 'description': ''},
          {'title': '', 'description': null},
          {'title': null, 'description': ''},
        ],
      });
      expect(s.totalActivities, 0);
    });

    test('handles activities with various status tokens', () {
      final s = snapshot({
        'projectActivities': [
          {'title': 'A1', 'status': 'Implemented'},
          {'title': 'A2', 'status': 'implemented'},
          {'title': 'A3', 'status': 'COMPLETE'},
          {'title': 'A4', 'status': 'closed'},
          {'title': 'A5', 'status': 'done'},
          {'title': 'A6', 'status': 'Pending'},
          {'title': 'A7', 'status': 'Rejected'},
          {'title': 'A8', 'status': 'Cancelled'},
          {'title': 'A9', 'status': ''},
          {'title': 'A10', 'status': null},
        ],
      });
      // 5 implemented (Implemented, implemented, COMPLETE, closed, done)
      // 3 pending (Pending, A9 with empty status, A10 with null status)
      // 2 rejected (Rejected, Cancelled)
      expect(s.totalActivities, 10);
      expect(s.implementedActivities, 5);
      expect(s.pendingActivities, 3);
    });

    test('handles activities with malformed data', () {
      final s = snapshot({
        'projectActivities': [
          'not-a-map',
          {'title': 'Valid', 'description': 'Valid'},
          null,
          42,
          {'title': null, 'description': null},
        ],
      });
      expect(s.totalActivities, 1);
    });

    test('handles milestone stats with various shapes', () {
      final s = snapshot({
        'keyMilestones': [
          {'name': 'M1', 'completed': true},
          {'name': 'M2', 'isCompleted': true},
          {'name': 'M3', 'achieved': true},
          {'name': 'M4', 'status': 'Completed'},
          {'name': 'M5', 'completedDate': '2026-01-01'},
          {'name': 'M6'}, // not achieved
          {}, // empty map (skipped)
        ],
      });
      expect(s.totalMilestones, 6); // empty map is skipped
      expect(s.achievedMilestones, 5);
    });

    test('handles milestone stats with planningGoals', () {
      final s = snapshot({
        'planningGoals': [
          {
            'id': 'g1',
            'milestones': [
              {'name': 'M1', 'completed': true},
              {'name': 'M2'},
            ],
          },
        ],
      });
      expect(s.totalMilestones, 2);
      expect(s.achievedMilestones, 1);
    });

    test('handles milestone stats with fallbackMilestone', () {
      final s = snapshot(
        {},
        fallbackMilestone: 'Initiation Completed',
      );
      expect(s.totalMilestones, 1);
      expect(s.achievedMilestones, 1); // "Completed" is detected
    });

    test('resolves phase from status', () {
      expect(snapshot({}, fallbackStatus: 'Execution').currentPhase,
          'Execution');
      expect(snapshot({}, fallbackStatus: 'Planning').currentPhase,
          'Planning');
      expect(snapshot({}, fallbackStatus: 'Initiation').currentPhase,
          'Initiation');
      expect(snapshot({}, fallbackStatus: 'Design').currentPhase, 'Design');
      expect(snapshot({}, fallbackStatus: 'Launch').currentPhase, 'Launch');
      expect(snapshot({}, fallbackStatus: 'Completed').currentPhase,
          'Completed');
    });

    test('resolves phase from checkpointRoute when status is empty', () {
      expect(
        snapshot({},
                fallbackStatus: '',
                checkpointRoute: 'fep_procurement')
            .currentPhase,
        'Front End Planning',
      );
      expect(
        snapshot({},
                fallbackStatus: '',
                checkpointRoute: 'execution_progress_tracking')
            .currentPhase,
        'Execution',
      );
      expect(
        snapshot({},
                fallbackStatus: '',
                checkpointRoute: 'design_phase')
            .currentPhase,
        'Design',
      );
      expect(
        snapshot({},
                fallbackStatus: '',
                checkpointRoute: 'close_out')
            .currentPhase,
        'Close-out',
      );
    });

    test('resolves phase from activity phaseCandidates', () {
      final s = snapshot({
        'projectActivities': [
          {'title': 'A1', 'phase': 'Execution'},
        ],
      }, fallbackStatus: '');
      expect(s.currentPhase, 'Execution');
    });

    test('computes health correctly', () {
      // 100% completion → completed
      expect(
        snapshot({
          'projectActivities': [
            {'title': 'A1', 'status': 'Implemented'},
          ],
        }).health,
        ProjectProgressHealth.completed,
      );

      // 0% with pending → in progress or behind
      final s = snapshot({
        'projectActivities': [
          {'title': 'A1', 'status': 'Pending'},
        ],
      });
      expect(s.health, anyOf(ProjectProgressHealth.inProgress,
          ProjectProgressHealth.behind));
    });
  });

  group('ProjectProgressSnapshot with very long string fields', () {
    /// These lengths match the N values seen in production errors.
    /// They ensure that none of the parsing helpers trigger a RangeError
    /// when given strings of these lengths.
    test('handles long activity titles and descriptions', () {
      for (final length in [58, 60, 66, 68, 75, 76, 77, 80, 81, 85, 89, 94, 95, 99, 107, 110, 113, 117]) {
        final longStr = 'x' * length;
        final s = ProjectProgressSnapshot.fromRaw(
          source: {
            'projectActivities': [
              {'title': longStr, 'description': longStr, 'phase': 'Execution'},
            ],
          },
          fallbackStatus: '',
          fallbackProgress: 0.0,
          fallbackMilestone: '',
          checkpointRoute: '',
        );
        expect(s.totalActivities, 1);
        // With empty fallbackStatus and empty checkpointRoute, phase comes
        // from the activity's phaseCandidates.
        expect(s.currentPhase, 'Execution');
      }
    });

    test('handles long milestone names', () {
      for (final length in [58, 60, 66, 68, 75, 76, 77, 80, 81, 85, 89, 94, 95, 99, 107, 110, 113, 117]) {
        final longStr = 'x' * length;
        final s = ProjectProgressSnapshot.fromRaw(
          source: {
            'keyMilestones': [
              {'name': longStr, 'completed': true},
            ],
          },
          fallbackStatus: 'Initiation',
          fallbackProgress: 0.0,
          fallbackMilestone: '',
          checkpointRoute: '',
        );
        expect(s.totalMilestones, 1);
        expect(s.achievedMilestones, 1);
      }
    });
  });
}

/// Minimal fake of DocumentSnapshot for testing — only the fields
/// actually used by ProjectRecord.fromDoc.
class _FakeDocSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocSnapshot({required this.id, Map<String, dynamic>? data})
      : _data = data;

  @override
  final String id;

  final Map<String, dynamic>? _data;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => _data != null;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    // Satisfy the rest of the abstract interface without implementing
    // every property.
    return super.noSuchMethod(invocation);
  }
}
