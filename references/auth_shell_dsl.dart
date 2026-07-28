library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  await flutterFlowAI(
    buildAuthShell,
    apiKey: options.apiKey,
    baseUrl: options.baseUrl,
    projectName: options.projectName,
    projectId: options.projectId,
    findOrCreate: options.findOrCreate,
    dryRun: options.dryRun,
    commitMessage: options.commitMessage,
    validationFilter: _keepValidationError,
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
Run the AuthShell DSL and push the compiled project to FlutterFlow.

Usage:
  dart run specs/dsl/auth_shell_dsl.dart [options]

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

bool _keepValidationError(error) =>
    !error.message.contains('config file is not uploaded') &&
    !error.message.contains('config files are not uploaded');

void buildAuthShell(App app) {
  final homePage = app.page(
    'AuthHomePage',
    route: '/home',
    body: Scaffold(
      appBar: AppBar(title: 'Home'),
      body: Column(
        crossAxis: CrossAxis.start,
        spacing: 16,
        children: [
          Text('Signed in as', style: Styles.bodyMedium),
          Text(
            const AuthUser(AuthUserField.email),
            name: 'HomeEmailText',
            style: Styles.titleMedium,
          ),
          Button(
            'Open Profile',
            name: 'OpenProfileButton',
            onTap: Navigate('ProfilePage'),
          ),
          Button('Logout', name: 'LogoutButton', onTap: const [Logout()]),
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
        crossAxis: CrossAxis.start,
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
              Snackbar('Reset link sent'),
              const NavigateBack(),
            ],
          ),
        ],
      ),
    ),
  );

  app.page(
    'SignInPage',
    route: '/sign-in',
    isInitial: true,
    state: {'email': string, 'password': string},
    body: Scaffold(
      appBar: AppBar(title: 'Sign In'),
      body: Column(
        crossAxis: CrossAxis.start,
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
            'Continue Anonymously',
            name: 'AnonymousSignInButton',
            onTap: const [LoginAnonymously()],
          ),
          Button(
            'Forgot Password?',
            name: 'ForgotPasswordButton',
            onTap: Navigate(resetPasswordPage),
          ),
        ],
      ),
    ),
  );

  app.page(
    'ProfilePage',
    route: '/profile',
    body: Scaffold(
      appBar: AppBar(title: 'Profile'),
      body: Column(
        crossAxis: CrossAxis.start,
        spacing: 16,
        children: [
          Text(
            const AuthUser(AuthUserField.displayName),
            name: 'ProfileDisplayNameText',
          ),
          Text(const AuthUser(AuthUserField.email), name: 'ProfileEmailText'),
          Text(
            const AuthUser(AuthUserField.phoneNumber),
            name: 'ProfilePhoneText',
          ),
          Button(
            'Delete Account',
            name: 'DeleteAccountButton',
            onTap: const [DeleteAccount()],
          ),
        ],
      ),
    ),
  );

  app.firebaseAuth(
    providers: const [
      FirebaseAuthProvider.email,
      FirebaseAuthProvider.google,
      FirebaseAuthProvider.apple,
      FirebaseAuthProvider.anonymous,
    ],
    homePage: homePage,
    signInPage: 'SignInPage',
  );
}
