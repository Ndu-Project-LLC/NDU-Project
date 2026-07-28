import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// 4 subscription tiers — matches the existing [SubscriptionTier] enum but
/// kept local to this config so the pricing module can evolve independently.
/// Order matters: index 0 is the cheapest tier.
enum PricingTierId { basicProject, project, program, portfolio }

/// 5 role-based access levels — mirrors [SiteRole] from user_role.dart.
/// Kept local so pricing config doesn't depend on the auth module.
enum PricingRoleId { owner, admin, editor, user, guest }

/// Configuration for a single subscription tier.
///
/// All monetary values are in USD and stored as plain doubles. The admin
/// panel edits these; the pricing screen and payment dialog read them.
class TierPricingConfig {
  final PricingTierId id;
  final String label;
  final String subtitle;

  /// Base monthly price (USD) for the tier, inclusive of [includedUsers].
  final double monthlyPrice;

  /// Original (pre-discount) monthly price, for strikethrough display.
  final double monthlyOriginalPrice;

  /// Maximum users allowed on this tier before add-on pricing kicks in.
  /// Also the number of users included in [monthlyPrice].
  final int includedUsers;

  /// Hard cap — even with add-ons, no more than this many users on a tier.
  /// Set to a very large number for "unlimited".
  final int maxUsers;

  /// Per-role add-on monthly price (USD) for one additional user of that
  /// role beyond [includedUsers]. Roles not in the map cannot be added as
  /// add-ons (e.g. guests are usually free).
  final Map<PricingRoleId, double> addonPricePerRole;

  /// Marketing copy for the tier (bullet strings shown on the pricing card).
  final List<String> features;

  /// Accent color for the tier badge, as a 0xAARRGGBB int.
  final int badgeColorArgb;

  const TierPricingConfig({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.monthlyPrice,
    required this.monthlyOriginalPrice,
    required this.includedUsers,
    required this.maxUsers,
    required this.addonPricePerRole,
    required this.features,
    required this.badgeColorArgb,
  });

  /// Default config used on first load (before admin has edited anything)
  /// and as a fallback if Firestore is unreachable. Matches the values that
  /// were previously hardcoded in pricing_screen.dart.
  static const TierPricingConfig defaultBasicProject = TierPricingConfig(
    id: PricingTierId.basicProject,
    label: 'Regular Project',
    subtitle: 'No Fuss routine project delivered at a fraction of the cost',
    monthlyPrice: 39,
    monthlyOriginalPrice: 79,
    includedUsers: 1,
    maxUsers: 1,
    addonPricePerRole: {
      // Basic tier doesn't allow add-ons — single user only.
    },
    features: [
      'Free for the first month',
      '1 user',
      'Full project delivery from initiation to Launch',
      'Auto AI assist',
      'One-time incremental AI assist per section',
      'Limited Documentation features',
      'Upgrade tier any time',
    ],
    badgeColorArgb: 0xFFFFD700,
  );

  static const TierPricingConfig defaultProject = TierPricingConfig(
    id: PricingTierId.project,
    label: 'Project',
    subtitle: 'Robust project delivered at an affordable rate',
    monthlyPrice: 129,
    monthlyOriginalPrice: 179,
    includedUsers: 7,
    maxUsers: 20,
    addonPricePerRole: {
      PricingRoleId.owner: 25,
      PricingRoleId.admin: 18,
      PricingRoleId.editor: 12,
      PricingRoleId.user: 8,
      PricingRoleId.guest: 0,
    },
    features: [
      'Maximum 7 users included',
      'Robust project delivery with full features including organization planning, design, change management, work breakdown structure, and more',
      'Auto AI assist',
      'One-time incremental AI assist per section',
      'Document print out feature',
      'Upgrade tier anytime',
    ],
    badgeColorArgb: 0xFFFFD700,
  );

  static const TierPricingConfig defaultProgram = TierPricingConfig(
    id: PricingTierId.program,
    label: 'Program',
    subtitle: 'Up to 3 projects at a discounted rate with interface management',
    monthlyPrice: 319,
    monthlyOriginalPrice: 1000,
    includedUsers: 12,
    maxUsers: 40,
    addonPricePerRole: {
      PricingRoleId.owner: 22,
      PricingRoleId.admin: 16,
      PricingRoleId.editor: 10,
      PricingRoleId.user: 6,
      PricingRoleId.guest: 0,
    },
    features: [
      'Everything in Project',
      'Maximum 12 users included',
      'Monthly. Annual at a discount.',
      'Interface management',
      'Project dependency tracking',
      'Program level reports for cost, schedule, scope tracking',
    ],
    badgeColorArgb: 0xFFFFD700,
  );

