import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ndu_project/firebase_options.dart';

/// Payment provider types supported by the app
enum PaymentProvider { stripe, paypal, paystack }

/// Subscription plan tiers
enum SubscriptionTier { project, program, portfolio }

/// Subscription status
enum SubscriptionStatus { active, cancelled, expired, pending, trial }

/// Subscription model
class Subscription {
  final String id;
  final String userId;
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final PaymentProvider provider;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? nextBillingDate;
  final bool isAnnual;
  final String? externalSubscriptionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isTrial;
  final DateTime? trialEndDate;
  final DateTime? pausedUntil;

  Subscription({
    required this.id,
    required this.userId,
    required this.tier,
    required this.status,
    required this.provider,
    required this.startDate,
    this.endDate,
    this.nextBillingDate,
    this.isAnnual = false,
    this.externalSubscriptionId,
    required this.createdAt,
    required this.updatedAt,
    this.isTrial = false,
    this.trialEndDate,
    this.pausedUntil,
  });

  bool get isActive {
    // Check if subscription is paused
    if (pausedUntil != null && pausedUntil!.isAfter(DateTime.now())) {
      return false; // Subscription is paused
    }
    return (status == SubscriptionStatus.active ||
            status == SubscriptionStatus.trial) &&
        (endDate == null || endDate!.isAfter(DateTime.now()));
  }

  bool get isTrialActive =>
      isTrial &&
      status == SubscriptionStatus.trial &&
      trialEndDate != null &&
      trialEndDate!.isAfter(DateTime.now());

  int get trialDaysRemaining {
    if (!isTrialActive || trialEndDate == null) return 0;
    return trialEndDate!.difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'tier': tier.name,
        'status': status.name,
        'provider': provider.name,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'nextBillingDate': nextBillingDate != null
            ? Timestamp.fromDate(nextBillingDate!)
            : null,
        'isAnnual': isAnnual,
        'externalSubscriptionId': externalSubscriptionId,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'isTrial': isTrial,
        'trialEndDate':
            trialEndDate != null ? Timestamp.fromDate(trialEndDate!) : null,
        'pausedUntil':
            pausedUntil != null ? Timestamp.fromDate(pausedUntil!) : null,
      };

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      tier: SubscriptionTier.values.firstWhere(
        (e) => e.name == json['tier'],
        orElse: () => SubscriptionTier.project,
      ),
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SubscriptionStatus.pending,
      ),
      provider: PaymentProvider.values.firstWhere(
        (e) => e.name == json['provider'],
        orElse: () => PaymentProvider.stripe,
      ),
      startDate: (json['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (json['endDate'] as Timestamp?)?.toDate(),
      nextBillingDate: (json['nextBillingDate'] as Timestamp?)?.toDate(),
      isAnnual: json['isAnnual'] ?? false,
      externalSubscriptionId: json['externalSubscriptionId'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isTrial: json['isTrial'] ?? false,
      trialEndDate: (json['trialEndDate'] as Timestamp?)?.toDate(),
      pausedUntil: (json['pausedUntil'] as Timestamp?)?.toDate(),
    );
  }

  Subscription copyWith({
    String? id,
    String? userId,
    SubscriptionTier? tier,
    SubscriptionStatus? status,
    PaymentProvider? provider,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nextBillingDate,
    bool? isAnnual,
    String? externalSubscriptionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isTrial,
    DateTime? trialEndDate,
    DateTime? pausedUntil,
  }) {
    return Subscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tier: tier ?? this.tier,
      status: status ?? this.status,
      provider: provider ?? this.provider,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
      isAnnual: isAnnual ?? this.isAnnual,
      externalSubscriptionId:
          externalSubscriptionId ?? this.externalSubscriptionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isTrial: isTrial ?? this.isTrial,
      trialEndDate: trialEndDate ?? this.trialEndDate,
      pausedUntil: pausedUntil ?? this.pausedUntil,
    );
  }
}

/// Result of a payment operation
class PaymentResult {
  final bool success;
  final String? message;
  final String? paymentUrl;
  final String? subscriptionId;
  final Map<String, dynamic>? data;

  PaymentResult({
    required this.success,
    this.message,
    this.paymentUrl,
    this.subscriptionId,
    this.data,
  });
}

/// Service for managing subscriptions and payments via Firebase Cloud Functions
class SubscriptionService {
  static final _firestore = FirebaseFirestore.instance;
  static final _subscriptionsCollection =
      _firestore.collection('subscriptions');

  /// Base URL for Cloud Functions
  static String get _cloudFunctionsBaseUrl {
    final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    // Default region us-central1 unless you deploy elsewhere
    return 'https://us-central1-$projectId.cloudfunctions.net';
  }

  /// Free trial duration in days
  static const int trialDurationDays = 3;

