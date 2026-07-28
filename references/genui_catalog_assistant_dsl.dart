library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  await flutterFlowAI(
    buildGenUiCatalogAssistant,
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
Run the GenUiCatalogAssistant DSL and push the compiled project to FlutterFlow.

Usage:
  dart run specs/dsl/genui_catalog_assistant_dsl.dart [options]

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

App buildGenUiCatalogAssistant(App app) {
  final previewData = app.struct('PreviewEventData', {
    'title': string,
    'priceLabel': string,
    'source': string,
  });

  app.state('lastPreviewTitle', string.withDefault('Nothing selected'));
  app.state('lastPreviewPriceLabel', string.withDefault(''));

  final formatRecommendationHeadline = app.customFunction(
    'formatRecommendationHeadline',
    args: {'title': string, 'priceLabel': string},
    returns: string,
    code: "return 'Spotlight: \${title ?? ''} - \${priceLabel ?? ''}';",
    description: 'Formats a visible GenUI recommendation headline.',
  );

  final suggestProductCallout = app.actionBlock(
    'suggestProductCallout',
    params: {'title': string, 'priceLabel': string},
    returns: string,
    actions: [
      UpdateAppState.set('lastPreviewTitle', const ActionBlockParam('title')),
      UpdateAppState.set(
        'lastPreviewPriceLabel',
        const ActionBlockParam('priceLabel'),
      ),
      Snackbar('Recommendation ready'),
      Terminate(const ActionBlockParam('title')),
    ],
    description: 'Generates a formatted recommendation headline for GenUI.',
  );

  final previewRequested = app.event(
    'PreviewRequested',
    scope: AppEventScope.local,
    dataStruct: previewData,
    description: 'Raised when a catalog product is previewed.',
  );

  final productCallout = app.component(
    'ProductCallout',
    params: {'title': string, 'priceLabel': string},
    body: Card(
      child: Column(
        spacing: 8,
        children: [
          Text(const Param('title'), name: 'ProductCalloutTitle'),
          Text(const Param('priceLabel'), name: 'ProductCalloutPrice'),
        ],
      ),
    ),
  );

  final assistantChat = GenUiChat(
    name: 'CatalogAssistantChat',
    systemPrompt: 'You help users decide which product to preview next.',
    thinkingMessage: 'Reviewing product context...',
  );

  final catalogPage = app.page(
    'CatalogAssistantPage',
    route: '/',
    isInitial: true,
    state: {
      'previewSource': string.withDefault('not_registered'),
      'previewHandlerStatus': string.withDefault('inactive'),
    },
    onLoad: [
      AddLocalEventHandler(
        previewRequested,
        actionBlock: ActionBlock.named(
          'rememberPreview',
          scope: ActionBlockLookupScope.local,
        ),
      ),
      SetState('previewHandlerStatus', 'active'),
    ],
    body: Scaffold(
      appBar: AppBar(title: 'Catalog Assistant'),
      body: Column(
        spacing: 16,
        children: [
          Text(
            CustomFunction(
              formatRecommendationHeadline,
              args: {
                'title': const AppState('lastPreviewTitle'),
                'priceLabel': const AppState('lastPreviewPriceLabel'),
              },
            ),
            name: 'RecommendationHeadlineText',
          ),
          productCallout(title: 'Arc Lamp', priceLabel: '\$120'),
          Button(
            'Preview Arc Lamp',
            name: 'PreviewArcLampButton',
            onTap: [
              TriggerEvent(
                previewRequested,
                data: Struct(previewData, {
                  'title': 'Arc Lamp',
                  'priceLabel': '\$120',
                  'source': 'catalog_card',
                }),
                waitForCompletion: true,
              ),
            ],
          ),
          Button(
            'Preview Oak Desk',
            name: 'PreviewOakDeskButton',
            onTap: [
              TriggerEvent(
                previewRequested,
                data: Struct(previewData, {
                  'title': 'Oak Desk',
                  'priceLabel': '\$340',
                  'source': 'catalog_card',
                }),
                waitForCompletion: true,
              ),
            ],
          ),
          Text(const State('previewSource'), name: 'PreviewSourceText'),
          Text(
            const State('previewHandlerStatus'),
            name: 'PreviewHandlerStatusText',
          ),
          Expanded(assistantChat),
        ],
      ),
    ),
  );

  catalogPage.actionBlock(
    'rememberPreview',
    params: {'data': previewData},
    actions: [
      UpdateAppState.set(
        'lastPreviewTitle',
        const ActionBlockParam('data')['title'],
      ),
      UpdateAppState.set(
        'lastPreviewPriceLabel',
        const ActionBlockParam('data')['priceLabel'],
      ),
      SetState('previewSource', const ActionBlockParam('data')['source']),
      Snackbar('Preview captured for the assistant'),
    ],
    description: 'Keeps visible preview state in sync with the local event.',
  );

  app.genUiTool(
    assistantChat,
    actionBlock: suggestProductCallout,
    loadingMessage: 'Drafting a recommendation...',
    description: 'Turns product inputs into a formatted recommendation.',
  );
  app.genUiEventListener(
    assistantChat,
    event: previewRequested,
    messageTemplate:
        'Preview requested for {title} ({priceLabel}) via {source}.',
    autoRespond: true,
  );
  app.genUiCatalogComponent(assistantChat, component: productCallout);
  app.genUiHeader(assistantChat, title: 'Catalog Copilot');
  app.genUiAvatar(
    assistantChat,
    url: 'https://images.example.com/catalog-copilot.png',
  );
  app.genUiMessageSpacing(assistantChat, value: 18);
  app.genUiScrollBehavior(assistantChat, enabled: false);
  app.genUiSystemPrompt(
    assistantChat,
    prompt:
        'You are the in-app catalog copilot. Prefer ProductCallout when you recommend products.',
  );

  return app;
}
