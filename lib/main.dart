import 'package:flutter/material.dart';
import 'dart:async';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/app_strings.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:ndu_project/firebase_options.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/services/api_config_secure.dart'
    show SecureAPIConfig;
import 'package:ndu_project/services/env_config_loader.dart';
import 'package:ndu_project/services/project_navigation_service.dart';
import 'package:ndu_project/services/user_preferences_service.dart';
import 'package:ndu_project/services/currency_service.dart';
import 'package:ndu_project/services/security_services.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/providers/app_content_provider.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/pbs/providers/pbs_provider.dart';
import 'package:ndu_project/project_controls/providers/project_controls_provider.dart';
import 'package:ndu_project/project_controls/providers/change_management_provider.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/providers/theme_provider.dart';
import 'package:ndu_project/platform/webview_platform_setup.dart';
import 'package:ndu_project/utils/browser_route_normalizer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  configureWebWebViewPlatform();
  normalizeBrowserHashRoute();

  // Suppress specific framework warnings and inspector errors
  final previousHandler = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final message = details.exceptionAsString();

    // Suppress inspector selection errors (common in Dreamflow preview)
    if (message.contains('Id does not exist.')) {
      debugPrint('Inspector selection error suppressed: $message');
      return;
    }

    // Comprehensive suppression of RestorableNode/ModalScope warnings.
    // NOTE: we deliberately do NOT match on stack-trace fragments like
    // 'mode#' here — in release builds every stack frame contains 'mode#'
    // (e.g. `<mode#...>`), so matching on it would suppress ALL errors and
    // hide every real bug as a silent grey/blank screen.
    if (message.contains('_RestorableNode') ||
        message.contains('RestorableNode') ||
        message.contains('_DialogScope') ||
        message.contains('ModalScopeStatus') ||
        message.contains('ModalScope') ||
        message.contains('Nested arrays are not supported') ||
        message.contains('Remote arrays are not supported') ||
        message.contains('listening Function with') ||
        message.contains('listening to Function') ||
        message.contains('called with invalid state') ||
        message.contains('saved with invalid state') ||
        message.contains('invalid state. Nested arrays') ||
        message.contains('ListTile background color or ink splashes') ||
        (message.contains('listening to') &&
            message.contains('invalid state'))) {
      // Silently suppress — these are benign framework warnings that
      // don't affect functionality and would only add noise to the console.
      return;
    }

    // Log other errors for debugging
    debugPrint('Flutter error: $message');
    if (details.stack != null) {
      debugPrint(details.stack.toString());
    }
    previousHandler?.call(details);
  };

  // Override the error widget builder to hide specific warnings from UI
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final message = details.exceptionAsString();

    // Don't show error widgets for these suppressed warnings (these are
    // benign framework-level warnings that don't affect functionality).
    // NOTE: we deliberately do NOT match on stack-trace fragments like
    // 'mode#' here — in release builds every stack frame contains 'mode#'
    // (e.g. `<mode#...>`), so matching on it would suppress ALL errors and
    // turn every broken screen into a silent grey/blank page.
    if (message.contains('Id does not exist.') ||
        message.contains('_RestorableNode') ||
        message.contains('RestorableNode') ||
        message.contains('_DialogScope') ||
        message.contains('ModalScopeStatus') ||
        message.contains('ModalScope') ||
        message.contains('Nested arrays are not supported') ||
        message.contains('Remote arrays are not supported') ||
        message.contains('listening Function with') ||
        message.contains('listening to Function') ||
        message.contains('called with invalid state') ||
        message.contains('saved with invalid state') ||
        message.contains('invalid state. Nested arrays') ||
        message.contains('ListTile background color or ink splashes') ||
        (message.contains('listening to') &&
            message.contains('invalid state'))) {
      return const SizedBox.shrink();
    }

    // For other errors, show a friendly error screen so the user sees a
    // helpful message instead of a silent grey/blank page.
    debugPrint('ErrorWidget.builder rendering error screen: $message');
    return _FriendlyErrorScreen(
      title: 'Something went wrong',
      message: message,
      stack: details.stack?.toString(),
    );
  };

  // Firebase must be ready before widgets touch Auth or Firestore. Letting the
  // app continue while initialization is still pending can crash Flutter web
  // with a FirebaseException/JavaScriptObject interop type error.
  try {
    // Firebase.initializeApp() can hang indefinitely in some browser
    // environments (e.g. when Firebase CDN is slow, IndexedDB is locked,
    // or during hot restart with a stale connection). Run it with a hard
    // timeout so app startup is never blocked by a stuck Firebase init.
    // On hot restart, Firebase.initializeApp() can hang indefinitely because
    // the Firebase SDK maintains a stale connection to IndexedDB/Firestore.
    // Throwing a TimeoutException (caught by the outer try/catch) lets
    // startup proceed without Firebase — the app degrades gracefully by
    // showing an error screen rather than sitting on an infinite spinner.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException(
        'Firebase.initializeApp() timed out after 10s',
      ),
    );

    // Configure Firestore to prevent INTERNAL ASSERTION FAILED errors on web.
    // Disabling persistence avoids IndexedDB cache corruption which causes
    // the "Unexpected state" assertion in Firestore SDK 12.x Watch system.
    final firestore = FirebaseFirestore.instance;
    if (kIsWeb) {
      // clearPersistence() can hang indefinitely in some browser environments
      // (e.g. when IndexedDB is locked by a stale service worker, or when
      // the tab is in the background). Run it with a hard timeout so app
      // startup is never blocked by a stuck IndexedDB cleanup.
      await firestore.clearPersistence().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint(
              '[main] firestore.clearPersistence() timed out after 3s — continuing startup.');
        },
      );
    }
    firestore.settings = Settings(
      persistenceEnabled: !kIsWeb,
      // Cap Firestore cache size to prevent unbounded IndexedDB growth on web.
      // CACHE_SIZE_UNLIMITED caused multi-hundred-MB IndexedDB bloat in long
      // sessions. 40 MB is the SDK default and comfortably holds ~1k documents.
      cacheSizeBytes: kIsWeb ? 40 * 1024 * 1024 : Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (error, stack) {
    debugPrint('Firebase init error: $error');
    debugPrint(stack.toString());
  }

  // Load runtime environment config (web/env-config.js → window.__NDU_ENV).
  // Must run BEFORE ApiKeyManager.initializeApiKey() so any OpenAI key
  // supplied at deploy time is picked up. On non-web this is a fast no-op.
  await EnvConfigLoader.load();

  // Initialize API key. Priority order:
  //   1. window.__NDU_ENV.OPENAI_API_KEY (deploy-time override)
  //   2. Per-user key loaded from Firestore (set via Settings screen)
  //   3. Server-side proxy (no client key needed)
  ApiKeyManager.initializeApiKey();
  if (EnvConfigLoader.hasOpenAiKey) {
    ApiKeyManager.setApiKey(EnvConfigLoader.openaiApiKey!);
  } else if (kIsWeb) {
    debugPrint(
      'NDU: no deploy-time API key in env-config.js — '
      'using server-side proxy.',
    );
  }
  // Tune image raster cache for web — default 100 MB / 1000 images is
  // excessive for a project-management app where most images are small
  // avatars, icons, and section banners. 50 MB / 500 images is plenty and
  // frees ~50 MB of memory for the actual app state.
  // (No-op on mobile — these only have effect on web.)
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 500;

  // Warm common local stores in background to reduce first-navigation latency.
  unawaited(UserPreferencesService.warmUp());
  unawaited(UserPreferencesService.loadCountryCurrency());
  unawaited(ProjectNavigationService.instance.warmUp());

  // #6: Start session manager (auto-logout after 30 minutes of inactivity)
  // The timer is reset on any user interaction via the Listener widget in MyApp.
  SessionManager.instance.start();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProjectDataProvider()),
        ChangeNotifierProvider(
            create: (_) => AppContentProvider()
              ..watchContent()
              ..loadLocalOverrides()),
        ChangeNotifierProvider(create: (_) => CostEstimateProvider()),
        ChangeNotifierProvider(create: (_) => WBSProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProvider(create: (_) => PBSProvider()),
        ChangeNotifierProvider(create: (_) => ProjectControlsProvider()),
        ChangeNotifierProvider(create: (_) => ChangeManagementProvider()),
        ChangeNotifierProvider(create: (_) {
          final tp = ThemeProvider();
          tp.load();
          return tp;
        }),
        ChangeNotifierProvider(create: (_) {
          final cs = CurrencyService.instance;
          cs.load();
          return cs;
        }),
      ],
      child: Builder(
        builder: (context) {
          final projectProvider =
              Provider.of<ProjectDataProvider>(context, listen: false);
          final themeProvider = Provider.of<ThemeProvider>(context);
          return ProjectDataInherited(
            provider: projectProvider,
            child: Listener(
              // #6: Reset session timer on any pointer interaction (mouse/touch)
              onPointerDown: (_) => SessionManager.instance.resetTimer(),
              onPointerMove: (_) => SessionManager.instance.resetTimer(),
              onPointerUp: (_) => SessionManager.instance.resetTimer(),
              child: MaterialApp.router(
                title: AppStrings.appName,
                debugShowCheckedModeBanner: false,
                theme: lightTheme,
                darkTheme: darkTheme,
                themeMode: themeProvider.themeMode,
                routerConfig: AppRouter.main,
                // Smooth cross-fade when toggling themes
                themeAnimationDuration: const Duration(milliseconds: 300),
                themeAnimationCurve: Curves.easeInOut,
                // Performance optimizations
                builder: (context, child) {
                  final media =
                      MediaQuery.of(context).copyWith(boldText: false);
                  return MediaQuery(
                    // Disable unnecessary animations and transitions on slow devices
                    data: media,
                    // Provide a transparent Material ancestor so that all
                    // ListTile widgets in the app have a Material ancestor,
                    // preventing the "background color or ink splashes may
                    // be invisible" warning from DecoratedBox wrappers.
                    child: Material(
                      type: MaterialType.transparency,
                      child: child ?? const SizedBox.shrink(),
                    ),
                  );
                },
                // Reduce checkerboard opacity for better performance
                checkerboardRasterCacheImages: false,
                checkerboardOffscreenLayers: false,
                // Show the Flutter performance overlay in profile/debug mode
                // so frame jank is visible during manual QA. Hidden in
                // release builds automatically.
                showPerformanceOverlay: kDebugMode,
              ),
            ),
          );
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SafeArea(
        top: true,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('You have pushed the button this many times:'),
              Text(
                '$_counter',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _FriendlyErrorScreen extends StatelessWidget {
  const _FriendlyErrorScreen(
      {required this.title, required this.message, this.stack});

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
                            // Try to navigate back safely, or do nothing if Navigator isn't available
                            try {
                              final nav = Navigator.maybeOf(context,
                                  rootNavigator: true);
                              if (nav != null && nav.canPop()) {
                                nav.pop();
                              } else {
                                debugPrint(
                                    'No Navigator available or cannot pop. Please refresh the app manually.');
                              }
                            } catch (e) {
                              debugPrint('Error during retry: $e');
                            }
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      )
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
