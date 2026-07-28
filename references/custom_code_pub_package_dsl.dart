/// Pairing pub.dev packages with custom actions and custom widgets.
///
/// Shows the end-to-end flow an agent runs when a feature needs a third-party
/// Dart package:
///   1. Decide on the package and version (pub.dev discovery is the agent's
///      job — the SDK only records the resolution).
///   2. Declare the dependency with `app.pubDependency(...)`.
///   3. Author a custom action or custom widget whose code imports the
///      package.
///   4. The validators in Phase 1 catch format / identifier / shape issues
///      before push; runtime errors surface after codegen regenerates.
///
/// Two pub packages are used here on purpose:
///   * `http` — consumed by a custom action (network call).
///   * `intl` — consumed by a custom widget (currency formatting).
library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  await flutterFlowAI(
    buildPubPackageShowcase,
    apiKey: options.apiKey,
    baseUrl: options.baseUrl,
    projectName: options.projectName,
    projectId: options.projectId,
    findOrCreate: options.findOrCreate,
    dryRun: options.dryRun,
    commitMessage: options.commitMessage,
  );
}

void buildPubPackageShowcase(App app) {
  // ---------- pub dependencies ----------
  //
  // Declare both deps up front so the pairing with the consumer code below
  // is obvious. Versions chosen to match what FlutterFlow projects typically
  // pin — override elsewhere if your target project has stricter bounds.
  app.pubDependency('http', '^1.2.0');
  app.pubDependency('intl', '^0.19.0');

  // ---------- app state the page binds to ----------
  app.state('latestAmountUsd', double_.withDefault(1234.56));
  app.state('latestLabel', string.withDefault('Fetching...'));

  // ---------- custom action that consumes `http` ----------
  //
  // FlutterFlow-style custom actions ship as a full function definition
  // inside `code`. The codegen pipeline wires the generated signature to
  // the runtime based on the declared `args` and `returns`; the body here
  // just has to compile.
  app.customAction(
    'FetchQuoteLabel',
    args: {'endpoint': string},
    returns: string,
    code: r'''
import 'package:http/http.dart' as http;

Future<String> fetchQuoteLabel(String endpoint) async {
  final response = await http.get(Uri.parse(endpoint));
  if (response.statusCode != 200) {
    return 'Unavailable';
  }
  return response.body.trim();
}
''',
    description: 'Fetches a plain-text label from the supplied endpoint.',
  );

  // ---------- custom widget that consumes `intl` ----------
  //
  // Custom widgets ship as a full Dart compilation unit: imports plus the
  // widget class. The parameters map declares each of the class's typed
  // constructor arguments to FlutterFlow so they show up in the widget's
  // properties panel after codegen.
  app.customWidget(
    'FormattedMoney',
    parameters: {'amount': double_, 'currencyCode': string, 'locale': string},
    code: r'''
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FormattedMoney extends StatelessWidget {
  const FormattedMoney({
    super.key,
    required this.amount,
    required this.currencyCode,
    required this.locale,
  });

  final double amount;
  final String currencyCode;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.simpleCurrency(
      locale: locale,
      name: currencyCode,
    );
    return Text(
      formatter.format(amount),
      style: Theme.of(context).textTheme.headlineMedium,
    );
  }
}
''',
    description: 'Formats a numeric amount as a locale-aware currency.',
  );

  // ---------- page that ties both together ----------
  //
  // The page doesn't need to actually invoke the custom action or embed the
  // custom widget to demonstrate the pattern — codegen places both into the
  // generated project regardless. In a real app, you'd reference the
  // widget via `CustomWidget('FormattedMoney', ...)` inside the page body
  // and trigger the action from a button's `onTap`.
  app.page(
    'RatesPage',
    route: '/',
    isInitial: true,
    body: Scaffold(
      appBar: AppBar(title: 'Rates'),
      body: Container(
        padding: 16,
        child: Column(
          children: [
            Text(AppState('latestLabel'), name: 'LabelText'),
            // Placeholder for where the custom widget would be mounted. The
            // real invocation is `CustomWidget('FormattedMoney', params: ...)`
            // once you're passing the state-bound amount and a locale.
            Text(AppState('latestAmountUsd'), name: 'AmountText'),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// CLI plumbing — identical to the other references in this directory.
// ---------------------------------------------------------------------------

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
    switch (args[i]) {
      case '--api-key':
        apiKey = args[++i];
      case '--base-url':
        baseUrl = args[++i];
      case '--project-name':
        projectName = args[++i];
      case '--project-id':
        projectId = args[++i];
      case '--find-or-create':
        findOrCreate = true;
      case '--dry-run':
        dryRun = true;
      case '--commit-message':
        commitMessage = args[++i];
      case '--help' || '-h':
        stdout.writeln(
          'Usage: dart run references/custom_code_pub_package_dsl.dart '
          '[--api-key KEY] [--base-url URL] [--project-name NAME] '
          '[--project-id ID] [--find-or-create] [--dry-run] '
          '[--commit-message MSG]',
        );
        exit(0);
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
