import 'package:flutter/material.dart';

/// Reusable compact horizontal action button with icon tile, label,
/// subtitle, and hover state. Used on the Project and Portfolio
/// dashboards for "Group Into A Program" / "Create Program" and
/// "Project Logs" buttons.
///
/// The button has a persistent subtle pulse animation on its accent
/// icon tile so it remains easily identifiable on a busy dashboard
/// without being distracting.
class CompactActionButton extends StatefulWidget {
  const CompactActionButton({
    super.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<CompactActionButton> createState() => _CompactActionButtonState();
}

class _CompactActionButtonState extends State<CompactActionButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  // ── Persistent pulse animation ──
  // Runs continuously while the button is on screen. The icon tile
  // gently scales (1.0 → 1.08 → 1.0) and its accent glow fades in/out,
  // making the button easily identifiable without being distracting.
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseGlow;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    _pulseGlow = Tween<double>(begin: 0.0, end: 0.35).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (!mounted || _isHovered) return;
        setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (!mounted || !_isHovered) return;
        setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _isHovered
                    ? widget.accent.withOpacity(0.08)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isHovered
                      ? widget.accent.withOpacity(0.4)
                      : Color.lerp(
                          const Color(0xFFE2E8F0),
                          widget.accent,
                          _pulseGlow.value * 0.5,
                        )!,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered
                        ? widget.accent.withOpacity(0.12)
                        : widget.accent.withOpacity(_pulseGlow.value * 0.15),
                    blurRadius: _isHovered ? 16 : 8 + (_pulseGlow.value * 8),
                    spreadRadius: _isHovered ? 0 : _pulseGlow.value * 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Row(
            children: [
              // ── Animated icon tile ──
              // The icon tile gently scales and its glow pulses continuously
              AnimatedBuilder(
                animation: _pulseScale,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseScale.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accent
                            .withOpacity(_pulseGlow.value * 0.4),
                        blurRadius: 8 + _pulseGlow.value * 8,
                        spreadRadius: _pulseGlow.value * 1.5,
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, size: 20, color: widget.accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        decoration: TextDecoration.none,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        decoration: TextDecoration.none,
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // ── Animated arrow ──
              // The chevron gently slides right and back, reinforcing that
              // the button is tappable and leads somewhere.
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_pulseGlow.value * 3, 0),
                    child: child,
                  );
                },
                child: Icon(Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: _isHovered
                        ? widget.accent
                        : const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
