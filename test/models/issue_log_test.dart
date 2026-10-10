// Lusaka 27 review, naming the tables:
//
//   "M-L-O-G is all these tables … this procurement table now [can] be called a
//    procurement log. The contract table can be called a contract log. The
//    issues management table can be called an issues log."
//   "all our tables should be numbered"
//
// One pure module owns the issue log columns, the row mapping and the overview
// numbers, so the log table and the Issues Overview card above it cannot report
// different things.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/issue_log.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/execution_service.dart';

IssueLogItem _item({
  String id = 'ISS-001',
  String title = 'Permit approval pending',
  String description = 'The council has not signed off the permit',
  String type = 'Schedule',
  String severity = 'High',
  String status = 'Open',
  String assignee = 'A. Banda',
  String dueDate = 'Mar 12, 2026',
  String milestone = 'Design freeze',
}) {
  return IssueLogItem(
    id: id,
    title: title,
    description: description,
    type: type,
    severity: severity,
    status: status,
    assignee: assignee,
    dueDate: dueDate,
    milestone: milestone,
  );
}

void main() {
  group('columns', () {
    test('are numbered first and read as the issue log', () {
      expect(issueLogColumns.first.key, 'number');
      expect(issueLogColumns.first.label, '#');
    });

    test('carry the issue, its type/severity/status, owner and dates', () {
      expect(
        issueLogColumns.map((c) => c.label),
        containsAll(<String>[
          'ID',
          'Issue',
          'Type',
          'Severity',
          'Status',
          'Assignee',
          'Due Date',
          'Milestone',
        ]),
      );
    });

    test('columnLabels and a row values line up', () {
      final row = IssueLogRow.fromItem(_item(), number: 1);
      expect(IssueLogRow.columnLabels.length, issueLogColumns.length);
      expect(row.values.length, issueLogColumns.length);
      expect(row.values.first, '1');
      expect(row.values[1], 'ISS-001');
    });
  });

  group('row', () {
    test('numbers the row and carries every field', () {
      final row = IssueLogRow.fromItem(_item(), number: 7);
      expect(row.number, 7);
      expect(row.valueFor('number'), '7');
      expect(row.valueFor('id'), 'ISS-001');
      expect(row.valueFor('title'), 'Permit approval pending');
      expect(row.valueFor('type'), 'Schedule');
      expect(row.valueFor('severity'), 'High');
      expect(row.valueFor('status'), 'Open');
      expect(row.valueFor('assignee'), 'A. Banda');
      expect(row.valueFor('dueDate'), 'Mar 12, 2026');
      expect(row.valueFor('milestone'), 'Design freeze');
    });

    test('fills the blanks instead of showing empty cells', () {
      final row = IssueLogRow.fromItem(
        _item(
          id: '  ',
          title: '  ',
          type: '',
          severity: '',
          status: '',
          assignee: '',
          dueDate: '',
          milestone: '',
        ),
        number: 2,
      );
      expect(row.valueFor('id'), '—');
      expect(row.valueFor('title'), 'Untitled issue');
      expect(row.valueFor('type'), 'Other');
      expect(row.valueFor('severity'), 'Medium');
      expect(row.valueFor('status'), 'Open');
      expect(row.valueFor('assignee'), 'Unassigned');
      expect(row.valueFor('dueDate'), 'No due date');
      expect(row.valueFor('milestone'), 'Unassigned');
    });

    test('an unknown column key is blank, not an exception', () {
      final row = IssueLogRow.fromItem(_item(), number: 1);
      expect(row.valueFor('nope'), '');
    });

    test('classifies open, in progress and resolved', () {
      expect(IssueLogRow.fromItem(_item(), number: 1).isOpen, isTrue);
      expect(
        IssueLogRow.fromItem(_item(status: 'In Progress'), number: 1)
            .isInProgress,
        isTrue,
      );
      expect(
        IssueLogRow.fromItem(_item(status: 'Resolved'), number: 1).isResolved,
        isTrue,
      );
      expect(
        IssueLogRow.fromItem(_item(status: 'Closed'), number: 1).isResolved,
        isTrue,
      );
      expect(
        IssueLogRow.fromItem(_item(status: 'in progress'), number: 1)
            .isInProgress,
        isTrue,
      );
    });

    test('matches search over the fields a user can see', () {
      final row = IssueLogRow.fromItem(_item(), number: 1);
      expect(row.matches(''), isTrue);
      expect(row.matches('permit'), isTrue);
      expect(row.matches('banda'), isTrue);
      expect(row.matches('design freeze'), isTrue);
      expect(row.matches('ISS-001'), isTrue);
      expect(row.matches('nothing here'), isFalse);
    });
  });

  group('the PDF export table', () {
    test('headers are the log columns, in order', () {
      expect(issueLogExportHeaders(), IssueLogRow.columnLabels);
      expect(issueLogExportHeaders().length, issueLogColumns.length);
      expect(issueLogExportHeaders().first, '#');
    });

    test('one numbered row per logged issue, in column order', () {
      final rows = issueLogExportRows(<IssueLogItem>[
        _item(id: 'ISS-001', title: 'Permit approval pending'),
        _item(id: 'ISS-002', title: 'Steel delivery late'),
      ]);
      expect(rows.length, 2);
      expect(rows.every((r) => r.length == issueLogColumns.length), isTrue,
          reason: 'every row must line up with the header');
      expect(rows.map((r) => r.first), ['1', '2']);
      expect(rows[1][1], 'ISS-002');
      expect(rows[1][2], 'Steel delivery late');
    });

    test('an empty log exports no rows', () {
      expect(issueLogExportRows(const []), isEmpty);
    });
  });

  group('summary', () {
    test('is empty with no issues', () {
      expect(IssueLogSummary.fromItems(const []), IssueLogSummary.empty);
      expect(IssueLogSummary.empty.isEmpty, isTrue);
    });

    test('counts open, in progress and resolved the way the log classifies',
        () {
      final summary = IssueLogSummary.fromItems(<IssueLogItem>[
        _item(id: '1', status: 'Open'),
        _item(id: '2', status: 'Open'),
        _item(id: '3', status: 'In Progress'),
        _item(id: '4', status: 'Resolved'),
        _item(id: '5', status: 'Closed'),
        _item(id: '6', status: ''),
      ]);
      expect(summary.total, 6);
      expect(summary.open, 3);
      expect(summary.inProgress, 1);
      expect(summary.resolved, 2);
    });
  });

  group('one log, two stores (planning ↔ execution)', () {
    ExecutionIssueModel exec({
      String id = 'x1',
      String topic = 'Tower crane breakdown',
      String description = 'Crane hydraulic line failed on site',
      String discipline = 'Engineering',
      String raisedBy = 'Site Engineer',
      bool approved = false,
      String comments = 'Severity: High, Status: Open',
    }) {
      return ExecutionIssueModel(
        id: id,
        projectId: 'p1',
        issueTopic: topic,
        description: description,
        discipline: discipline,
        raisedBy: raisedBy,
        scheduleImpact: '2 weeks',
        costImpact: r'$5,000',
        approved: approved,
        comments: comments,
        createdById: 'u1',
        createdByEmail: 'u1@example.com',
        createdByName: 'U1',
        createdAt: DateTime(2026, 1, 2),
        updatedAt: DateTime(2026, 1, 2),
      );
    }

    test('an execution issue maps onto a planning log row', () {
      final item = issueLogItemFromExecution(exec());
      expect(item.id, 'exec_x1');
      expect(item.title, 'Tower crane breakdown');
      expect(item.description, 'Crane hydraulic line failed on site');
      expect(item.type, 'Engineering');
      expect(item.severity, 'High');
      expect(item.status, 'Open');
      expect(item.assignee, 'Site Engineer');
      // Rendered with the log's defaults where the execution store carries
      // no field.
      final row = IssueLogRow.fromItem(item, number: 1);
      expect(row.valueFor('dueDate'), 'No due date');
      expect(row.valueFor('milestone'), 'Unassigned');
    });

    test('approved without a status comment reads as resolved', () {
      final item = issueLogItemFromExecution(
        exec(approved: true, comments: 'Closed out on site'),
      );
      expect(item.status, 'Resolved');
      expect(item.severity, isEmpty);
    });

    test('id helpers round-trip and leave native rows alone', () {
      expect(executionDocIdForPlanningItem('ISS-9'), 'plan_ISS-9');
      expect(planningItemIdFromExecutionDocId('plan_ISS-9'), 'ISS-9');
      expect(planningItemIdFromExecutionDocId('x1'), isNull);
      expect(viewIdForExecutionIssue('x1'), 'exec_x1');
      expect(executionDocIdFromViewId('exec_x1'), 'x1');
      expect(executionDocIdFromViewId('ISS-001'), isNull);
    });

    test('a linked copy is not shown twice while the planning row exists', () {
      final merged = mergeIssueLogViews(
        planning: <IssueLogItem>[_item(id: 'ISS-9')],
        execution: <ExecutionIssueModel>[
          exec(id: 'plan_ISS-9', topic: _item(id: 'ISS-9').title),
          exec(),
        ],
      );
      expect(merged.map((i) => i.id), ['ISS-9', 'exec_x1']);
    });

    test('an orphaned linked copy still shows, so nothing is lost', () {
      final merged = mergeIssueLogViews(
        planning: const <IssueLogItem>[],
        execution: <ExecutionIssueModel>[
          exec(id: 'plan_ISS-9', topic: 'Permit approval pending'),
        ],
      );
      expect(merged.single.id, 'exec_plan_ISS-9');
      expect(merged.single.title, 'Permit approval pending');
    });

    test('planning rows keep their order and execution rows follow', () {
      final merged = mergeIssueLogViews(
        planning: <IssueLogItem>[
          _item(id: 'ISS-1'),
          _item(id: 'ISS-2'),
        ],
        execution: <ExecutionIssueModel>[exec(id: 'a'), exec(id: 'b')],
      );
      expect(merged.map((i) => i.id), ['ISS-1', 'ISS-2', 'exec_a', 'exec_b']);
    });

    test('comment meta is rewritten in place, not clobbered', () {
      expect(
        upsertExecutionCommentMeta(
          'Severity: Low, Status: Open',
          severity: 'High',
          status: 'Resolved',
        ),
        'Severity: High, Status: Resolved',
      );
      expect(
        upsertExecutionCommentMeta(
          'Follow up with authorities',
          severity: 'High',
          status: 'Open',
        ),
        'Follow up with authorities, Severity: High, Status: Open',
      );
      expect(
        upsertExecutionCommentMeta('', severity: 'High', status: 'Open'),
        'Severity: High, Status: Open',
      );
    });
  });
}
