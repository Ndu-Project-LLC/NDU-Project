import 'package:flutter/material.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:provider/provider.dart';

/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/// GlobalSaveBar
/// ─────────────────────────────────────────────────────────────────────────
/// A floating "Save" pill rendered at the bottom-left of every project
/// workspace screen. Matches the design shown in the reference screenshot:
///
///   • Pill / capsule shape with rounded corners
///   • White background with a thin light-gray border
///   • Floppy-disk icon (Icons.save_outlined) on the left
///   • "Save" text label in dark gray/black
///
/// On tap, the button flushes any pending autosave for the current project
/// by calling [ProjectDataProvider.flushAutoSave] — this drains the 2-second
/// debounce timer and writes the in-memory project state to Firestore
/// immediately. A [ScaffoldMessenger] snack bar confirms the save outcome.
///
/// The bar is positioned bottom-LEFT so it does not collide with the
/// [KazAiChatBubble] floating action button at bottom-RIGHT. It is rendered
/// as a `Positioned` overlay inside the scaffold's `Stack`, so existing
/// body content and any `bottomNavigationBar` are left untouched.
///
/// The button is **stateful** so it can show a brief "Saving…" /
/// "Saved ✓" state while the Firestore write is in flight. If no project
/// is loaded (e.g. on a dashboard with no active project), the bar still
/// renders but taps show an informational "Nothing to save" message.
/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class GlobalSaveBar extends StatefulWidget {
  const GlobalSaveBar({super.key});

  @override
  State<GlobalSaveBar> createState() => _GlobalSaveBarState();
}

class _GlobalSaveBarState extends State<GlobalSaveBar> {
  bool _isSaving = false;

  Future<void> _handleSave() async {
    if (_isSaving) return;

    final provider = context.read<ProjectDataProvider>();
    final hasProject = provider.projectData.projectId != null &&
        provider.projectData.projectId!.isNotEmpty;

    if (!hasProject) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Nothing to save — open a project first.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await provider.flushAutoSave();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Saved ✓'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isSaving ? null : _handleSave,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSaving)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.onSurface,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.save_outlined,
                  size: 20,
                  color: colorScheme.onSurface,
                ),
              const SizedBox(width: 8),
              Text(
                _isSaving ? 'Saving…' : 'Save',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
