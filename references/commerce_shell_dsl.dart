library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  await flutterFlowAI(
    buildCommerceShell,
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
Run the CommerceShell DSL and push the compiled project to FlutterFlow.

Usage:
  dart run specs/dsl/commerce_shell_dsl.dart [options]

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

App buildCommerceShell(App app) {
  final home = app.page(
    'StoreHomePage',
    route: '/home',
    body: Scaffold(
      appBar: AppBar(title: 'Store Home'),
      drawer: Drawer(
        child: Column(
          crossAxis: CrossAxis.stretch,
          spacing: 12,
          children: [
            ListTile(title: 'Orders', leadingIcon: 'receipt_long'),
            Button('Close Drawer', onTap: const DrawerControl.close()),
          ],
        ),
      ),
      body: Column(
        crossAxis: CrossAxis.stretch,
        spacing: 16,
        children: [
          Badge(
            content: 3,
            child: Button('Open Cart', onTap: Snackbar('Cart opened')),
          ),
          Button('Open Drawer', onTap: const DrawerControl.open()),
          Button('Open End Drawer', onTap: const DrawerControl.openEnd()),
        ],
      ),
    ),
    isInitial: true,
  );

  final catalog = app.page(
    'CatalogPage',
    route: '/catalog',
    state: {'shareUrl': string},
    body: Scaffold(
      appBar: AppBar(title: 'Catalog'),
      body: Column(
        crossAxis: CrossAxis.stretch,
        spacing: 16,
        children: [
          TabBar(
            name: 'CatalogTabs',
            style: TabBarStyle.button,
            tabs: [
              TabItem(
                'Featured',
                Column(
                  spacing: 12,
                  children: [
                    Carousel(
                      name: 'HeroCarousel',
                      children: [
                        Card(child: Text('Drop 01')),
                        Card(child: Text('Drop 02')),
                      ],
                    ),
                    Button(
                      'Next Hero',
                      onTap: const CarouselControl.next('HeroCarousel'),
                    ),
                  ],
                ),
              ),
              TabItem(
                'Deals',
                Column(
                  spacing: 12,
                  children: [
                    PageView(
                      name: 'DealsPager',
                      children: [
                        Card(child: Text('Deal A')),
                        Card(child: Text('Deal B')),
                      ],
                    ),
                    Button(
                      'Jump Deal',
                      onTap: const PageViewControl.jumpTo('DealsPager', 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Button(
            'Go To Deals Tab',
            onTap: const TabBarControl.jumpTo('CatalogTabs', 1),
          ),
          Button('Share Product', onTap: Share(State('shareUrl'))),
          Button(
            'Upload Receipt',
            onTap: const UploadData(
              source: UploadSource.files,
              allowPhoto: false,
              allowFile: true,
              destination: UploadDestination.localFile,
              actionName: 'receiptUpload',
            ),
          ),
          Button(
            'Clear Receipt',
            onTap: const ClearUploadedData('receiptUpload'),
          ),
          Button(
            'Download Spec',
            onTap: DownloadFile(
              'https://example.com/spec.pdf',
              filename: 'spec.pdf',
            ),
          ),
        ],
      ),
    ),
  );

  final profile = app.page(
    'ProfilePage',
    route: '/profile',
    body: Scaffold(
      appBar: AppBar(title: 'Profile'),
      body: Column(
        spacing: 16,
        children: [
          Avatar(text: 'AS', size: 56),
          ListTile(
            title: 'Saved Items',
            subtitle: 'Review your wishlist',
            leadingIcon: 'favorite',
            trailingIcon: 'chevron_right',
          ),
        ],
      ),
    ),
  );

  app.bottomNav(
    items: [
      BottomNavItem(home, icon: 'home'),
      BottomNavItem(catalog, icon: 'storefront'),
      BottomNavItem(profile, icon: 'person'),
    ],
    style: BottomNavStyle.floating,
    backgroundColor: Colors.secondaryBackground,
    selectedColor: Colors.primary,
    unselectedColor: Colors.secondaryText,
  );

  return app;
}
