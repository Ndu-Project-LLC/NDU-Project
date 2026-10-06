import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/project_controls/providers/change_management_provider.dart';

void main() {
  group('resolveChangeManagementAuditActor', () {
    test('uses the current email for the legacy placeholder', () {
      expect(
        resolveChangeManagementAuditActor(
          'you@ndu.project',
          'person@example.com',
        ),
        'person@example.com',
      );
    });

    test('uses the current email when the stored actor is missing', () {
      expect(
        resolveChangeManagementAuditActor(null, 'person@example.com'),
        'person@example.com',
      );
      expect(
        resolveChangeManagementAuditActor('', 'person@example.com'),
        'person@example.com',
      );
    });

    test('preserves a named historical actor', () {
      expect(
        resolveChangeManagementAuditActor('Sarah Chen', 'person@example.com'),
        'Sarah Chen',
      );
    });

    test('uses Unknown user when no authenticated email is available', () {
      expect(
        resolveChangeManagementAuditActor('you@ndu.project', ''),
        'Unknown user',
      );
    });
  });
}
