import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile sidebar opens in a full-height left drawer',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              MobileSidebarHamburger(
                sidebar: ColoredBox(
                  key: ValueKey('sidebar-content'),
                  color: Colors.white,
                  child: Center(child: Text('Navigation menu')),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    final drawer = find.byKey(const ValueKey('sidebar-content'));
    expect(drawer, findsOneWidget);
    expect(find.text('Navigation menu'), findsOneWidget);

    final rect = tester.getRect(drawer);
    expect(rect.left, closeTo(0, 1));
    expect(rect.top, closeTo(0, 1));
    expect(rect.height, closeTo(800, 1));
    expect(
        rect.width,
        closeTo(
            AppBreakpoints.sidebarWidth(
              tester.element(drawer),
            ),
            1));
    expect(tester.takeException(), isNull);
  });
}
