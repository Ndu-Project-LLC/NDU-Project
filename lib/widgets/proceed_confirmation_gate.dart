import 'package:flutter/material.dart';
import 'package:ndu_project/services/user_preferences_service.dart';
import 'package:ndu_project/widgets/review_confirmation_checkbox.dart';

String _normalizedProceedTitle(String? title) {
  if (title == null || title.trim().isEmpty) {
    return 'Please confirm you have reviewed and understood this step';
  }
  final lowered = title.toLowerCase();
  if (lowered.contains('some information is still missing') ||
      lowered.contains('information is still missing')) {
    return 'Please confirm you have reviewed and understood this step';
  }
  return title;
}

Future<bool> showProceedWithoutReviewDialog(
  BuildContext context, {
  String? title,
  String? message,
}) async {
  final shouldSkip = await UserPreferencesService.shouldSkipStepConfirmation();
  if (shouldSkip) return true;

  bool confirmChecked = false;
  bool skipFuture = false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            title: Row(
              children: [
                const Icon(Icons.fact_check_rounded,
                    color: Color(0xFF1D4ED8)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _normalizedProceedTitle(title),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message != null && message.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      message,
                      style: const TextStyle(
                          fontSize: 13.5, color: Color(0xFF4B5563)),
                    ),
                  ),
                CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: confirmChecked,
                  onChanged: (value) =>
                      setState(() => confirmChecked = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'I confirm that I have reviewed all information on this step.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF111827)),
                  ),
                ),
                CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: skipFuture,
                  onChanged: (value) =>
                      setState(() => skipFuture = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Skip confirmation for future steps',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: confirmChecked
                    ? () async {
                        if (skipFuture) {
                          await UserPreferencesService.setSkipStepConfirmation(
                              true);
                        }
                        if (context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD24C),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirm & Continue'),
              ),
            ],
          );
        },
      );
    },
  );

  return result ?? false;
}

class ProceedConfirmationGate extends StatefulWidget {
  const ProceedConfirmationGate({
    super.key,
    required this.value,
    required this.onChanged,
    this.scrollController,
    this.padding = const EdgeInsets.only(top: 16),
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry padding;

  @override
  State<ProceedConfirmationGate> createState() =>
      _ProceedConfirmationGateState();
}

class _ProceedConfirmationGateState extends State<ProceedConfirmationGate> {
  bool _showGate = true;

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  @override
  void didUpdateWidget(covariant ProceedConfirmationGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_handleScroll);
      widget.scrollController?.addListener(_handleScroll);
      _handleScroll();
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) {
      if (!_showGate) {
        setState(() => _showGate = true);
      }
      return;
    }

    final max = controller.position.maxScrollExtent;
    final atBottom = controller.offset >= (max - 4);
    final shouldShow = max <= 0 ? true : atBottom;
    if (shouldShow != _showGate) {
      setState(() => _showGate = shouldShow);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showGate) {
      return const SizedBox.shrink();
    }

    return ReviewConfirmationCheckbox(
      value: widget.value,
      onChanged: widget.onChanged,
      padding: widget.padding,
    );
  }
}
