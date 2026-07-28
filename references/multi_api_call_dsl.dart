/// Reference: multiple API calls on a single page.
///
/// Demonstrates:
/// - Two API calls in onLoad with distinct `outputAs` names
/// - API call from a button tap (lazy fetch)
/// - Chained API calls (second call in first's onSuccess)
library;

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  await flutterFlowAI(
    buildMultiApiApp,
    apiKey: options.apiKey,
    baseUrl: options.baseUrl,
    projectName: options.projectName,
    projectId: options.projectId,
    findOrCreate: options.findOrCreate,
    dryRun: options.dryRun,
    commitMessage: options.commitMessage,
  );
}

void buildMultiApiApp(App app) {
  // -- Data model --
  final post = app.struct('Post', {
    'id': int_,
    'userId': int_,
    'title': string,
    'body': string,
  });

  final comment = app.struct('Comment', {
    'id': int_,
    'postId': int_,
    'name': string,
    'email': string,
    'body': string,
  });

  final user = app.struct('User', {
    'id': int_,
    'name': string,
    'email': string,
  });

  // -- API endpoints --
  final getPost = Endpoint.get(
    'GetPost',
    '/posts/[id]',
    variables: {'id': int_},
    response: post,
  );

  final getComments = Endpoint.get(
    'GetComments',
    '/posts/[postId]/comments',
    variables: {'postId': int_},
    response: listOf(comment),
  );

  final getUser = Endpoint.get(
    'GetUser',
    '/users/[id]',
    variables: {'id': int_},
    response: user,
  );

  app.apiGroup(
    'JsonPlaceholderAPI',
    baseUrl: 'https://jsonplaceholder.typicode.com',
    headers: {'Content-Type': 'application/json'},
    endpoints: [getPost, getComments, getUser],
  );

  // -- Detail page: two API calls in onLoad + one from button --
  //
  // KEY PATTERN: use `outputAs` to give each API call a distinct output
  // variable name. Without `outputAs`, FlutterFlow will reject duplicate
  // names within the same page scope.
  app.page(
    'PostDetailPage',
    route: '/post-detail',
    params: {'postId': int_},
    state: {'post': post, 'comments': listOf(comment), 'author': user},
    onLoad: [
      // First API call — fetch the post.
      ApiCall(
        getPost,
        outputAs: 'postResult',
        params: {'id': PageParam('postId')},
        onSuccess: (res) => [SetState('post', res)],
        onFailure: [Snackbar('Failed to load post')],
      ),
      // Second API call — fetch comments for the same post.
      ApiCall(
        getComments,
        outputAs: 'commentsResult',
        params: {'postId': PageParam('postId')},
        onSuccess: (res) => [SetState('comments', res)],
        onFailure: [Snackbar('Failed to load comments')],
      ),
    ],
    body: Scaffold(
      appBar: AppBar(title: 'Post Details'),
      body: Container(
        padding: 16,
        child: Column(
          scrollable: true,
          crossAxis: CrossAxis.start,
          spacing: 16,
          children: [
            Text(State('post')['title'], style: Styles.headlineSmall),
            Text(State('post')['body'], style: Styles.bodyLarge),
            Divider(),

            // Lazy fetch: load author on button tap.
            Button(
              'Load Author',
              onTap: ApiCall(
                getUser,
                outputAs: 'authorResult',
                params: {'id': State('post')['userId']},
                onSuccess: (res) => [SetState('author', res)],
                onFailure: [Snackbar('Failed to load author')],
              ),
            ),
            Text(State('author')['name'], style: Styles.titleMedium),

            Divider(),
            Text('Comments', style: Styles.titleMedium),
            ListView(
              source: State('comments'),
              spacing: 8,
              shrinkWrap: true,
              itemBuilder:
                  (item) => Container(
                    padding: 12,
                    borderRadius: 8,
                    color: Colors.secondaryBackground,
                    child: Column(
                      crossAxis: CrossAxis.start,
                      spacing: 4,
                      children: [
                        Text(item['name'], style: Styles.labelMedium),
                        Text(item['body'], style: Styles.bodySmall),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      ),
    ),
  );
}

// -- CLI boilerplate --
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
  var findOrCreate = false;
  var dryRun = false;
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