  static const TierPricingConfig defaultPortfolio = TierPricingConfig(
    id: PricingTierId.portfolio,
    label: 'Portfolio',
    subtitle: 'Up to 9 projects at a bulk rate with integrated stewarding',
    monthlyPrice: 750,
    monthlyOriginalPrice: 1400,
    includedUsers: 24,
    maxUsers: 100,
    addonPricePerRole: {
      PricingRoleId.owner: 20,
      PricingRoleId.admin: 14,
      PricingRoleId.editor: 9,
      PricingRoleId.user: 5,
      PricingRoleId.guest: 0,
    },
    features: [
      'Everything in Program',
      'Maximum 24 users included',
      'Portfolio level reports for cost, schedule, scope tracking',
    ],
    badgeColorArgb: 0xFFFFD700,
  );

  /// All four default tiers in display order.
  static const List<TierPricingConfig> defaults = [
    defaultBasicProject,
    defaultProject,
    defaultProgram,
    defaultPortfolio,
  ];

  Map<String, dynamic> toFirestore() => {
        'label': label,
        'subtitle': subtitle,
        'monthlyPrice': monthlyPrice,
        'monthlyOriginalPrice': monthlyOriginalPrice,
        'includedUsers': includedUsers,
        'maxUsers': maxUsers,
        'addonPricePerRole': addonPricePerRole.map(
            (k, v) => MapEntry(k.name, v)),
        'features': features,
        'badgeColorArgb': badgeColorArgb,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory TierPricingConfig.fromFirestore(
      PricingTierId id, Map<String, dynamic> data) {
    Map<PricingRoleId, double> parseAddons(dynamic raw) {
      if (raw is! Map) return const {};
      return Map<PricingRoleId, double>.fromEntries(
        raw.entries.whereType<MapEntry>().where((e) {
          try {
            PricingRoleId.values.byName(e.key as String);
            return true;
          } catch (_) {
            return false;
          }
        }).map((e) => MapEntry(
              PricingRoleId.values.byName(e.key as String),
              (e.value as num).toDouble(),
            )),
      );
    }

    return TierPricingConfig(
      id: id,
      label: (data['label'] as String?) ?? _defaultFor(id).label,
      subtitle: (data['subtitle'] as String?) ?? _defaultFor(id).subtitle,
      monthlyPrice:
          (data['monthlyPrice'] as num?)?.toDouble() ?? _defaultFor(id).monthlyPrice,
      monthlyOriginalPrice:
          (data['monthlyOriginalPrice'] as num?)?.toDouble() ??
              _defaultFor(id).monthlyOriginalPrice,
      includedUsers:
          (data['includedUsers'] as num?)?.toInt() ?? _defaultFor(id).includedUsers,
      maxUsers:
          (data['maxUsers'] as num?)?.toInt() ?? _defaultFor(id).maxUsers,
      addonPricePerRole:
          parseAddons(data['addonPricePerRole']) ?? _defaultFor(id).addonPricePerRole,
      features: (data['features'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          _defaultFor(id).features,
      badgeColorArgb:
          (data['badgeColorArgb'] as num?)?.toInt() ?? _defaultFor(id).badgeColorArgb,
    );
  }

  static TierPricingConfig _defaultFor(PricingTierId id) {
    switch (id) {
      case PricingTierId.basicProject:
        return defaultBasicProject;
      case PricingTierId.project:
        return defaultProject;
      case PricingTierId.program:
        return defaultProgram;
      case PricingTierId.portfolio:
        return defaultPortfolio;
    }
  }

  TierPricingConfig copyWith({
    String? label,
    String? subtitle,
    double? monthlyPrice,
    double? monthlyOriginalPrice,
    int? includedUsers,
    int? maxUsers,
    Map<PricingRoleId, double>? addonPricePerRole,
    List<String>? features,
    int? badgeColorArgb,
  }) {
    return TierPricingConfig(
      id: id,
      label: label ?? this.label,
      subtitle: subtitle ?? this.subtitle,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      monthlyOriginalPrice:
          monthlyOriginalPrice ?? this.monthlyOriginalPrice,
      includedUsers: includedUsers ?? this.includedUsers,
      maxUsers: maxUsers ?? this.maxUsers,
      addonPricePerRole: addonPricePerRole ?? this.addonPricePerRole,
      features: features ?? this.features,
      badgeColorArgb: badgeColorArgb ?? this.badgeColorArgb,
    );
  }
}

/// A user's selection of add-on users during checkout.
/// Maps each role to a count of additional users of that role.
class AddonUserSelection {
  /// Number of additional users per role, beyond the tier's [includedUsers].
  final Map<PricingRoleId, int> counts;

  const AddonUserSelection({this.counts = const {}});

  int get total => counts.values.fold(0, (a, b) => a + b);

  /// Compute the additional monthly cost (USD) for the selected add-on users,
  /// given a tier's per-role add-on prices.
  double monthlyAddonCost(TierPricingConfig tier) {
    double sum = 0;
    counts.forEach((role, count) {
      sum += (tier.addonPricePerRole[role] ?? 0) * count;
    });
    return sum;
  }

  AddonUserSelection copyWith(Map<PricingRoleId, int> newCounts) =>
      AddonUserSelection(counts: {...counts, ...newCounts});

  Map<String, dynamic> toFirestore() =>
      {for (final e in counts.entries) e.key.name: e.value};
}

/// Top-level pricing configuration: the 4 tiers + global settings.
class SubscriptionPricingConfig {
  final Map<PricingTierId, TierPricingConfig> tiers;

  /// Currency code (ISO 4217) used for display and Stripe/Paystack/PayPal.
  final String currencyCode;

  /// Currency symbol used for display.
  final String currencySymbol;

  /// Discount multiplier applied when billing annually (e.g. 0.917 = ~1 month free).
  final double annualDiscountMultiplier;

  const SubscriptionPricingConfig({
    required this.tiers,
    required this.currencyCode,
    required this.currencySymbol,
    required this.annualDiscountMultiplier,
  });

  static SubscriptionPricingConfig get defaults => SubscriptionPricingConfig(
        tiers: {
          for (final t in TierPricingConfig.defaults) t.id: t,
        },
        currencyCode: 'USD',
        currencySymbol: r'$',
        annualDiscountMultiplier: 11 / 12, // pay for 11 months, get 12
      );

  TierPricingConfig tier(PricingTierId id) =>
      tiers[id] ?? TierPricingConfig.defaults.firstWhere((t) => t.id == id);

  Map<String, dynamic> toFirestore() => {
        'currencyCode': currencyCode,
        'currencySymbol': currencySymbol,
        'annualDiscountMultiplier': annualDiscountMultiplier,
        'tiers': tiers.map((k, v) => MapEntry(k.name, v.toFirestore())),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory SubscriptionPricingConfig.fromFirestore(
      Map<String, dynamic>? data) {
    if (data == null) return defaults;
    final tiersMap = data['tiers'] as Map?;
    final tiers = <PricingTierId, TierPricingConfig>{};
    for (final id in PricingTierId.values) {
      final t = tiersMap?[id.name];
      if (t is Map) {
        tiers[id] = TierPricingConfig.fromFirestore(
            id, Map<String, dynamic>.from(t));
      } else {
        tiers[id] = TierPricingConfig._defaultFor(id);
      }
    }
    return SubscriptionPricingConfig(
      tiers: tiers,
      currencyCode: (data['currencyCode'] as String?) ?? 'USD',
      currencySymbol: (data['currencySymbol'] as String?) ?? r'$',
      annualDiscountMultiplier:
          (data['annualDiscountMultiplier'] as num?)?.toDouble() ??
              (11 / 12),
    );
  }
}

/// Service that loads and persists the subscription pricing config to
/// Firestore at `config/subscription_pricing`.
///
/// On first load (or if Firestore is unreachable), returns [SubscriptionPricingConfig.defaults].
/// The admin panel writes updates via [save].
class SubscriptionPricingService {
  SubscriptionPricingService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _docPath = 'config/subscription_pricing';

  /// Loads the current pricing config. Returns defaults on any failure.
  static Future<SubscriptionPricingConfig> load() async {
    try {
      final snap =
          await _firestore.doc(_docPath).get();
      if (!snap.exists) return SubscriptionPricingConfig.defaults;
      return SubscriptionPricingConfig.fromFirestore(
          snap.data() as Map<String, dynamic>?);
    } catch (e) {
      debugPrint('[SubscriptionPricingService] load error: $e');
      return SubscriptionPricingConfig.defaults;
    }
  }

  /// Saves the full config (all 4 tiers + globals). Used by the admin panel.
  static Future<void> save(SubscriptionPricingConfig config) async {
    try {
      await _firestore.doc(_docPath).set(config.toFirestore());
    } catch (e) {
      debugPrint('[SubscriptionPricingService] save error: $e');
      rethrow;
    }
  }

  /// Stream of config updates so the pricing screen can react live to
  /// admin changes.
  static Stream<SubscriptionPricingConfig> watch() {
    try {
      return _firestore.doc(_docPath).snapshots().map((snap) {
        if (!snap.exists) return SubscriptionPricingConfig.defaults;
        return SubscriptionPricingConfig.fromFirestore(
            snap.data() as Map<String, dynamic>?);
      });
    } catch (e) {
      debugPrint('[SubscriptionPricingService] watch error: $e');
      return Stream.value(SubscriptionPricingConfig.defaults);
    }
  }

  /// Reset to defaults (admin "Restore defaults" button).
  static Future<void> resetToDefaults() async {
    await save(SubscriptionPricingConfig.defaults);
  }
}
