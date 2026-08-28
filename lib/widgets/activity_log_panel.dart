import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/activity_log_service.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

class ActivityLogPanel {
  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const _FullScreenActivityLog();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.05),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _ActivityLogPanelDialog extends StatelessWidget {
  const _ActivityLogPanelDialog();

  @override
  Widget build(BuildContext context) {
    final projectId =
        ProjectDataInherited.maybeOf(context)?.projectData.projectId?.trim() ??
            '';

    return SafeArea(
      child: Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.sizeOf(context).width.clamp(320.0, 560.0),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x24000000),
                  blurRadius: 28,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PanelHeader(
                  title: 'Activity Log',
                  subtitle: projectId.isEmpty
                      ? 'No active project found.'
                      : 'Recent changes across all phases and pages.',
                ),
                Expanded(
                  child: projectId.isEmpty
                      ? const _ActivityLogState(
                          title: 'No active project',
                          message:
                              'Select or open a project first to view its audit trail.',
                        )
                      : RepaintBoundary(
                          child: StreamBuilder<List<ActivityLogEntry>>(
                            stream: ActivityLogService.instance
                                .watchActivityLog(projectId),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return _ActivityLogErrorState(
                                  onRetry: () => Navigator.of(context).pop(),
                                );
                              }
                              if (snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  !snapshot.hasData) {
                                return const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 12),
                                      Text(
                                        'Loading activity log...',
                                        style: TextStyle(
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final entries = snapshot.data ?? const [];
                              if (entries.isEmpty) {
                                return const _ActivityLogState(
                                  title: 'No logged activity yet',
                                  message:
                                      'Edits, AI runs, row changes, and page saves will appear here.',
                                );
                              }

                              return ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                itemCount: entries.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  return RepaintBoundary(
                                    key: ValueKey('activity_log_$index'),
                                    child:
                                        _ActivityLogTile(entry: entries[index]),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen activity log page that replaces the old side panel.
///
/// Navigated to via [ActivityLogPanel.open] — a page-route push with a
/// slide-up transition gives users an immersive, screen-filling view of
/// the entire project audit trail.
class _FullScreenActivityLog extends StatelessWidget {
  const _FullScreenActivityLog();

  @override
  Widget build(BuildContext context) {
    final projectId =
        ProjectDataInherited.maybeOf(context)?.projectData.projectId?.trim() ??
            '';
    final projectName =
        ProjectDataInherited.maybeOf(context)?.projectData.projectName ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Activity Log',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            if (projectName.isNotEmpty)
              Text(
                projectName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
            onPressed: () => _exportPdf(context),
            tooltip: 'Export PDF',
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFE5E7EB),
            height: 1,
          ),
        ),
      ),
      body: projectId.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fact_check_outlined,
                    size: 64,
                    color: Color(0xFFD1D5DB),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No active project',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Select or open a project first to view its audit trail.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            )
          : StreamBuilder<List<ActivityLogEntry>>(
              stream: ActivityLogService.instance.watchActivityLog(projectId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 56,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Unable to load activity log',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'The audit feed could not be loaded right now.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading activity log...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final entries = snapshot.data ?? const [];
                if (entries.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fact_check_outlined,
                          size: 64,
                          color: Color(0xFFD1D5DB),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No logged activity yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Edits, AI runs, row changes, and page saves will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Group entries by date
                final groupedEntries = _groupByDate(entries);

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: groupedEntries.length,
                  itemBuilder: (context, index) {
                    final dateGroup = groupedEntries[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date header
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, top: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFFFFC812).withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  dateGroup.date,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${dateGroup.entries.length} event${dateGroup.entries.length != 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Entries for this date
                        ...dateGroup.entries.map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _FullScreenActivityLogTile(entry: entry),
                            )),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  void _exportPdf(BuildContext context) {
    final projectData = ProjectDataHelper.getData(context);
    PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Activity Log',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName ?? 'N/A'},
        ]),
        PdfSection.text('Activity Log', 'Activity log export'),
      ],
    );
  }

  List<_DateGroup> _groupByDate(List<ActivityLogEntry> entries) {
    final map = <String, List<ActivityLogEntry>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final entry in entries) {
      final ts = entry.timestamp ?? DateTime.now();
      final date = DateTime(ts.year, ts.month, ts.day);
      String dateLabel;
      if (date == today) {
        dateLabel = 'Today';
      } else if (date == yesterday) {
        dateLabel = 'Yesterday';
      } else {
        dateLabel = DateFormat('EEEE, MMMM d').format(ts);
      }
      map.putIfAbsent(dateLabel, () => []).add(entry);
    }

    return map.entries.map((e) => _DateGroup(date: e.key, entries: e.value)).toList();
  }
}

class _DateGroup {
  final String date;
  final List<ActivityLogEntry> entries;
  _DateGroup({required this.date, required this.entries});
}

class _FullScreenActivityLogTile extends StatelessWidget {
  const _FullScreenActivityLogTile({required this.entry});

  final ActivityLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final timestamp = entry.timestamp;
    final formattedTime = timestamp == null
        ? ''
        : DateFormat('HH:mm').format(timestamp.toLocal());
    final userLabel = entry.userName.trim().isNotEmpty
        ? entry.userName.trim()
        : entry.userEmail.trim().isNotEmpty
            ? entry.userEmail.trim()
            : 'Unknown user';
    final details = entry.details.entries
        .where((item) => item.value.toString().trim().isNotEmpty)
        .toList(growable: false);

    // Determine icon and color based on action type
    final (icon, iconColor, bgColor) = _getActionStyle(entry.action);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
          // Action icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action title and time
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.action,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    if (formattedTime.isNotEmpty)
                      Text(
                        formattedTime,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                // User and phase info
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 4),
                    Text(
                      userLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    if (entry.phase.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      _MetaChip(label: entry.phase),
                    ],
                    if (entry.page.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _MetaChip(label: entry.page),
                    ],
                  ],
                ),
                // Details
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: details
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item.key}: ',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${item.value}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF4B5563),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
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

  (IconData, Color, Color) _getActionStyle(String action) {
    final lowerAction = action.toLowerCase();
    if (lowerAction.contains('create') || lowerAction.contains('add')) {
      return (Icons.add_circle_outline, const Color(0xFF10B981), const Color(0xFFECFDF5));
    } else if (lowerAction.contains('update') || lowerAction.contains('edit')) {
      return (Icons.edit_outlined, const Color(0xFF3B82F6), const Color(0xFFEFF6FF));
    } else if (lowerAction.contains('delete') || lowerAction.contains('remove')) {
      return (Icons.delete_outline, const Color(0xFFEF4444), const Color(0xFFFEF2F2));
    } else if (lowerAction.contains('approve')) {
      return (Icons.check_circle_outline, const Color(0xFF10B981), const Color(0xFFECFDF5));
    } else if (lowerAction.contains('ai') || lowerAction.contains('generate')) {
      return (Icons.auto_awesome, const Color(0xFFFFC812), const Color(0xFFFFF8E1));
    } else if (lowerAction.contains('save')) {
      return (Icons.save_outlined, const Color(0xFF8B5CF6), const Color(0xFFF5F3FF));
    } else {
      return (Icons.fiber_manual_record_outlined, const Color(0xFF6B7280), const Color(0xFFF3F4F6));
    }
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close activity log',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Color(0xFF374151)),
          ),
        ],
      ),
    );
  }
}

class _ActivityLogTile extends StatelessWidget {
  const _ActivityLogTile({required this.entry});

  final ActivityLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final timestamp = entry.timestamp;
    final formattedTime = timestamp == null
        ? 'Pending timestamp'
        : DateFormat('dd MMM yyyy, HH:mm').format(timestamp.toLocal());
    final userLabel = entry.userName.trim().isNotEmpty
        ? entry.userName.trim()
        : entry.userEmail.trim().isNotEmpty
            ? entry.userEmail.trim()
            : 'Unknown user';
    final details = entry.details.entries
        .where((item) => item.value.toString().trim().isNotEmpty)
        .take(3)
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(label: entry.phase),
              _MetaChip(label: entry.page),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            entry.action,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$userLabel • $formattedTime',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...details.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${item.key}: ${item.value}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF374151),
        ),
      ),
    );
  }
}

class _ActivityLogState extends StatelessWidget {
  const _ActivityLogState({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.fact_check_outlined,
              size: 40,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityLogErrorState extends StatelessWidget {
  const _ActivityLogErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 42,
              color: Color(0xFFF59E0B),
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load activity log',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The audit feed could not be loaded right now. Close the panel and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
