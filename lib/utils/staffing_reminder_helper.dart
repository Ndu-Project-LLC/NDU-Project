import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/project_data_model.dart';

/// Types of staffing reminders
enum ReminderType {
  upcomingMobilization,
  overdueMobilization,
  upcomingRelease,
  overdueRelease,
  unfilledPosition,
}

/// Priority levels for reminders
enum Priority { low, medium, high, critical }

/// Data model for a staffing reminder
class StaffingReminder {
  final String id;
  final ReminderType type;
  final String requirementId;
  final String positionTitle;
  final String personName;
  final String targetDate;
  final int daysUntil;
  final Priority priority;
  final String message;

  const StaffingReminder({
    required this.id,
    required this.type,
    required this.requirementId,
    required this.positionTitle,
    required this.personName,
    required this.targetDate,
    required this.daysUntil,
    required this.priority,
    required this.message,
  });

  /// Get icon based on reminder type
  IconData get typeIcon {
    switch (type) {
      case ReminderType.upcomingMobilization:
        return Icons.login_rounded;
      case ReminderType.overdueMobilization:
        return Icons.login_outlined;
      case ReminderType.upcomingRelease:
        return Icons.logout_rounded;
      case ReminderType.overdueRelease:
        return Icons.logout_outlined;
      case ReminderType.unfilledPosition:
        return Icons.person_add_disabled;
    }
  }

  /// Get color based on priority
  Color get priorityColor {
    switch (priority) {
      case Priority.low:
        return const Color(0xFF6B7280);
      case Priority.medium:
        return const Color(0xFFD97706);
      case Priority.high:
        return const Color(0xFFDC2626);
      case Priority.critical:
        return const Color(0xFF991B1B);
    }
  }

  /// Get background color based on priority
  Color get backgroundColor {
    switch (priority) {
      case Priority.low:
        return const Color(0xFFF9FAFB);
      case Priority.medium:
        return const Color(0xFFFFFBEB);
      case Priority.high:
        return const Color(0xFFFEF2F2);
      case Priority.critical:
        return const Color(0xFFFEF2F2);
    }
  }

  /// Get border color based on priority
  Color get borderColor {
    switch (priority) {
      case Priority.low:
        return const Color(0xFFE5E7EB);
      case Priority.medium:
        return const Color(0xFFFDE68A);
      case Priority.high:
        return const Color(0xFFFECACA);
      case Priority.critical:
        return const Color(0xFECACA);
    }
  }
}

