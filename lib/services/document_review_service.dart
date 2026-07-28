import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/models/document_review_models.dart';
import 'package:flutter/material.dart';

/// Service for managing document review and approval workflow
class DocumentReviewService {
  DocumentReviewService._();
  static final DocumentReviewService instance = DocumentReviewService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Collection reference for document review items
  CollectionReference get _reviewCollection => FirebaseFirestore.instance
      .collection('document_reviews'); // Top-level collection for cross-project access

  /// Initialize document review matrix for a project from templates
  Future<void> initializeForProject(String projectId) async {
    final existingDoc = await _reviewCollection.doc(projectId).get();
    if (existingDoc.exists) return; // Already initialized

    final templates = DocumentTemplates.allTemplates;
    final reviewItems = templates.map((t) => t.createReviewItem()).toList();

    await _reviewCollection.doc(projectId).set({
      'projectId': projectId,
      'reviewItems': reviewItems.map((e) => e.toJson()).toList(),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  /// Load all document review items for a project
  Future<List<DocumentReviewItem>> loadDocumentReviewMatrix(
      String projectId) async {
    try {
      final doc = await _reviewCollection.doc(projectId).get();
      if (!doc.exists) {
        // Initialize if not exists
        await initializeForProject(projectId);
        final newDoc = await _reviewCollection.doc(projectId).get();
        if (newDoc.exists && newDoc.data() != null) {
          final data = newDoc.data()! as Map<String, dynamic>;
          final itemsJson = data['reviewItems'] as List?;
          if (itemsJson != null) {
            return itemsJson
                .map((e) =>
                    DocumentReviewItem.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
        return [];
      }

      final data = doc.data()! as Map<String, dynamic>;
      final itemsJson = data['reviewItems'] as List?;
      if (itemsJson == null) return [];

      return itemsJson
          .map((e) => DocumentReviewItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading document review matrix: $e');
      return [];
    }
  }

  /// Save the entire document review matrix
  Future<bool> saveDocumentReviewMatrix({
    required String projectId,
    required List<DocumentReviewItem> reviewItems,
  }) async {
    try {
      await _reviewCollection.doc(projectId).set({
        'projectId': projectId,
        'reviewItems': reviewItems.map((e) => e.toJson()).toList(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error saving document review matrix: $e');
      return false;
    }
  }

  /// Assign a reviewer to a document
  Future<bool> assignReviewer({
    required String projectId,
    required String reviewItemId,
    required String reviewerId,
    required String reviewerName,
    required ReviewerRole role,
  }) async {
    try {
      final items = await loadDocumentReviewMatrix(projectId);
      final index = items.indexWhere((item) => item.id == reviewItemId);
      if (index == -1) return false;

      final item = items[index];
      DocumentReviewItem updated;

      switch (role) {
        case ReviewerRole.primary:
          updated = item.copyWith(
            primaryReviewerId: reviewerId,
            primaryReviewerName: reviewerName,
            status: ReviewStatus.pendingReview,
          );
          break;
        case ReviewerRole.secondary:
          updated = item.copyWith(
            secondaryReviewerId: reviewerId,
            secondaryReviewerName: reviewerName,
          );
          break;
        case ReviewerRole.approver:
          updated = item.copyWith(
            finalApproverId: reviewerId,
            finalApproverName: reviewerName,
          );
          break;
      }

      // Add history entry
      final historyEntry = ReviewHistoryEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        reviewerId: _userId,
        reviewerName: reviewerName,
        reviewerRole: role.name,
        action: ReviewAction.assigned,
        timestamp: DateTime.now(),
      );
      updated = updated.addHistoryEntry(historyEntry);

      items[index] = updated;
      return await saveDocumentReviewMatrix(
        projectId: projectId,
        reviewItems: items,
      );
    } catch (e) {
      debugPrint('Error assigning reviewer: $e');
      return false;
    }
  }

  /// Submit a review with comments
  Future<bool> submitReview({
    required String projectId,
    required String reviewItemId,
    required String reviewerId,
    required String reviewerName,
    required String reviewerRole,
    required ReviewAction action,
    String? comments,
  }) async {
    try {
      final items = await loadDocumentReviewMatrix(projectId);
      final index = items.indexWhere((item) => item.id == reviewItemId);
      if (index == -1) return false;

      final item = items[index];
      DocumentReviewItem updated = item;

      // Update status based on action
      switch (action) {
        case ReviewAction.underReview:
          updated = item.copyWith(status: ReviewStatus.underReview);
          break;
        case ReviewAction.approved:
          // Check if this is final approval
          if (item.finalApproverId == reviewerId) {
            updated = item.copyWith(
              status: ReviewStatus.approved,
              approvedDate: DateTime.now(),
              version: item.version + 1,
            );
          } else {
            // Primary or secondary reviewer approved
            updated = item.copyWith(status: ReviewStatus.underReview);
          }
          break;
        case ReviewAction.rejected:
          updated = item.copyWith(status: ReviewStatus.rejected);
          break;
        case ReviewAction.changesRequested:
          updated = item.copyWith(status: ReviewStatus.changesRequested);
          break;
        case ReviewAction.comment:
          // Don't change status for comments
          break;
        default:
          break;
      }

      // Add review comments
      if (comments != null && comments.isNotEmpty) {
        final existingComments = updated.reviewComments ?? '';
        final newComment =
            '$reviewerName ($reviewerRole): $comments\n\n$existingComments';
        updated = updated.copyWith(reviewComments: newComment);
      }

      // Add history entry
      final historyEntry = ReviewHistoryEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        reviewerId: reviewerId,
        reviewerName: reviewerName,
        reviewerRole: reviewerRole,
        action: action,
        comments: comments,
        timestamp: DateTime.now(),
      );
      updated = updated.addHistoryEntry(historyEntry);

      items[index] = updated;
      return await saveDocumentReviewMatrix(
        projectId: projectId,
        reviewItems: items,
      );
    } catch (e) {
      debugPrint('Error submitting review: $e');
      return false;
    }
  }

  /// Approve a document
  Future<bool> approveDocument({
    required String projectId,
    required String reviewItemId,
    required String reviewerId,
    required String reviewerName,
    required String reviewerRole,
    String? comments,
  }) async {
    return await submitReview(
      projectId: projectId,
      reviewItemId: reviewItemId,
      reviewerId: reviewerId,
      reviewerName: reviewerName,
      reviewerRole: reviewerRole,
      action: ReviewAction.approved,
      comments: comments,
    );
  }

  /// Reject a document
  Future<bool> rejectDocument({
    required String projectId,
    required String reviewItemId,
    required String reviewerId,
    required String reviewerName,
    required String reviewerRole,
    required String reason,
  }) async {
    return await submitReview(
      projectId: projectId,
      reviewItemId: reviewItemId,
      reviewerId: reviewerId,
      reviewerName: reviewerName,
      reviewerRole: reviewerRole,
      action: ReviewAction.rejected,
      comments: reason,
    );
  }

  /// Request changes for a document
  Future<bool> requestChanges({
    required String projectId,
    required String reviewItemId,
    required String reviewerId,
    required String reviewerName,
    required String reviewerRole,
    required String requestedChanges,
  }) async {
    return await submitReview(
      projectId: projectId,
      reviewItemId: reviewItemId,
      reviewerId: reviewerId,
      reviewerName: reviewerName,
      reviewerRole: reviewerRole,
      action: ReviewAction.changesRequested,
      comments: requestedChanges,
    );
  }

  /// Get pending reviews for a specific reviewer
  Future<List<DocumentReviewItem>> getPendingReviewsForReviewer({
    required String projectId,
    required String reviewerId,
  }) async {
    final allItems = await loadDocumentReviewMatrix(projectId);
    return allItems.where((item) {
      // Check if this user is a reviewer and the document is pending/under review
      final isReviewer = item.primaryReviewerId == reviewerId ||
          item.secondaryReviewerId == reviewerId ||
          item.finalApproverId == reviewerId;
      final isPending = item.status == ReviewStatus.pendingReview ||
          item.status == ReviewStatus.underReview;
      return isReviewer && isPending;
    }).toList();
  }

  /// Get all documents that are pending review
  Future<List<DocumentReviewItem>> getPendingReviews(String projectId) async {
    final allItems = await loadDocumentReviewMatrix(projectId);
    return allItems.where((item) {
      return item.status == ReviewStatus.pendingReview ||
          item.status == ReviewStatus.underReview;
    }).toList();
  }

  /// Get documents by category
  Future<List<DocumentReviewItem>> getDocumentsByCategory({
    required String projectId,
    required DocumentCategory category,
  }) async {
    final allItems = await loadDocumentReviewMatrix(projectId);
    return allItems.where((item) => item.category == category).toList();
  }

  /// Get documents by phase
  Future<List<DocumentReviewItem>> getDocumentsByPhase({
    required String projectId,
    required DocumentPhase phase,
  }) async {
    final allItems = await loadDocumentReviewMatrix(projectId);
    return allItems.where((item) => item.phase == phase).toList();
  }

  /// Get documents by status
  Future<List<DocumentReviewItem>> getDocumentsByStatus({
    required String projectId,
    required ReviewStatus status,
  }) async {
    final allItems = await loadDocumentReviewMatrix(projectId);
    return allItems.where((item) => item.status == status).toList();
  }

  /// Get overdue documents
  Future<List<DocumentReviewItem>> getOverdueDocuments(String projectId) async {
    final allItems = await loadDocumentReviewMatrix(projectId);
    return allItems.where((item) => item.isOverdue).toList();
  }

  /// Mark a document for re-review when source changes
  Future<bool> markForRereview({
    required String projectId,
    required String documentId,
  }) async {
    try {
      final items = await loadDocumentReviewMatrix(projectId);
      final index = items.indexWhere((item) => item.documentId == documentId);
      if (index == -1) return false;

      final item = items[index];
      final updated = item.copyWith(
        requiresRereview: true,
        status: ReviewStatus.pendingReview,
      );

      items[index] = updated;
      return await saveDocumentReviewMatrix(
        projectId: projectId,
        reviewItems: items,
      );
    } catch (e) {
      debugPrint('Error marking for re-review: $e');
      return false;
    }
  }

  /// Set review due date
  Future<bool> setReviewDueDate({
    required String projectId,
    required String reviewItemId,
    required DateTime dueDate,
  }) async {
    try {
      final items = await loadDocumentReviewMatrix(projectId);
      final index = items.indexWhere((item) => item.id == reviewItemId);
      if (index == -1) return false;

      final item = items[index];
      final updated = item.copyWith(reviewDueDate: dueDate);

      items[index] = updated;
      return await saveDocumentReviewMatrix(
        projectId: projectId,
        reviewItems: items,
      );
    } catch (e) {
      debugPrint('Error setting review due date: $e');
      return false;
    }
  }

  /// Bulk assign reviewers
  Future<bool> bulkAssignReviewers({
    required String projectId,
    required List<String> reviewItemIds,
    required String reviewerId,
    required String reviewerName,
    required ReviewerRole role,
  }) async {
    try {
      final items = await loadDocumentReviewMatrix(projectId);

      for (var i = 0; i < items.length; i++) {
        if (reviewItemIds.contains(items[i].id)) {
          DocumentReviewItem updated;

          switch (role) {
            case ReviewerRole.primary:
              updated = items[i].copyWith(
                primaryReviewerId: reviewerId,
                primaryReviewerName: reviewerName,
                status: ReviewStatus.pendingReview,
              );
              break;
            case ReviewerRole.secondary:
              updated = items[i].copyWith(
                secondaryReviewerId: reviewerId,
                secondaryReviewerName: reviewerName,
              );
              break;
            case ReviewerRole.approver:
              updated = items[i].copyWith(
                finalApproverId: reviewerId,
                finalApproverName: reviewerName,
              );
              break;
          }

          items[i] = updated;
        }
      }

      return await saveDocumentReviewMatrix(
        projectId: projectId,
        reviewItems: items,
      );
    } catch (e) {
      debugPrint('Error bulk assigning reviewers: $e');
      return false;
    }
  }

  /// Get review statistics
  Future<DocumentReviewStatistics> getStatistics(String projectId) async {
    final items = await loadDocumentReviewMatrix(projectId);

    final total = items.length;
    final notStarted =
        items.where((i) => i.status == ReviewStatus.notStarted).length;
    final pendingReview =
        items.where((i) => i.status == ReviewStatus.pendingReview).length;
    final underReview =
        items.where((i) => i.status == ReviewStatus.underReview).length;
    final changesRequested = items
        .where((i) => i.status == ReviewStatus.changesRequested)
        .length;
    final approved =
        items.where((i) => i.status == ReviewStatus.approved).length;
    final rejected =
        items.where((i) => i.status == ReviewStatus.rejected).length;
    final overdue = items.where((i) => i.isOverdue).length;
    final needsRereview = items.where((i) => i.needsRereview).length;

    return DocumentReviewStatistics(
      total: total,
      notStarted: notStarted,
      pendingReview: pendingReview,
      underReview: underReview,
      changesRequested: changesRequested,
      approved: approved,
      rejected: rejected,
      overdue: overdue,
      needsRereview: needsRereview,
      completionPercent: total > 0 ? (approved / total) * 100 : 0,
    );
  }

  /// Find review item by document ID
  Future<DocumentReviewItem?> findByDocumentId({
    required String projectId,
    required String documentId,
  }) async {
    final items = await loadDocumentReviewMatrix(projectId);
    for (final item in items) {
      if (item.documentId == documentId) return item;
    }
    return null;
  }
}

/// Reviewer role for assignment
enum ReviewerRole {
  primary,
  secondary,
  approver,
}

/// Statistics for document review matrix
class DocumentReviewStatistics {
  final int total;
  final int notStarted;
  final int pendingReview;
  final int underReview;
  final int changesRequested;
  final int approved;
  final int rejected;
  final int overdue;
  final int needsRereview;
  final double completionPercent;

  const DocumentReviewStatistics({
    required this.total,
    this.notStarted = 0,
    this.pendingReview = 0,
    this.underReview = 0,
    this.changesRequested = 0,
    this.approved = 0,
    this.rejected = 0,
    this.overdue = 0,
    this.needsRereview = 0,
    required this.completionPercent,
  });

  int get pending => pendingReview + underReview;
  int get completed => approved;
  int get active => total - rejected;

  Map<String, int> toMap() => {
        'total': total,
        'notStarted': notStarted,
        'pendingReview': pendingReview,
        'underReview': underReview,
        'changesRequested': changesRequested,
        'approved': approved,
        'rejected': rejected,
        'overdue': overdue,
        'needsRereview': needsRereview,
        'completionPercent': completionPercent.round(),
      };
}
