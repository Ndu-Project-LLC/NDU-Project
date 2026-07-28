library;

/// Accounting Screen — provider picker, mock OAuth, GL code mapping.
///
/// Rendered inside the Cost Estimate module's [ResponsiveScaffold] body —
/// no Scaffold of its own. Light-mode (white) theme.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  bool _connecting = false;

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
        // Current status
        Container(
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
                          ? 'Connected ${integration.connectedAt != null ? integration.connectedAt.toString().substring(0, 16) : ""}'
                          : 'Pick a provider below to connect',
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (integration.connected)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
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
        ),
        const SizedBox(height: 16),
        // Provider picker
        if (!integration.connected && canEdit)
          ...AccountingProvider.values
              .where((p) => p != AccountingProvider.none)
              .map((p) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _connecting ? null : () => _connect(context, provider, p),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFE4E7EC)),
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
                              Icon(Icons.account_balance,
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
                                            color: Color(0xFF6B7280),
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                              if (_connecting)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: LightModeColors.accent),
                                )
                              else
                                const Icon(Icons.arrow_forward,
                                    color: Color(0xFF6B7280), size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )),
        if (integration.connected && canEdit)
          TextButton(
            onPressed: () => provider.updateAccounting(
                const AccountingIntegration(
                    provider: AccountingProvider.none,
                    connected: false,
                    glMapping: [])),
            child: const Text('Disconnect',
                style: TextStyle(color: Color(0xFFB91C1C))),
          ),
      ],
    );
  }

  void _connect(BuildContext context, CostEstimateProvider provider,
      AccountingProvider p) async {
    setState(() => _connecting = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    provider.updateAccounting(AccountingIntegration(
      provider: p,
      connected: true,
      connectedAt: DateTime.now(),
      glMapping: [],
    ));
    setState(() => _connecting = false);
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
