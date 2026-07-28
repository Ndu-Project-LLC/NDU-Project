library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  await flutterFlowAI(
    buildSupabaseCrudAuthShell,
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
Run the SupabaseCrudAuthShell DSL and push the compiled project to FlutterFlow.

Usage:
  dart run specs/dsl/supabase_crud_auth_shell_dsl.dart [options]

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

App buildSupabaseCrudAuthShell(App app) {
  app.supabase(
    url: 'https://example.supabase.co',
    anonKey: 'supabase-anon-key',
    connectedProjectId: 'supabase-connected-project',
    connectedProjectName: 'Supabase Demo',
    connectedRegion: 'us-east-1',
    googleAuth: const SupabaseGoogleAuthConfig(
      iosClientId: 'ios-google-client-id',
      webClientId: 'web-google-client-id',
    ),
    appleAuth: const SupabaseAppleAuthConfig(),
  );

  final tasks = app.table(
    'tasks',
    fields: {
      'id': const PostgresTableField(
        string,
        postgresType: 'uuid',
        isPrimaryKey: true,
        hasDefault: true,
      ),
      'title': const PostgresTableField(
        string,
        postgresType: 'text',
        isRequired: true,
      ),
      'details': const PostgresTableField(string, postgresType: 'text'),
      'is_done': const PostgresTableField(
        bool_,
        postgresType: 'bool',
        hasDefault: true,
      ),
      'owner_email': const PostgresTableField(
        string,
        postgresType: 'text',
        isRequired: true,
      ),
    },
    description: 'Simple task rows stored in Supabase.',
  );

  final tasksPage = app.page(
    'TasksPage',
    route: '/tasks',
    state: {'statusMessage': string.withDefault('Loading tasks...')},
    onLoad: [
      PostgresQuery(
        tasks,
        outputAs: 'loadedTasks',
        query: PostgresQuerySpec(orderBys: const [PostgresOrderBy('title')]),
      ),
      SetState('statusMessage', 'Tasks synced'),
    ],
    body: Scaffold(
      appBar: AppBar(title: 'Tasks'),
      body: Column(
        crossAxis: CrossAxis.start,
        spacing: 16,
        children: [
          Text(
            const AuthUser(AuthUserField.email),
            name: 'CurrentUserEmailText',
            style: Styles.titleMedium,
          ),
          Text(State('statusMessage'), name: 'StatusMessageText'),
          Button(
            'Create Task',
            name: 'OpenCreateTaskButton',
            onTap: Navigate('CreateTaskPage'),
          ),
          Button(
            'Edit Task',
            name: 'OpenEditTaskButton',
            onTap: Navigate('EditTaskPage'),
          ),
          Button(
            'Logout',
            name: 'LogoutButton',
            variant: ButtonVariant.text,
            onTap: const [Logout()],
          ),
        ],
      ),
    ),
  );

  final resetPasswordPage = app.page(
    'ResetPasswordPage',
    route: '/reset-password',
    state: {'email': string},
    body: Scaffold(
      appBar: AppBar(title: 'Reset Password'),
      body: Column(
        spacing: 16,
        children: [
          TextField(
            name: 'ResetEmailField',
            label: 'Email',
            keyboard: Keyboard.email,
            onChanged: SetState('email', const TextValue()),
          ),
          Button(
            'Send Reset Link',
            name: 'SendResetLinkButton',
            onTap: [
              ResetPassword(State('email')),
              Snackbar('Reset email sent'),
              const NavigateBack(),
            ],
          ),
        ],
      ),
    ),
  );

  final updatePasswordPage = app.page(
    'UpdatePasswordPage',
    route: '/update-password',
    state: {'password': string, 'confirmPassword': string},
    body: Scaffold(
      appBar: AppBar(title: 'Update Password'),
      body: Column(
        spacing: 16,
        children: [
          TextField(
            name: 'UpdatePasswordField',
            label: 'New Password',
            onChanged: SetState('password', const TextValue()),
          ),
          TextField(
            name: 'ConfirmUpdatePasswordField',
            label: 'Confirm Password',
            onChanged: SetState('confirmPassword', const TextValue()),
          ),
          Button(
            'Update Password',
            name: 'UpdatePasswordButton',
            onTap: [
              UpdatePassword(
                State('password'),
                confirmPassword: State('confirmPassword'),
              ),
              Snackbar('Password updated'),
            ],
          ),
        ],
      ),
    ),
  );

  final signInPage = app.page(
    'SignInPage',
    route: '/sign-in',
    isInitial: true,
    state: {'email': string, 'password': string},
    body: Scaffold(
      appBar: AppBar(title: 'Sign In'),
      body: Column(
        spacing: 16,
        children: [
          TextField(
            name: 'EmailField',
            label: 'Email',
            keyboard: Keyboard.email,
            onChanged: SetState('email', const TextValue()),
          ),
          TextField(
            name: 'PasswordField',
            label: 'Password',
            onChanged: SetState('password', const TextValue()),
          ),
          Button(
            'Sign In',
            name: 'SignInButton',
            onTap: [LoginEmailPassword(State('email'), State('password'))],
          ),
          Button(
            'Create Account',
            name: 'CreateAccountButton',
            onTap: [
              SignupEmailPassword(
                State('email'),
                State('password'),
                confirmPassword: State('password'),
              ),
            ],
          ),
          Button(
            'Continue with Google',
            name: 'GoogleSignInButton',
            onTap: const [LoginWithGoogle()],
          ),
          Button(
            'Continue with Apple',
            name: 'AppleSignInButton',
            onTap: const [LoginWithApple()],
          ),
          Button(
            'Forgot Password?',
            name: 'ForgotPasswordButton',
            onTap: Navigate(resetPasswordPage),
          ),
          Button(
            'Update Password',
            name: 'OpenUpdatePasswordButton',
            variant: ButtonVariant.text,
            onTap: Navigate(updatePasswordPage),
          ),
        ],
      ),
    ),
  );

  app.page(
    'CreateTaskPage',
    route: '/create-task',
    state: {
      'title': string,
      'details': string,
      'isDone': bool_.withDefault(false),
    },
    body: Scaffold(
      appBar: AppBar(title: 'Create Task'),
      body: Column(
        spacing: 16,
        children: [
          TextField(
            name: 'CreateTitleField',
            label: 'Title',
            onChanged: SetState('title', const TextValue()),
          ),
          TextField(
            name: 'CreateDetailsField',
            label: 'Details',
            onChanged: SetState('details', const TextValue()),
          ),
          Checkbox(
            name: 'CreateDoneCheckbox',
            label: 'Completed',
            value: State('isDone'),
            onChanged: SetState('isDone', const WidgetValue()),
          ),
          Button(
            'Save Task',
            name: 'SaveTaskButton',
            onTap: [
              PostgresCreate(
                tasks,
                fields: {
                  'title': State('title'),
                  'details': State('details'),
                  'is_done': State('isDone'),
                  'owner_email': const AuthUser(AuthUserField.email),
                },
                outputAs: 'createdTask',
              ),
              Snackbar('Task created'),
              Navigate(tasksPage),
            ],
          ),
        ],
      ),
    ),
  );

  app.page(
    'EditTaskPage',
    route: '/edit-task',
    state: {
      'taskId': string,
      'title': string,
      'details': string,
      'isDone': bool_,
    },
    body: Scaffold(
      appBar: AppBar(title: 'Edit Task'),
      body: Column(
        spacing: 16,
        children: [
          TextField(
            name: 'EditTaskIdField',
            label: 'Task ID',
            onChanged: SetState('taskId', const TextValue()),
          ),
          TextField(
            name: 'EditTitleField',
            label: 'Title',
            onChanged: SetState('title', const TextValue()),
          ),
          TextField(
            name: 'EditDetailsField',
            label: 'Details',
            onChanged: SetState('details', const TextValue()),
          ),
          Checkbox(
            name: 'EditDoneCheckbox',
            label: 'Completed',
            value: State('isDone'),
            onChanged: SetState('isDone', const WidgetValue()),
          ),
          Button(
            'Update Task',
            name: 'UpdateTaskButton',
            onTap: [
              PostgresUpdate(
                tasks,
                outputAs: 'updatedTasks',
                fields: {
                  'title': State('title'),
                  'details': State('details'),
                  'is_done': State('isDone'),
                },
                query: PostgresQuerySpec(
                  filters: [
                    PostgresFilter(
                      'id',
                      relation: PostgresFilterRelation.equalTo,
                      value: State('taskId'),
                    ),
                  ],
                  isSingleRow: true,
                ),
              ),
              Snackbar('Task updated'),
              Navigate(tasksPage),
            ],
          ),
          Button(
            'Delete Task',
            name: 'DeleteTaskButton',
            variant: ButtonVariant.text,
            onTap: [
              PostgresDelete(
                tasks,
                outputAs: 'deletedTasks',
                query: PostgresQuerySpec(
                  filters: [
                    PostgresFilter(
                      'id',
                      relation: PostgresFilterRelation.equalTo,
                      value: State('taskId'),
                    ),
                  ],
                  isSingleRow: true,
                ),
              ),
              Snackbar('Task deleted'),
              Navigate(tasksPage),
            ],
          ),
        ],
      ),
    ),
  );

  app.supabaseAuth(
    providers: const [
      SupabaseAuthProvider.email,
      SupabaseAuthProvider.google,
      SupabaseAuthProvider.apple,
    ],
    homePage: tasksPage,
    signInPage: signInPage,
  );

  return app;
}
