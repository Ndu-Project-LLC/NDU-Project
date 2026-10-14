// Tests for change-request supporting documents (Section E of the Create CR
// form). The upload itself needs Firebase Storage, but everything the app
// does with a document afterwards — carrying it on the CR, serializing it to
// Firestore, and surviving a status change — is pure and covered here.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/project_controls/models/change_management_models.dart';
import 'package:ndu_project/project_controls/providers/change_management_provider.dart';

final _quote = CMAttachment(
  id: 'att_1',
  name: 'vendor-quote.pdf',
  downloadUrl: 'https://storage.example/vendor-quote.pdf',
  storagePath: 'projects/proj_1/change_requests/1737000000_vendor-quote.pdf',
  sizeBytes: 2048,
  uploadedAt: DateTime(2026, 9, 10, 15, 56),
);

String _createCrWith(ChangeManagementProvider provider,
    List<CMAttachment> attachments) {
  return provider.createChangeRequest(
    title: 'Swap pump model',
    description: 'Vendor discontinued the specified pump.',
    changeType: CMChangeType.scope,
    priority: CMPriority.medium,
    businessJustification: 'Continuity of supply.',
    attachments: attachments,
  );
}

void main() {
  group('change request attachments', () {
    test('createChangeRequest carries the uploaded documents', () {
      final provider = ChangeManagementProvider();
      final crId = _createCrWith(provider, [_quote]);

      final cr = provider.changeRequests.firstWhere((c) => c.id == crId);
      expect(cr.attachments, hasLength(1));
      expect(cr.attachments.first.name, 'vendor-quote.pdf');
      expect(cr.attachments.first.downloadUrl, _quote.downloadUrl);
    });

    test('a change request with no documents stays empty', () {
      final provider = ChangeManagementProvider();
      final crId = _createCrWith(provider, const []);

      final cr = provider.changeRequests.firstWhere((c) => c.id == crId);
      expect(cr.attachments, isEmpty);
    });

    test('attachments survive an unrelated field change', () {
      final provider = ChangeManagementProvider();
      final crId = _createCrWith(provider, [_quote]);
      final cr = provider.changeRequests.firstWhere((c) => c.id == crId);

      final updated = cr.copyWith(title: 'Swap pump model (rev 2)');

      expect(updated.title, 'Swap pump model (rev 2)');
      expect(updated.attachments, hasLength(1));
      expect(updated.attachments.first.id, _quote.id);
    });

    test('round-trips through JSON exactly as Firestore stores it', () {
      final restored = CMAttachment.fromJson(_quote.toJson());

      expect(restored.id, _quote.id);
      expect(restored.name, _quote.name);
      expect(restored.downloadUrl, _quote.downloadUrl);
      expect(restored.storagePath, _quote.storagePath);
      expect(restored.sizeBytes, _quote.sizeBytes);
      expect(restored.uploadedAt, _quote.uploadedAt);
    });

    test('tolerates a legacy document with missing fields', () {
      final restored = CMAttachment.fromJson(const {'name': 'old.pdf'});

      expect(restored.name, 'old.pdf');
      expect(restored.downloadUrl, isEmpty);
      expect(restored.sizeBytes, 0);
    });
  });
}
