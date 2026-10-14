import 'package:flutter/material.dart';

/// Accent banner shown across the top of every screen when the app is built
/// with `AI_MODE=local` (see `AiMode`).
///
/// Every AI surface is answered by the in-code generator in that mode, so the
/// banner tells users and reviewers that content is locally generated rather
/// than mistaking it for live model output. Dismissible for the session.
class LocalAiBanner extends StatefulWidget {
  const LocalAiBanner({super.key});

  static const String message =
      'Local generation mode — KAZ AI content is generated in the app with no '
      'AI provider connected.';

  @override
  State<LocalAiBanner> createState() => _LocalAiBannerState();
}

class _LocalAiBannerState extends State<LocalAiBanner> {
  /// KAZ AI amber, readable on the pale banner background.
  static const Color _accent = Color(0xFFB45309);
  static const Color _background = Color(0xFFFFF3D6);

  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    return Material(
      color: _background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.psychology_rounded, color: _accent, size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  LocalAiBanner.message,
                  style: TextStyle(color: _accent, fontSize: 12.5),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _dismissed = true),
                icon: const Icon(Icons.close, color: _accent, size: 16),
                tooltip: 'Dismiss',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
