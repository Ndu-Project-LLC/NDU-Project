library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  await flutterFlowAI(
    buildActionBlockShowcase,
    apiKey: options.apiKey,
    baseUrl: options.baseUrl,
    projectName: options.projectName,
    projectId: options.projectId,
    findOrCreate: options.findOrCreate,
    dryRun: options.dryRun,
    commitMessage: options.commitMessage,
  );
}

final class _CliOptions {
  const _CliOptions({
    this.apiKey,
    this.baseUrl,
    this.projectName,
    this.projectId,
    this.findOrCreate = false,
    this.dryRun = false,
    this.commitMessage,
  });

  final String? apiKey;
  final String? baseUrl;
  final String? projectName;
  final String? projectId;
  final bool findOrCreate;
  final bool dryRun;
  final String? commitMessage;
}

_CliOptions _parseCliOptions(List<String> args) {
  String? apiKey;
  String? baseUrl;
  String? projectName;
  String? projectId;
  String? commitMessage;
  var findOrCreate = false;
  var dryRun = false;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--help':
      case '-h':
        _printUsage();
        exit(0);
      case '--api-key':
        apiKey = _requireValue(args, ++i, '--api-key');
      case '--base-url':
        baseUrl = _requireValue(args, ++i, '--base-url');
      case '--project-name':
        projectName = _requireValue(args, ++i, '--project-name');
      case '--project-id':
        projectId = _requireValue(args, ++i, '--project-id');
      case '--commit-message':
        commitMessage = _requireValue(args, ++i, '--commit-message');
      case '--find-or-create':
        findOrCreate = true;
      case '--dry-run':
        dryRun = true;
      default:
        stderr.writeln('Unknown option: ${args[i]}');
        _printUsage();
        exit(64);
    }
  }

  return _CliOptions(
    apiKey: apiKey,
    baseUrl: baseUrl,
    projectName: projectName,
    projectId: projectId,
    findOrCreate: findOrCreate,
    dryRun: dryRun,
    commitMessage: commitMessage,
  );
}

String _requireValue(List<String> args, int index, String flag) {
  if (index >= args.length) {
    stderr.writeln('Missing value for $flag.');
    _printUsage();
    exit(64);
  }
  return args[index];
}

void _printUsage() {
  stdout.writeln('''
Run the ActionBlockShowcase DSL and push the compiled project to FlutterFlow.

Usage:
  dart run specs/dsl/action_block_showcase_dsl.dart [options]

Options:
  --api-key <key>         FlutterFlow API key. Defaults to FF_API_KEY.
  --base-url <url>        Override the FlutterFlow API base URL.
  --project-name <name>   Create a new project with this name.
  --project-id <id>       Push into an existing project by ID.
  --find-or-create        Find by project name before creating.
  --commit-message <msg>  Commit message for the push.
  --dry-run               Compile and validate without pushing.
  --help, -h              Show this help.
''');
}

App buildActionBlockShowcase(App app) {
  app.state('favoriteIds', listOf(string), persisted: true);
  app.state('favoriteCount', int_, persisted: true);

  final dynamic favoriteChip = app.component(
    'FavoriteChip',
    params: {'itemId': string, 'label': string},
    body: Column(
      name: 'FavoriteChipContainer',
      spacing: 8,
      children: [
        Text(Param('itemId'), name: 'FavoriteChipItemIdText', visible: false),
        Button(
          Param('label'),
          name: 'FavoriteChipButton',
          onTap: [Snackbar('Favorite chip tapped')],
        ),
      ],
    ),
  );
  favoriteChip.actionBlock(
    'rememberFavoriteLocal',
    params: {'itemId': string},
    returns: string,
    actions: [Terminate(const ActionBlockParam('itemId'))],
    description: 'Component-local action block for the reusable favorite chip.',
  );

  final formatFavorites = app.customFunction(
    'formatFavoritesCount',
    args: {'count': int_},
    returns: string,
    code: "return '\${count} favorites saved';",
    description: 'Formats the visible favorites summary.',
  );

  final addToFavorites = app.actionBlock(
    'addToFavorites',
    params: {'itemId': string},
    returns: string,
    actions: [
      UpdateAppState.addToList('favoriteIds', const ActionBlockParam('itemId')),
      UpdateAppState.increment('favoriteCount', 1),
      Snackbar(
        CustomFunction(
          formatFavorites,
          args: {'count': const AppState('favoriteCount')},
        ),
      ),
      Terminate(const ActionBlockParam('itemId')),
    ],
    description: 'Shared app-level add-to-favorites action block.',
  );

  final favoritesPage = app.page(
    'FavoritesPage',
    route: '/favorites',
    state: {'lastFavoritedId': string},
    body: Scaffold(
      appBar: AppBar(title: 'Favorites'),
      body: Column(
        spacing: 16,
        children: [
          Text(
            CustomFunction(
              formatFavorites,
              args: {'count': const AppState('favoriteCount')},
            ),
            name: 'FavoritesSummaryText',
          ),
          Button(
            'Favorite Beta',
            name: 'FavoriteBetaButton',
            onTap: [
              ExecuteActionBlock(
                addToFavorites,
                params: {'itemId': 'beta'},
                outputAs: 'favoritedId',
                shouldSetState: true,
              ),
              SetState('lastFavoritedId', const ActionOutput('favoritedId')),
            ],
          ),
          Text(const State('lastFavoritedId'), name: 'LastFavoritedText'),
        ],
      ),
    ),
  );

  app.page(
    'CatalogPage',
    route: '/',
    isInitial: true,
    state: {'lastFavoritedId': string},
    body: Scaffold(
      appBar: AppBar(title: 'Catalog'),
      body: Column(
        spacing: 16,
        children: [
          TabBar(
            name: 'CatalogTabs',
            tabs: [
              TabItem('All', Text('All catalog items')),
              TabItem('Saved', Text('Saved catalog items')),
            ],
          ),
          Text(
            CustomFunction(
              formatFavorites,
              args: {'count': const AppState('favoriteCount')},
            ),
            name: 'CatalogSummaryText',
          ),
          Text(
            WidgetState('CatalogTabs', WidgetStateProperty.currentIndex),
            name: 'SelectedTabIndexText',
          ),
          Container(
            name: 'SavedOnlyBanner',
            visible: Equals(
              const WidgetState(
                'CatalogTabs',
                WidgetStateProperty.currentIndex,
              ),
              1,
            ),
            child: Text('Saved tab selected'),
          ),
          Button(
            'Favorite Alpha',
            name: 'FavoriteAlphaButton',
            onTap: [
              ExecuteActionBlock(
                addToFavorites,
                params: {'itemId': 'alpha'},
                outputAs: 'favoritedId',
                shouldSetState: true,
              ),
              SetState('lastFavoritedId', const ActionOutput('favoritedId')),
              Navigate(favoritesPage),
            ],
          ),
          favoriteChip(itemId: 'gamma', label: 'Favorite Gamma'),
          Text(
            const State('lastFavoritedId'),
            name: 'CatalogLastFavoritedText',
          ),
        ],
      ),
    ),
  );

  return app;
}
