import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:ndu_project/models/coupon_model.dart';

/// Service for managing coupons across all payment platforms
class CouponService {
  static final _firestore = FirebaseFirestore.instance;
  static final _couponsCollection = _firestore.collection('coupons');

  /// Create a new coupon
  static Future<CouponModel?> createCoupon({
    required String code,
    required String description,
    required double discountPercent,
    double? discountAmount,
    required DateTime validFrom,
    required DateTime validUntil,
    int? maxUses,
    List<String> applicableTiers = const [],
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Check if code already exists
      final existing = await _couponsCollection
          .where('code', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();
      
      if (existing.docs.isNotEmpty) {
        debugPrint('Coupon code already exists: $code');
        return null;
      }

      final docRef = _couponsCollection.doc();
      final now = DateTime.now();
      
      final coupon = CouponModel(
        id: docRef.id,
        code: code.toUpperCase(),
        description: description,
        discountPercent: discountPercent,
        discountAmount: discountAmount,
        validFrom: validFrom,
        validUntil: validUntil,
        maxUses: maxUses,
        currentUses: 0,
        isActive: true,
        applicableTiers: applicableTiers,
        createdAt: now,
        updatedAt: now,
        createdBy: user.uid,
      );

      await docRef.set(coupon.toJson());
      return coupon;
    } catch (e) {
      debugPrint('Error creating coupon: $e');
      return null;
    }
  }

  /// Get all coupons (for admin)
  static Stream<List<CouponModel>> watchAllCoupons() {
    return _couponsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CouponModel.fromJson(doc.data()))
            .toList());
  }

  /// Get a coupon by code
  static Future<CouponModel?> getCouponByCode(String code) async {
    try {
      final snapshot = await _couponsCollection
          .where('code', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return CouponModel.fromJson(snapshot.docs.first.data());
    } catch (e) {
      debugPrint('Error getting coupon by code: $e');
      return null;
    }
  }

  /// Validate a coupon for a specific tier
  static Future<CouponModel?> validateCoupon(String code, String tier) async {
    try {
      final coupon = await getCouponByCode(code);
      if (coupon == null) return null;

      if (!coupon.isValid) return null;

      // Check if coupon applies to this tier
      if (coupon.applicableTiers.isNotEmpty && 
          !coupon.applicableTiers.contains(tier)) {
        return null;
      }

      return coupon;
    } catch (e) {
      debugPrint('Error validating coupon: $e');
      return null;
    }
  }

  /// Use a coupon (increment usage count)
  static Future<bool> useCoupon(String couponId) async {
    try {
      await _couponsCollection.doc(couponId).update({
        'currentUses': FieldValue.increment(1),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      debugPrint('Error using coupon: $e');
      return false;
    }
  }

  /// Toggle coupon active status
  static Future<bool> toggleCouponStatus(String couponId, bool isActive) async {
    try {
      await _couponsCollection.doc(couponId).update({
        'isActive': isActive,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      debugPrint('Error toggling coupon status: $e');
      return false;
    }
  }

  /// Delete a coupon
  static Future<bool> deleteCoupon(String couponId) async {
    try {
      await _couponsCollection.doc(couponId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting coupon: $e');
      return false;
    }
  }

  /// Update coupon
  static Future<bool> updateCoupon(CouponModel coupon) async {
    try {
      await _couponsCollection.doc(coupon.id).update(
        coupon.copyWith(updatedAt: DateTime.now()).toJson(),
      );
      return true;
    } catch (e) {
      debugPrint('Error updating coupon: $e');
      return false;
    }
  }

  /// Calculate discounted price
  static double calculateDiscountedPrice(double originalPrice, CouponModel coupon) {
    if (coupon.discountAmount != null && coupon.discountAmount! > 0) {
      return (originalPrice - coupon.discountAmount!).clamp(0, originalPrice);
    }
    return originalPrice * (1 - coupon.discountPercent / 100);
  }
}
