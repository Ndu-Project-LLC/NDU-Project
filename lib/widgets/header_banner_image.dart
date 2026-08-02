import 'package:flutter/material.dart';

/// A robust banner image widget that avoids red error overlays.
///
/// Tries to load [asset] first. If it fails, falls back to [fallbackAsset].
/// If both fail, it renders a soft gradient container to preserve layout.
class HeaderBannerImage extends StatefulWidget {
  /// Primary asset path to display.
  final String asset;

  /// Fallback asset used if [asset] fails to load.
  final String fallbackAsset;

  /// Desired height of the banner.
  final double? height;

  /// BoxFit for the image.
  final BoxFit fit;

  const HeaderBannerImage({
    super.key,
    this.asset = 'assets/images/NDU_items.png',
    this.fallbackAsset = 'assets/images/NDU.png',
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  State<HeaderBannerImage> createState() => _HeaderBannerImageState();
}

class _HeaderBannerImageState extends State<HeaderBannerImage> {
  bool _primaryFailed = false;
  bool _fallbackFailed = false;

  @override
  Widget build(BuildContext context) {
    // If both failed, show gradient placeholder
    if (_primaryFailed && _fallbackFailed) {
      return _buildGradientPlaceholder();
    }

    // If primary failed, try fallback
    if (_primaryFailed) {
      return Image.asset(
        widget.fallbackAsset,
        fit: widget.fit,
        height: widget.height,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('HeaderBannerImage: fallback "${widget.fallbackAsset}" failed: $error');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_fallbackFailed) {
              setState(() => _fallbackFailed = true);
            }
          });
          return _buildGradientPlaceholder();
        },
      );
    }

    // Try primary asset first
    return Image.asset(
      widget.asset,
      fit: widget.fit,
      height: widget.height,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('HeaderBannerImage: primary "${widget.asset}" failed: $error');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_primaryFailed) {
            setState(() => _primaryFailed = true);
          }
        });
        // Immediately return fallback while rebuilding
        return Image.asset(
          widget.fallbackAsset,
          fit: widget.fit,
          height: widget.height,
          width: double.infinity,
          errorBuilder: (context2, error2, stackTrace2) {
            debugPrint('HeaderBannerImage: fallback "${widget.fallbackAsset}" also failed: $error2');
            return _buildGradientPlaceholder();
          },
        );
      },
    );
  }

  Widget _buildGradientPlaceholder() {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF4CC), Color(0xFFFFFCF0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: Colors.amber.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
