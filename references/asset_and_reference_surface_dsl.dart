/// Asset/reference type reference — media paths and document references.
///
/// Demonstrates:
/// - `imagePath`, `videoPath`, and `audioPath` scalar types
/// - `listOf(...)` variants for media collections
/// - `docRef(collection)` for Firestore document-reference state
/// - app state, page state, and component params using these types
/// - binding media-typed state into `Image(...)` and list-based galleries
///
/// Notes:
/// - Use `imagePath`, `videoPath`, and `audioPath` for uploaded asset URLs /
///   stored media paths instead of raw `string` when you want parity with
///   FlutterFlow's typed field surface.
/// - FlutterFlow AI now imports existing-project app/page/component state
///   using `ImagePath`, `VideoPath`, `AudioPath`, `DocumentReference`, and
///   list variants cleanly during edit compilation.
/// - Typed app constants are not first-class in FlutterFlow AI yet. `app.constant(...)`
///   still infers from raw Dart values, so string constants remain `String`
///   rather than explicit asset/reference types.
library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  await flutterFlowAI(
    buildAssetAndReferenceSurfaceApp,
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
        stderr.writeln('Unknown option: $arg');
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

void buildAssetAndReferenceSurfaceApp(App app) {
  app.themeColor('primary', 0xFF0E5AA7);
  app.themeColor('primaryBackground', 0xFFF6F8FC);
  app.themeColor('secondaryBackground', 0xFFFFFFFF);
  app.themeColor('primaryText', 0xFF132238);
  app.themeColor('secondaryText', 0xFF5C6574);
  app.primaryFont('Inter');

  final libraryItem = app.collection(
    'LibraryItem',
    fields: {'title': string, 'summary': string},
    description: 'Simple Firestore collection used for docRef examples.',
  );

  app.state(
    'heroImage',
    imagePath.withDefault('https://images.example.com/hero-cover.jpg'),
    persisted: true,
  );
  app.state(
    'introVideo',
    videoPath.withDefault('https://videos.example.com/launch.mp4'),
    persisted: true,
  );
  app.state(
    'ambientAudio',
    audioPath.withDefault('https://audio.example.com/ambient.mp3'),
    persisted: true,
  );
  app.state('galleryImages', listOf(imagePath), persisted: true);
  app.state('queuedVideos', listOf(videoPath), persisted: true);
  app.state('voiceNotes', listOf(audioPath), persisted: true);
  app.state('selectedLibraryItem', docRef(libraryItem), persisted: true);
  app.state('recentLibraryItems', listOf(docRef(libraryItem)), persisted: true);

  final mediaCard = app.component(
    'MediaCard',
    description: 'Reusable card for image/video/audio asset metadata.',
    params: {
      'thumbnail': imagePath,
      'videoUrl': videoPath,
      'audioUrl': audioPath,
      'title': string,
    },
    body: Container(
      borderRadius: 16,
      color: Colors.secondaryBackground,
      child: Column(
        crossAxis: CrossAxis.start,
        spacing: 8,
        children: [
          Image(
            Param('thumbnail'),
            width: double.infinity,
            height: 180,
            fit: ImageFit.cover,
            borderRadius: 16,
          ),
          Container(
            padding: 12,
            child: Column(
              crossAxis: CrossAxis.start,
              spacing: 6,
              children: [
                Text(Param('title'), style: Styles.titleSmall),
                Text(
                  'Video path and audio path params can be stored on components '
                  'even when the widget tree renders only the thumbnail preview.',
                  style: Styles.bodySmall,
                  color: Colors.secondaryText,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  app.page(
    'AssetAndReferenceSurfacePage',
    route: '/',
    isInitial: true,
    description: 'Demonstrates typed media paths and Firestore doc refs.',
    state: {
      'selectedImage': imagePath.withDefault(
        'https://images.example.com/selected-shot.jpg',
      ),
      'selectedVideo': videoPath,
      'selectedAudio': audioPath,
      'highlightedItem': docRef(libraryItem),
      'queuedImages': listOf(imagePath),
    },
    body: Scaffold(
      appBar: AppBar(title: 'Asset + Reference Types'),
      body: Column(
        scrollable: true,
        spacing: 16,
        padding: 16,
        crossAxis: CrossAxis.start,
        children: [
          Text('ImagePath in app state', style: Styles.titleLarge),
          Image(
            AppState('heroImage'),
            width: double.infinity,
            height: 200,
            fit: ImageFit.cover,
            borderRadius: 20,
          ),

          Text('Component params for media assets', style: Styles.titleLarge),
          mediaCard(
            thumbnail: State('selectedImage'),
            videoUrl: AppState('introVideo'),
            audioUrl: AppState('ambientAudio'),
            title: 'Selected media bundle',
          ),

          Text('Image galleries from typed lists', style: Styles.titleLarge),
          Container(
            height: 150,
            child: ListView(
              source: AppState('galleryImages'),
              horizontal: true,
              spacing: 12,
              itemBuilder:
                  (item) => Image(
                    item,
                    width: 180,
                    height: 150,
                    fit: ImageFit.cover,
                    borderRadius: 16,
                  ),
            ),
          ),

          Text('Queued page-state images', style: Styles.titleLarge),
          Container(
            height: 120,
            child: ListView(
              source: State('queuedImages'),
              horizontal: true,
              spacing: 12,
              itemBuilder:
                  (item) => Container(
                    width: 120,
                    borderRadius: 16,
                    color: Colors.secondaryBackground,
                    child: Image(
                      item,
                      width: 120,
                      height: 120,
                      fit: ImageFit.cover,
                      borderRadius: 16,
                    ),
                  ),
            ),
          ),

          Container(
            padding: 16,
            borderRadius: 16,
            color: Colors.secondaryBackground,
            child: Column(
              crossAxis: CrossAxis.start,
              spacing: 8,
              children: [
                Text('DocumentReference notes', style: Styles.titleSmall),
                Text(
                  'Use docRef(collection) for Firestore document references in '
                  'app state, page state, and component params. These values are '
                  'preserved during edit existing-project import.',
                  style: Styles.bodyMedium,
                  color: Colors.secondaryText,
                ),
                Text(
                  'This example stores docRef values in selectedLibraryItem, '
                  'recentLibraryItems, and highlightedItem.',
                  style: Styles.bodyMedium,
                  color: Colors.secondaryText,
                ),
              ],
            ),
          ),

          Container(
            padding: 16,
            borderRadius: 16,
            color: Colors.secondaryBackground,
            child: Text(
              'Use typed asset/reference fields instead of raw strings when you '
              'want the FlutterFlow AI DSL to match FlutterFlow field semantics for images, '
              'video/audio paths, and Firestore document references.',
              style: Styles.bodyMedium,
              color: Colors.secondaryText,
            ),
          ),
        ],
      ),
    ),
  );
}
