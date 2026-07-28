import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/widgets/shimmer_loading.dart';

/// Creates a [CustomTransitionPage] that shows a branded shimmer skeleton
/// during the page transition, then cross-fades to the actual page content.
///
/// This is applied to every GoRoute in the app so that navigation between
/// pages always shows a shimmer loading effect instead of an instant swap
/// or a blank white flash.
CustomTransitionPage<void> shimmerTransitionPage({
  required GoRouterState state,
  required Widget child,
  bool showStatsRow = true,
  Duration transitionDuration = const Duration(milliseconds: 600),
  Duration reverseDuration = const Duration(milliseconds: 400),
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: transitionDuration,
    reverseTransitionDuration: reverseDuration,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // ── Outgoing page: fade out quickly ──
      final outgoingFade = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
          parent: secondaryAnimation,
          curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
        ),
      );

      // ── Incoming page: fade in after shimmer phase ──
      final incomingFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
        ),
      );

      // ── Shimmer overlay: visible during early part of transition ──
      final shimmerOpacity = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: ConstantTween<double>(1.0),
          weight: 40,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 30,
        ),
      ]).animate(animation);

      // ── Gold progress bar at top ──
      final progressWidth = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 0.0, end: 0.65)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 0.65, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInCubic)),
          weight: 50,
        ),
      ]).animate(animation);

      return Stack(
        children: [
          // Outgoing page (fading out)
          if (!secondaryAnimation.isDismissed)
            FadeTransition(
              opacity: outgoingFade,
              child: secondaryAnimation.isAnimating
                  ? child
                  : const SizedBox.shrink(),
            ),

          // Incoming page (fading in)
          FadeTransition(
            opacity: incomingFade,
            child: child,
          ),

          // Shimmer overlay (visible during transition)
          ShimmerAnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              if (animation.value > 0.95) return const SizedBox.shrink();
              return Opacity(
                opacity: shimmerOpacity.value,
                child: IgnorePointer(
                  child: Stack(
                    children: [
                      // Full-page shimmer skeleton
                      Positioned.fill(
                        child: ColoredBox(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: PageShimmerSkeleton(
                            showStatsRow: showStatsRow,
                          ),
                        ),
                      ),
                      // Gold progress line at top
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          height: 2.5,
                          width: MediaQuery.sizeOf(context).width *
                              progressWidth.value,
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
                ),
              );
            },
          ),
        ],
      );
    },
  );
}
