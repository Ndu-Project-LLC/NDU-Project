import 'package:flutter/material.dart';
import 'package:ndu_project/theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ndu_project/firebase_options.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/providers/app_content_provider.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress specific framework warnings
  final previousHandler = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    final stackTrace = details.stack?.toString() ?? '';

    // Suppress inspector selection errors
    if (message.contains('Id does not exist.')) {
      debugPrint('Inspector selection error suppressed: $message');
      return;
    }

    // Comprehensive suppression of RestorableNode/ModalScope warnings
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
        stackTrace.contains('mode#') ||
        (message.contains('listening to') &&
            message.contains('invalid state'))) {
      debugPrint('Route state warning suppressed: $message');
      return;
    }

    final hadPreviousHandler = previousHandler != null;
    previousHandler?.call(details);
    if (!hadPreviousHandler) {
      FlutterError.presentError(details);
    }
  };

  // Override the error widget builder to hide specific warnings from UI
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    final stackTrace = details.stack?.toString() ?? '';

    // Don't show error widgets for these warnings
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
        stackTrace.contains('mode#') ||
        (message.contains('listening to') &&
            message.contains('invalid state'))) {
      return const SizedBox.shrink(); // Return empty widget
    }

    // For other errors, show the default error widget
    return ErrorWidget(details.exception);
  };

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('Firebase initialized for Admin App');
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // Initialize OpenAI API key from environment (if provided)
  ApiKeyManager.initializeApiKey();

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProjectDataProvider()),
        ChangeNotifierProvider(
            create: (_) => AppContentProvider()
              ..watchContent()
              ..loadLocalOverrides()),
      ],
      child: Builder(
        builder: (context) {
          final projectProvider =
              Provider.of<ProjectDataProvider>(context, listen: false);
          return ProjectDataInherited(
            provider: projectProvider,
            child: MaterialApp.router(
              title: 'NDU Project - Admin Dashboard',
              debugShowCheckedModeBanner: false,
              theme: lightTheme,
              themeMode: ThemeMode.light,
              routerConfig: AppRouter.admin,
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(boldText: false),
                  child: child ?? const SizedBox.shrink(),
                );
              },
              checkerboardRasterCacheImages: false,
              checkerboardOffscreenLayers: false,
            ),
          );
        },
      ),
    );
  }
}
