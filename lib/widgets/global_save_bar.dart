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
/// [KazAiChatBubble] floating action button at bottom-RIGHT. Both floating
/// elements sit inside a reserved bottom strip — see
/// [kFloatingBottomReservedHeight] — so they NEVER overlap or cut off body
/// content. Host scaffolds pad their body by this amount to leave room.
///
/// The button is **stateful** so it can show a brief "Saving…" /
/// "Saved ✓" state while the Firestore write is in flight. If no project
/// is loaded (e.g. on a dashboard with no active project), the bar still
/// renders but taps show an informational "Nothing to save" message.
/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Vertical space reserved at the bottom of every screen that hosts the
/// [GlobalSaveBar] and/or the [KazAiChatBubble] FAB. Both floating elements
/// live inside this strip — body content is padded up by this amount so
/// nothing is ever hidden behind them.
///
/// Calculation:
///   KazAiChatBubble FAB height           64
///   + bottom margin                       24
///   + small visual gap                     8
///   ─────────────────────────────────────────
///   Total reserved                        96
///
/// The Save pill is shorter (~44px tall + 24px margin = 68px) so it sits
/// comfortably within this strip alongside the taller chat bubble FAB.
const double kFloatingBottomReservedHeight = 96.0;

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
