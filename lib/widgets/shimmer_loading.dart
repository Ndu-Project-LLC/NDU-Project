import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:ndu_project/theme.dart';

/// Brand-aligned colors for shimmer effects across the app.
class ShimmerColors {
  /// The base (background) color of a shimmer bone.
  static Color base(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? const Color(0xFF1F2937)
        : const Color(0xFFE5E7EB);
  }

  /// The highlight (sweep) color of a shimmer bone.
  static Color highlight(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? const Color(0xFF374151)
        : const Color(0xFFF3F4F6);
  }

  /// The container/card background behind shimmer bones.
  static Color container(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? const Color(0xFF111318)
        : Colors.white;
  }
}

/// A single shimmer bone (rounded rectangle placeholder).
class ShimmerBone extends StatelessWidget {
  const ShimmerBone({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 6,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: ShimmerColors.base(context),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A circular shimmer bone (avatar placeholder).
class ShimmerCircle extends StatelessWidget {
  const ShimmerCircle({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ShimmerColors.base(context),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A full-page shimmer skeleton that mimics the typical NDU screen layout:
/// - Top header/app bar area with back button + title
/// - Stat cards row
/// - Content sections with lines
class PageShimmerSkeleton extends StatelessWidget {
  const PageShimmerSkeleton({super.key, this.showStatsRow = true});

  final bool showStatsRow;

  @override
  Widget build(BuildContext context) {
    final baseColor = ShimmerColors.base(context);
    final highlightColor = ShimmerColors.highlight(context);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row (back + title) ──
              Row(
                children: [
                  ShimmerCircle(size: 36),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBone(width: 180, height: 20),
                        const SizedBox(height: 8),
                        ShimmerBone(width: 240, height: 14),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Stats row ──
              if (showStatsRow) ...[
                Row(
                  children: List.generate(
                    3,
                    (_) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ShimmerColors.container(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: baseColor,
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBone(width: 32, height: 32, borderRadius: 8),
                            const SizedBox(height: 12),
                            ShimmerBone(width: 48, height: 22),
                            const SizedBox(height: 6),
                            ShimmerBone(width: 80, height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // ── Content sections ──
              ...List.generate(3, (sectionIndex) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ShimmerColors.container(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: baseColor, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBone(width: 140, height: 18),
                        const SizedBox(height: 14),
                        ShimmerBone(height: 12),
                        const SizedBox(height: 8),
                        ShimmerBone(height: 12, width: 260),
                        const SizedBox(height: 8),
                        ShimmerBone(height: 12, width: 200),
                        const SizedBox(height: 16),
                        // Table-like rows
                        ...List.generate(4, (rowIndex) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                ShimmerBone(
                                    width: 80, height: 12, borderRadius: 4),
                                const Spacer(),
                                ShimmerBone(
                                    width: 60, height: 12, borderRadius: 4),
                                const Spacer(),
                                ShimmerBone(
                                    width: 90, height: 12, borderRadius: 4),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact shimmer skeleton for sidebar-style narrow layouts.
class SidebarShimmerSkeleton extends StatelessWidget {
  const SidebarShimmerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final baseColor = ShimmerColors.base(context);
    final highlightColor = ShimmerColors.highlight(context);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo area
            ShimmerBone(width: 120, height: 28, borderRadius: 8),
            const SizedBox(height: 28),
            // Nav items
            ...List.generate(8, (_) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    ShimmerCircle(size: 20),
                    const SizedBox(width: 12),
                    ShimmerBone(width: 100, height: 14, borderRadius: 4),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// A wrapper widget that shows a shimmer skeleton while [isLoading] is true,
/// then cross-fades to the actual [child] content when data is ready.
class ShimmerLoadingWrapper extends StatefulWidget {
  const ShimmerLoadingWrapper({
    super.key,
    required this.isLoading,
    required this.child,
    this.showStatsRow = true,
    this.skeleton,
    this.duration = const Duration(milliseconds: 400),
  });

  /// Whether to show the shimmer skeleton instead of real content.
  final bool isLoading;

  /// The actual content to display when loading completes.
  final Widget child;

  /// Whether the skeleton should include a stats row section.
  final bool showStatsRow;

  /// Optional custom skeleton widget. If null, [PageShimmerSkeleton] is used.
  final Widget? skeleton;

  /// Cross-fade animation duration.
  final Duration duration;

  @override
  State<ShimmerLoadingWrapper> createState() => _ShimmerLoadingWrapperState();
}

class _ShimmerLoadingWrapperState extends State<ShimmerLoadingWrapper> {
  bool _showSkeleton = true;

  @override
  void didUpdateWidget(ShimmerLoadingWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isLoading && _showSkeleton) {
      // Data finished loading — start fade-out of skeleton
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _showSkeleton = false);
      });
    } else if (widget.isLoading && !_showSkeleton) {
      // Started loading again — show skeleton immediately
      setState(() => _showSkeleton = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skeleton = widget.skeleton ??
        PageShimmerSkeleton(showStatsRow: widget.showStatsRow);

    if (_showSkeleton && widget.isLoading) {
      return AnimatedOpacity(
        opacity: 1.0,
        duration: widget.duration,
        child: skeleton,
      );
    }

    // Cross-fade: brief overlap where both are visible
    return AnimatedOpacity(
      opacity: _showSkeleton ? 0.0 : 1.0,
      duration: widget.duration,
      child: widget.child,
    );
  }
}

/// A full-screen shimmer overlay used during GoRouter page transitions.
/// Shows the NDU-branded shimmer skeleton with a subtle gold accent line
/// at the top to indicate navigation progress.
class ShimmerTransitionOverlay extends StatefulWidget {
  const ShimmerTransitionOverlay({
    super.key,
    this.showStatsRow = true,
  });

  final bool showStatsRow;

  @override
  State<ShimmerTransitionOverlay> createState() =>
      _ShimmerTransitionOverlayState();
}

class _ShimmerTransitionOverlayState extends State<ShimmerTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _progressWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _progressWidth = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.7)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.7),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.7, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 10,
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShimmerAnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Stack(
            children: [
              // Full-page shimmer skeleton
              Positioned.fill(
                child: ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: PageShimmerSkeleton(
                    showStatsRow: widget.showStatsRow,
                  ),
                ),
              ),
              // Gold progress line at top
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  height: 2.5,
                  width:
                      MediaQuery.sizeOf(context).width * _progressWidth.value,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC812),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(2),
                      bottomRight: Radius.circular(2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFC812).withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shimmer-specific animated builder that rebuilds when the animation changes.
class ShimmerAnimatedBuilder extends AnimatedWidget {
  const ShimmerAnimatedBuilder({
    super.key,
    required Listenable animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
