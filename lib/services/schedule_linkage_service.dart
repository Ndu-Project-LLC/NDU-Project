import 'package:flutter/material.dart';
import 'package:ndu_project/models/procurement/procurement_models.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/procurement_service.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

/// Manages linkage between procurement items and schedule milestones
class ScheduleLinkageService {
  ScheduleLinkageService._();

  /// Sync requiredByDates for items linked to milestones
  /// Called client-side when schedule changes are detected
  static Future<void> syncRequiredByDates(
    BuildContext context,
    List<ScheduleActivity> updatedActivities,
  ) async {
    final data = ProjectDataHelper.getData(context);
    final projectId = data.projectId ?? '';
    if (projectId.isEmpty) {
      debugPrint('Skipping procurement schedule sync: missing projectId.');
      return;
    }

    for (final activity in updatedActivities) {
      // Only process milestone activities with due dates
      if (!activity.isMilestone || activity.dueDate.isEmpty) continue;

      // Parse the due date
      final newDate = DateTime.tryParse(activity.dueDate);
      if (newDate == null) continue;

      // Find items linked to this milestone
      final itemsStream = ProcurementService.streamItems(projectId);
      final items = await itemsStream.first;

      final linkedItems = items
          .where((item) => item.linkedMilestoneId == activity.id)
          .toList();

      // Update each linked item's requiredByDate
      for (final item in linkedItems) {
        try {
          await ProcurementService.updateItemScheduleLink(
            projectId,
            item.id,
            wbsId: item.linkedWbsId,
            milestoneId: activity.id,
            requiredByDate: newDate,
          );
          debugPrint(
            'Updated item "${item.name}" required date to ${activity.dueDate}',
          );
        } catch (e) {
          debugPrint('Failed to update item ${item.id}: $e');
        }
      }
    }
  }

  /// Check if schedule has updates since last sync and auto-update if needed
  /// Called on screen open for procurement
  static Future<void> checkAndSyncOnOpen(BuildContext context) async {
    final data = ProjectDataHelper.getData(context);

    // Get last sync timestamp from project notes
    final lastSyncStr = data.planningNotes['procurement_schedule_last_sync'];
    DateTime? lastSync;

    if (lastSyncStr != null) {
      lastSync = DateTime.tryParse(lastSyncStr);
    }

    // If schedule has been updated since last sync, sync the items
    if (lastSync != null) {
      final scheduleUpdated = data.planningNotes['planning_schedule_updated'];
      if (scheduleUpdated != null) {
        final updatedTime = DateTime.tryParse(scheduleUpdated);
        if (updatedTime != null && updatedTime.isAfter(lastSync)) {
          // Schedule was updated after our last sync
          await syncRequiredByDates(context, data.scheduleActivities);
          if (!context.mounted) return;
          await _updateLastSyncTimestamp(context);
        }
      }
    } else {
      // First time syncing, do initial sync
      await syncRequiredByDates(context, data.scheduleActivities);
      if (!context.mounted) return;
      await _updateLastSyncTimestamp(context);
    }
  }

  /// Update the last sync timestamp
  static Future<void> _updateLastSyncTimestamp(BuildContext context) async {
    final now = DateTime.now().toIso8601String();
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'procurement',
      dataUpdater: (data) => data.copyWith(
        planningNotes: {
          ...data.planningNotes,
          'procurement_schedule_last_sync': now,
        },
      ),
      showSnackbar: false,
    );
  }

  /// Get available milestones for linking
  static List<ScheduleActivity> getMilestones(ProjectDataModel data) {
    return data.scheduleActivities
        .where((a) => a.isMilestone && a.dueDate.isNotEmpty)
        .toList();
  }

  /// Get WBS elements for linking
  static List<ScheduleActivity> getWbsElements(ProjectDataModel data) {
    return data.scheduleActivities
        .where((a) => a.wbsId.isNotEmpty)
        .toList();
  }

  /// Find milestone by ID
  static ScheduleActivity? findMilestoneById(
    ProjectDataModel data,
    String milestoneId,
  ) {
    try {
      return data.scheduleActivities.firstWhere(
        (a) => a.id == milestoneId && a.isMilestone,
      );
    } catch (e) {
      return null;
    }
  }

  /// Find WBS element by ID
  static ScheduleActivity? findWbsById(
    ProjectDataModel data,
    String wbsId,
  ) {
    try {
      return data.scheduleActivities.firstWhere(
        (a) => a.wbsId == wbsId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get milestone display name
  static String getMilestoneDisplayName(ScheduleActivity activity) {
    if (activity.title.isNotEmpty) return activity.title;
    if (activity.wbsId.isNotEmpty) return activity.wbsId;
    return 'Milestone ${activity.id}';
  }

  /// Get WBS display name
  static String getWbsDisplayName(ScheduleActivity activity) {
    if (activity.title.isNotEmpty) return activity.title;
    if (activity.wbsId.isNotEmpty) return activity.wbsId;
    return 'WBS ${activity.id}';
  }

  /// Calculate lead time warning for an item
  /// Returns true if item must be ordered soon to meet requiredByDate
  static bool needsOrderingSoon(ProcurementItemModel item) {
    if (item.requiredByDate == null) return false;

    final requiredBy = item.requiredByDate!;
    final today = DateTime.now();

    // Calculate lead time based on category (in days)
    final leadTimeDays = _getLeadTimeDaysForCategory(item.category);

    // Calculate latest order date
    final latestOrderDate = requiredBy.subtract(Duration(days: leadTimeDays));

    // Warning if we're within 7 days of latest order date
    return today.isAfter(
      latestOrderDate.subtract(const Duration(days: 7)),
    );
  }

  /// Get lead time in days for a procurement category
  static int _getLeadTimeDaysForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'it equipment':
      case 'technology':
        return 14;
      case 'construction services':
      case 'facilities':
        return 30;
      case 'office & workspace':
      case 'furniture':
        return 21;
      case 'professional services':
      case 'consulting':
        return 7;
      default:
        return 14;
    }
  }

  /// Get all items that are overdue based on their requiredByDate
  static List<ProcurementItemModel> getOverdueItems(
    List<ProcurementItemModel> items,
  ) {
    final now = DateTime.now();
    return items.where((item) {
      return item.requiredByDate != null &&
          item.requiredByDate!.isBefore(now) &&
          item.status != ProcurementItemStatus.delivered;
    }).toList();
  }

  /// Get all items approaching deadline (within 7 days)
  static List<ProcurementItemModel> getApproachingDeadlineItems(
    List<ProcurementItemModel> items,
  ) {
    final now = DateTime.now();
    final sevenDaysFromNow = now.add(const Duration(days: 7));

    return items.where((item) {
      return item.requiredByDate != null &&
          item.requiredByDate!.isAfter(now) &&
          item.requiredByDate!.isBefore(sevenDaysFromNow) &&
          item.status != ProcurementItemStatus.delivered;
    }).toList();
  }
}
