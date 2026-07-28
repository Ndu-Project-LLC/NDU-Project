import 'package:flutter/material.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';

class PhaseTransitionHelper {
  static Route<T> buildRoute<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    String? destinationCheckpoint,
    String? sourceCheckpoint,
    RouteSettings? settings,
  }) {
    final fromCheckpoint = sourceCheckpoint ??
        ProjectDataInherited.maybeOf(context)?.projectData.currentCheckpoint;
    final fromPhase = SidebarNavigationService.phaseForCheckpoint(fromCheckpoint);
    final toPhase =
        SidebarNavigationService.phaseForCheckpoint(destinationCheckpoint);
    final isPhaseChange = (fromPhase != null &&
            toPhase != null &&
            fromPhase != toPhase) ||
        (fromPhase == null &&
            toPhase != null &&
            SidebarNavigationService.isPhaseStartCheckpoint(
              destinationCheckpoint,
            ));

    if (!isPhaseChange) {
      return MaterialPageRoute(builder: builder, settings: settings);
    }

    return PhaseTransitionRoute<T>(
      builder: builder,
      phaseLabel: toPhase,
      settings: settings,
    );
  }

  static Future<T?> pushPhaseAware<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    String? destinationCheckpoint,
    String? sourceCheckpoint,
    RouteSettings? settings,
  }) {
    return Navigator.of(context).push(
      buildRoute(
        context: context,
        builder: builder,
        destinationCheckpoint: destinationCheckpoint,
        sourceCheckpoint: sourceCheckpoint,
        settings: settings,
      ),
    );
  }
}

class PhaseTransitionRoute<T> extends PageRouteBuilder<T> {
  PhaseTransitionRoute({
    required WidgetBuilder builder,
    String? phaseLabel,
    super.settings,
  }) : super(
          // Keep phase-change transitions snappy; long transitions feel like
          // navigation latency and can amplify perceived jank.
          transitionDuration: const Duration(milliseconds: 650),
          reverseTransitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
            final slide = Tween<Offset>(
              begin: const Offset(0.0, 0.06),
              end: Offset.zero,
            ).animate(curve);
            final scale = Tween<double>(begin: 0.985, end: 1.0).animate(curve);

            final overlayOpacity = TweenSequence<double>([
              TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 90),
              TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 10),
            ]).animate(animation);

            final labelOpacity = TweenSequence<double>([
              TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 20),
              TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 70),
              TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 10),
            ]).animate(animation);

            final labelOffset = Tween<Offset>(
              begin: const Offset(0.0, 0.08),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.1, 0.55, curve: Curves.easeOutCubic),
              ),
            );

            final labelText = (phaseLabel ?? '').trim();
            final showPhaseBadge = labelText.isNotEmpty &&
                animation.status != AnimationStatus.reverse;

            return Stack(
              children: [
                FadeTransition(
                  opacity: fade,
                  child: SlideTransition(
                    position: slide,
                    child: ScaleTransition(scale: scale, child: child),
                  ),
                ),
                if (showPhaseBadge) ...[
                  Positioned.fill(
                    child: IgnorePointer(
                      child: FadeTransition(
                        opacity: overlayOpacity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF0F172A)
                                    .withOpacity(0.58),
                                const Color(0xFF1F2937)
                                    .withOpacity(0.48),
                                const Color(0xFF111827)
                                    .withOpacity(0.38),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: FadeTransition(
                        opacity: overlayOpacity,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SizedBox(
                                height: 36,
                                width: 36,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFFFC812),
                                  ),
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Loading next phase...',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: FadeTransition(
                          opacity: labelOpacity,
                          child: SlideTransition(
                            position: labelOffset,
                            child: Container(
                              margin: const EdgeInsets.only(top: 72),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.94),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withOpacity(0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Text(
                                'Entering $labelText',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
}
