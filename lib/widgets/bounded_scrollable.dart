import 'package:flutter/material.dart';

/// A helper widget that wraps scrollable content with bounded height constraints.
/// 
/// This is the recommended replacement for `shrinkWrap: true` on ListView, 
/// GridView, and other scrollable widgets. Using `shrinkWrap: true` forces
/// all items to be built at once, defeating lazy loading and causing
/// performance issues with large lists.
/// 
/// Usage:
/// ```dart
/// BoundedScrollable(
///   child: ListView.builder(
///     physics: const NeverScrollableScrollPhysics(),
///     itemCount: items.length,
///     itemBuilder: (context, index) => ItemWidget(items[index]),
///   ),
/// )
/// ```
class BoundedScrollable extends StatelessWidget {
  const BoundedScrollable({
    super.key,
    required this.child,
    this.maxHeight = 400,
    this.minHeight = 0,
  });

  /// The scrollable child widget (ListView, GridView, etc.)
  final Widget child;

  /// Maximum height constraint. Default is 400px.
  /// Adjust based on expected content size.
  final double maxHeight;

  /// Minimum height constraint. Default is 0.
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: minHeight,
        maxHeight: maxHeight,
      ),
      child: child,
    );
  }
}

/// Extension on Widget to easily wrap with bounded height.
extension BoundedScrollableExtension on Widget {
  /// Wraps this widget with bounded height constraints.
  /// Useful for replacing shrinkWrap: true pattern.
  Widget boundedScroll({double maxHeight = 400, double minHeight = 0}) {
    return BoundedScrollable(
      maxHeight: maxHeight,
      minHeight: minHeight,
      child: this,
    );
  }
}
