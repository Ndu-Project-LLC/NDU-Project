/// TaskBoard reference implementation in the FlutterFlow AI DSL.
library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  await flutterFlowAI(
    buildTaskBoard,
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
Run the TaskBoard DSL and push the compiled project to FlutterFlow.

Usage:
  dart run specs/dsl/taskboard_dsl.dart [options]

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

void buildTaskBoard(App app) {
  final taskStatus = app.enum_('TaskStatus', [
    'todo',
    'in_progress',
    'done',
    'blocked',
  ]);

  final taskItem = app.struct('TaskItem', {
    'title': string,
    'description': string,
    'status': enum_(taskStatus),
    'assignee': string,
    'dueDate': string,
    'priority': int_,
    'updatedAt': dateTime,
    'accentColor': color,
    'metadata': json,
  });

  app.state('tasks', listOf(taskItem), persisted: true);
  app.state('statusFilter', string.withDefault('all'));
  app.state('lastSyncAt', dateTime);
  app.constant('appName', 'TaskBoard');
  app.constant('taskTemplateMetadata', {
    'createdBy': 'dsl',
    'source': 'taskboard',
  });

  final listTasks = Endpoint.get(
    'ListTasks',
    '/tasks?status=[status]&q=[q]',
    variables: {'status': string, 'q': string},
    response: listOf(taskItem),
  );
  final createTask = Endpoint.post(
    'CreateTask',
    '/tasks',
    variables: {
      'title': string,
      'description': string,
      'assignee': string,
      'priority': int_,
      'status': string,
    },
    body: {
      'title': '<title>',
      'description': '<description>',
      'assignee': '<assignee>',
      'priority': '<priority>',
      'status': '<status>',
    },
    response: taskItem,
  );
  final updateTask = Endpoint.put(
    'UpdateTask',
    '/tasks/[taskId]',
    variables: {
      'taskId': string,
      'status': string,
      'assignee': string,
      'priority': int_,
    },
    body: {
      'status': '<status>',
      'assignee': '<assignee>',
      'priority': '<priority>',
    },
    response: taskItem,
  );

  app.apiGroup(
    'TaskApi',
    baseUrl: 'https://api.taskboard.io/v1',
    headers: {'Content-Type': 'application/json'},
    endpoints: [listTasks, createTask, updateTask],
  );

  final dynamic taskCard = app.component(
    'TaskCard',
    params: {
      'title': string,
      'status': string,
      'assignee': string,
      'priority': int_,
    },
    body: Card(
      elevation: 3,
      borderRadius: 16,
      color: Colors.secondaryBackground,
      child: Container(
        padding: 16,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Row(
              crossAxis: CrossAxis.start,
              children: [
                Flexible(
                  Column(
                    crossAxis: CrossAxis.start,
                    spacing: 8,
                    children: [
                      Text(Param('title'), style: Styles.titleMedium),
                      Text(
                        Param('assignee'),
                        style: Styles.bodySmall,
                        color: Colors.secondaryText,
                      ),
                      Text(
                        Param('status'),
                        style: Styles.labelSmall,
                        color: Colors.primary,
                      ),
                    ],
                  ),
                  flex: 1,
                ),
                Spacer(flex: 1, name: 'TaskCard Spacer'),
              ],
            ),
            Container(
              color: Colors.primaryBackground,
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              borderRadius: 999,
              child: Text(Param('priority'), style: Styles.labelMedium),
            ),
          ],
        ),
      ),
    ),
  );

  final dynamic taskBoardHelpSheet = app.component(
    'TaskBoardHelpSheet',
    body: Container(
      padding: 20,
      color: Colors.primaryBackground,
      child: Column(
        crossAxis: CrossAxis.start,
        spacing: 12,
        children: [
          Text('TaskBoard Help', style: Styles.headlineSmall),
          Text(
            'Open the docs or copy the support address for help with board workflows.',
            style: Styles.bodyMedium,
            color: Colors.secondaryText,
          ),
          Button(
            'Open Docs',
            icon: 'open_in_new',
            width: double.infinity,
            onTap: LaunchUrl('https://docs.taskboard.io'),
          ),
          Button(
            'Copy Support Email',
            icon: 'content_copy',
            variant: ButtonVariant.outlined,
            width: double.infinity,
            onTap: CopyToClipboard('support@taskboard.io'),
          ),
        ],
      ),
    ),
  );

  List<DslAction> loadTasks({bool showRefreshedMessage = false}) {
    return [
      ApiCall(
        listTasks,
        params: {'status': AppState('statusFilter'), 'q': State('searchQuery')},
        onSuccess:
            (res) => [
              UpdateAppState.set('tasks', res),
              SetState('isLoading', false),
              if (showRefreshedMessage) Snackbar('Board refreshed'),
            ],
        onFailure: [
          SetState('isLoading', false),
          Snackbar('Failed to load tasks'),
        ],
      ),
    ];
  }

  List<DslAction> applyStatusFilter(Object? status) {
    return [
      UpdateAppState.set('statusFilter', status),
      SetState('isLoading', true),
      ...loadTasks(),
    ];
  }

  app.page(
    'TaskBoardPage',
    route: '/board',
    isInitial: true,
    state: {
      'isLoading': bool_.withDefault(true),
      'searchQuery': string.withDefault(''),
      'showGrid': bool_.withDefault(false),
    },
    onLoad: loadTasks(),
    body: Scaffold(
      appBar: AppBar(title: 'TaskBoard'),
      body: Container(
        color: Colors.primaryBackground,
        padding: 20,
        child: Column(
          crossAxis: CrossAxis.start,
          spacing: 12,
          children: [
            Text('Project Overview', style: Styles.headlineSmall),
            Image(
              'https://images.unsplash.com/photo-1516321318423-f06f85e504b3',
              height: 120,
              fit: ImageFit.cover,
              borderRadius: 20,
              name: 'Board Hero',
            ),
            TextField(
              label: 'Search tasks',
              hint: 'Find by title or assignee',
              prefixIcon: 'search',
              onChanged: SetState('searchQuery', TextValue()),
              onSubmitted: [SetState('isLoading', true), ...loadTasks()],
            ),
            Row(
              crossAxis: CrossAxis.center,
              spacing: 12,
              children: [
                Flexible(
                  Dropdown(
                    options: const [
                      'all',
                      'todo',
                      'in_progress',
                      'done',
                      'blocked',
                    ],
                    label: 'Status',
                    hint: 'Filter by status',
                    value: AppState('statusFilter'),
                    onChanged: applyStatusFilter(const WidgetValue()),
                  ),
                  flex: 1,
                ),
                Toggle(
                  label: 'Grid view',
                  value: State('showGrid'),
                  onChanged: SetState('showGrid', const WidgetValue()),
                ),
                Checkbox(
                  label: 'Blocked only',
                  value: Equals(AppState('statusFilter'), 'blocked'),
                  onChanged: [
                    If(
                      const WidgetValue(),
                      then: applyStatusFilter('blocked'),
                      orElse: applyStatusFilter('all'),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              spacing: 12,
              children: [
                Flexible(
                  Button(
                    'Refresh',
                    variant: ButtonVariant.outlined,
                    icon: 'refresh',
                    width: double.infinity,
                    onTap: If(
                      State('isLoading'),
                      then: Snackbar('Tasks are already loading'),
                      orElse: [
                        SetState('isLoading', true),
                        ...loadTasks(showRefreshedMessage: true),
                      ],
                    ),
                  ),
                  flex: 1,
                ),
                Flexible(
                  Button(
                    'Add Task',
                    icon: 'add',
                    width: double.infinity,
                    onTap: Navigate('AddTaskPage'),
                  ),
                  flex: 1,
                ),
              ],
            ),
            Row(
              spacing: 12,
              children: [
                Flexible(
                  Button(
                    'Help',
                    variant: ButtonVariant.outlined,
                    icon: 'help_outline',
                    width: double.infinity,
                    onTap: ShowBottomSheet(taskBoardHelpSheet),
                  ),
                  flex: 1,
                ),
                Flexible(
                  Button(
                    'Board Tips',
                    variant: ButtonVariant.outlined,
                    icon: 'lightbulb_outline',
                    width: double.infinity,
                    onTap: ShowDialog.message(
                      title: 'Board Tips',
                      message:
                          'Use filters to focus, then switch between list and grid to scan task status quickly.',
                    ),
                  ),
                  flex: 1,
                ),
              ],
            ),
            Button(
              'Copy Visible Titles',
              variant: ButtonVariant.text,
              icon: 'content_copy',
              width: double.infinity,
              onTap: [
                ForEach(
                  AppState('tasks'),
                  body: (task) => [CopyToClipboard(task['title'])],
                ),
                Snackbar('Copied visible task titles'),
              ],
            ),
            ProgressBar.circular(
              size: 40,
              thickness: 4,
              visible: State('isLoading'),
            ),
            Expanded(
              ListView(
                source: AppState('tasks'),
                spacing: 12,
                visible: Not(State('showGrid')),
                itemBuilder:
                    (item) => taskCard(
                      title: item['title'],
                      status: item['status'],
                      assignee: item['assignee'],
                      priority: item['priority'],
                    ),
              ),
            ),
            Expanded(
              GridView(
                source: AppState('tasks'),
                columns: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
                visible: State('showGrid'),
                itemBuilder:
                    (item) => taskCard(
                      title: item['title'],
                      status: item['status'],
                      assignee: item['assignee'],
                      priority: item['priority'],
                    ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  app.page(
    'AddTaskPage',
    route: '/add-task',
    state: {
      'title': string,
      'description': string,
      'assignee': string,
      'priority': int_.withDefault(3),
      'status': string.withDefault('todo'),
    },
    body: Scaffold(
      appBar: AppBar(title: 'Add Task'),
      body: Container(
        color: Colors.primaryBackground,
        padding: 24,
        child: Column(
          crossAxis: CrossAxis.start,
          spacing: 16,
          children: [
            Text('Create a new task', style: Styles.headlineMedium),
            TextField(
              label: 'Title',
              hint: 'Ship Phase 1 beta',
              onChanged: SetState('title', TextValue()),
            ),
            TextField(
              label: 'Description',
              hint: 'Describe the work to be completed',
              onChanged: SetState('description', TextValue()),
            ),
            TextField(
              label: 'Assignee',
              hint: 'Who owns this task?',
              onChanged: SetState('assignee', TextValue()),
            ),
            TextField(
              label: 'Priority',
              hint: '1-5',
              keyboard: Keyboard.number,
              onChanged: SetState('priority', TextValue().asInt()),
            ),
            Dropdown(
              options: const ['todo', 'in_progress', 'done', 'blocked'],
              label: 'Status',
              value: State('status'),
              onChanged: SetState('status', const WidgetValue()),
            ),
            Button(
              'Create Task',
              icon: 'check',
              width: double.infinity,
              height: 48,
              onTap: [
                ApiCall(
                  createTask,
                  params: {
                    'title': State('title'),
                    'description': State('description'),
                    'assignee': State('assignee'),
                    'priority': State('priority'),
                    'status': State('status'),
                  },
                  onSuccess:
                      (res) => [
                        UpdateAppState.addToList('tasks', res),
                        Snackbar('Task created'),
                        const Wait(200),
                        const NavigateBack(),
                      ],
                  onFailure: [Snackbar('Failed to create task')],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
