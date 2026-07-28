/// Media browser reference — patterns for layout, lists, and visual content.
///
/// Demonstrates:
/// - ListView: horizontal, shrinkWrap
/// - Row: scrollable, padding
/// - Container: width, height, margin, borderRadius, alignment
/// - Text: textAlign, maxLines, overflow
/// - Image: network, fit, width, height, borderRadius
/// - GridView with childAspectRatio and padding
/// - Card with onTap
/// - EdgeInsets.only() for asymmetric padding
/// - Navigate with params
/// - Component with params
library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  await flutterFlowAI(
    buildMediaBrowserApp,
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

void buildMediaBrowserApp(App app) {
  // -- Theme --
  app.themeColor('primary', 0xFF0061A4);
  app.themeColor('primaryBackground', 0xFFFBFCFF);
  app.themeColor('secondaryBackground', 0xFFFFFFFF);
  app.themeColor('primaryText', 0xFF001D35);
  app.themeColor('secondaryText', 0xFF43474E);
  app.primaryFont('Inter');

  // -- Data model --
  final mediaItem = app.struct('MediaItem', {
    'title': string,
    'subtitle': string,
    'imageUrl': string,
    'category': string,
  });

  app.state('featured', listOf(mediaItem), persisted: true);
  app.state('recent', listOf(mediaItem), persisted: true);
  app.state('selectedCategory', string);

  // ---------------------------------------------------------------------------
  // Media card component — demonstrates component params + layout patterns
  // ---------------------------------------------------------------------------
  app.component(
    'MediaCard',
    params: {'title': string, 'subtitle': string, 'imageUrl': string},
    body: Container(
      width: 160,
      // KEY PATTERN: margin with EdgeInsets.only() for asymmetric spacing.
      margin: EdgeInsets.only(right: 12),
      borderRadius: 12,
      color: Colors.secondaryBackground,
      child: Column(
        crossAxis: CrossAxis.start,
        children: [
          // KEY PATTERN: Image with explicit sizing and border radius.
          Image(
            Param('imageUrl'),
            width: 160,
            height: 100,
            fit: ImageFit.cover,
            borderRadius: 12,
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxis: CrossAxis.start,
              spacing: 2,
              children: [
                // KEY PATTERN: maxLines + ellipsis prevents text overflow in cards.
                Text(
                  Param('title'),
                  style: Styles.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  Param('subtitle'),
                  style: Styles.bodySmall,
                  color: Colors.secondaryText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  // ---------------------------------------------------------------------------
  // Browse page
  // ---------------------------------------------------------------------------
  app.page(
    'BrowsePage',
    route: '/',
    isInitial: true,
    body: Scaffold(
      appBar: AppBar(title: 'Browse'),
      body: Column(
        scrollable: true,
        crossAxis: CrossAxis.start,
        children: [
          // -- Section: Featured (horizontal list) --
          Container(
            padding: EdgeInsets.only(left: 16, top: 16),
            child: Text(
              'Featured',
              style: Styles.titleLarge,
              // KEY PATTERN: textAlign controls horizontal text position.
              textAlign: TextAlign.start,
            ),
          ),

          // KEY PATTERN: horizontal ListView scrolls sideways.
          // shrinkWrap: true makes it size to content height instead of
          // expanding to fill available space.
          Container(
            height: 180,
            padding: EdgeInsets.only(left: 16, top: 8),
            child: ListView(
              source: AppState('featured'),
              horizontal: true,
              shrinkWrap: true,
              itemBuilder:
                  (item) => Container(
                    width: 280,
                    margin: EdgeInsets.only(right: 12),
                    borderRadius: 16,
                    child: Stack(
                      children: [
                        Image(
                          item['imageUrl'],
                          width: 280,
                          height: 180,
                          fit: ImageFit.cover,
                          borderRadius: 16,
                        ),
                        Container(
                          width: 280,
                          height: 180,
                          borderRadius: 16,
                          alignment: Alignment.bottomLeft,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Column(
                              mainAxis: MainAxis.end,
                              crossAxis: CrossAxis.start,
                              spacing: 4,
                              children: [
                                Text(
                                  item['title'],
                                  style: Styles.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  item['subtitle'],
                                  style: Styles.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ),

          // -- Section: Categories (scrollable row of chips) --
          Container(
            padding: EdgeInsets.only(left: 16, top: 20),
            child: Text('Categories', style: Styles.titleLarge),
          ),
          // KEY PATTERN: scrollable Row for horizontal chip/tag lists.
          Row(
            scrollable: true,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            spacing: 8,
            children: [
              Button(
                'All',
                variant: ButtonVariant.filled,
                color: Colors.primary,
                textColor: Colors.primaryBackground,
                borderRadius: 20,
                onTap: UpdateAppState.set('selectedCategory', ''),
              ),
              Button(
                'Music',
                variant: ButtonVariant.outlined,
                borderRadius: 20,
                onTap: UpdateAppState.set('selectedCategory', 'music'),
              ),
              Button(
                'Videos',
                variant: ButtonVariant.outlined,
                borderRadius: 20,
                onTap: UpdateAppState.set('selectedCategory', 'videos'),
              ),
              Button(
                'Podcasts',
                variant: ButtonVariant.outlined,
                borderRadius: 20,
                onTap: UpdateAppState.set('selectedCategory', 'podcasts'),
              ),
              Button(
                'Articles',
                variant: ButtonVariant.outlined,
                borderRadius: 20,
                onTap: UpdateAppState.set('selectedCategory', 'articles'),
              ),
            ],
          ),

          // -- Section: Recent (grid view) --
          Container(
            padding: EdgeInsets.only(left: 16, top: 12),
            child: Text('Recent', style: Styles.titleLarge),
          ),
          // KEY PATTERN: GridView with padding and aspect ratio.
          GridView(
            source: AppState('recent'),
            columns: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
            padding: EdgeInsets.all(16),
            itemBuilder:
                (item) => Container(
                  borderRadius: 12,
                  color: Colors.secondaryBackground,
                  child: Column(
                    crossAxis: CrossAxis.start,
                    children: [
                      Image(
                        item['imageUrl'],
                        height: 120,
                        fit: ImageFit.cover,
                        borderRadius: 12,
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxis: CrossAxis.start,
                          spacing: 2,
                          children: [
                            Text(
                              item['title'],
                              style: Styles.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              item['category'],
                              style: Styles.bodySmall,
                              color: Colors.secondaryText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    ),
  );
}
