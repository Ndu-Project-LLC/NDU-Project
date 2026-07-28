import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/procurement/procurement_models.dart';

class BudgetTrackingTable extends StatelessWidget {
  const BudgetTrackingTable({
    super.key,
    required this.items,
    required this.purchaseOrders,
  });

  final List<ProcurementItemModel> items;
  final List<PurchaseOrderModel> purchaseOrders;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Text(
          'No procurement items yet for budget tracking.',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }

    final totals = _BudgetTotals.from(items, purchaseOrders);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricTile(label: 'Budget', value: _formatCurrency(totals.budget)),
              _MetricTile(label: 'Spent', value: _formatCurrency(totals.spent)),
              _MetricTile(
                label: 'Committed',
                value: _formatCurrency(totals.committed),
              ),
              _MetricTile(
                label: 'Remaining',
                value: _formatCurrency(totals.remaining),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Item')),
                DataColumn(label: Text('Budget')),
                DataColumn(label: Text('Spent')),
                DataColumn(label: Text('Committed')),
                DataColumn(label: Text('Remaining')),
                DataColumn(label: Text('Variance')),
                DataColumn(label: Text('Status')),
              ],
              rows: items
                  .map(
                    (item) {
                      final committed = item.committedAmount(purchaseOrders);
                      final remaining = item.remainingBudget(purchaseOrders);
                      final variance = item.variancePercent(purchaseOrders);
                      final status = item.budgetStatus(purchaseOrders);
                      return DataRow(
                        cells: [
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Text(
                                item.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text(_formatCurrency(item.budget))),
                          DataCell(Text(_formatCurrency(item.spent))),
                          DataCell(Text(_formatCurrency(committed))),
                          DataCell(Text(_formatCurrency(remaining))),
                          DataCell(Text('${variance.toStringAsFixed(1)}%')),
                          DataCell(_BudgetStatusBadge(status: status)),
                        ],
                      );
                    },
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(value);
  }
}

class _BudgetTotals {
  const _BudgetTotals({
    required this.budget,
    required this.spent,
    required this.committed,
    required this.remaining,
  });

  final double budget;
  final double spent;
  final double committed;
  final double remaining;

  factory _BudgetTotals.from(
    List<ProcurementItemModel> items,
    List<PurchaseOrderModel> purchaseOrders,
  ) {
    final budget = items.fold<double>(0, (total, item) => total + item.budget);
    final spent = items.fold<double>(0, (total, item) => total + item.spent);
    final committed = items.fold<double>(
      0,
      (total, item) => total + item.committedAmount(purchaseOrders),
    );
    return _BudgetTotals(
      budget: budget,
      spent: spent,
      committed: committed,
      remaining: budget - spent - committed,
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetStatusBadge extends StatelessWidget {
  const _BudgetStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    late final Color background;
    late final Color border;
    late final Color foreground;
    late final String label;

    switch (status) {
      case 'over':
        label = 'Over';
        background = const Color(0xFFFEE2E2);
        border = const Color(0xFFFCA5A5);
        foreground = const Color(0xFFB91C1C);
        break;
      case 'under':
        label = 'Under';
        background = const Color(0xFFDCFCE7);
        border = const Color(0xFF86EFAC);
        foreground = const Color(0xFF15803D);
        break;
      case 'within':
      default:
        label = 'Within';
        background = const Color(0xFFDBEAFE);
        border = const Color(0xFF93C5FD);
        foreground = const Color(0xFF1D4ED8);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}
