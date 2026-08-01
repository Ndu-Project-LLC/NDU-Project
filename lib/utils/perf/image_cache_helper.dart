// Image cache helper for the NDU Project app.
//
// Forces a target decode size on Image widgets so the raster cache doesn't
// hold full-resolution images (often 1-4 MB PNGs) when they're displayed at
// 48x48 or 96x96 in the UI.
//
// Usage:
//   Image.asset(
//     'assets/images/Ndu_logo.png',
//     cacheWidth: ImageCacheHelper.targetWidth(context, 48),
//   ),
//
// This is a no-op on platforms where cacheWidth/cacheHeight are not supported
// (currently all platforms support it; the helper exists for future-proofing
// and to centralize the dpr multiplier).

import 'dart:ui' show FlutterView;

import 'package:flutter/widgets.dart';

class ImageCacheHelper {
  ImageCacheHelper._();

  /// Returns the physical pixel width to pass to Image's `cacheWidth`.
  ///
  /// [logicalWidth] is the intended display width in logical pixels
  /// (e.g. 48 for a 48x48 avatar).
  ///
  /// The result is `logicalWidth * devicePixelRatio`, rounded to int.
  /// On a 3x retina display, a 48-logical-px avatar decodes at 144 physical
  /// pixels — far smaller than the original 1024-px asset.
  static int targetWidth(BuildContext context, double logicalWidth) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (logicalWidth * dpr).round();
  }

  /// Returns the physical pixel height to pass to Image's `cacheHeight`.
  /// See [targetWidth] for semantics.
  static int targetHeight(BuildContext context, double logicalHeight) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (logicalHeight * dpr).round();
  }

  /// Convenience: returns both cacheWidth and cacheHeight for square avatars.
  static ({int cacheWidth, int cacheHeight}) square(
    BuildContext context,
    double logicalSize,
  ) {
    final px = targetWidth(context, logicalSize);
    return (cacheWidth: px, cacheHeight: px);
  }

  /// For widgets that don't have a BuildContext yet (e.g. top-level Image
  /// in a StatelessWidget.build before the first frame), use the implicit
  /// view's device pixel ratio. Returns null if no view is available.
  static int? targetWidthFromView(double logicalWidth) {
    final FlutterView? view = PlatformDispatcher.instance.views.isEmpty
        ? null
        : PlatformDispatcher.instance.views.first;
    if (view == null) return null;
    return (logicalWidth * view.devicePixelRatio).round();
  }
}
