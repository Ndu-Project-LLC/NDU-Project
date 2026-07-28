/// User-authored Dart classes + functions that reference them via `classRef`.
///
/// Demonstrates the pattern an agent uses to model domain objects with real
/// Dart code (methods, computed getters, constructors) and thread them
/// through custom function signatures — something FlutterFlow's built-in
/// data structs (`app.struct`) can't do because structs are schema-only.
///
/// The compile order is enforced by the Phase 3 compiler: classes compile
/// first, so later custom functions/actions/widgets can type-reference them
/// via `classRef(handle)` without forward-reference errors.
library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  await flutterFlowAI(
    buildCustomClassShowcase,
    apiKey: options.apiKey,
    baseUrl: options.baseUrl,
    projectName: options.projectName,
    projectId: options.projectId,
    findOrCreate: options.findOrCreate,
    dryRun: options.dryRun,
    commitMessage: options.commitMessage,
  );
}

void buildCustomClassShowcase(App app) {
  // ---------- custom enum ----------
  //
  // Custom enums carry real Dart source — unlike `app.enum_(...)` which is
  // schema-only. The handle returned here is usable as a parameter / return
  // type via `customEnumRef(...)`.
  final paymentStatus = app.customEnum(
    'PaymentStatus',
    code: r'''
enum PaymentStatus {
  pending,
  authorized,
  captured,
  refunded;

  bool get isFinal => this == captured || this == refunded;
}
''',
  );

  // ---------- custom classes ----------
  //
  // `LineItem` is a leaf DTO — no references to other user types.
  final lineItem = app.customClass(
    'LineItem',
    code: r'''
class LineItem {
  final String sku;
  final String label;
  final double unitPrice;
  final int quantity;

  const LineItem({
    required this.sku,
    required this.label,
    required this.unitPrice,
    required this.quantity,
  });

  double get subtotal => unitPrice * quantity;
}
''',
  );

  // `Invoice` is a composite that references `LineItem` AND `PaymentStatus`.
  // The handles are captured above so their Dart names are stable — if we
  // later rename, only the `customClass(...)` / `customEnum(...)` call
  // changes and the handle plumbing keeps working.
  app.customClass(
    'Invoice',
    code: r'''
class Invoice {
  final String id;
  final List<LineItem> items;
  final PaymentStatus status;

  const Invoice({
    required this.id,
    required this.items,
    required this.status,
  });

  double get total => items.fold(0.0, (sum, item) => sum + item.subtotal);
  int get itemCount => items.length;
}
''',
  );

  // ---------- custom functions that reference the types ----------
  //
  // `summarizeLineItem` takes a LineItem and returns a formatted summary.
  // Using `classRef(lineItem)` lets FlutterFlow surface the parameter as a
  // typed custom-class input in the properties panel.
  app.customFunction(
    'summarizeLineItem',
    args: {'item': classRef(lineItem)},
    returns: string,
    code: "return '\${item.label} x \${item.quantity} = \${item.subtotal}';",
    description: 'Formats a single LineItem as a one-line summary.',
  );

  // `statusLabel` takes the custom enum and returns a human-readable label.
  app.customFunction(
    'statusLabel',
    args: {'status': customEnumRef(paymentStatus)},
    returns: string,
    code: r'''
switch (status) {
  case PaymentStatus.pending:
    return 'Awaiting payment';
  case PaymentStatus.authorized:
    return 'Authorized';
  case PaymentStatus.captured:
    return 'Paid';
  case PaymentStatus.refunded:
    return 'Refunded';
}
''',
    description: 'Human-friendly label for a PaymentStatus value.',
  );

  // ---------- thin page that exercises the types ----------
  //
  // The page body stays minimal because the point of this reference is the
  // type-plumbing at the schema level. In a real app, you'd pull Invoice
  // instances from state or an API response and render them via a component.
  app.state('invoiceStatusLabel', string.withDefault('Awaiting payment'));

  app.page(
    'InvoiceSummaryPage',
    route: '/',
    isInitial: true,
    body: Scaffold(
      appBar: AppBar(title: 'Invoice'),
      body: Container(
        padding: 16,
        child: Column(
          crossAxis: CrossAxis.start,
          children: [
            Text('Status', name: 'StatusHeader'),
            Text(AppState('invoiceStatusLabel'), name: 'StatusLabel'),
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
          'Usage: dart run references/custom_code_classes_and_functions_dsl.dart '
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