  /// Check if user is eligible for a free trial (first-time users only)
  static Future<bool> isEligibleForFreeTrial() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Check if user has ever had any subscription (including expired/cancelled trials)
      final snapshot = await _subscriptionsCollection
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      // User is eligible if they've never had any subscription
      return snapshot.docs.isEmpty;
    } catch (e) {
      debugPrint('Error checking trial eligibility: $e');
      return false;
    }
  }

  /// Start a free trial for the user
  static Future<PaymentResult> startFreeTrial({
    required SubscriptionTier tier,
    required bool isAnnual,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return PaymentResult(success: false, message: 'User not authenticated');
      }

      // Verify eligibility
      final isEligible = await isEligibleForFreeTrial();
      if (!isEligible) {
        return PaymentResult(
          success: false,
          message: 'You have already used your free trial',
        );
      }

      final now = DateTime.now();
      final trialEndDate = now.add(const Duration(days: trialDurationDays));
      final docRef = _subscriptionsCollection.doc();

      final subscription = Subscription(
        id: docRef.id,
        userId: user.uid,
        tier: tier,
        status: SubscriptionStatus.trial,
        provider: PaymentProvider.stripe, // Default provider for trial
        startDate: now,
        endDate: trialEndDate,
        trialEndDate: trialEndDate,
        isAnnual: isAnnual,
        isTrial: true,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(subscription.toJson());

      return PaymentResult(
        success: true,
        message: 'Free trial started successfully',
        subscriptionId: docRef.id,
        data: {'trialEndDate': trialEndDate.toIso8601String()},
      );
    } catch (e) {
      debugPrint('Error starting free trial: $e');
      return PaymentResult(success: false, message: e.toString());
    }
  }

  /// Activate a subscription via a 100% off coupon
  static Future<bool> activateCouponSubscription({
    required SubscriptionTier tier,
    required bool isAnnual,
    required String couponCode,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final now = DateTime.now();
      // Grant 1 year access for annual, or 1 month (but typically coupons like SAVE200 might imply longer)
      // For now, let's treat SAVE200 as a 1 year valid period or indefinite?
      // User didn't specify, but implies "access". Let's give 1 year for now to be safe, or 100 years.
      // Given it's a "bypass" maybe just 1 year renewable.
      final endDate = isAnnual
          ? now.add(const Duration(days: 365))
          : now.add(const Duration(days: 30));

      final docRef = _subscriptionsCollection.doc();

      final subscription = Subscription(
        id: docRef.id,
        userId: user.uid,
        tier: tier,
        status: SubscriptionStatus.active,
        provider: PaymentProvider.stripe, // Placeholder provider
        startDate: now,
        endDate: endDate,
        nextBillingDate: endDate,
        isAnnual: isAnnual,
        externalSubscriptionId: 'coupon_$couponCode',
        createdAt: now,
        updatedAt: now,
        isTrial: false,
      );

      await docRef.set(subscription.toJson());
      return true;
    } catch (e) {
      debugPrint('Error activating coupon subscription: $e');
      return false;
    }
  }

  /// Get current user's active subscription (including trials)
  static Future<Subscription?> getCurrentSubscription() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // First check for active subscriptions
      var snapshot = await _subscriptionsCollection
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: SubscriptionStatus.active.name)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final subscription = Subscription.fromJson(snapshot.docs.first.data());
        if (subscription.isActive) return subscription;
      }

      // Then check for active trials
      snapshot = await _subscriptionsCollection
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: SubscriptionStatus.trial.name)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final subscription = Subscription.fromJson(snapshot.docs.first.data());
        if (subscription.isActive) return subscription;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting current subscription: $e');
      return null;
    }
  }

  /// Check if user has an active subscription for a specific tier
  static Future<bool> hasActiveSubscription({SubscriptionTier? tier}) async {
    try {
      final subscription = await getCurrentSubscription();
      if (subscription == null) return false;
      if (!subscription.isActive) return false;

      // If no specific tier requested, any active subscription is valid
      if (tier == null) return true;

      // Check if user's subscription tier allows access to the requested tier
      // Portfolio includes Program and Project access
      // Program includes Project access
      switch (subscription.tier) {
        case SubscriptionTier.portfolio:
          return true; // Portfolio has access to all tiers
        case SubscriptionTier.program:
          return tier != SubscriptionTier.portfolio;
        case SubscriptionTier.project:
          return tier == SubscriptionTier.project;
      }
    } catch (e) {
      debugPrint('Error checking subscription status: $e');
      return false;
    }
  }

  /// Stream the current user's subscription
  static Stream<Subscription?> watchSubscription() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(null);

    return _subscriptionsCollection
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: SubscriptionStatus.active.name)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final subscription = Subscription.fromJson(snapshot.docs.first.data());
      return subscription.isActive ? subscription : null;
    });
  }

  /// Initiate a payment with Stripe
  static Future<PaymentResult> initiateStripePayment({
    required SubscriptionTier tier,
    required bool isAnnual,
    String? couponCode,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return PaymentResult(success: false, message: 'User not authenticated');
      }

      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$_cloudFunctionsBaseUrl/createStripeCheckout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'tier': tier.name,
          'isAnnual': isAnnual,
          'userId': user.uid,
          'email': user.email,
          if (couponCode != null && couponCode.isNotEmpty)
            'couponCode': couponCode,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return PaymentResult(
          success: true,
          paymentUrl: data['checkoutUrl'],
          subscriptionId: data['subscriptionId'],
          data: data,
        );
      } else {
        return PaymentResult(
          success: false,
          message: data['error'] ?? 'Failed to create checkout session',
        );
      }
    } catch (e) {
      debugPrint('Error initiating Stripe payment: $e');
      return PaymentResult(success: false, message: e.toString());
    }
  }

  /// Initiate a payment with PayPal
  static Future<PaymentResult> initiatePayPalPayment({
    required SubscriptionTier tier,
    required bool isAnnual,
    String? couponCode,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return PaymentResult(success: false, message: 'User not authenticated');
      }

      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$_cloudFunctionsBaseUrl/createPayPalOrder'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'tier': tier.name,
          'isAnnual': isAnnual,
          'userId': user.uid,
          'email': user.email,
          if (couponCode != null && couponCode.isNotEmpty)
            'couponCode': couponCode,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return PaymentResult(
          success: true,
          paymentUrl: data['approvalUrl'],
          subscriptionId: data['subscriptionId'],
          data: data,
        );
      } else {
        return PaymentResult(
          success: false,
          message: data['error'] ?? 'Failed to create PayPal order',
        );
      }
    } catch (e) {
      debugPrint('Error initiating PayPal payment: $e');
      return PaymentResult(success: false, message: e.toString());
    }
  }

  /// Initiate a payment with Paystack
  static Future<PaymentResult> initiatePaystackPayment({
    required SubscriptionTier tier,
    required bool isAnnual,
    String? couponCode,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return PaymentResult(success: false, message: 'User not authenticated');
      }

      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$_cloudFunctionsBaseUrl/createPaystackTransaction'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'tier': tier.name,
          'isAnnual': isAnnual,
          'userId': user.uid,
          'email': user.email,
          if (couponCode != null && couponCode.isNotEmpty)
            'couponCode': couponCode,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return PaymentResult(
          success: true,
          paymentUrl: data['authorizationUrl'],
          subscriptionId: data['subscriptionId'],
          data: data,
        );
      } else {
        return PaymentResult(
          success: false,
          message: data['error'] ?? 'Failed to create Paystack transaction',
        );
      }
    } catch (e) {
      debugPrint('Error initiating Paystack payment: $e');
      return PaymentResult(success: false, message: e.toString());
    }
  }

  /// Verify payment completion (called after redirect back from payment provider)
  static Future<PaymentResult> verifyPayment({
    required PaymentProvider provider,
    required String reference,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return PaymentResult(success: false, message: 'User not authenticated');
      }

      final idToken = await user.getIdToken();
      final endpoint = switch (provider) {
        PaymentProvider.stripe => 'verifyStripePayment',
        PaymentProvider.paypal => 'verifyPayPalPayment',
        PaymentProvider.paystack => 'verifyPaystackPayment',
      };

      final response = await http.post(
        Uri.parse('$_cloudFunctionsBaseUrl/$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'reference': reference,
          'userId': user.uid,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return PaymentResult(
          success: true,
          message: 'Payment verified successfully',
          subscriptionId: data['subscriptionId'],
          data: data,
        );
      } else {
        return PaymentResult(
          success: false,
          message: data['error'] ?? 'Payment verification failed',
        );
      }
    } catch (e) {
      debugPrint('Error verifying payment: $e');
      return PaymentResult(success: false, message: e.toString());
    }
  }

  /// Cancel current subscription
  static Future<bool> cancelSubscription() async {
    try {
      final subscription = await getCurrentSubscription();
      if (subscription == null) return false;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$_cloudFunctionsBaseUrl/cancelSubscription'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'subscriptionId': subscription.id,
          'provider': subscription.provider.name,
          'externalSubscriptionId': subscription.externalSubscriptionId,
        }),
      );

      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      debugPrint('Error cancelling subscription: $e');
      return false;
    }
  }

  /// Pause subscription for a specified duration
  /// Updates the user document in Firestore with paused_until timestamp
  static Future<bool> pauseSubscription(int months) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final pausedUntil = DateTime.now().add(Duration(days: months * 30));

      // Update user document in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'pausedUntil': Timestamp.fromDate(pausedUntil),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Subscription paused until: $pausedUntil');
      return true;
    } catch (e) {
      debugPrint('Error pausing subscription: $e');
      return false;
    }
  }

  /// Resume subscription (clear paused_until)
  static Future<bool> resumeSubscription() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Clear paused_until from user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'pausedUntil': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Subscription resumed');
      return true;
    } catch (e) {
      debugPrint('Error resuming subscription: $e');
      return false;
    }
  }

  /// Check if user's subscription is currently paused
  static Future<bool> isSubscriptionPaused() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!userDoc.exists) return false;

      final data = userDoc.data();
      final pausedUntil = data?['pausedUntil'];

      if (pausedUntil == null) return false;

      if (pausedUntil is Timestamp) {
        return pausedUntil.toDate().isAfter(DateTime.now());
      }

      return false;
    } catch (e) {
      debugPrint('Error checking subscription pause status: $e');
      return false;
    }
  }

  /// Get price for a tier
  static Map<String, String> getPriceForTier(SubscriptionTier tier,
      {bool annual = false}) {
    switch (tier) {
      case SubscriptionTier.project:
        return annual
            ? {'price': '\$790', 'period': 'per year'}
            : {'price': '\$79', 'period': 'per month'};
      case SubscriptionTier.program:
        return annual
            ? {'price': '\$1,890', 'period': 'per year'}
            : {'price': '\$189', 'period': 'per month'};
      case SubscriptionTier.portfolio:
        return annual
            ? {'price': '\$4,490', 'period': 'per year'}
            : {'price': '\$449', 'period': 'per month'};
    }
  }

  /// Get tier display name
  static String getTierName(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.project:
        return 'Project Plan';
      case SubscriptionTier.program:
        return 'Program Plan';
      case SubscriptionTier.portfolio:
        return 'Portfolio Plan';
    }
  }

  /// Fetch invoice history for a user
  static Future<List<Invoice>> getInvoiceHistory(
      {String? userId, String? userEmail}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$_cloudFunctionsBaseUrl/getUserInvoices'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'userId': userId ?? user.uid,
          'userEmail': userEmail ?? user.email,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final invoices = (data['invoices'] as List?)
                ?.map((i) => Invoice.fromJson(i))
                .toList() ??
            [];
        return invoices;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching invoice history: $e');
      return [];
    }
  }

  /// Validate and apply a coupon server-side (works across all providers)
  static Future<AppliedCouponResult?> applyCoupon({
    required String couponCode,
    required SubscriptionTier tier,
    required double originalPrice,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$_cloudFunctionsBaseUrl/applyCoupon'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'couponCode': couponCode,
          'tier': tier.name,
          'originalPrice': originalPrice,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return AppliedCouponResult(
          couponId: data['couponId'] ?? '',
          code: couponCode.toUpperCase(),
          discountedPrice:
              (data['discountedPrice'] ?? originalPrice).toDouble(),
          originalPrice: originalPrice,
          discountPercent: (data['discountPercent'] ?? 0).toDouble(),
          discountAmount: (data['discountAmount'] ?? 0).toDouble(),
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error applying coupon: $e');
      return null;
    }
  }
}

