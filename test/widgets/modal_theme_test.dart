// Pop-up modals share one cream palette (see ModalColors in lib/theme.dart).
// These tests pin it so a dialog cannot quietly drift back to white.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/theme.dart';

void main() {
  testWidgets('showAppDialog paints the dialog and its inputs in cream',
      (tester) async {
    late BuildContext dialogContext;

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showAppDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Modal'),
                    content: Builder(
                      builder: (inner) {
                        dialogContext = inner;
                        return const TextField();
                      },
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final dialogMaterial = tester.widget<Material>(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(Material),
      ).first,
    );
    expect(dialogMaterial.color, ModalColors.surface);
    expect(
      Theme.of(dialogContext).inputDecorationTheme.fillColor,
      ModalColors.field,
    );
  });

  test('modalSurface is cream in light mode and not cream in dark mode', () {
    expect(lightTheme.dialogTheme.backgroundColor, ModalColors.surface);
    expect(darkTheme.brightness, Brightness.dark);
    expect(darkTheme.dialogTheme.backgroundColor, isNot(ModalColors.surface));
  });
}
