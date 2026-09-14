// Tests for LocalAiBanner — the app-wide indicator that AI content is being
// generated in code rather than fetched from a provider.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/widgets/local_ai_banner.dart';

Widget _host() => const MaterialApp(
      home: Scaffold(
        body: Column(
          children: [LocalAiBanner(), Expanded(child: SizedBox())],
        ),
      ),
    );

void main() {
  testWidgets('shows the local-generation notice', (tester) async {
    await tester.pumpWidget(_host());

    expect(find.text(LocalAiBanner.message), findsOneWidget);
    expect(find.byIcon(Icons.psychology_rounded), findsOneWidget);
    expect(LocalAiBanner.message, contains('no AI provider connected'));
  });

  testWidgets('stays out of the way of the content below it', (tester) async {
    await tester.pumpWidget(_host());

    final bannerHeight = tester.getSize(find.byType(LocalAiBanner)).height;
    expect(bannerHeight, greaterThan(0));
    // A single-line notice — it must not eat the screen.
    expect(bannerHeight, lessThan(80));
  });

  testWidgets('can be dismissed for the session', (tester) async {
    await tester.pumpWidget(_host());

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.text(LocalAiBanner.message), findsNothing);
  });
}