class AppliedCouponResult {
  AppliedCouponResult({
    required this.couponId,
    required this.code,
    required this.discountedPrice,
    required this.originalPrice,
    required this.discountPercent,
    required this.discountAmount,
  });

  final String couponId;
  final String code;
  final double discountedPrice;
  final double originalPrice;
  final double discountPercent;
  final double discountAmount;
}

/// Invoice model for payment history
class Invoice {
  final String id;
  final double amount;
  final String currency;
  final String status;
  final String provider;
  final String description;
  final DateTime createdAt;
  final DateTime? paidAt;
  final String? subscriptionId;
  final String? externalId;
  final String? tier;
  final String? receiptUrl;

  Invoice({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    required this.provider,
    required this.description,
    required this.createdAt,
    this.paidAt,
    this.subscriptionId,
    this.externalId,
    this.tier,
    this.receiptUrl,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
      status: json['status'] ?? 'unknown',
      provider: json['provider'] ?? 'unknown',
      description: json['description'] ?? 'Payment',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
      subscriptionId: json['subscriptionId'],
      externalId: json['externalId'],
      tier: json['tier'],
      receiptUrl: json['receiptUrl'],
    );
  }

  bool get isPaid =>
      status == 'paid' || status == 'succeeded' || status == 'success';

  String get formattedAmount {
    final symbol = currency == 'USD'
        ? '\$'
        : currency == 'NGN'
            ? '₦'
            : currency;
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  String get providerDisplayName {
    switch (provider.toLowerCase()) {
      case 'stripe':
        return 'Stripe';
      case 'paypal':
        return 'PayPal';
      case 'paystack':
        return 'Paystack';
      case 'admin_granted':
        return 'Admin Granted';
      default:
        return provider;
    }
  }
}
