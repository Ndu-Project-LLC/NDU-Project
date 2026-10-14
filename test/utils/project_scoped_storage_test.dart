import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/utils/project_scoped_storage.dart';

void main() {
  group('projectScopedPrefsKey', () {
    test('namespaces the key by project id', () {
      expect(
        projectScopedPrefsKey('ndu_cost_estimate_v2', 'proj-a'),
        'ndu_cost_estimate_v2_project_proj-a',
      );
    });

    test('falls back to the default scope for an empty project id', () {
      expect(
        projectScopedPrefsKey('ndu_schedule_v2', ''),
        'ndu_schedule_v2_project_default',
      );
      expect(
        projectScopedPrefsKey('ndu_schedule_v2', '   '),
        'ndu_schedule_v2_project_default',
      );
    });

    test('two projects never share a key', () {
      expect(
        projectScopedPrefsKey('ndu_schedule_v2', 'a'),
        isNot(projectScopedPrefsKey('ndu_schedule_v2', 'b')),
      );
    });
  });

  group('legacyRecordBelongsToProject', () {
    test('adopts a record that names this exact project', () {
      expect(
        legacyRecordBelongsToProject(
          projectId: 'proj-a',
          projectName: 'Chipata Road',
          legacyProjectId: 'proj-a',
          legacyProjectName: 'Something else',
        ),
        isTrue,
      );
    });

    test('adopts a pre-scoping record for the project whose name it carries',
        () {
      // Records written before ids were persisted all say `'default'`, so the
      // captured project name is the only signal left.
      expect(
        legacyRecordBelongsToProject(
          projectId: 'proj-a',
          projectName: '  Chipata Road ',
          legacyProjectId: 'default',
          legacyProjectName: 'chipata road',
        ),
        isTrue,
      );
      expect(
        legacyRecordBelongsToProject(
          projectId: 'proj-a',
          projectName: 'Chipata Road',
          legacyProjectId: null,
          legacyProjectName: 'Chipata Road',
        ),
        isTrue,
      );
    });

    test("never adopts another project's record", () {
      expect(
        legacyRecordBelongsToProject(
          projectId: 'proj-b',
          projectName: 'Lusaka Bridge',
          legacyProjectId: 'proj-a',
          legacyProjectName: 'Chipata Road',
        ),
        isFalse,
      );
      expect(
        legacyRecordBelongsToProject(
          projectId: 'proj-b',
          projectName: 'Lusaka Bridge',
          legacyProjectId: 'default',
          legacyProjectName: 'Chipata Road',
        ),
        isFalse,
      );
    });

    test('does not adopt when the record cannot be attributed', () {
      expect(
        legacyRecordBelongsToProject(
          projectId: 'proj-a',
          projectName: null,
          legacyProjectId: null,
          legacyProjectName: null,
        ),
        isFalse,
      );
      expect(
        legacyRecordBelongsToProject(
          projectId: 'proj-a',
          projectName: 'Chipata Road',
          legacyProjectId: 'default',
          legacyProjectName: '',
        ),
        isFalse,
      );
    });

    test('no active project means nothing may be adopted', () {
      expect(
        legacyRecordBelongsToProject(
          projectId: '',
          projectName: 'Chipata Road',
          legacyProjectId: 'default',
          legacyProjectName: 'Chipata Road',
        ),
        isFalse,
      );
      expect(
        legacyRecordBelongsToProject(
          projectId: 'default',
          projectName: 'Chipata Road',
          legacyProjectId: 'default',
          legacyProjectName: 'Chipata Road',
        ),
        isFalse,
      );
    });
  });
}
