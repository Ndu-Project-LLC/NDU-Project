/// Styled profile & settings reference — patterns for theming, forms, and layout.
///
/// Demonstrates:
/// - app.themeColor(), app.darkMode(), app.primaryFont(), app.breakpoints()
/// - TextField: obscureText, suffixIcon, maxLines
/// - Button: color, textColor, disabled, padding, borderRadius
/// - Container: width, height, margin, borderColor, borderWidth, alignment
/// - Text: maxLines, textAlign, overflow
/// - Column: padding, scrollable
/// - EdgeInsets.only() and EdgeInsets.symmetric()
/// - Conditional visibility with visible:
/// - Form + ValidateForm + ResetFormField
library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  await flutterFlowAI(
    buildStyledProfileApp,
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
  String? apiKey, baseUrl, projectName, projectId, commitMessage;
  var findOrCreate = false, dryRun = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--api-key':
        apiKey = args[++i];
      case '--base-url':
        baseUrl = args[++i];
      case '--project-name':
        projectName = args[++i];
      case '--project-id':
        projectId = args[++i];
      case '--commit-message':
        commitMessage = args[++i];
      case '--find-or-create':
        findOrCreate = true;
      case '--dry-run':
        dryRun = true;
      default:
        stderr.writeln('Unknown option: ${args[i]}');
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

void buildStyledProfileApp(App app) {
  // ---------------------------------------------------------------------------
  // Theme configuration — declarative, no app.raw() needed
  // ---------------------------------------------------------------------------

  // KEY PATTERN: themeColor sets a named slot in the FF color scheme.
  app.themeColor('primary', 0xFF6750A4);
  app.themeColor('secondary', 0xFF625B71);
  app.themeColor('tertiary', 0xFF7D5260);
  app.themeColor('primaryBackground', 0xFFF6F2FF);
  app.themeColor('secondaryBackground', 0xFFFFFFFF);
  app.themeColor('primaryText', 0xFF1C1B1F);
  app.themeColor('secondaryText', 0xFF49454F);
  app.themeColor('error', 0xFFB3261E);
  app.themeColor('success', 0xFF2E7D32);

  // KEY PATTERN: darkMode enables the dark theme toggle.
  app.darkMode(enabled: true);

  // KEY PATTERN: primaryFont sets the default font family.
  app.primaryFont('Inter');

  // KEY PATTERN: breakpoints set responsive layout thresholds.
  app.breakpoints(small: 479, medium: 991, large: 1200);

  // -- Data --
  app.state('displayName', string, persisted: true);
  app.state('bio', string, persisted: true);
  app.state('isEditing', bool_);

  app.constant('appName', 'My Profile');

  // ---------------------------------------------------------------------------
  // Profile page
  // ---------------------------------------------------------------------------
  app.page(
    'ProfilePage',
    route: '/',
    isInitial: true,
    state: {
      'editName': string,
      'editBio': string,
      'currentPassword': string,
      'newPassword': string,
      'confirmPassword': string,
    },
    body: Scaffold(
      appBar: AppBar(title: 'Profile'),
      // KEY PATTERN: scrollable Column avoids overflow on small screens.
      body: Column(
        scrollable: true,
        // KEY PATTERN: padding on Column — no wrapping Container needed.
        padding: 20,
        spacing: 16,
        children: [
          // -- Avatar area with centered alignment --
          Container(
            // KEY PATTERN: explicit width/height for sizing.
            width: double.infinity,
            height: 160,
            // KEY PATTERN: alignment positions the child within the container.
            alignment: Alignment.center,
            // KEY PATTERN: margin adds outer spacing (vs padding = inner).
            margin: EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxis: MainAxis.center,
              spacing: 12,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  borderRadius: 40,
                  color: Colors.primary,
                  alignment: Alignment.center,
                  child: Text(
                    'AS',
                    style: Styles.headlineMedium,
                    // KEY PATTERN: textAlign centers text within its box.
                    textAlign: TextAlign.center,
                    color: Colors.primaryBackground,
                  ),
                ),
                // KEY PATTERN: maxLines + overflow truncates long text.
                Text(
                  'Your display name will appear here',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  color: Colors.secondaryText,
                ),
              ],
            ),
          ),

          // -- Profile info card (read mode) --
          Container(
            // KEY PATTERN: borderColor + borderWidth for outlined containers.
            borderColor: Colors.secondary,
            borderWidth: 1,
            borderRadius: 12,
            padding: 16,
            // KEY PATTERN: visible controls conditional rendering.
            visible: Not(AppState('isEditing')),
            child: Column(
              crossAxis: CrossAxis.start,
              spacing: 8,
              children: [
                Text(
                  'Display Name',
                  style: Styles.labelMedium,
                  color: Colors.secondaryText,
                ),
                Text(AppState('displayName'), style: Styles.bodyLarge),
                Divider(),
                Text(
                  'Bio',
                  style: Styles.labelMedium,
                  color: Colors.secondaryText,
                ),
                Text(
                  AppState('bio'),
                  style: Styles.bodyMedium,
                  // KEY PATTERN: maxLines limits multi-line text display.
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // KEY PATTERN: Button with color, textColor, borderRadius, padding.
          Button(
            'Edit Profile',
            icon: 'edit',
            width: double.infinity,
            color: Colors.primary,
            textColor: Colors.primaryBackground,
            borderRadius: 12,
            padding: EdgeInsets.symmetric(vertical: 14),
            visible: Not(AppState('isEditing')),
            onTap: UpdateAppState.set('isEditing', true),
          ),

          // -- Edit form (edit mode) --
          Container(
            borderColor: Colors.primary,
            borderWidth: 1,
            borderRadius: 12,
            padding: 16,
            visible: AppState('isEditing'),
            child: Form(
              name: 'profileForm',
              child: Column(
                crossAxis: CrossAxis.start,
                spacing: 16,
                children: [
                  Text('Edit Profile', style: Styles.titleMedium),
                  TextField(
                    label: 'Display Name',
                    hint: 'Enter your name',
                    name: 'nameField',
                    prefixIcon: 'person',
                    onChanged: SetState('editName', TextValue()),
                  ),
                  // KEY PATTERN: maxLines on TextField makes a multi-line input.
                  TextField(
                    label: 'Bio',
                    hint: 'Tell us about yourself...',
                    name: 'bioField',
                    maxLines: 4,
                    onChanged: SetState('editBio', TextValue()),
                  ),
                  Row(
                    spacing: 12,
                    mainAxis: MainAxis.end,
                    children: [
                      Button(
                        'Cancel',
                        variant: ButtonVariant.outlined,
                        onTap: [
                          UpdateAppState.set('isEditing', false),
                          ClearTextField('nameField'),
                          ClearTextField('bioField'),
                        ],
                      ),
                      Button(
                        'Save',
                        color: Colors.primary,
                        textColor: Colors.primaryBackground,
                        onTap: [
                          ValidateForm('profileForm'),
                          UpdateAppState.set(
                            'displayName',
                            WidgetState('nameField', WidgetStateProperty.text),
                          ),
                          UpdateAppState.set(
                            'bio',
                            WidgetState('bioField', WidgetStateProperty.text),
                          ),
                          UpdateAppState.set('isEditing', false),
                          Snackbar('Profile updated'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Divider(),

          // -- Password section --
          Text('Security', style: Styles.titleMedium),
          // KEY PATTERN: obscureText hides input (password field).
          TextField(
            label: 'Current Password',
            hint: 'Enter current password',
            obscureText: true,
            // KEY PATTERN: suffixIcon adds a trailing icon.
            suffixIcon: 'visibility_off',
            name: 'currentPwField',
            onChanged: SetState('currentPassword', TextValue()),
          ),
          TextField(
            label: 'New Password',
            obscureText: true,
            suffixIcon: 'visibility_off',
            name: 'newPwField',
            onChanged: SetState('newPassword', TextValue()),
          ),
          // KEY PATTERN: disabled prevents interaction.
          Button(
            'Change Password',
            width: double.infinity,
            variant: ButtonVariant.outlined,
            disabled: true,
            padding: EdgeInsets.symmetric(vertical: 14),
            onTap: Snackbar('Password changed'),
          ),
        ],
      ),
    ),
  );
}
