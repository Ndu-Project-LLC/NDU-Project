/// Edit reference: Bind existing Firestore data to existing UI.
///
/// Demonstrates:
/// - app.existingCollection() — reference an already-existing collection
/// - app.existingComponent() — reference an already-existing component
/// - app.editPageOnLoad() — attach page-load actions to existing pages
/// - page.setComponentParam() — bind component instance params to expressions
/// - app.ensurePage() — idempotent page creation for safe reruns
/// - app.ensureFirebaseAuth() — idempotent auth configuration
/// - listOf(), docRef() with existing collection handles
/// - FirestoreQuery + SetState + ActionOutput for data hydration
/// - ListView with ItemRef field access
///
/// Assumes a base project with:
/// - A 'trips' Firestore collection with name, status, startDate fields
/// - A 'TripCard' reusable component with title, status params
/// - A 'FilterChip' reusable component with label, active params
/// - A 'MyTrips' page showing static TripCard instances
/// - A 'HomePage' page
/// - A 'SignInPage' page
library;

import 'package:flutterflow_ai/flutterflow_ai.dart';

// ---------------------------------------------------------------------------
// Base project (create — run once to create the project)
// ---------------------------------------------------------------------------

void buildBaseProject(App app) {
  app.collection(
    'trips',
    fields: {'name': string, 'status': string, 'startDate': dateTime},
  );

  final tripCard = app.component(
    'TripCard',
    description: 'Displays a single trip summary.',
    params: {'title': string, 'status': string},
    body: Container(
      padding: 16,
      color: Colors.secondaryBackground,
      borderRadius: 12,
      child: Column(
        spacing: 4,
        children: [
          Text(Param('title'), style: Styles.titleMedium),
          Text(Param('status'), style: Styles.bodySmall),
        ],
      ),
    ),
  );

  final filterChip = app.component(
    'FilterChip',
    description: 'Selectable filter pill.',
    params: {'label': string, 'active': bool_},
    body: Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.alternate,
      borderRadius: 20,
      child: Text(Param('label'), style: Styles.bodySmall),
    ),
  );

  app.page(
    'MyTrips',
    route: '/trips',
    isInitial: true,
    description: 'Shows a list of trips (static in base project).',
    body: Scaffold(
      appBar: AppBar(title: 'My Trips'),
      body: Column(
        padding: 16,
        spacing: 12,
        children: [
          Row(
            spacing: 8,
            children: [
              filterChip(label: 'All', active: true),
              filterChip(label: 'Planned', active: false),
              filterChip(label: 'Active', active: false),
            ],
          ),
          tripCard(title: 'Beach Vacation', status: 'planned'),
          tripCard(title: 'Mountain Trek', status: 'active'),
        ],
      ),
    ),
  );

  app.page(
    'HomePage',
    route: '/',
    description: 'Landing page.',
    body: Scaffold(body: Text('Welcome')),
  );

  app.page(
    'SignInPage',
    route: '/sign-in',
    description: 'Auth sign-in page.',
    body: Scaffold(body: Text('Sign In')),
  );
}

// ---------------------------------------------------------------------------
// Edit flow — turns static UI into data-driven Firestore app
// ---------------------------------------------------------------------------

void applyDataBindingPatch(App app) {
  // -- Reference existing project resources (no creation, no collision) --
  final trips = app.existingCollection('trips');
  // ignore: unused_local_variable
  final tripCard = app.existingComponent(
    'TripCard',
    params: {'title': string, 'status': string},
  );
  // tripCard can be used in new layouts, e.g.:
  //   ListView(source: State('tripsList'), itemBuilder: (item) =>
  //     tripCard(title: item['name'], status: item['status']));

  // -- Add state fields for the data query results and filter --
  app.editPageState('MyTrips', (state) {
    state.ensureField('tripsList', listOf(trips));
    state.ensureField('selectedFilter', string.withDefault('all'));
  });

  // -- Attach page-load query using the convenience API --
  app.editPageOnLoad('MyTrips', [
    FirestoreQuery(trips, limit: 50, outputAs: 'loadedTrips'),
    SetState('tripsList', ActionOutput('loadedTrips')),
  ]);

  // -- Bind existing filter chips to state --
  app.editPage('MyTrips', (page) {
    // Bind the 'active' param on each FilterChip to a comparison expression.
    page.setComponentParam(
      page.findByText('All'),
      'active',
      Equals(State('selectedFilter'), 'all'),
    );
    page.setComponentParam(
      page.findByText('Planned'),
      'active',
      Equals(State('selectedFilter'), 'planned'),
    );
    page.setComponentParam(
      page.findByText('Active'),
      'active',
      Equals(State('selectedFilter'), 'active'),
    );

    // Wire filter chip taps to update selectedFilter state.
    page.ensureActions(
      page.findByText('All'),
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [SetState('selectedFilter', 'all')],
    );
    page.ensureActions(
      page.findByText('Planned'),
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [SetState('selectedFilter', 'planned')],
    );
    page.ensureActions(
      page.findByText('Active'),
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [SetState('selectedFilter', 'active')],
    );
  });

  // -- Add a new page idempotently (safe to re-run) --
  app.ensurePage(
    'CreateTripPage',
    route: '/create-trip',
    description: 'Form page for creating a new trip.',
    state: {'tripName': string.withDefault('')},
    body: Scaffold(
      appBar: AppBar(title: 'New Trip'),
      body: Column(
        padding: 16,
        spacing: 12,
        children: [
          TextField(
            label: 'Trip Name',
            name: 'TripNameField',
            onChanged: SetState('tripName', TextValue()),
          ),
          Button(
            'Create',
            width: double.infinity,
            color: Colors.primary,
            textColor: Colors.primaryBackground,
            name: 'CreateButton',
          ),
        ],
      ),
    ),
  );

  // -- Idempotent auth (safe to re-run) --
  app.ensureFirebaseAuth(
    providers: [FirebaseAuthProvider.email, FirebaseAuthProvider.google],
    homePage: 'MyTrips',
    signInPage: 'SignInPage',
  );
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void main() {
  // -- First run: create the base project --
  // flutterflow ai run dsl/create.dart --project-name "TravelPlanner"

  // -- Subsequent runs: apply edit flows --
  // flutterflow ai run dsl/edit.dart --project-id "<id>"
}
