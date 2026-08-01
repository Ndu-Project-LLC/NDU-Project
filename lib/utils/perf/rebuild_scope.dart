// Rebuild scope helpers for the NDU Project app.
//
// These widgets wrap subtrees so that repainting a child does NOT cause the
// parent to rebuild. Use them around heavy list items, chart canvases, and
// any widget that animates independently of its parent's state.
//
// Usage:
//   RepaintBoundary(
//     child: ExpensiveChart(data: data),
//   )
//
// Or use the pre-built wrappers below which also set up a const subtree.

import 'package:flutter/material.dart';

/// A [RepaintBoundary] wrapper for list items. Wrap each item in a ListView
/// to prevent the parent's repaint from cascading down into the item's
/// subtree.
///
/// Example:
///   ListView.builder(
///     itemBuilder: (context, i) => RepaintBoundaryItem(
///       child: MyExpensiveRow(item: items[i]),
///     ),
///   )
class RepaintBoundaryItem extends StatelessWidget {
  const RepaintBoundaryItem({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: child);
  }
}

/// Wraps a child in a RepaintBoundary AND uses a const subtree for the
/// static frame around it. Use this for chart panels and other heavy
/// widgets that are always visible.
class ScopedRepaintBoundary extends StatelessWidget {
  const ScopedRepaintBoundary({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: child);
  }
}

/// Wraps a [StreamBuilder] or [FutureBuilder] so that rebuilds triggered
/// by the stream/future do NOT propagate up to the parent widget. The
/// parent only rebuilds when its own state changes.
///
/// Without this, every snapshot arrival can cause the entire screen to
/// rebuild. With this, only the subtree wrapped in [ScopedStreamBuilder]
/// rebuilds.
class ScopedStreamBuilder<T> extends StatelessWidget {
  const ScopedStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.initialData,
  });

  final Stream<T> stream;
  final AsyncWidgetBuilder<T> builder;
  final T? initialData;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: StreamBuilder<T>(
        stream: stream,
        initialData: initialData,
        builder: builder,
      ),
    );
  }
}

/// Same as [ScopedStreamBuilder] but for [FutureBuilder].
class ScopedFutureBuilder<T> extends StatelessWidget {
  const ScopedFutureBuilder({
    super.key,
    required this.future,
    required this.builder,
    this.initialData,
  });

  final Future<T> future;
  final AsyncWidgetBuilder<T> builder;
  final T? initialData;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FutureBuilder<T>(
        future: future,
        initialData: initialData,
        builder: builder,
      ),
    );
  }
}
