library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  await flutterFlowAI(
    buildWorkflowForms,
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
Run the WorkflowForms DSL and push the compiled project to FlutterFlow.

Usage:
  dart run specs/dsl/workflow_forms_dsl.dart [options]

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

App buildWorkflowForms(App app) {
  final submissionResult = app.struct('SubmissionResult', {
    'status': string,
    'nextLabel': string,
    'showCta': bool_,
  });

  final workflowApi = app.apiGroup(
    'WorkflowApi',
    baseUrl: 'https://workflow.example.com',
    endpoints: [
      Endpoint.post(
        'SubmitRequest',
        '/submit',
        body: {'email': '<email>', 'name': '<name>'},
        variables: {'email': string, 'name': string},
        response: submissionResult,
      ),
    ],
  );
  final submitRequest = workflowApi.endpoints.single;

  app.constant('supportEmail', 'support@workflow.dev');

  final successPage = app.page(
    'WorkflowDonePage',
    route: '/done',
    body: Scaffold(
      appBar: AppBar(title: 'Workflow Done'),
      body: Column(
        spacing: 12,
        children: [
          Text('Workflow complete', style: Styles.titleLarge),
          Text('Support:'),
          Text(Constant('supportEmail')),
        ],
      ),
    ),
  );

  app.page(
    'WorkflowRequestPage',
    route: '/',
    isInitial: true,
    state: {
      'email': string,
      'name': string,
      'submitLabel': string.withDefault('Submit Request'),
      'showSubmitButton': bool_.withDefault(true),
      'attempts': int_.withDefault(0),
    },
    body: Scaffold(
      appBar: AppBar(title: 'Workflow Forms'),
      body: Column(
        spacing: 16,
        children: [
          Form(
            name: 'RequestForm',
            child: Column(
              spacing: 12,
              children: [
                TextField(
                  name: 'EmailField',
                  label: 'Email',
                  keyboard: Keyboard.email,
                  onChanged: SetState('email', TextValue()),
                ),
                TextField(
                  name: 'NameField',
                  label: 'Name',
                  onChanged: SetState('name', TextValue()),
                ),
              ],
            ),
          ),
          Button(
            name: 'SubmitButton',
            State('submitLabel'),
            visible: State('showSubmitButton'),
            onTap: [
              ValidateForm('RequestForm'),
              ApiCall(
                submitRequest,
                params: {'email': State('email'), 'name': State('name')},
                outputAs: 'submitResult',
              ),
              SetState(
                'submitLabel',
                ActionOutput('submitResult')['nextLabel'],
              ),
              SetState(
                'showSubmitButton',
                ActionOutput('submitResult')['showCta'],
              ),
              Switch(
                ActionOutput('submitResult')['status'],
                cases: [
                  SwitchCase(
                    'accepted',
                    then: [
                      Parallel([
                        [
                          NonBlocking(Snackbar('Accepted')),
                          CopyToClipboard(Constant('supportEmail')),
                        ],
                        [Navigate.to(successPage)],
                      ]),
                    ],
                  ),
                  SwitchCase(
                    'retry',
                    then: [
                      SetState.increment('attempts', 1),
                      ResetFormField('EmailField'),
                      SetFormField('NameField', Constant('supportEmail')),
                    ],
                  ),
                ],
                orElse: [Terminate('unsupported')],
              ),
            ],
          ),
          Button(
            'Quick Reset',
            variant: ButtonVariant.text,
            onTap: [
              ClearTextField('NameField'),
              SetFormField('EmailField', Constant('supportEmail')),
            ],
          ),
        ],
      ),
    ),
  );

  return app;
}
