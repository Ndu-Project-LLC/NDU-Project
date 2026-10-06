import 'package:flutter/material.dart';
import 'package:ndu_project/theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ndu_project/firebase_options.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/utils/error_widget_policy.dart';
import 'package:ndu_project/providers/app_content_provider.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Same error policy as the user app: only framework noise is hidden,
  // everything else draws a visible error screen (this handler used to
  // match on "mode#" in the stack trace, which in a release build matches
  // every frame — so every broken admin screen came up blank).
  installAppErrorHandling();

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

