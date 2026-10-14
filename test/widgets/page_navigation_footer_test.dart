// The footer is the one piece of chrome that has to be identical on every
// page: a labelled way back, the page's position in the flow, and a way
// forward that names where it goes. Before it existed pages drifted — some
// had a bare back arrow, some a "Submit" with no way back, and a few had no
// forward button at all. These tests pin the contract.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/widgets/page_navigation_footer.dart';

Future<void> _pump(
  WidgetTester tester, {
  required String checkpoint,
  required String pageTitle,
  VoidCallback? onPrevious,
  VoidCallback? onNext,
  VoidCallback? onSave,
  String? nextLabel,
  bool? confirmationValue,
  ValueChanged<bool>? onConfirmationChanged,
  List<Widget> extraActions = const <Widget>[],
  Size size = const Size(1400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PageNavigationFooter(
            checkpoint: checkpoint,
            pageTitle: pageTitle,
            onPrevious: onPrevious,
            onNext: onNext,
            onSave: onSave,
            nextLabel: nextLabel,
            confirmationValue: confirmationValue,
            onConfirmationChanged: onConfirmationChanged,
            extraActions: extraActions,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

/// The text of the footer's forward button, whatever the flow resolved it to.
String _continueLabel(WidgetTester tester) {
  final button = find.byWidgetPredicate(
    (w) => w is ElevatedButton && w.onPressed != null,
  );
  return tester.widget<Text>(find.descendant(
    of: button.first,
    matching: find.byType(Text),
  )).data!;
}

void main() {
  // fep_requirements is mid-flow: it has both a previous and a next page.
  const midFlow = 'fep_requirements';

  testWidgets('the footer offers a labelled way back and a way forward',
      (tester) async {
    await _pump(tester, checkpoint: midFlow, pageTitle: 'Requirements');

    expect(find.text('Previous'), findsOneWidget);
    expect(find.textContaining('Continue to'), findsOneWidget);
  });

  testWidgets('the forward button names a real page in the flow',
      (tester) async {
    await _pump(tester, checkpoint: midFlow, pageTitle: 'Requirements');

    final label = _continueLabel(tester);
    expect(label, startsWith('Continue to '),
        reason: 'a generic "Next" is the drift this footer removes');

    final destination = label.substring('Continue to '.length);
    expect(
      SidebarNavigationService.allItems.any((i) => i.label == destination),
      isTrue,
      reason: '"$destination" must be an actual page label, not an invented one',
    );
  });

  testWidgets('the page position is shown so the user knows where they are',
      (tester) async {
    await _pump(tester, checkpoint: midFlow, pageTitle: 'Requirements');

    expect(
      find.textContaining('Requirements · Step '),
      findsOneWidget,
      reason: 'the step status names the page and its position in the flow '
          '("Requirements · Step N of M" — the old "(N of M)" read like a '
          'row count next to the page\'s tables)',
    );
  });

  testWidgets('Previous is disabled on the first page of the flow',
      (tester) async {
    final first = SidebarNavigationService.allItems.first;
    await _pump(
      tester,
      checkpoint: first.checkpoint,
      pageTitle: first.label,
    );

    final previous = tester.widget<OutlinedButton>(find.ancestor(
      of: find.text('Previous'),
      matching: find.byType(OutlinedButton),
    ));
    expect(previous.onPressed, isNull,
        reason: 'there is nothing before the first page to go back to');
  });

  testWidgets('Previous is enabled mid-flow', (tester) async {
    await _pump(tester, checkpoint: midFlow, pageTitle: 'Requirements');

    final previous = tester.widget<OutlinedButton>(find.ancestor(
      of: find.text('Previous'),
      matching: find.byType(OutlinedButton),
    ));
    expect(previous.onPressed, isNotNull);
  });

  testWidgets('tapping back and forward runs the page\'s own actions',
      (tester) async {
    var wentBack = false;
    var wentForward = false;

    await _pump(
      tester,
      checkpoint: midFlow,
      pageTitle: 'Requirements',
      onPrevious: () => wentBack = true,
      onNext: () => wentForward = true,
    );

    await tester.tap(find.text('Previous'));
    await tester.pump();
    await tester.tap(find.textContaining('Continue to'));
    await tester.pump();

    expect(wentBack, isTrue);
    expect(wentForward, isTrue);
  });

  testWidgets('Save appears only when the page has something to save',
      (tester) async {
    await _pump(tester, checkpoint: midFlow, pageTitle: 'Requirements');
    expect(find.text('Save'), findsNothing);

    await _pump(
      tester,
      checkpoint: midFlow,
      pageTitle: 'Requirements',
      onSave: () {},
    );
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('the review gate is shown only when the page wires it',
      (tester) async {
    await _pump(tester, checkpoint: midFlow, pageTitle: 'Requirements');
    expect(find.byType(Checkbox), findsNothing);

    await _pump(
      tester,
      checkpoint: midFlow,
      pageTitle: 'Requirements',
      confirmationValue: false,
      onConfirmationChanged: (_) {},
    );
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('on a phone the buttons stack instead of being clipped',
      (tester) async {
    await _pump(
      tester,
      checkpoint: midFlow,
      pageTitle: 'Requirements',
      onSave: () {},
      size: const Size(390, 900),
    );

    expect(tester.takeException(), isNull,
        reason: 'a long "Continue to ..." label must not overflow a phone');

    final previousTop = tester.getTopLeft(find.text('Previous')).dy;
    final continueTop =
        tester.getTopLeft(find.textContaining('Continue to')).dy;
    expect(continueTop, greaterThan(previousTop),
        reason: 'the forward button takes its own row on a phone');
  });

  testWidgets('survives the narrowest phone with a long page title',
      (tester) async {
    // 320 logical px is the narrowest screen the app supports. This footer is
    // now mounted on dozens of pages, so an overflow here would be an
    // app-wide yellow-and-black stripe.
    await _pump(
      tester,
      checkpoint: 'fep_contract_vendor_quotes',
      pageTitle: 'Contract Vendor Quotes And Commercial Evaluation Summary',
      onSave: () {},
      onNext: () {},
      nextLabel:
          'Continue to Project Opportunities And Commercial Alignment Review',
      size: const Size(320, 640),
    );

    expect(tester.takeException(), isNull,
        reason: 'no RenderFlex overflow at 320px');
    expect(find.text('Previous'), findsOneWidget);
  });

  testWidgets('extra actions do not force the buttons off the edge',
      (tester) async {
    await _pump(
      tester,
      checkpoint: midFlow,
      pageTitle: 'Requirements',
      onSave: () {},
      size: const Size(320, 640),
      extraActions: const [
        Text('AI Suggestions That Have A Fairly Long Label'),
        Text('Import CSV From Another System'),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Previous'), findsOneWidget);
  });

  testWidgets('an explicit next label wins over the derived one',
      (tester) async {
    await _pump(
      tester,
      checkpoint: midFlow,
      pageTitle: 'Requirements',
      nextLabel: 'Submit and continue',
    );

    expect(find.text('Submit and continue'), findsOneWidget);
  });

  testWidgets('the last page of the flow keeps an actionable forward button',
      (tester) async {
    final last = SidebarNavigationService.allItems.last;
    var finished = false;
    await _pump(
      tester,
      checkpoint: last.checkpoint,
      pageTitle: last.label,
      onNext: () => finished = true,
    );

    expect(find.text('Finish'), findsOneWidget,
        reason: 'the end of the flow reads as finishing, not as a dead end');
    await tester.tap(find.text('Finish'));
    await tester.pump();
    expect(finished, isTrue);
  });
}
