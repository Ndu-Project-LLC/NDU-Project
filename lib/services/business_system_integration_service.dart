import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Top-level category of business system.
enum BusinessSystemCategory {
  crm('CRM', 'Customer relationships, leads, opportunities, accounts'),
  erp('ERP', 'Resource planning, orders, inventory, suppliers, operations'),
  accounting('Accounting',
      'Invoices, payments, general ledger, financial reporting');

  const BusinessSystemCategory(this.label, this.description);
  final String label;
  final String description;
}

/// Concrete providers supported by the integration layer. Adding a new
/// provider here is sufficient to make it appear in the connect screen —
/// the actual API calls are made via [BusinessSystemClient].
enum BusinessSystemProvider {
  // ── CRM ──
  salesforce(
      BusinessSystemCategory.crm,
      'Salesforce',
      'Leading enterprise CRM',
      'https://login.salesforce.com/services/oauth2/authorize',
      'https://login.salesforce.com/services/oauth2/token'),
  hubspot(BusinessSystemCategory.crm, 'HubSpot', 'Inbound marketing + sales CRM',
      'https://app.hubspot.com/oauth/authorize', 'https://api.hubapi.com/oauth/v1/token'),
  zohoCrm(BusinessSystemCategory.crm, 'Zoho CRM', 'Affordable full-featured CRM',
      'https://accounts.zoho.com/oauth/v2/auth', 'https://accounts.zoho.com/oauth/v2/token'),
  pipedrive(BusinessSystemCategory.crm, 'Pipedrive', 'Sales-pipeline-focused CRM',
      'https://oauth.pipedrive.com/oauth/authorize', 'https://oauth.pipedrive.com/oauth/token'),

  // ── ERP ──
  sap(BusinessSystemCategory.erp, 'SAP', 'Enterprise resource planning',
      null, null),
  oracleErp(BusinessSystemCategory.erp, 'Oracle ERP', 'Oracle Cloud ERP',
      null, null),
  netsuite(BusinessSystemCategory.erp, 'NetSuite', 'Oracle NetSuite ERP',
      'https://system.netsuite.com/pages/oauth2/authorize',
      'https://system.netsuite.com/services/rest/auth/oauth2/v1/token'),
  odoo(BusinessSystemCategory.erp, 'Odoo', 'Open-source modular ERP',
      'https://www.odoo.com/oauth2/auth', 'https://www.odoo.com/oauth2/token'),

  // ── Accounting ──
  quickbooks(BusinessSystemCategory.accounting, 'QuickBooks Online',
      'Intuit small-business accounting', 'https://appcenter.intuit.com/connect/oauth2',
      'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer'),
  xero(BusinessSystemCategory.accounting, 'Xero', 'Cloud accounting for SMBs',
      'https://login.xero.com/identity/connect/authorize',
      'https://identity.xero.com/connect/token'),
  sage(BusinessSystemCategory.accounting, 'Sage Business Cloud',
      'Sage accounting suite', null, null),
  freshbooks(BusinessSystemCategory.accounting, 'FreshBooks',
      'Invoicing + accounting for service businesses',
      'https://auth.freshbooks.com/oauth/authorize',
      'https://api.freshbooks.com/auth/oauth/token');

  const BusinessSystemProvider(
    this.category,
    this.label,
    this.description,
    this.oauthAuthorizeUrl,
    this.oauthTokenUrl,
  );

  final BusinessSystemCategory category;
  final String label;
  final String description;

  /// OAuth 2.0 authorize endpoint, or null for providers that use API-key
  /// auth only (SAP, Oracle, Sage).
  final String? oauthAuthorizeUrl;
  final String? oauthTokenUrl;

  /// Whether this provider supports OAuth 2.0 (vs API-key-only).
  bool get supportsOAuth => oauthAuthorizeUrl != null;

  /// Brand-ish accent color for the provider's icon background.
  int get brandColorArgb {
    switch (this) {
      case BusinessSystemProvider.salesforce:
        return 0xFF00A1E0;
      case BusinessSystemProvider.hubspot:
        return 0xFFFF7A59;
      case BusinessSystemProvider.zohoCrm:
        return 0xFFC8202F;
      case BusinessSystemProvider.pipedrive:
        return 0xFF1A1A1A;
      case BusinessSystemProvider.sap:
        return 0xFF0FAAFF;
      case BusinessSystemProvider.oracleErp:
        return 0xFFC74634;
      case BusinessSystemProvider.netsuite:
        return 0xFF16535A;
      case BusinessSystemProvider.odoo:
        return 0xFF714B67;
      case BusinessSystemProvider.quickbooks:
        return 0xFF2CA01C;
      case BusinessSystemProvider.xero:
        return 0xFF13B5EA;
      case BusinessSystemProvider.sage:
        return 0xFF00D672;
      case BusinessSystemProvider.freshbooks:
        return 0xFF0075DD;
    }
  }
}

