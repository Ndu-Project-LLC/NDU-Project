library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  await flutterFlowAI(
    buildAppEventShowcase,
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
Run the AppEventShowcase DSL and push the compiled project to FlutterFlow.

Usage:
  dart run specs/dsl/app_event_showcase_dsl.dart [options]

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

App buildAppEventShowcase(App app) {
  final selectionData = app.struct('SelectionEventData', {
    'itemId': string,
    'source': string,
  });

  app.state('lastFavoriteId', string, persisted: true);
  app.state('favoriteSource', string, persisted: true);
  app.state('favoriteCount', int_, persisted: true);

  final formatFavoriteSummary = app.customFunction(
    'formatFavoriteSummary',
    args: {'itemId': string, 'source': string},
    returns: string,
    code: "return 'Favorite: \${itemId ?? ''} via \${source ?? ''}';",
    description: 'Formats the selected favorite event payload.',
  );

  final globalFavoriteHandler = app.actionBlock(
    'rememberFavoriteSelection',
    params: {'data': selectionData},
    actions: [
      UpdateAppState.set(
        'lastFavoriteId',
        const ActionBlockParam('data')['itemId'],
      ),
      UpdateAppState.set(
        'favoriteSource',
        const ActionBlockParam('data')['source'],
      ),
      UpdateAppState.increment('favoriteCount', 1),
      Snackbar('Favorite updated'),
    ],
    description: 'Global event handler for favorite selection updates.',
  );

  final favoriteSelected = app.event(
    'FavoriteSelected',
    scope: AppEventScope.global,
    dataStruct: selectionData,
    handler: globalFavoriteHandler,
    description: 'Published when a catalog item is favorited.',
  );

  final previewRequested = app.event(
    'PreviewRequested',
    scope: AppEventScope.local,
    dataStruct: selectionData,
    description: 'Published when a page-local item preview is requested.',
  );

  final favoritesPage = app.page(
    'FavoritesPage',
    route: '/favorites',
    body: Scaffold(
      appBar: AppBar(title: 'Favorites'),
      body: Column(
        spacing: 16,
        children: [
          Text(
            CustomFunction(
              formatFavoriteSummary,
              args: {
                'itemId': const AppState('lastFavoriteId'),
                'source': const AppState('favoriteSource'),
              },
            ),
            name: 'FavoriteSummaryText',
          ),
          Text(AppState('favoriteCount'), name: 'FavoriteCountText'),
          Button(
            'Back to catalog',
            name: 'BackToCatalogButton',
            onTap: [NavigateBack()],
          ),
        ],
      ),
    ),
  );

  final catalogPage = app.page(
    'CatalogPage',
    route: '/',
    isInitial: true,
    state: {
      'previewItemId': string,
      'previewSource': string,
      'previewHandlerStatus': string.withDefault('inactive'),
    },
    body: Scaffold(
      appBar: AppBar(title: 'Catalog'),
      body: Column(
        spacing: 16,
        children: [
          Text('Catalog events', name: 'CatalogHeadingText'),
          Button(
            'Register preview handler',
            name: 'RegisterPreviewHandlerButton',
            onTap: [
              AddLocalEventHandler(
                previewRequested,
                actionBlock: ActionBlock.named(
                  'handlePreviewRequest',
                  scope: ActionBlockLookupScope.local,
                ),
              ),
              SetState('previewHandlerStatus', 'active'),
            ],
          ),
          Button(
            'Cancel preview handler',
            name: 'CancelPreviewHandlerButton',
            onTap: [
              CancelLocalEventHandler(previewRequested),
              SetState('previewHandlerStatus', 'inactive'),
            ],
          ),
          Button(
            'Preview Alpha',
            name: 'PreviewAlphaButton',
            onTap: [
              TriggerEvent(
                previewRequested,
                data: Struct(selectionData, {
                  'itemId': 'alpha',
                  'source': 'catalog_preview',
                }),
                waitForCompletion: true,
              ),
            ],
          ),
          Button(
            'Favorite Alpha',
            name: 'FavoriteAlphaButton',
            onTap: [
              TriggerEvent(
                favoriteSelected,
                data: Struct(selectionData, {
                  'itemId': 'alpha',
                  'source': 'catalog',
                }),
                waitForCompletion: true,
              ),
              Navigate(favoritesPage),
            ],
          ),
          Text(const State('previewItemId'), name: 'PreviewItemText'),
          Text(const State('previewSource'), name: 'PreviewSourceText'),
          Text(const State('previewHandlerStatus'), name: 'PreviewStatusText'),
        ],
      ),
    ),
  );

  catalogPage.actionBlock(
    'handlePreviewRequest',
    params: {'data': selectionData},
    actions: [
      SetState('previewItemId', const ActionBlockParam('data')['itemId']),
      SetState('previewSource', const ActionBlockParam('data')['source']),
      Snackbar('Preview updated'),
    ],
    description: 'Page-local event handler for local preview updates.',
  );

  return app;
}
