library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  await flutterFlowAI(
    buildContentCompanion,
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
    final arg = args[i];
    switch (arg) {
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
        stderr.writeln('Unknown option: $arg');
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
Run the ContentCompanion DSL and push the compiled project to FlutterFlow.

Usage:
  dart run specs/dsl/content_companion_dsl.dart [options]

Options:
  --api-key <key>           FlutterFlow API key. Defaults to FF_API_KEY.
  --base-url <url>          Override the FlutterFlow API base URL.
  --project-name <name>     Create a new project with this name.
  --project-id <id>         Push into an existing project by ID.
  --find-or-create          Find by project name before creating.
  --commit-message <text>   Commit message for the push.
  --dry-run                 Compile and validate without pushing.
  --help, -h                Show this help.
''');
}

App buildContentCompanion(App app) {
  app.page(
    'ReadingPage',
    route: '/reading',
    state: {'authorTag': string, 'publishAt': dateTime},
    body: Scaffold(
      appBar: AppBar(title: 'Reading'),
      body: Column(
        crossAxis: CrossAxis.stretch,
        spacing: 16,
        children: [
          RichText(
            name: 'ArticleHeader',
            spans: [
              RichTextSpan('Insight by '),
              RichTextSpan(
                State('authorTag'),
                bold: true,
                color: Colors.primary,
              ),
            ],
          ),
          Tooltip(
            message: 'Long press to save this article',
            child: ListTile(
              title: 'Save for later',
              subtitle: 'Keep this article in your reading list',
              leadingIcon: 'bookmark',
              trailingIcon: 'info_outline',
              onTap: Snackbar('Saved'),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip('Culture', selected: true),
              Chip('Design'),
              Chip('Systems'),
            ],
          ),
          Button(
            'Pick Publish Date',
            onTap: [
              DatePicker(
                mode: DatePickerMode.dateTime,
                defaultDateTime: State('publishAt'),
                outputAs: 'pickedPublishAt',
              ),
              SetState('publishAt', ActionOutput('pickedPublishAt')),
            ],
          ),
          Text(State('publishAt')),
          Button('Share Story', onTap: Share('https://example.com/story/42')),
        ],
      ),
    ),
    isInitial: true,
  );

  return app;
}
