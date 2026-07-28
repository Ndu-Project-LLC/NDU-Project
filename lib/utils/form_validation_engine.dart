import 'package:flutter/material.dart';

enum ValidationFieldType {
  text,
  dropdown,
  date,
  multiSelect,
  fileUpload,
  custom,
}

enum MissingRequirementsAction {
  manual,
  autoFill,
  skip,
}

class ValidationFieldRule {
  const ValidationFieldRule({
    required this.id,
    required this.label,
    this.value,
    this.type = ValidationFieldType.text,
    this.section,
    this.required = true,
    this.errorText,
    this.fieldKey,
    this.focusNode,
    this.isMissing,
    this.isAiGenerated = false,
  });

  final String id;
  final String label;
  final dynamic value;
  final ValidationFieldType type;
  final String? section;
  final bool required;
  final String? errorText;
  final GlobalKey? fieldKey;
  final FocusNode? focusNode;
  final bool Function(ValidationFieldRule field)? isMissing;
  final bool isAiGenerated;
}

class ValidationIssue {
  const ValidationIssue({
    required this.id,
    required this.label,
    required this.errorText,
    this.section,
    this.fieldKey,
    this.focusNode,
  });

  final String id;
  final String label;
  final String errorText;
  final String? section;
  final GlobalKey? fieldKey;
  final FocusNode? focusNode;
}

class FormValidationResult {
  const FormValidationResult(this.issues);

  final List<ValidationIssue> issues;

  bool get isValid =>
      !FormValidationEngine.enforceBlockingValidation || issues.isEmpty;
  bool get hasIssues => issues.isNotEmpty;
  ValidationIssue? get firstIssue => issues.isEmpty ? null : issues.first;

  Map<String, String> get errorByFieldId {
    final errors = <String, String>{};
    for (final issue in issues) {
      errors[issue.id] = issue.errorText;
    }
    return errors;
  }

  Map<String, List<ValidationIssue>> get issuesBySection {
    final grouped = <String, List<ValidationIssue>>{};
    for (final issue in issues) {
      final key = (issue.section ?? '').trim();
      if (key.isEmpty) continue;
      grouped.putIfAbsent(key, () => <ValidationIssue>[]).add(issue);
    }
    return grouped;
  }
}

class FormValidationEngine {
  /// When false, validation remains available for UX hints but will not block
  /// navigation/actions that depend on `FormValidationResult.isValid`.
  static bool enforceBlockingValidation = false;

  static FormValidationResult validateForm(
    List<ValidationFieldRule> fields, {
    bool skipAiGeneratedFields = false,
  }) {
    final issues = <ValidationIssue>[];

    for (final field in fields) {
      if (!field.required) continue;
      if (skipAiGeneratedFields && field.isAiGenerated) continue;

      final missing = field.isMissing != null
          ? field.isMissing!(field)
          : _isMissingByType(field);
      if (!missing) continue;

      issues.add(
        ValidationIssue(
          id: field.id,
          label: field.label,
          section: field.section,
          fieldKey: field.fieldKey,
          focusNode: field.focusNode,
          errorText: field.errorText ?? 'This field is required',
        ),
      );
    }

    return FormValidationResult(issues);
  }

  static String buildMissingFieldsMessage(
    FormValidationResult result, {
    int maxItems = 6,
    String intro = 'Please complete the following before continuing:',
  }) {
    if (result.issues.isEmpty) return '';

    final sections = result.issuesBySection.keys.toList(growable: false);
    final header = sections.length == 1
        ? 'The ${sections.first} section is incomplete. Please fill in all required fields.'
        : intro;

    final uniqueLabels = <String>[];
    final seen = <String>{};
    for (final issue in result.issues) {
      if (seen.add(issue.label)) {
        uniqueLabels.add(issue.label);
      }
    }

    final visibleLabels = uniqueLabels.take(maxItems).toList(growable: false);
    final overflow = uniqueLabels.length - visibleLabels.length;
    final bullets = <String>[
      for (final label in visibleLabels) '- $label',
      if (overflow > 0) '- +$overflow more',
    ].join('\n');

    return '$header\n$bullets';
  }

