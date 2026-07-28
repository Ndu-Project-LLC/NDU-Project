/// Edit reference: Add search + filter to an existing list page.
///
/// Demonstrates:
/// - app.editPageState() — add new state fields to existing page
/// - app.ensureSearchBar() — semantic pattern for inserting search input
/// - app.editPage() with structural edits (ensureInsertedBefore)
/// - page.ensureActions() — wire triggers on existing widgets
/// - page.update() — patch widget properties in place
/// - page.bindVisible() — conditional visibility binding
/// - EditPatternTarget selectors (byName, byType)
///
/// Assumes a base project with a page called 'ItemListPage' that has:
/// - A ListView named 'ItemList' showing items from app state
/// - A Text named 'PageTitle' at the top
///
/// Run pattern: first build the base, then apply this patch.
library;

import 'package:flutterflow_ai/flutterflow_ai.dart';

// ---------------------------------------------------------------------------
// Base project (minimal create that the patch edits)
// ---------------------------------------------------------------------------

void buildBaseProject(App app) {
  final item = app.struct('ListItem', {'title': string, 'category': string});

  app.state('items', listOf(item), persisted: true);

  app.page(
    'ItemListPage',
    route: '/',
    isInitial: true,
    body: Scaffold(
      appBar: AppBar(title: 'Items'),
      body: Column(
        padding: 16,
        spacing: 12,
        children: [
          Text('All Items', style: Styles.titleLarge, name: 'PageTitle'),
          Expanded(
            ListView(
              source: AppState('items'),
              spacing: 8,
              name: 'ItemList',
              itemBuilder:
                  (item) => Container(
                    padding: 16,
                    color: Colors.secondaryBackground,
                    borderRadius: 8,
                    child: Column(
                      crossAxis: CrossAxis.start,
                      spacing: 4,
                      children: [
                        Text(item['title'], style: Styles.bodyLarge),
                        Text(
                          item['category'],
                          style: Styles.bodySmall,
                          color: Colors.secondaryText,
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Edit flow — adds search + filter capabilities
// ---------------------------------------------------------------------------

void applySearchFilterPatch(App app) {
  // KEY PATTERN: editPageState adds new local state fields to an existing page.
  // This is rerun-safe — if the field already exists, it's a no-op.
  app.editPageState('ItemListPage', (state) {
    state.ensureField('searchQuery', string.withDefault(''));
    state.ensureField('activeFilter', string.withDefault('all'));
  });

  // KEY PATTERN: ensureSearchBar is a semantic pattern that inserts a search
  // text field before an anchor widget. It wires onChanged to set the state
  // field and is rerun-safe (won't duplicate on re-application).
  app.ensureSearchBar(
    page: 'ItemListPage',
    before: EditPatternTarget.byName('ItemList'),
    stateField: 'searchQuery',
    name: 'SearchField',
    hint: 'Search items...',
  );

  // KEY PATTERN: editPage gives low-level access to the widget tree editor.
  // Use this when semantic patterns don't cover your use case.
  app.editPage('ItemListPage', (page) {
    // KEY PATTERN: ensureInsertedBefore places a widget before an anchor.
    // The anchor is resolved at compile time against the current tree.
    page.ensureInsertedBefore(
      page.findByName('SearchField'),
      Row(
        spacing: 8,
        scrollable: true,
        name: 'FilterChips',
        children: [
          Button(
            'All',
            variant: ButtonVariant.filled,
            borderRadius: 20,
            name: 'FilterAll',
          ),
          Button(
            'Electronics',
            variant: ButtonVariant.outlined,
            borderRadius: 20,
            name: 'FilterElectronics',
          ),
          Button(
            'Books',
            variant: ButtonVariant.outlined,
            borderRadius: 20,
            name: 'FilterBooks',
          ),
        ],
      ),
    );

    // KEY PATTERN: ensureActions wires action triggers on existing widgets.
    page.ensureActions(
      page.findByName('FilterAll'),
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [SetState('activeFilter', 'all')],
    );
    page.ensureActions(
      page.findByName('FilterElectronics'),
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [SetState('activeFilter', 'electronics')],
    );
    page.ensureActions(
      page.findByName('FilterBooks'),
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [SetState('activeFilter', 'books')],
    );

    // KEY PATTERN: update() patches properties on an existing widget in place.
    page.update(page.findByName('PageTitle'), (patch) {
      patch.text('Browse & Search');
    });
  });
}
