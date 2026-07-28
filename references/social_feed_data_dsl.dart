library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  await flutterFlowAI(
    buildSocialFeedData,
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
Run the SocialFeedData DSL and push the compiled project to FlutterFlow.

Usage:
  dart run specs/dsl/social_feed_data_dsl.dart [options]

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

App buildSocialFeedData(App app) {
  final post = app.collection(
    'Post',
    fields: {
      'title': string,
      'body': string,
      'authorName': string,
      'likeCount': int_,
      'featured': bool_,
    },
    description: 'Posts shown in the feed.',
  );
  app.collection(
    'Profile',
    fields: {'displayName': string, 'bio': string, 'avatarUrl': string},
    description: 'Public author profiles.',
  );
  final like = app.collection(
    'Like',
    fields: {'postTitle': string, 'userName': string},
    description: 'Simple likes without auth coupling.',
  );

  final postDetailPage = app.page(
    'PostDetailPage',
    route: '/post',
    params: {'post': post},
    state: {
      'post': post,
      'statusMessage': string.withDefault('Loading post...'),
    },
    onLoad: [
      FirestoreRead(
        post,
        DocumentReferenceOf(PageParam('post')),
        outputAs: 'loadedPost',
      ),
      SetState('post', ActionOutput('loadedPost')),
      SetState('statusMessage', 'Post ready'),
    ],
    body: Scaffold(
      appBar: AppBar(title: State('post')['title']),
      body: Column(
        spacing: 12,
        children: [
          Text(State('statusMessage'), style: Styles.labelMedium),
          Text(State('post')['authorName'], style: Styles.titleMedium),
          Text(State('post')['body']),
          Row(
            spacing: 12,
            children: [
              Button(
                'Like Post',
                onTap: [
                  FirestoreCreate(
                    like,
                    fields: {
                      'postTitle': State('post')['title'],
                      'userName': 'Guest',
                    },
                  ),
                  Snackbar('Like saved'),
                ],
              ),
              Button(
                'Mark Featured',
                variant: ButtonVariant.outlined,
                onTap: [
                  FirestoreUpdate(
                    DocumentReferenceOf(State('post')),
                    collection: post,
                    fields: {'featured': true, 'likeCount': 99},
                  ),
                  Snackbar('Post updated'),
                ],
              ),
            ],
          ),
          Button(
            'Delete Post',
            variant: ButtonVariant.text,
            onTap: [
              FirestoreDelete(DocumentReferenceOf(State('post'))),
              NavigateBack(),
            ],
          ),
        ],
      ),
    ),
  );

  final composePostPage = app.page(
    'ComposePostPage',
    route: '/compose',
    state: {
      'draftTitle': string,
      'draftBody': string,
      'authorName': string.withDefault('FlutterFlow AI Agent'),
    },
    body: Scaffold(
      appBar: AppBar(title: 'Compose Post'),
      body: Column(
        spacing: 16,
        children: [
          TextField(
            name: 'TitleField',
            label: 'Title',
            onChanged: SetState('draftTitle', TextValue()),
          ),
          TextField(
            name: 'BodyField',
            label: 'Body',
            onChanged: SetState('draftBody', TextValue()),
          ),
          Button(
            'Publish',
            onTap: [
              FirestoreCreate(
                post,
                fields: {
                  'title': State('draftTitle'),
                  'body': State('draftBody'),
                  'authorName': State('authorName'),
                  'likeCount': 0,
                  'featured': false,
                },
                outputAs: 'newPost',
              ),
              Navigate.to(
                postDetailPage,
                params: {'post': ActionOutput('newPost')},
              ),
            ],
          ),
        ],
      ),
    ),
  );

  app.page(
    'FeedPage',
    route: '/',
    isInitial: true,
    state: {'posts': listOf(post)},
    onLoad: [
      FirestoreQuery(post, limit: 10, outputAs: 'loadedPosts'),
      SetState('posts', ActionOutput('loadedPosts')),
    ],
    body: Scaffold(
      appBar: AppBar(title: 'Social Feed Data'),
      body: Column(
        spacing: 16,
        children: [
          Button('Compose Post', onTap: Navigate.to(composePostPage)),
          ListView(
            source: State('posts'),
            spacing: 12,
            itemBuilder:
                (_) => Card(
                  child: Column(
                    spacing: 6,
                    children: [
                      Text(ItemRef()['title'], style: Styles.titleMedium),
                      Text(ItemRef()['authorName'], style: Styles.labelMedium),
                      Text(ItemRef()['body']),
                    ],
                  ),
                ),
          ),
        ],
      ),
    ),
  );

  return app;
}
