/// The app-wide policy for what happens when a widget's `build` throws.
///
/// Both entry points (`main.dart` and `main_admin.dart`) install the same
/// policy, so a failure is handled — and, crucially, *reported* — identically
/// in the user app and the admin panel.
///
/// Why this lives in one place: the previous handlers listed error-message
/// fragments and returned `SizedBox.shrink()` for anything that matched. Some
/// of those fragments come from real data failures (Firestore's "Nested arrays
/// are not supported", stream-listener "invalid state" errors), so a widget
/// that threw one of them rendered **nothing at all** — a blank page body with
/// a live sidebar and header, nothing in the console, and no way for the user
/// or a developer to tell what happened. Only framework/harness noise is
/// silently dropped now; every other failure draws [AppErrorScreen] with the
/// message and stack, and every suppression is logged.
library;

import 'package:flutter/material.dart';

/// Error-message fragments that indicate framework or tooling noise rather
/// than a broken screen.
///
/// These are safe to hide: they are emitted by the widget inspector, by
/// `Restorable*` property registration on hot reload, by modal-route
/// bookkeeping, and by `ListTile`s that sit behind a `DecoratedBox` (the app
/// wraps every route in a transparent `Material` for exactly that reason).
/// Hiding one of them cannot hide a failure of the screen's own content.
///
/// Deliberately narrow: stack-trace fragments are never matched (in a release
/// build every frame contains `mode#`, which would suppress *every* error and
/// turn each broken screen into a silent blank page), and data-layer failures
/// such as Firestore's "Nested arrays are not supported" or a listener's
/// "invalid state" are **not** listed — those mean the page really did fail to
/// render something, so they must be visible.
bool isBenignFrameworkNoise(String message) {
  return message.contains('Id does not exist.') ||
      message.contains('_RestorableNode') ||
      message.contains('RestorableNode') ||
      message.contains('_DialogScope') ||
      message.contains('ModalScopeStatus') ||
      message.contains('ModalScope') ||
      message.contains('ListTile background color or ink splashes');
}

/// What a failed subtree renders.
///
/// Never `SizedBox.shrink()`: a page that fails to build must say so. The
/// sidebar and header of the surrounding shell keep rendering either way, so a
/// silent empty body is indistinguishable from "this page has no content" —
/// the symptom this policy exists to prevent.
Widget buildAppErrorWidget(FlutterErrorDetails details) {
  final message = details.exceptionAsString();
  if (isBenignFrameworkNoise(message)) {
    return const SizedBox.shrink();
  }
  debugPrint('ErrorWidget.builder rendering error screen: $message');
  return AppErrorScreen(
    title: 'Something went wrong',
    message: message,
    stack: details.stack?.toString(),
  );
}

/// Installs [buildAppErrorWidget] and an error handler that chains to whatever
/// handler was already in place (the Flutter binding's, or a test's).
///
/// Suppressed noise is logged, not swallowed silently: if a screen ever comes
/// up blank, the console has to say which error blanked it.
void installAppErrorHandling() {
  final previousHandler = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final message = details.exceptionAsString();

    if (isBenignFrameworkNoise(message)) {
      debugPrint('[suppressed framework noise] '
          '${message.split('\n').first}');
      return;
    }

    // Log other errors for debugging, then hand them to the previous handler
    // so the binding still reports them (test failures, red screens, crash
    // reporting).
    debugPrint('Flutter error: $message');
    if (details.stack != null) {
      debugPrint(details.stack.toString());
    }
    previousHandler?.call(details);
  };

  ErrorWidget.builder = buildAppErrorWidget;
}

/// Full-screen fallback shown in place of a subtree whose build threw.
///
/// Names the failure and offers a back/retry action, so a broken page is
/// visible and diagnosable instead of blank.
class AppErrorScreen extends StatelessWidget {
  const AppErrorScreen({
    super.key,
    required this.title,
    required this.message,
    this.stack,
  });

  final String title;
  final String message;
  final String? stack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        top: true,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: theme.colorScheme.error, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child:
                                Text(title, style: theme.textTheme.titleLarge),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(message, style: theme.textTheme.bodyMedium),
                      if (stack != null) ...[
                        const SizedBox(height: 12),
                        ExpansionTile(
                          leading:
                              const Icon(Icons.bug_report, color: Colors.red),
                          title: const Text('Technical details'),
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Text(
                                stack!,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () {
                            // Try to navigate back safely, or do nothing if
                            // Navigator isn't available.
                            try {
                              final nav = Navigator.maybeOf(context,
                                  rootNavigator: true);
                              if (nav != null && nav.canPop()) {
                                nav.pop();
                              } else {
                                debugPrint('No Navigator available or cannot '
                                    'pop. Please refresh the app manually.');
                              }
                            } catch (e) {
                              debugPrint('Error during retry: $e');
                            }
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
