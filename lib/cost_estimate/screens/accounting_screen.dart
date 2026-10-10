library;

/// GL code mapping for this project's cost estimate.
///
/// The accounting connection is an account-level setting and is managed in
/// Settings (see `AccountingConnectionPanel`). This screen reads that
/// connection, so the estimate knows which provider its GL codes map to.
///
/// Rendered inside the Cost Estimate module's [ResponsiveScaffold] body —
/// no Scaffold of its own. Light-mode (white) theme.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';
import 'package:ndu_project/cost_estimate/services/accounting_integration_service.dart';
import 'package:ndu_project/screens/settings_screen.dart';

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _syncEstimateWithAccount();
    });
  }

  /// Brings the estimate's connection record in line with the account's
  /// connection, so GL mapping reflects what the user actually connected.
  Future<void> _syncEstimateWithAccount() async {
    if (!mounted) return;
    final provider = context.read<CostEstimateProvider>();

    // A web build may be booting straight out of the provider's redirect.
    final pending =
        await AccountingIntegrationService.completePendingBrokerConnect();
    if (!mounted) return;
    if (pending != null &&
        pending.connection.connected &&
        pending.provider != AccountingProvider.none) {
      _adoptConnection(provider, pending.provider, pending.connection);
      return;
    }

    final record = provider.estimate?.accountingIntegration;
    if (record != null &&
        record.connected &&
        record.provider != AccountingProvider.none) {
      await _verifyEstimateRecord(provider, record);
      return;
    }

    // The estimate has no connection yet: adopt the account's, if any.
    for (final p in AccountingProvider.values) {
      if (p == AccountingProvider.none) continue;
      final connection = await AccountingIntegrationService.load(p);
      if (!mounted) return;
      if (connection.connected) {
        _adoptConnection(provider, p, connection);
        return;
      }
    }
  }

  /// Renews a live estimate connection, or clears it when the provider has
  /// withdrawn authorisation.
  Future<void> _verifyEstimateRecord(
      CostEstimateProvider provider, AccountingIntegration record) async {
    final live =
        await AccountingIntegrationService.loadAndRenew(record.provider);
    if (!mounted) return;

    if (live.connected) {
      final renewed =
          live.expiresAt != null && live.expiresAt != record.expiresAt;
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
        _showMessage('${record.provider.label} session renewed.');
      }
      return;
    }

    // Only a *verified* "not connected" clears the record: an unreadable
    // store must never silently drop a real connection.
    if (live.verified) {
      provider
          .updateAccounting(AccountingIntegrationService.disconnectedRecord);
      _showMessage(
          '${record.provider.label} is no longer authorised — reconnect it in Settings to resume syncing.');
    }
  }

  /// Records [connection] on the estimate, keeping any GL codes already mapped.
  void _adoptConnection(CostEstimateProvider provider, AccountingProvider p,
      AccountingConnection connection) {
    final existingMapping =
        provider.estimate?.accountingIntegration?.glMapping ??
            const <AccountingGLMapping>[];
    provider.updateAccounting(AccountingIntegrationService.toEstimateRecord(
      provider: p,
      connection: connection,
      glMapping: existingMapping,
    ));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
                  Text('GL Code Mapping',
                      style: TextStyle(
                          color: Color(0xFF1A1D1F),
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              _buildConnectionNotice(integration),
              const SizedBox(height: 16),
              _buildGLMappingSection(
                  context, provider, integration, canEdit, glMap),
            ],
          ),
        );
      },
    );
  }

  /// Shows which account connection this estimate maps to, or points the user
  /// to Settings to connect one.
  Widget _buildConnectionNotice(AccountingIntegration integration) {
    final connected = integration.connected &&
        integration.provider != AccountingProvider.none;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: connected
            ? const Color(0xFF16A34A).withValues(alpha: 0.05)
            : const Color(0xFFF9FAFB),
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
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              connected
                  ? 'GL codes map to ${integration.provider.label}, your account connection.'
                  : 'No accounting system is connected to your account yet.',
              style: const TextStyle(color: Color(0xFF1A1D1F), fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => SettingsScreen.open(context),
            child: Text(connected ? 'Manage in Settings' : 'Connect in Settings',
                style: const TextStyle(color: LightModeColors.accent)),
          ),
        ],
      ),
    );
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
              child: Text(
                  'Connect an accounting system in Settings to map GL codes.',
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
