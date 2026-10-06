library;

/// Accounting Screen — provider picker, OAuth connection, GL code mapping.
///
/// Rendered inside the Cost Estimate module's [ResponsiveScaffold] body —
/// no Scaffold of its own. Light-mode (white) theme.
///
/// Connecting is a real OAuth 2.0 authorisation: choosing a provider opens the
/// credentials modal, the provider's own consent screen is shown, and the row
/// is only reported as connected once that provider returned a usable access
/// token (see [AccountingIntegrationService]).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';
import 'package:ndu_project/cost_estimate/services/accounting_integration_service.dart';

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  /// Provider currently being connected/disconnected (row spinner).
  AccountingProvider? _busyProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // A web build may be booting straight out of the provider's redirect;
      // finish that first, then check whatever token we hold.
      await _completePendingBrokerConnect();
      await _verifyStoredConnection();
    });
  }

  /// Finishes a brokered connect the provider has just redirected back.
  ///
  /// No-op on native builds and whenever nothing is waiting.
  Future<void> _completePendingBrokerConnect() async {
    if (!mounted) return;
    if (!AccountingIntegrationService.usesServerBroker) return;
    final provider = context.read<CostEstimateProvider>();

    final outcome =
        await AccountingIntegrationService.completePendingBrokerConnect();
    if (!mounted || outcome == null) return;

    if (!outcome.connection.connected ||
        outcome.provider == AccountingProvider.none) {
      _showMessage(
          'Could not finish connecting: ${outcome.connection.message ?? 'the provider did not complete the authorisation.'}');
      return;
    }

    final existingMapping =
        provider.estimate?.accountingIntegration?.glMapping ??
            const <AccountingGLMapping>[];
    provider.updateAccounting(AccountingIntegrationService.toEstimateRecord(
      provider: outcome.provider,
      connection: outcome.connection,
      glMapping: existingMapping,
    ));
    await AccountingIntegrationService.mirrorToCloud(
      projectId: provider.estimate?.projectId ?? '',
      provider: outcome.provider,
      connection: outcome.connection,
    );
    if (!mounted) return;
    _showMessage('${outcome.provider.label} connected.');
  }

  /// Confirms the estimate's stored connection still has a live token.
  ///
  /// An access token that has merely lapsed is renewed in place — that is what
  /// keeps a connected ledger connected across a restart. A connection the
  /// provider has genuinely withdrawn, or one that cannot be renewed, is
  /// reported as disconnected rather than shown as live.
  Future<void> _verifyStoredConnection() async {
    if (!mounted) return;
    final provider = context.read<CostEstimateProvider>();
    final record = provider.estimate?.accountingIntegration;
    if (record == null ||
        !record.connected ||
        record.provider == AccountingProvider.none) {
      return;
    }

    final live =
        await AccountingIntegrationService.loadAndRenew(record.provider);
    if (!mounted) return;

    if (live.connected) {
      // Surface the renewed expiry/scopes; leave the mapping and the
      // authorised account exactly as they were.
      final renewed = live.expiresAt != null &&
          live.expiresAt != record.expiresAt;
      if (renewed) {
        provider.updateAccounting(AccountingIntegration(
          provider: record.provider,
          connected: true,
          connectedAt: live.connectedAt ?? record.connectedAt,
          glMapping: record.glMapping,
          accountLabel: record.accountLabel,
          scopes: live.scopes.isEmpty ? record.scopes : live.scopes,
          expiresAt: live.expiresAt,
        ));
        if (!mounted) return;
        _showMessage('${record.provider.label} session renewed.');
      }
      return;
    }

    // Only a *verified* "not connected" clears the record: an unreadable
    // store must never silently drop a real connection.
    if (live.verified) {
      provider
          .updateAccounting(AccountingIntegrationService.disconnectedRecord);
      if (!mounted) return;
      _showMessage(
          '${record.provider.label} is no longer authorised — reconnect to resume syncing.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CostEstimateProvider>(
      builder: (context, provider, _) {
        final estimate = provider.estimate!;
        final integration = estimate.accountingIntegration ??
            const AccountingIntegration(
                provider: AccountingProvider.none,
                connected: false,
                glMapping: []);
        final canEdit =
            (provider.currentRole == RBACRole.approver ||
                provider.currentRole == RBACRole.admin) &&
            estimate.status == EstimateStatus.draft;
        final glMap = defaultGLMappings();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.link, color: LightModeColors.accent, size: 20),
                  SizedBox(width: 8),
                  Text('Accounting Integration',
                      style: TextStyle(
                          color: Color(0xFF1A1D1F),
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Connection
                  Expanded(
                    child: _buildConnectionSection(
                        context, provider, integration, canEdit),
                  ),
                  const SizedBox(width: 24),
                  // GL Mapping
                  Expanded(
                    child: _buildGLMappingSection(
                        context, provider, integration, canEdit, glMap),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionSection(
    BuildContext context,
    CostEstimateProvider provider,
    AccountingIntegration integration,
    bool canEdit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Connection',
            style: TextStyle(
                color: Color(0xFF1A1D1F),
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildStatusCard(integration),
        const SizedBox(height: 16),
        // Provider picker
        if (!integration.connected && canEdit)
          ...AccountingProvider.values
              .where((p) => p != AccountingProvider.none)
              .map((p) => _buildProviderRow(p)),
        if (!integration.connected && !canEdit)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4E7EC)),
            ),
            child: const Text(
              'Only an approver or admin can connect an accounting provider, and only while the estimate is a draft.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ),
        if (integration.connected && canEdit)
          TextButton(
            onPressed: _busyProvider != null
                ? null
                : () => _disconnect(provider, integration.provider),
            child: const Text('Disconnect',
                style: TextStyle(color: Color(0xFFB91C1C))),
          ),
      ],
    );
  }

  /// Current connection status — driven by the stored token, never by an
  /// optimistic "connecting" flag.
  Widget _buildStatusCard(AccountingIntegration integration) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: integration.connected
            ? const Color(0xFF16A34A).withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: integration.connected
              ? const Color(0xFF16A34A).withValues(alpha: 0.4)
              : const Color(0xFFE4E7EC),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            integration.connected ? Icons.cloud_done : Icons.link_off,
            color: integration.connected
                ? const Color(0xFF16A34A)
                : const Color(0xFF6B7280),
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  integration.connected
                      ? integration.provider.label
                      : 'Not connected',
                  style: const TextStyle(
                      color: Color(0xFF1A1D1F),
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  integration.connected
                      ? _connectedSubtitle(integration)
                      : 'Pick a provider below to connect',
                  style:
                      const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                ),
              ],
            ),
          ),
          if (integration.connected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('LIVE',
                  style: TextStyle(
                      color: Color(0xFF16A34A),
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  String _connectedSubtitle(AccountingIntegration integration) {
    final parts = <String>[];
    final label = integration.accountLabel?.trim() ?? '';
    if (label.isNotEmpty && label != integration.provider.label) {
      parts.add(label);
    }
    final at = integration.connectedAt;
    if (at != null) {
      parts.add('connected ${at.toIso8601String().substring(0, 16)}');
    }
    if (integration.scopes.isNotEmpty) {
      parts.add('${integration.scopes.length} scope'
          '${integration.scopes.length == 1 ? '' : 's'} granted');
    }
    if (parts.isEmpty) return 'Authorised connection';
    return parts.join(' · ');
  }

  Widget _buildProviderRow(AccountingProvider p) {
    final busy = _busyProvider == p;
    final anyBusy = _busyProvider != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: anyBusy ? null : () => _openConnectDialog(p),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4E7EC)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance,
                    color: LightModeColors.accent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.label,
                          style: const TextStyle(
                              color: Color(0xFF1A1D1F),
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const Text('OAuth 2.0 · Secure connection',
                          style: TextStyle(
                              color: Color(0xFF6B7280), fontSize: 11)),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: LightModeColors.accent),
                  )
                else
                  const Icon(Icons.arrow_forward,
                      color: Color(0xFF6B7280), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Collects the client credentials the customer registered with [p] and runs
  /// the provider's OAuth 2.0 flow.
  Future<void> _openConnectDialog(AccountingProvider p) async {
    final provider = context.read<CostEstimateProvider>();
    final needsTenant = AccountingIntegrationService.requiresTenantHost(p);

    // The modal opens straight away; the credentials saved from a previous
    // attempt are filled in as they load, so a slow secure-storage read can
    // never leave the tap with no visible response.
    final needsCredentials = AccountingIntegrationService.requiresClientCredentials;
    final credentials = await showDialog<_ConnectCredentials>(
      context: context,
      builder: (dialogContext) => _ConnectDialog(
        provider: p,
        needsTenantHost: needsTenant,
        needsClientCredentials: needsCredentials,
        usesServerBroker: AccountingIntegrationService.usesServerBroker,
        redirectUri: AccountingIntegrationService.redirectUriForCurrentBuild(),
        scopes: AccountingIntegrationService.scopesFor(p),
        canRunInApp: AccountingIntegrationService.supportsInAppConnect,
      ),
    );

    if (credentials == null || !mounted) return;
    if (needsCredentials && credentials.clientId.isEmpty) {
      _showMessage(
          'Enter the OAuth client ID registered with ${p.label} in your developer app.');
      return;
    }
    if (needsTenant && credentials.tenantHost.isEmpty) {
      _showMessage(
          'Enter your SAP tenant host, for example acme.authentication.sap.hana.ondemand.com.');
      return;
    }

    setState(() => _busyProvider = p);
    final result = await AccountingIntegrationService.connect(
      provider: p,
      clientId: credentials.clientId,
      clientSecret: credentials.clientSecret,
      tenantHost: needsTenant ? credentials.tenantHost : null,
    );
    if (!mounted) return;
    setState(() => _busyProvider = null);

    // Web: the browser has been handed to the provider; the connection is
    // finalised when it comes back (see _completePendingBrokerConnect).
    if (result.pendingRedirect) {
      _showMessage(result.message ??
          'Continue in the provider window to finish connecting ${p.label}.');
      return;
    }

    if (!result.connected) {
      _showMessage(
          'Could not connect ${p.label}: ${result.message ?? 'the provider did not complete the authorisation.'}');
      return;
    }

    // Carry any GL codes already mapped across the (re)connection.
    final existingMapping =
        provider.estimate?.accountingIntegration?.glMapping ??
            const <AccountingGLMapping>[];
    provider.updateAccounting(AccountingIntegrationService.toEstimateRecord(
      provider: p,
      connection: result,
      glMapping: existingMapping,
    ));
    await AccountingIntegrationService.mirrorToCloud(
      projectId: provider.estimate?.projectId ?? '',
      provider: p,
      connection: result,
    );
    if (!mounted) return;
    _showMessage('${p.label} connected.');
  }

  Future<void> _disconnect(
      CostEstimateProvider provider, AccountingProvider p) async {
    if (p == AccountingProvider.none) return;
    final projectId = provider.estimate?.projectId ?? '';
    setState(() => _busyProvider = p);

    // The estimate and the screen are cleared first: a disconnect the user
    // asked for must not wait on a secure-storage or Firestore round-trip.
    provider.updateAccounting(AccountingIntegrationService.disconnectedRecord);
    setState(() => _busyProvider = null);
    _showMessage('${p.label} disconnected.');

    // Token and cloud cleanup continue in the background; neither is allowed
    // to bring the connection back if it fails (see _verifyStoredConnection).
    await AccountingIntegrationService.disconnect(p);
    await AccountingIntegrationService.removeFromCloud(
      projectId: projectId,
      provider: p,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildGLMappingSection(
    BuildContext context,
    CostEstimateProvider provider,
    AccountingIntegration integration,
    bool canEdit,
    Map<CostCategory, ({String code, String name})> glMap,
  ) {
    final mappedCount = integration.glMapping.length;
    final totalCats = CostCategory.values.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('GL Code Mapping',
                style: TextStyle(
                    color: Color(0xFF1A1D1F),
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            if (integration.connected && canEdit)
              TextButton.icon(
                onPressed: () {
                  // Auto-map all
                  final mappings = glMap.entries
                      .map((e) => AccountingGLMapping(
                          category: e.key,
                          glCode: e.value.code,
                          glName: e.value.name))
                      .toList();
                  provider.updateAccounting(AccountingIntegration(
                    provider: integration.provider,
                    connected: true,
                    connectedAt: integration.connectedAt,
                    glMapping: mappings,
                    accountLabel: integration.accountLabel,
                    scopes: integration.scopes,
                    expiresAt: integration.expiresAt,
                  ));
                },
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Auto-map'),
                style: TextButton.styleFrom(
                    foregroundColor: LightModeColors.accent),
              ),
          ],
        ),
        Text('$mappedCount of $totalCats categories mapped',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        const SizedBox(height: 8),
        // Progress bar
        LinearProgressIndicator(
          value: totalCats > 0 ? mappedCount / totalCats : 0,
          backgroundColor: const Color(0xFFE5E7EB),
          color: LightModeColors.accent,
          minHeight: 4,
        ),
        const SizedBox(height: 16),
        if (!integration.connected)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4E7EC)),
            ),
            child: const Center(
              child: Text('Connect an accounting provider to map GL codes.',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
            ),
          )
        else
          ...CostCategory.values.map((cat) {
            final mapping = integration.glMapping
                .where((m) => m.category == cat)
                .firstOrNull;
            final defaultGl = glMap[cat];
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE4E7EC)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(cat.label,
                        style: const TextStyle(
                            color: Color(0xFF495057), fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(mapping?.glCode ?? defaultGl?.code ?? '—',
                        style: const TextStyle(
                            color: Color(0xFF1A1D1F),
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ),
                  Expanded(
                    child: Text(mapping?.glName ?? defaultGl?.name ?? '',
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (mapping != null)
                    const Icon(Icons.check,
                        size: 12, color: Color(0xFF16A34A)),
                ],
              ),
            );
          }),
      ],
    );
  }
}

/// What [_ConnectDialog] collects: the OAuth client credentials the customer
/// registered with the provider.
class _ConnectCredentials {
  const _ConnectCredentials({
    required this.clientId,
    required this.clientSecret,
    required this.tenantHost,
  });

  final String clientId;
  final String clientSecret;
  final String tenantHost;
}

/// The connect modal: the redirect URI to register, the client credentials to
/// paste, and an explicit note about what the connection will do.
class _ConnectDialog extends StatefulWidget {
  const _ConnectDialog({
    required this.provider,
    required this.needsTenantHost,
    required this.needsClientCredentials,
    required this.usesServerBroker,
    required this.redirectUri,
    required this.scopes,
    required this.canRunInApp,
  });

  final AccountingProvider provider;
  final bool needsTenantHost;

  /// Web builds leave this false: the broker holds the credentials server-side.
  final bool needsClientCredentials;
  final bool usesServerBroker;

  /// The URI that must be registered for this build.
  final String redirectUri;
  final List<String> scopes;
  final bool canRunInApp;

  @override
  State<_ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends State<_ConnectDialog> {
  final TextEditingController _clientId = TextEditingController();
  final TextEditingController _clientSecret = TextEditingController();
  final TextEditingController _tenantHost = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  /// Fills in the credentials saved from a previous attempt, without delaying
  /// the modal.
  Future<void> _prefill() async {
    final saved =
        await AccountingIntegrationService.loadClientConfig(widget.provider);
    if (!mounted || saved == null) return;
    setState(() {
      if (_clientId.text.isEmpty) _clientId.text = saved.clientId ?? '';
      if (_tenantHost.text.isEmpty) _tenantHost.text = saved.tenantHost ?? '';
    });
  }

  @override
  void dispose() {
    _clientId.dispose();
    _clientSecret.dispose();
    _tenantHost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.provider.label;
    return AlertDialog(
      title: Text('Connect $label'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.needsClientCredentials
                    ? '1. Register this redirect URI'
                    : '1. Register this redirect URI with $label',
                style: const TextStyle(
                    color: Color(0xFF1A1D1F),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              SelectableText(widget.redirectUri,
                  style: const TextStyle(
                      color: Color(0xFF495057), fontSize: 12)),
              const SizedBox(height: 12),
              Text(
                '${widget.needsClientCredentials
                    ? '2. Paste the OAuth client credentials from your $label developer app.'
                    : '2. Your $label sign-in opens next; the secure server-side broker completes the exchange, so no credentials are entered here.'}'
                '${widget.scopes.isEmpty ? '' : ' Requested scopes: ${widget.scopes.join(', ')}.'}',
                style:
                    const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
              ),
              const SizedBox(height: 14),
              if (widget.needsClientCredentials) ...[
                TextField(
                  controller: _clientId,
                  decoration: const InputDecoration(
                      labelText: 'OAuth client ID',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _clientSecret,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'OAuth client secret (if required)',
                      border: OutlineInputBorder()),
                ),
              ],
              if (widget.needsTenantHost) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _tenantHost,
                  decoration: const InputDecoration(
                      labelText: 'SAP tenant host',
                      hintText: 'acme.authentication.sap.hana.ondemand.com',
                      border: OutlineInputBorder()),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: Text(
                  widget.usesServerBroker
                      ? 'Nothing is marked connected until the provider returns an access token. The exchange runs on the server, so the client secret never reaches this browser; the tokens are kept in this device\u2019s secure storage.'
                      : widget.canRunInApp
                          ? 'Your $label sign-in opens next. Nothing is marked connected unless the provider returns an access token; tokens are kept in this device\u2019s secure storage.'
                          : 'This build cannot launch the provider sign-in itself — the OAuth exchange needs the Android, iOS or macOS app (or the server-side broker). Reopen this screen there to finish connecting $label.',
                  style:
                      const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _ConnectCredentials(
              clientId: _clientId.text.trim(),
              clientSecret: _clientSecret.text,
              tenantHost: _tenantHost.text.trim(),
            ),
          ),
          child: Text('Continue with $label'),
        ),
      ],
    );
  }
}
