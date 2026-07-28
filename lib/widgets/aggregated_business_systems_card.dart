import 'package:flutter/material.dart';
import 'package:ndu_project/screens/business_system_integrations_screen.dart';
import 'package:ndu_project/services/business_system_integration_service.dart';

/// Card shown on the program dashboard that aggregates data from all
/// connected CRM / ERP / Accounting integrations.
///
/// Shows:
/// - A row of category chips (CRM / ERP / Accounting) with per-category
///   counts of connected providers
/// - A 4-stat grid: Total customers · Open pipeline $ · Outstanding invoices $ · Open orders $
/// - A "Connect more" button that opens [BusinessSystemIntegrationsScreen]
class AggregatedBusinessSystemsCard extends StatefulWidget {
  const AggregatedBusinessSystemsCard({
    super.key,
    required this.programId,
    this.programName,
  });

  final String programId;
  final String? programName;

  @override
  State<AggregatedBusinessSystemsCard> createState() =>
      _AggregatedBusinessSystemsCardState();
}

class _AggregatedBusinessSystemsCardState
    extends State<AggregatedBusinessSystemsCard> {
  List<BusinessSystemSnapshot> _snapshots = [];
  List<BusinessSystemIntegration> _integrations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final integrations = await BusinessSystemIntegrationService.loadAll(
          widget.programId);
      final snapshots = await BusinessSystemIntegrationService.loadSnapshots(
          widget.programId);
      if (mounted) {
        setState(() {
          _integrations = integrations;
          _snapshots = snapshots;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center),
            )
          else if (_integrations.where((i) => i.status.isActive).isEmpty)
            _emptyState()
          else ...[
            _categoryChips(),
            const SizedBox(height: 16),
            _statsGrid(),
            const SizedBox(height: 16),
            _providerList(),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const Icon(Icons.business_center, color: Color(0xFFFFD700), size: 22),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Business systems',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          onPressed: _isLoading ? null : _load,
          icon: const Icon(Icons.refresh, size: 18),
          tooltip: 'Refresh',
        ),
        TextButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BusinessSystemIntegrationsScreen(
                programId: widget.programId,
                programName: widget.programName,
              ),
            ),
          ),
          icon: const Icon(Icons.settings, size: 16),
          label: const Text('Manage',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFE2E8F0),
            style: BorderStyle.solid,
            width: 1),
      ),
      child: Column(
        children: [
          const Icon(Icons.link_off, color: Color(0xFF94A3B8), size: 32),
          const SizedBox(height: 10),
          const Text(
            'No business systems connected',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Connect your CRM, ERP, or accounting software to see aggregated '
            'customers, pipeline, invoices, and orders here.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BusinessSystemIntegrationsScreen(
                  programId: widget.programId,
                  programName: widget.programName,
                ),
              ),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Connect a system'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChips() {
    final byCategory = <BusinessSystemCategory, int>{};
    for (final i in _integrations.where((i) => i.status.isActive)) {
      byCategory[i.provider.category] =
          (byCategory[i.provider.category] ?? 0) + 1;
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: BusinessSystemCategory.values.map((c) {
        final count = byCategory[c] ?? 0;
        final has = count > 0;
        return Chip(
          label: Text('${c.label} · $count',
              style: TextStyle(
                  color: has ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          backgroundColor:
              has ? const Color(0xFFFFD700).withOpacity(0.12) : const Color(0xFFF1F5F9),
          side: BorderSide(
              color: has
                  ? const Color(0xFFFFD700).withOpacity(0.4)
                  : const Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }

  Widget _statsGrid() {
    int totalCustomers = 0;
    double totalPipeline = 0;
    double totalOutstanding = 0;
    int totalOrders = 0;
    double totalOrderValue = 0;
    for (final s in _snapshots) {
      totalCustomers += s.customerCount;
      totalPipeline += s.pipelineValueUsd;
      totalOutstanding += s.outstandingUsd;
      totalOrders += s.orderCount;
      totalOrderValue += s.orderValueUsd;
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.6,
      children: [
        _statTile('Customers', '$totalCustomers',
            Icons.people_outline, const Color(0xFF3B82F6)),
        _statTile('Open pipeline', _money(totalPipeline),
            Icons.trending_up, const Color(0xFF10B981)),
        _statTile('Outstanding', _money(totalOutstanding),
            Icons.receipt_long, const Color(0xFFF59E0B)),
        _statTile('Open orders', '$totalOrders · ${_money(totalOrderValue)}',
            Icons.shopping_cart_outlined, const Color(0xFF8B5CF6)),
      ],
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B))),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _providerList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Connected systems',
            style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ..._integrations
            .where((i) => i.status.isActive)
            .map((i) => _providerRow(i)),
      ],
    );
  }

  Widget _providerRow(BusinessSystemIntegration i) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Color(i.provider.brandColorArgb),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(
              child: Text(
                i.provider.label.substring(0, 1),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.provider.label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  '${i.provider.category.label} · last sync ${_formatSyncTime(i.lastSyncAt)}',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          Icon(i.autoSync ? Icons.sync : Icons.sync_disabled,
              size: 14, color: const Color(0xFF94A3B8)),
        ],
      ),
    );
  }

  String _money(double v) {
    if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(1)}K';
    return '\$${v.toStringAsFixed(0)}';
  }

  String _formatSyncTime(DateTime? t) {
    if (t == null) return 'never';
    final age = DateTime.now().difference(t);
    if (age.inMinutes < 1) return 'just now';
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    if (age.inHours < 24) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }
}