/// Connection status of a single provider integration.
enum IntegrationStatus {
  disconnected,
  connecting,
  connected,
  error,
  expired;

  bool get isActive => this == connected;
}

/// Auth method used by a connected integration.
enum AuthMethod { oauth, apiKey, basic }

/// One user's connection to one business-system provider, scoped to a
/// program (a collection of up to 3 projects).
///
/// Stored at: `programs/{programId}/businessIntegrations/{providerName}`
class BusinessSystemIntegration {
  final BusinessSystemProvider provider;
  final IntegrationStatus status;
  final AuthMethod authMethod;

  /// Encrypted OAuth access token (or null for API-key auth). In production
  /// this should be stored in a secrets manager — kept here as a placeholder.
  final String? accessToken;
  final DateTime? tokenExpiresAt;
  final String? refreshToken;

  /// API key for providers that use key auth (SAP, Oracle, Sage).
  final String? apiKey;

  /// Base URL override — useful for self-hosted Odoo / SAP instances.
  final String? baseUrlOverride;

  /// Sync settings.
  final bool autoSync;
  final DateTime? lastSyncAt;
  final String? lastSyncError;

  /// Scopes granted by the user (provider-specific strings).
  final List<String> scopes;

  final String connectedById;
  final String connectedByEmail;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BusinessSystemIntegration({
    required this.provider,
    required this.status,
    required this.authMethod,
    this.accessToken,
    this.tokenExpiresAt,
    this.refreshToken,
    this.apiKey,
    this.baseUrlOverride,
    required this.autoSync,
    this.lastSyncAt,
    this.lastSyncError,
    required this.scopes,
    required this.connectedById,
    required this.connectedByEmail,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BusinessSystemIntegration.disconnected(
      BusinessSystemProvider provider, String userId, String email) {
    final now = DateTime.now();
    return BusinessSystemIntegration(
      provider: provider,
      status: IntegrationStatus.disconnected,
      authMethod: provider.supportsOAuth ? AuthMethod.oauth : AuthMethod.apiKey,
      autoSync: false,
      scopes: const [],
      connectedById: userId,
      connectedByEmail: email,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'provider': provider.name,
        'status': status.name,
        'authMethod': authMethod.name,
        'accessToken': accessToken,
        'tokenExpiresAt': tokenExpiresAt != null
            ? Timestamp.fromDate(tokenExpiresAt!)
            : null,
        'refreshToken': refreshToken,
        'apiKey': apiKey,
        'baseUrlOverride': baseUrlOverride,
        'autoSync': autoSync,
        'lastSyncAt': lastSyncAt != null
            ? Timestamp.fromDate(lastSyncAt!)
            : null,
        'lastSyncError': lastSyncError,
        'scopes': scopes,
        'connectedById': connectedById,
        'connectedByEmail': connectedByEmail,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory BusinessSystemIntegration.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    BusinessSystemProvider parseProvider(String name) {
      try {
        return BusinessSystemProvider.values.byName(name);
      } catch (_) {
        return BusinessSystemProvider.salesforce;
      }
    }

    IntegrationStatus parseStatus(String name) {
      try {
        return IntegrationStatus.values.byName(name);
      } catch (_) {
        return IntegrationStatus.disconnected;
      }
    }

    AuthMethod parseAuth(String name) {
      try {
        return AuthMethod.values.byName(name);
      } catch (_) {
        return AuthMethod.apiKey;
      }
    }

    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return BusinessSystemIntegration(
      provider: parseProvider(data['provider'] as String? ?? 'salesforce'),
      status: parseStatus(data['status'] as String? ?? 'disconnected'),
      authMethod: parseAuth(data['authMethod'] as String? ?? 'apiKey'),
      accessToken: data['accessToken'] as String?,
      tokenExpiresAt: data['tokenExpiresAt'] != null
          ? (data['tokenExpiresAt'] as Timestamp).toDate()
          : null,
      refreshToken: data['refreshToken'] as String?,
      apiKey: data['apiKey'] as String?,
      baseUrlOverride: data['baseUrlOverride'] as String?,
      autoSync: (data['autoSync'] as bool?) ?? false,
      lastSyncAt: data['lastSyncAt'] != null
          ? (data['lastSyncAt'] as Timestamp).toDate()
          : null,
      lastSyncError: data['lastSyncError'] as String?,
      scopes: ((data['scopes'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      connectedById: data['connectedById'] as String? ?? '',
      connectedByEmail: data['connectedByEmail'] as String? ?? '',
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
    );
  }

  BusinessSystemIntegration copyWith({
    IntegrationStatus? status,
    AuthMethod? authMethod,
    String? accessToken,
    DateTime? tokenExpiresAt,
    String? refreshToken,
    String? apiKey,
    String? baseUrlOverride,
    bool? autoSync,
    DateTime? lastSyncAt,
    String? lastSyncError,
    List<String>? scopes,
    DateTime? updatedAt,
  }) {
    return BusinessSystemIntegration(
      provider: provider,
      status: status ?? this.status,
      authMethod: authMethod ?? this.authMethod,
      accessToken: accessToken ?? this.accessToken,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
      refreshToken: refreshToken ?? this.refreshToken,
      apiKey: apiKey ?? this.apiKey,
      baseUrlOverride: baseUrlOverride ?? this.baseUrlOverride,
      autoSync: autoSync ?? this.autoSync,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastSyncError: lastSyncError ?? this.lastSyncError,
      scopes: scopes ?? this.scopes,
      connectedById: connectedById,
      connectedByEmail: connectedByEmail,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

/// Aggregated sample data pulled from one integration. Used by the program
/// dashboard to show a roll-up of customers / invoices / orders across all
/// connected systems. Real implementations would call each provider's REST
/// API; this model captures the unified shape.
class BusinessSystemSnapshot {
  final BusinessSystemProvider provider;
  final int customerCount;
  final int openDealCount;
  final double pipelineValueUsd;
  final int invoiceCount;
  final double outstandingUsd;
  final int orderCount;
  final double orderValueUsd;
  final DateTime fetchedAt;

  const BusinessSystemSnapshot({
    required this.provider,
    required this.customerCount,
    required this.openDealCount,
    required this.pipelineValueUsd,
    required this.invoiceCount,
    required this.outstandingUsd,
    required this.orderCount,
    required this.orderValueUsd,
    required this.fetchedAt,
  });

  /// Zero-filled snapshot for a freshly connected integration (before the
  /// first sync has run).
  factory BusinessSystemSnapshot.empty(BusinessSystemProvider p) =>
      BusinessSystemSnapshot(
        provider: p,
        customerCount: 0,
        openDealCount: 0,
        pipelineValueUsd: 0,
        invoiceCount: 0,
        outstandingUsd: 0,
        orderCount: 0,
        orderValueUsd: 0,
        fetchedAt: DateTime.now(),
      );
}

/// Service that manages business-system integrations per program.
///
/// Firestore layout:
///   programs/{programId}/businessIntegrations/{providerName} — connection config
///   programs/{programId}/businessIntegrations/{providerName}/snapshots/latest — cached snapshot
class BusinessSystemIntegrationService {
  BusinessSystemIntegrationService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Collection reference for a program's integrations.
  static CollectionReference<Map<String, dynamic>> _coll(String programId) {
    return _firestore
        .collection('programs')
        .doc(programId)
        .collection('businessIntegrations');
  }

  /// Stream all integrations for a program, live.
  static Stream<List<BusinessSystemIntegration>> watchAll(String programId) {
    try {
      return _coll(programId).snapshots().map((snap) => snap.docs
          .map((d) => BusinessSystemIntegration.fromFirestore(
              d as DocumentSnapshot<Map<String, dynamic>>))
          .toList());
    } catch (e) {
      debugPrint('[BusinessSystemIntegrationService] watchAll error: $e');
      return Stream.value([]);
    }
  }

  /// Load all integrations for a program (one-shot).
  static Future<List<BusinessSystemIntegration>> loadAll(
      String programId) async {
    try {
      final snap = await _coll(programId).get();
      return snap.docs
          .map((d) => BusinessSystemIntegration.fromFirestore(
              d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    } catch (e) {
      debugPrint('[BusinessSystemIntegrationService] loadAll error: $e');
      return [];
    }
  }

  /// Upsert a connection. Called when the user connects, updates credentials,
  /// or toggles auto-sync.
  static Future<void> save(
      String programId, BusinessSystemIntegration integration) async {
    try {
      await _coll(programId)
          .doc(integration.provider.name)
          .set(integration.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[BusinessSystemIntegrationService] save error: $e');
      rethrow;
    }
  }

  /// Delete a connection (disconnect).
  static Future<void> delete(String programId, BusinessSystemProvider p) async {
    try {
      await _coll(programId).doc(p.name).delete();
    } catch (e) {
      debugPrint('[BusinessSystemIntegrationService] delete error: $e');
      rethrow;
    }
  }

  /// Mark a connection as connecting (during OAuth dance) or connected
  /// (after token exchange).
  static Future<void> updateStatus(
      String programId, BusinessSystemProvider p, IntegrationStatus s,
      {String? error}) async {
    final existing = (await _coll(programId).doc(p.name).get());
    BusinessSystemIntegration current;
    if (existing.exists) {
      current = BusinessSystemIntegration.fromFirestore(
          existing as DocumentSnapshot<Map<String, dynamic>>);
    } else {
      final user = _auth.currentUser;
      current = BusinessSystemIntegration.disconnected(
          p, user?.uid ?? '', user?.email ?? '');
    }
    await save(programId,
        current.copyWith(status: s, lastSyncError: error));
  }

  /// Save a cached snapshot for a provider. Stored as a subcollection so
  /// we keep history.
  static Future<void> saveSnapshot(
      String programId, BusinessSystemSnapshot snapshot) async {
    try {
      final docRef = _coll(programId).doc(snapshot.provider.name);
      await docRef
          .collection('snapshots')
          .add({
            'customerCount': snapshot.customerCount,
            'openDealCount': snapshot.openDealCount,
            'pipelineValueUsd': snapshot.pipelineValueUsd,
            'invoiceCount': snapshot.invoiceCount,
            'outstandingUsd': snapshot.outstandingUsd,
            'orderCount': snapshot.orderCount,
            'orderValueUsd': snapshot.orderValueUsd,
            'fetchedAt': Timestamp.fromDate(snapshot.fetchedAt),
          });
      // Also store a 'latest' pointer doc for quick reads
      await docRef
          .collection('snapshots')
          .doc('latest')
          .set({
            'customerCount': snapshot.customerCount,
            'openDealCount': snapshot.openDealCount,
            'pipelineValueUsd': snapshot.pipelineValueUsd,
            'invoiceCount': snapshot.invoiceCount,
            'outstandingUsd': snapshot.outstandingUsd,
            'orderCount': snapshot.orderCount,
            'orderValueUsd': snapshot.orderValueUsd,
            'fetchedAt': Timestamp.fromDate(snapshot.fetchedAt),
          });
    } catch (e) {
      debugPrint('[BusinessSystemIntegrationService] saveSnapshot error: $e');
    }
  }

  /// Load the latest cached snapshot for each connected provider, returning
  /// a list of snapshots for the program dashboard roll-up.
  static Future<List<BusinessSystemSnapshot>> loadSnapshots(
      String programId) async {
    try {
      final integrations = await loadAll(programId);
      final active =
          integrations.where((i) => i.status.isActive).toList();
      final snapshots = <BusinessSystemSnapshot>[];
      for (final i in active) {
        final snap = await _coll(programId)
            .doc(i.provider.name)
            .collection('snapshots')
            .doc('latest')
            .get();
        if (!snap.exists) {
          snapshots.add(BusinessSystemSnapshot.empty(i.provider));
          continue;
        }
        final d = snap.data() ?? {};
        snapshots.add(BusinessSystemSnapshot(
          provider: i.provider,
          customerCount: (d['customerCount'] as num?)?.toInt() ?? 0,
          openDealCount: (d['openDealCount'] as num?)?.toInt() ?? 0,
          pipelineValueUsd:
              (d['pipelineValueUsd'] as num?)?.toDouble() ?? 0,
          invoiceCount: (d['invoiceCount'] as num?)?.toInt() ?? 0,
          outstandingUsd: (d['outstandingUsd'] as num?)?.toDouble() ?? 0,
          orderCount: (d['orderCount'] as num?)?.toInt() ?? 0,
          orderValueUsd: (d['orderValueUsd'] as num?)?.toDouble() ?? 0,
          fetchedAt: (d['fetchedAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
        ));
      }
      return snapshots;
    } catch (e) {
      debugPrint('[BusinessSystemIntegrationService] loadSnapshots error: $e');
      return [];
    }
  }
}
