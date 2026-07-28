import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/procurement/procurement_models.dart';
import 'package:ndu_project/models/procurement/procurement_ui_extensions.dart';

class ProcurementTable extends StatelessWidget {
  const ProcurementTable({super.key, required this.items});

  final List<ProcurementItemModel> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            const Text(
              'No procurement items yet.',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add items to track sourcing and contracts.',
              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: _HeaderCell('Item Name')),
                Expanded(flex: 2, child: _HeaderCell('Category')),
                Expanded(flex: 2, child: _HeaderCell('Status')),
                Expanded(flex: 2, child: _HeaderCell('Budget')),
                Expanded(flex: 2, child: _HeaderCell('Updated')),
              ],
            ),
          ),
          ...items.map((item) => _ProcurementRow(item: item)),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ProcurementRow extends StatelessWidget {
  const _ProcurementRow({required this.item});

  final ProcurementItemModel item;

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency(decimalDigits: 0);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A)),
                ),
                if (item.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.description,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.category,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.status.backgroundColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: item.status.borderColor),
                ),
                child: Text(
                  item.status.label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: item.status.textColor),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              currencyFormat.format(item.budget),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              dateFormat.format(item.updatedAt),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }
}
