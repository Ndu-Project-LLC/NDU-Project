library;

/// Account-level accounting connection: the provider picker, OAuth 2.0 sign-in
/// and connection status.
///
/// A connection belongs to the user's account, not to a project, so it is
/// managed here in account Settings. Every cost estimate then maps its GL codes
/// against that one connection (see `AccountingScreen`).
///
/// Connecting is a real OAuth 2.0 authorisation: choosing a provider opens the
/// credentials modal, the provider's own consent screen is shown, and the
/// provider is only reported as connected once it returned a usable access
/// token (see [AccountingIntegrationService]).

import 'package:flutter/material.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/services/accounting_integration_service.dart';

class AccountingConnectionPanel extends StatefulWidget {
  const AccountingConnectionPanel({super.key});

  @override
  State<AccountingConnectionPanel> createState() =>
      _AccountingConnectionPanelState();
}

class _AccountingConnectionPanelState extends State<AccountingConnectionPanel> {
  /// The one provider this account is connected to, or `none`.
  AccountingProvider _connectedProvider = AccountingProvider.none;
  AccountingConnection? _connection;

  /// Provider currently being connected/disconnected (row spinner).
  AccountingProvider? _busyProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // A web build may be booting straight out of the provider's redirect;
      // finish that first, then read whatever token is held.
      await _completePendingBrokerConnect();
      await _refresh();
    });
  }

  /// Reads the stored connection for every provider and renews the live one.
  Future<void> _refresh() async {
    var found = AccountingProvider.none;
    for (final p in AccountingProvider.values) {
      if (p == AccountingProvider.none) continue;
      final stored = await AccountingIntegrationService.load(p);
      if (stored.connected) {
        found = p;
        break;
      }
    }
    AccountingConnection? live;
    if (found != AccountingProvider.none) {
      live = await AccountingIntegrationService.loadAndRenew(found);
      if (!live.connected) {
        // Only a verified "not connected" drops the row; an unreadable store
        // must never silently remove a real connection.
        if (live.verified) found = AccountingProvider.none;
        live = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _connectedProvider = found;
      _connection = live;
    });
  }

  /// Finishes a brokered connect the provider has just redirected back.
  /// No-op on native builds and whenever nothing is waiting.
  Future<void> _completePendingBrokerConnect() async {
    if (!mounted) return;
    if (!AccountingIntegrationService.usesServerBroker) return;

    final outcome =
        await AccountingIntegrationService.completePendingBrokerConnect();
    if (!mounted || outcome == null) return;

    if (!outcome.connection.connected ||
        outcome.provider == AccountingProvider.none) {
      _showMessage(
          'Could not finish connecting: ${outcome.connection.message ?? 'the provider did not complete the authorisation.'}');
      return;
    }
    _showMessage('${outcome.provider.label} connected.');
  }

  /// Collects the client credentials the customer registered with [p] and runs
  /// the provider's OAuth 2.0 flow.
  Future<void> _openConnectDialog(AccountingProvider p) async {
    final needsTenant = AccountingIntegrationService.requiresTenantHost(p);

    // The modal opens straight away; saved credentials fill in as they load.
    final needsCredentials =
        AccountingIntegrationService.requiresClientCredentials;
    final credentials = await showAppDialog<_ConnectCredentials>(
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

    _showMessage('${p.label} connected.');
    setState(() {
      _connectedProvider = p;
      _connection = result;
    });
  }

  Future<void> _disconnect(AccountingProvider p) async {
    if (p == AccountingProvider.none) return;
    // The screen is cleared first: a disconnect the user asked for must not
    // wait on a secure-storage round-trip. Token cleanup runs in the background.
    setState(() {
      _connectedProvider = AccountingProvider.none;
      _connection = null;
    });
    _showMessage('${p.label} disconnected.');
    await AccountingIntegrationService.disconnect(p);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // The picker is shown straight away and switches to the status card once
    // the stored connection has been read, so the page never waits on storage.
    final connected = _connection != null &&
        _connectedProvider != AccountingProvider.none;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Connect your accounting system once. The connection belongs to your '
          'account, so every project\u2019s cost estimate can map its GL codes '
          'to it.',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
        ),
        const SizedBox(height: 12),
        _buildStatusCard(connected),
        const SizedBox(height: 12),
        if (connected)
          TextButton(
            onPressed: _busyProvider != null
                ? null
                : () => _disconnect(_connectedProvider),
            child: const Text('Disconnect',
                style: TextStyle(color: Color(0xFFB91C1C))),
          )
        else
          for (final p in AccountingProvider.values)
            if (p != AccountingProvider.none) _buildProviderRow(p),
      ],
    );
  }

  Widget _buildStatusCard(bool connected) {
    final connection = _connection;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: connected
            ? const Color(0xFF16A34A).withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: connected
              ? const Color(0xFF16A34A).withValues(alpha: 0.4)
              : const Color(0xFFE4E7EC),
        ),
      ),
      child: Row(
        children: [
          Icon(
            connected ? Icons.cloud_done : Icons.link_off,
            color: connected ? const Color(0xFF16A34A) : const Color(0xFF6B7280),
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? _connectedProvider.label : 'Not connected',
                  style: const TextStyle(
                      color: Color(0xFF1A1D1F),
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  connected
                      ? _connectedSubtitle(connection!)
                      : 'Pick a provider below to connect',
                  style:
                      const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                ),
              ],
            ),
          ),
          if (connected)
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

  String _connectedSubtitle(AccountingConnection connection) {
    final parts = <String>[];
    final label = connection.accountLabel?.trim() ?? '';
    if (label.isNotEmpty && label != _connectedProvider.label) {
      parts.add(label);
    }
    final at = connection.connectedAt;
    if (at != null) {
      parts.add('connected ${at.day}/${at.month}/${at.year}');
    }
    return parts.isEmpty ? 'OAuth 2.0 · Secure connection' : parts.join(' · ');
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