  static void showValidationSnackBar(
    BuildContext context,
    FormValidationResult result, {
    int maxItems = 6,
    String intro = 'Please complete the following before continuing:',
    Duration duration = const Duration(seconds: 5),
    Color backgroundColor = const Color(0xFFEF4444),
  }) {
    if (!context.mounted || result.issues.isEmpty) return;
    final message = buildMissingFieldsMessage(
      result,
      maxItems: maxItems,
      intro: intro,
    );
    if (message.isEmpty) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: backgroundColor,
          duration: duration,
        ),
      );
  }

  static Future<MissingRequirementsAction?> showMissingRequirementsDialog(
    BuildContext context,
    FormValidationResult result, {
    String title = 'Missing Required Information',
    String intro =
        'The following fields are recommended before continuing. You can still proceed and complete them later.',
    String? message,
    String manualActionLabel = 'Edit on Page',
    String autoFillActionLabel = 'Auto-fill with AI',
    String skipActionLabel = 'Continue Anyway',
    bool showAutoFillAction = false,
    int maxItems = 6,
    int dialogWidth = 560,
  }) {
    if (!context.mounted) {
      return Future.value(null);
    }

    final summaries = <String>[];
    final seen = <String>{};
    for (final issue in result.issues) {
      final section = (issue.section ?? '').trim();
      final summary =
          section.isEmpty ? issue.label : '${issue.label} ($section)';
      if (seen.add(summary)) {
        summaries.add(summary);
      }
    }

    final customMessage = (message ?? '').trim();
    final hasIssueList = summaries.isNotEmpty;
    if (!hasIssueList && customMessage.isEmpty) {
      return Future.value(MissingRequirementsAction.skip);
    }

    final visible = summaries.take(maxItems).toList(growable: false);
    final hiddenCount = summaries.length - visible.length;

    return showDialog<MissingRequirementsAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: dialogWidth.toDouble(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customMessage.isNotEmpty ? customMessage : intro,
                style: const TextStyle(fontSize: 13, height: 1.35),
              ),
              if (hasIssueList) const SizedBox(height: 10),
              for (final item in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '- $item',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              if (hiddenCount > 0)
                Text(
                  '- +$hiddenCount more',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (showAutoFillAction)
            TextButton.icon(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(MissingRequirementsAction.autoFill),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text(autoFillActionLabel),
            ),
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(MissingRequirementsAction.manual),
            child: Text(manualActionLabel),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(MissingRequirementsAction.skip),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
            ),
            child: Text(skipActionLabel),
          ),
        ],
      ),
    );
  }

  static Future<void> scrollToFirstIssue(
    FormValidationResult result, {
    Duration duration = const Duration(milliseconds: 280),
    Curve curve = Curves.easeOutCubic,
  }) async {
    final first = result.firstIssue;
    if (first == null) return;

    final issueContext = first.fieldKey?.currentContext;
    if (issueContext != null) {
      await Scrollable.ensureVisible(
        issueContext,
        alignment: 0.12,
        duration: duration,
        curve: curve,
      );
    }

    final focusNode = first.focusNode;
    if (focusNode != null && focusNode.canRequestFocus) {
      focusNode.requestFocus();
    }
  }

  static bool _isMissingByType(ValidationFieldRule field) {
    switch (field.type) {
      case ValidationFieldType.text:
        return !_hasText(field.value);
      case ValidationFieldType.dropdown:
      case ValidationFieldType.date:
      case ValidationFieldType.custom:
        return !_hasValue(field.value);
      case ValidationFieldType.multiSelect:
      case ValidationFieldType.fileUpload:
        return !_hasCollectionValue(field.value);
    }
  }

  static bool _hasText(dynamic value) {
    return value is String && value.trim().isNotEmpty;
  }

  static bool _hasCollectionValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  static bool _hasValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is bool) return value;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }
}

/// Compatibility helper used by older call sites that expect a bool response.
Future<bool> showMissingRequirementsDialog(
  BuildContext context,
  FormValidationResult result, {
  String title = 'Missing Required Information',
  String intro =
      'The following fields are recommended before continuing. You can still proceed and complete them later.',
  String message = '',
  String manualActionLabel = 'Edit on Page',
  String skipActionLabel = 'Continue Anyway',
  bool isAiGenerated = false,
}) async {
  if (isAiGenerated && result.issues.isEmpty && message.trim().isEmpty) {
    return true;
  }

  final action = await FormValidationEngine.showMissingRequirementsDialog(
    context,
    result,
    title: title,
    intro: intro,
    message: message.trim().isEmpty ? null : message.trim(),
    manualActionLabel: manualActionLabel,
    skipActionLabel: skipActionLabel,
    showAutoFillAction: false,
  );

  return action == MissingRequirementsAction.skip;
}
