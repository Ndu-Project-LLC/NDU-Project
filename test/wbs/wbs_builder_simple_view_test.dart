// Tests for the WBS Builder screen's Simple (diagram) view — the two things
// the owner asked for on 2026-09-30:
//
//   1. "cards … have a solid color instead of the gradient color"
//   2. "connector arrows actually touch and connect to each other instead of
//      the current manner it is reflected"
//
// The geometry contract is: a parent card's bottom edge, the connector band,
// and the child cards' top edges are laid out flush (no SizedBox gaps), and
// every stub is drawn at a slot centre the card row also uses. These tests
// pin that contract so a future layout tweak cannot quietly reintroduce
// floating lines.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/wbs/screens/wbs_builder_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A WBS provider with storage loaded and a small tree set up:
/// root → Engineering (Design, Build) and Procurement (leaf).
Future<WBSProvider> newWbsProvider(WidgetTester tester) async {
  final provider = WBSProvider();
  await tester.runAsync(() async {
    for (var i = 0; i < 200 && provider.isLoadingFromStorage; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });
  provider.setup(
      projectName: 'Lusaka', framework: WBSFramework.waterfallDeliverable);
  final one = provider.addChildNode(provider.wbs!.level0.id, 'Engineering');
  provider.addChildNode(provider.wbs!.level0.id, 'Procurement');
  provider.addChildNode(one, 'Design');
  provider.addChildNode(one, 'Build');
  return provider;
}

Future<void> pumpBuilder(WidgetTester tester, WBSProvider provider) async {
  tester.view.physicalSize = const Size(1600, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WBSProvider>.value(value: provider),
        ChangeNotifierProvider<CostEstimateProvider>(
            create: (_) => CostEstimateProvider()),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: WBSBuilderScreen())),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// The diagram node card containing [name]: the view's cards are the only
/// Containers constrained to a 240 max width.
Finder cardFor(String name) => find
    .ancestor(
      of: find.text(name),
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.maxWidth == 240,
      ),
    )
    .first;

/// Connector bands by painter type (the painters are private, so match on
/// the runtime type string).
Finder topDownBands() => find.byWidgetPredicate(
      (w) =>
          w is CustomPaint &&
          w.painter.runtimeType.toString() == '_TopDownConnectorPainter',
    );

Finder leftRightBands() => find.byWidgetPredicate(
      (w) =>
          w is CustomPaint &&
          w.painter.runtimeType.toString() == '_LeftRightConnectorPainter',
    );

Finder parentStubs() => find.byWidgetPredicate(
      (w) =>
          w is CustomPaint &&
          w.painter.runtimeType.toString() == '_LeftRightParentStubPainter',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('diagram cards are solid — no gradient anywhere on them',
      (tester) async {
    final provider = await newWbsProvider(tester);
    await pumpBuilder(tester, provider);

    final cards = find.byWidgetPredicate(
      (w) => w is Container && w.constraints?.maxWidth == 240,
    );
    expect(cards, findsWidgets);
    for (final widget in tester.widgetList<Container>(cards)) {
      final decoration = widget.decoration! as BoxDecoration;
      expect(decoration.gradient, isNull,
          reason: 'diagram cards must not use a gradient');
      expect(decoration.color, LightModeColors.accent.withValues(alpha: 0.14));
    }
  });

  testWidgets('top-down connectors touch both the parent and child cards',
      (tester) async {
    final provider = await newWbsProvider(tester);
    await pumpBuilder(tester, provider);

    // Root card ("Lusaka") bottom edge, the root connector band, and the
    // level-1 cards' top edges must be flush: card bottom == band top, band
    // bottom == child card top. The old layout inserted 10px/6px SizedBox
    // gaps that left every line floating short of the cards.
    final rootCard = tester.getRect(cardFor('Lusaka'));
    final band = tester.getRect(topDownBands().first);
    final engineeringCard = tester.getRect(cardFor('Engineering'));
    final procurementCard = tester.getRect(cardFor('Procurement'));

    expect(rootCard.bottom, band.top,
        reason: 'parent stub must start on the parent card bottom edge');
    expect(band.bottom, engineeringCard.top,
        reason: 'child stubs must end on the child card top edge');
    expect(band.bottom, procurementCard.top);

    // Each stub is drawn at its slot centre — where the card row actually
    // puts the card (slots are 260 wide, cards centred in them).
    expect(engineeringCard.center.dx, closeTo(band.left + 130, 1.0));
    expect(procurementCard.center.dx, closeTo(band.left + 390, 1.0));
  });

  testWidgets('expanded parents keep the flush chain one level deeper',
      (tester) async {
    final provider = await newWbsProvider(tester);
    await pumpBuilder(tester, provider);

    // Nodes start collapsed; expand "Engineering" through its card toggle
    // (the Tooltip-wrapped icon button inside the card).
    await tester.tap(find
        .descendant(
          of: cardFor('Engineering'),
          matching: find.byIcon(Icons.expand_more),
        )
        .first);
    await tester.pump();
    await tester.pump();

    // Engineering's own band now runs from its card's bottom edge to its
    // children's top edges with no gaps.
    final engineeringCard = tester.getRect(cardFor('Engineering'));
    final engineeringBand = tester.getRect(
        topDownBands().at(1)); // 0 = root band, 1 = Engineering's band
    final designCard = tester.getRect(cardFor('Design'));
    final buildCard = tester.getRect(cardFor('Build'));

    expect(engineeringCard.bottom, engineeringBand.top);
    expect(engineeringBand.bottom, designCard.top);
    expect(engineeringBand.bottom, buildCard.top);
    expect(designCard.center.dx, closeTo(engineeringBand.left + 130, 1.0));
    expect(buildCard.center.dx, closeTo(engineeringBand.left + 390, 1.0));
  });

  testWidgets('left-right connectors touch the cards too', (tester) async {
    final provider = await newWbsProvider(tester);
    await pumpBuilder(tester, provider);

    // Switch to Left-Right via the orientation SegmentedButton.
    await tester.tap(find.text('Left Right'));
    await tester.pump();
    await tester.pump();

    // Parent stub box sits directly between the parent card's right edge and
    // the rows' spine, and the child rows' bands touch the child cards: the
    // gap parent→child is exactly stub(16) + spine(16), no dead space.
    final rootCard = tester.getRect(cardFor('Lusaka'));
    final engineeringCard = tester.getRect(cardFor('Engineering'));

    expect(parentStubs(), findsWidgets);
    expect(leftRightBands(), findsWidgets);
    expect(engineeringCard.left - rootCard.right, 32.0,
        reason: 'stub + spine with zero dead space between card edges');

    // The spine bands hug their child cards: band right edge == card left
    // edge (checked through the widget hierarchy instead of coordinates,
    // since band boxes stretch to their row height).
    final firstBandBox = tester.getRect(leftRightBands().first);
    expect(firstBandBox.right, engineeringCard.left);
  });
}
