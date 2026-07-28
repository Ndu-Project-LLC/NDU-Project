import 'package:flutter/material.dart';
import 'package:ndu_project/models/planning_contracting_models.dart';

class VendorComparisonTable extends StatelessWidget {
  const VendorComparisonTable({
    super.key,
    required this.ranking,
    required this.criteria,
    this.title = 'Vendor Comparison Sheet',
    this.summary,
    this.recommendedVendor,
  });

  final List<MapEntry<String, double>> ranking;
  final List<EvaluationCriteria> criteria;
  final String title;
  final String? summary;
  final String? recommendedVendor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Weighted against ${criteria.length} criteria.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          if (recommendedVendor != null && recommendedVendor!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Recommended vendor: ${recommendedVendor!.trim()}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF047857),
              ),
            ),
          ],
          if (summary != null && summary!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              summary!.trim(),
              style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
            ),
          ],
          const SizedBox(height: 10),
          if (ranking.isEmpty)
            const Text(
              'No scored vendor comparison is available yet.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey[100]),
                  children: const [
                    _HeaderCell('Vendor'),
                    _HeaderCell('Weighted Score'),
                  ],
                ),
                ...ranking.map(
                  (entry) => TableRow(
                    children: [
                      _ValueCell(
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _ValueCell(
                        Text(
                          entry.value.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: child,
    );
  }
}
