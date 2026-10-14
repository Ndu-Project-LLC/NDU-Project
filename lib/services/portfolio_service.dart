import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/portfolio_model.dart';

class PortfolioService {
  static final CollectionReference<Map<String, dynamic>> _portfoliosCol =
      FirebaseFirestore.instance.collection('portfolios');

  /// Creates a new portfolio.
  ///
  /// [name] — portfolio display name (required).
  /// [projectIds] — Firestore project doc IDs grouped into this portfolio.
  /// [ownerId] — Firebase Auth uid of the portfolio owner (account owner).
  /// [managerId] — optional Firebase Auth uid of the assigned portfolio
  /// manager. Picked from the account's registered users via the
  /// create-portfolio modal's dropdown.
  /// [managerName] / [managerEmail] — denormalized manager fields so the
  /// dashboard card doesn't have to join against the users collection.
  static Future<String> createPortfolio({
    required String name,
    required List<String> projectIds,
    required String ownerId,
    String managerId = '',
    String managerName = '',
    String managerEmail = '',
  }) async {
    try {
      final docRef = await _portfoliosCol.add({
        'name': name,
        'projectIds': projectIds,
        'ownerId': ownerId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'Active',
        if (managerId.isNotEmpty) 'managerId': managerId,
        if (managerName.isNotEmpty) 'managerName': managerName,
        if (managerEmail.isNotEmpty) 'managerEmail': managerEmail,
      });
      debugPrint('✅ Portfolio created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating portfolio: $e');
      rethrow;
    }
  }

  static Stream<List<PortfolioModel>> streamPortfolios(
      {required String ownerId}) {
    return _portfoliosCol
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final portfolios = <PortfolioModel>[];
      for (final doc in snapshot.docs) {
        try {
          if (doc.exists) {
            portfolios.add(PortfolioModel.fromFirestore(doc));
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing portfolio ${doc.id}: $e');
        }
      }
      return portfolios;
    });
  }

  static Future<PortfolioModel?> getPortfolio(String portfolioId) async {
    try {
      final doc = await _portfoliosCol.doc(portfolioId).get();
      if (!doc.exists) return null;
      return PortfolioModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ Error fetching portfolio: $e');
      return null;
    }
  }

  static Future<void> updatePortfolio(
      String portfolioId, Map<String, dynamic> data) async {
    try {
      await _portfoliosCol.doc(portfolioId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Portfolio updated: $portfolioId');
    } catch (e) {
      debugPrint('❌ Error updating portfolio: $e');
      rethrow;
    }
  }

  /// Assigns a portfolio manager to the given portfolio.
  ///
  /// Used by the create-portfolio modal (Task 13) — the user picks a
  /// registered user from a dropdown of account members, and we write
  /// their uid + denormalized name + email so the dashboard card can
  /// display the assignment without joining collections.
  static Future<void> assignManager({
    required String portfolioId,
    required String managerId,
    required String managerName,
    required String managerEmail,
  }) async {
    try {
      await _portfoliosCol.doc(portfolioId).update({
        'managerId': managerId,
        'managerName': managerName,
        'managerEmail': managerEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Portfolio manager assigned: $portfolioId → $managerName');
    } catch (e) {
      debugPrint('❌ Error assigning portfolio manager: $e');
      rethrow;
    }
  }

  static Future<void> deletePortfolio(String portfolioId) async {
    try {
      await _portfoliosCol.doc(portfolioId).delete();
      debugPrint('✅ Portfolio deleted: $portfolioId');
    } catch (e) {
      debugPrint('❌ Error deleting portfolio: $e');
      rethrow;
    }
  }

  static Future<int> getPortfolioCount({required String ownerId}) async {
    try {
      final snapshot = await _portfoliosCol
          .where('ownerId', isEqualTo: ownerId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting portfolio count: $e');
      return 0;
    }
  }
}