/// Helper class for generating staffing plan reminders
class StaffingReminderHelper {
  /// Analyze all staffing requirements and generate reminders
  /// 
  /// Checks for:
  /// - Upcoming mobilizations (within 14 days)
  /// - Overdue mobilizations (up to 30 days past)
  /// - Upcoming releases (within 14 days)
  /// - Overdue releases (up to 30 days past)
  /// - Unfilled positions near start date (within 30 days)
  static List<StaffingReminder> generateReminders(
      List<StaffingRequirement> requirements) {
    final reminders = <StaffingReminder>[];
    final now = DateTime.now();

    for (final req in requirements) {
      // Skip if no dates set
      if (req.startDate.isEmpty && req.endDate.isEmpty) continue;

      try {
        // Check mobilization reminders
        if (req.startDate.isNotEmpty) {
          final startDate = _parseDate(req.startDate);
          if (startDate != null) {
            final daysUntilMobilization = startDate.difference(now).inDays;

            if (daysUntilMobilization <= 14 && daysUntilMobilization > 0) {
              // Upcoming mobilization
              reminders.add(StaffingReminder(
                id: '${req.id}_mobilize',
                type: ReminderType.upcomingMobilization,
                requirementId: req.id,
                positionTitle: req.title,
                personName: req.personName,
                targetDate: req.startDate,
                daysUntil: daysUntilMobilization,
                priority: daysUntilMobilization <= 7 ? Priority.high : Priority.medium,
                message: '${req.personName.isNotEmpty ? req.personName : req.title} mobilizes in $daysUntilMobilization day${daysUntilMobilization != 1 ? 's' : ''} (${_formatDisplayDate(req.startDate)})',
              ));
            } else if (daysUntilMobilization <= 0 && daysUntilMobilization >= -30) {
              // Past due mobilization
              reminders.add(StaffingReminder(
                id: '${req.id}_mobilize_overdue',
                type: ReminderType.overdueMobilization,
                requirementId: req.id,
                positionTitle: req.title,
                personName: req.personName,
                targetDate: req.startDate,
                daysUntil: daysUntilMobilization,
                priority: Priority.critical,
                message: 'OVERDUE: ${req.personName.isNotEmpty ? req.personName : req.title} was supposed to mobilize on ${_formatDisplayDate(req.startDate)}',
              ));
            }
          }
        }

        // Check release/demobilization reminders
        if (req.endDate.isNotEmpty) {
          final endDate = _parseDate(req.endDate);
          if (endDate != null) {
            final daysUntilRelease = endDate.difference(now).inDays;

            if (daysUntilRelease <= 14 && daysUntilRelease > 0) {
              // Upcoming release
              reminders.add(StaffingReminder(
                id: '${req.id}_release',
                type: ReminderType.upcomingRelease,
                requirementId: req.id,
                positionTitle: req.title,
                personName: req.personName,
                targetDate: req.endDate,
                daysUntil: daysUntilRelease,
                priority: daysUntilRelease <= 7 ? Priority.high : Priority.medium,
                message: '${req.personName.isNotEmpty ? req.personName : req.title} releases in $daysUntilRelease day${daysUntilRelease != 1 ? 's' : ''} (${_formatDisplayDate(req.endDate)})',
              ));
            } else if (daysUntilRelease <= 0 && daysUntilRelease >= -30) {
              // Stayed longer than planned
              reminders.add(StaffingReminder(
                id: '${req.id}_release_overdue',
                type: ReminderType.overdueRelease,
                requirementId: req.id,
                positionTitle: req.title,
                personName: req.personName,
                targetDate: req.endDate,
                daysUntil: daysUntilRelease,
                priority: Priority.critical,
                message: 'OVERDUE: ${req.personName.isNotEmpty ? req.personName : req.title} was supposed to release on ${_formatDisplayDate(req.endDate)} (stayed ${daysUntilRelease.abs()} extra day${daysUntilRelease.abs() != 1 ? 's' : ''})',
              ));
            }
          }
        }

        // Check for positions without names assigned near start date
        if (req.startDate.isNotEmpty && req.personName.isEmpty) {
          final startDate = _parseDate(req.startDate);
          if (startDate != null) {
            final daysUntil = startDate.difference(now).inDays;

            if (daysUntil <= 30 && daysUntil > 0) {
              reminders.add(StaffingReminder(
                id: '${req.id}_unfilled',
                type: ReminderType.unfilledPosition,
                requirementId: req.id,
                positionTitle: req.title,
                personName: '',
                targetDate: req.startDate,
                daysUntil: daysUntil,
                priority: Priority.medium,
                message: 'UNFILLED: ${req.title} starts in $daysUntil day${daysUntil != 1 ? 's' : ''} - no person assigned yet',
              ));
            }
          }
        }
      } catch (e) {
        // Skip invalid dates
        continue;
      }
    }

    // Sort by priority (critical first), then by days until (soonest first)
    reminders.sort((a, b) {
      final priorityCompare = b.priority.index.compareTo(a.priority.index);
      if (priorityCompare != 0) return priorityCompare;
      return a.daysUntil.compareTo(b.daysUntil);
    });

    return reminders;
  }

  /// Get summary statistics for reminders
  static Map<String, int> getReminderStats(List<StaffingReminder> reminders) {
    return {
      'total': reminders.length,
      'critical': reminders.where((r) => r.priority == Priority.critical).length,
      'high': reminders.where((r) => r.priority == Priority.high).length,
      'medium': reminders.where((r) => r.priority == Priority.medium).length,
      'low': reminders.where((r) => r.priority == Priority.low).length,
      'mobilization': reminders.where((r) =>
          r.type == ReminderType.upcomingMobilization ||
          r.type == ReminderType.overdueMobilization).length,
      'release': reminders.where((r) =>
          r.type == ReminderType.upcomingRelease ||
          r.type == ReminderType.overdueRelease).length,
      'unfilled': reminders.where((r) =>
          r.type == ReminderType.unfilledPosition).length,
    };
  }

  /// Parse date string in various formats
  static DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    
    // Try common date formats
    final formats = [
      'yyyy-MM-dd',       // 2024-01-15
      'MM/dd/yyyy',       // 01/15/2024
      'dd/MM/yyyy',       // 15/01/2024
      'yyyy/MM/dd',       // 2024/01/15
      'MMM dd, yyyy',     // Jan 15, 2024
      'MMMM dd, yyyy',    // January 15, 2024
    ];
    
    for (final format in formats) {
      try {
        return DateFormat(format).parse(dateStr.trim());
      } catch (e) {
        continue;
      }
    }
    
    // Try parsing quarter format like "Q1 2025"
    final quarterMatch = RegExp(r'Q([1-4])\s*(\d{4})').firstMatch(dateStr.toUpperCase());
    if (quarterMatch != null) {
      final quarter = int.parse(quarterMatch.group(1)!);
      final year = int.parse(quarterMatch.group(2)!);
      final month = (quarter - 1) * 3 + 1; // Q1=Jan, Q2=Apr, Q3=Jul, Q4=Oct
      return DateTime(year, month, 1);
    }
    
    return null;
  }

  /// Format date for display
  static String _formatDisplayDate(String dateStr) {
    final date = _parseDate(dateStr);
    if (date == null) return dateStr;
    return DateFormat('MMM dd, yyyy').format(date);
  }
}
