library;

/// WBS Validator Screen — V1-V8 validation checks with pass/warn/fail UI.
///
/// Rendered inside the parent [ResponsiveScaffold]'s TabBarView, so this widget
/// returns its content directly (no Scaffold) with a white background.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/wbs/providers/wbs_validator.dart';

class WBSValidatorScreen extends StatelessWidget {
  const WBSValidatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WBSProvider>(
      builder: (context, provider, _) {
        final wbs = provider.wbs;
        if (wbs == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final checks = WBSValidator.validate(wbs);
        final summary = WBSValidator.summarize(checks);
        final overallColor = switch (summary.overall) {
          'PASS' => const Color(0xFF16A34A),
          'WARN' => const Color(0xFFD97706),
          _ => const Color(0xFFB91C1C),
        };

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: LightModeColors.accent, size: 20),
                  SizedBox(width: 8),
                  Text('WBS Validator',
                      style: TextStyle(
                          color: Color(0xFF1A1D1F),
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                  '8 checks from the WBS guidance docs. Fix all FAIL items before baseline.',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              const SizedBox(height: 24),
              // Overall summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: overallColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: overallColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('OVERALL STATUS',
                            style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 4),
                        Text(
                          summary.overall == 'PASS'
                              ? 'All checks passed'
                              : summary.overall == 'WARN'
                                  ? 'Warnings — review recommended'
                                  : 'Failures — must fix before baseline',
                          style: TextStyle(
                              color: overallColor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: overallColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        summary.overall == 'PASS'
                            ? Icons.check_circle
                            : summary.overall == 'WARN'
                                ? Icons.warning_amber
                                : Icons.error,
                        color: overallColor,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Summary pills
              Row(
                children: [
                  _buildPill('Pass', summary.pass, const Color(0xFF16A34A)),
                  const SizedBox(width: 12),
                  _buildPill('Warn', summary.warn, const Color(0xFFD97706)),
                  const SizedBox(width: 12),
                  _buildPill('Fail', summary.fail, const Color(0xFFB91C1C)),
                ],
              ),
              const SizedBox(height: 24),
              // Check list
              ...checks.map((c) => _buildCheckRow(c)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPill(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text('$count',
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(label.toUpperCase(),
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildCheckRow(ValidationCheck check) {
    final color = switch (check.severity) {
      ValidationSeverity.pass => const Color(0xFF16A34A),
      ValidationSeverity.warn => const Color(0xFFD97706),
      ValidationSeverity.fail => const Color(0xFFB91C1C),
    };
    final icon = switch (check.severity) {
      ValidationSeverity.pass => Icons.check_circle,
      ValidationSeverity.warn => Icons.warning_amber,
      ValidationSeverity.fail => Icons.error,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(check.id,
                          style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    Text(check.title,
                        style: const TextStyle(
                            color: Color(0xFF1A1D1F),
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(check.detail,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 13)),
                if (check.fix != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFFE4E7EC)
                              .withValues(alpha: 0.8)),
                    ),
                    child: Row(
                      children: [
                        const Text('Fix: ',
                            style: TextStyle(
                                color: LightModeColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        Expanded(
                          child: Text(check.fix!,
                              style: const TextStyle(
                                  color: Color(0xFF6B7280), fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
