/// Local-state CRUD reference — patterns for list apps with persisted state.
///
/// Demonstrates:
/// - WidgetState text reading (avoids onChanged debounce)
/// - ClearTextField after submission
/// - item.index for per-item mutations inside ListView
/// - UpdateAppState.updateItemAtIndex for in-place list edits
/// - UpdateAppState.removeAtIndex for per-item deletion
/// - Reusable action sequences via Dart functions
/// - Struct-typed persisted app state
///
/// This is the canonical reference for todo lists, shopping lists, note apps,
/// and any app that manages a local list without a backend.
library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  await flutterFlowAI(
    buildLocalStateCrudApp,
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

// ---------------------------------------------------------------------------
// Reusable action sequences
// ---------------------------------------------------------------------------

/// Add a new item and clear the input field.
///
/// This is a Dart function that returns a List<DslAction> — a reusable action
/// sequence. Use the spread operator to inline it: `onTap: [...addItem()]`.
List<DslAction> addItem(StructHandle itemStruct) => [
  If(
    // KEY PATTERN: Read the text field value directly using WidgetState.
    // This avoids the onChanged debounce issue — WidgetState reads the
    // current controller value, not a delayed page-state copy.
    Not(Equals(WidgetState('itemInput', WidgetStateProperty.text), '')),
    then: [
      UpdateAppState.addToList(
        'items',
        Struct(itemStruct, {
          'title': WidgetState('itemInput', WidgetStateProperty.text),
          'done': false,
        }),
      ),
      // KEY PATTERN: ClearTextField resets the text controller by widget
      // name. Must match the `name:` parameter on the TextField widget.
      ClearTextField('itemInput'),
      Snackbar('Item added'),
    ],
  ),
];

void buildLocalStateCrudApp(App app) {
  // -- Data model --
  final item = app.struct('ChecklistItem', {'title': string, 'done': bool_});

  // -- Persisted app state --
  app.state('items', listOf(item), persisted: true);
  app.constant('appName', 'Checklist');

  // -- Single page --
  app.page(
    'ChecklistPage',
    route: '/',
    isInitial: true,
    body: Scaffold(
      appBar: AppBar(title: 'Checklist'),
      body: Container(
        padding: 16,
        child: Column(
          spacing: 12,
          children: [
            // ---------------------------------------------------------------
            // Input row — demonstrates WidgetState + ClearTextField
            // ---------------------------------------------------------------
            Row(
              spacing: 8,
              crossAxis: CrossAxis.center,
              children: [
                Flexible(
                  TextField(
                    // KEY PATTERN: Name the text field so other widgets can
                    // read its value via WidgetState('itemInput', .text).
                    name: 'itemInput',
                    hint: 'Add an item...',
                    // onSubmitted fires immediately (no debounce), and
                    // TextValue() is valid inside the callback.
                    onSubmitted: addItem(item),
                  ),
                  flex: 1,
                ),
                IconButton(
                  'add_circle',
                  size: 32,
                  color: Colors.primary,
                  // KEY PATTERN: The button reads the text field value using
                  // WidgetState — no page state intermediate needed. This
                  // avoids the codegen debounce on onChanged.
                  onTap: addItem(item),
                ),
              ],
            ),

            // ---------------------------------------------------------------
            // List — demonstrates item.index, updateItemAtIndex, removeAtIndex
            // ---------------------------------------------------------------
            Expanded(
              ListView(
                source: AppState('items'),
                spacing: 8,
                itemBuilder:
                    (listItem) => Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      color: Colors.secondaryBackground,
                      borderRadius: 12,
                      child: Row(
                        crossAxis: CrossAxis.center,
                        children: [
                          // Toggle completion — uses updateItemAtIndex + item.index
                          Checkbox(
                            value: listItem['done'],
                            onChanged: [
                              // KEY PATTERN: updateItemAtIndex replaces the item
                              // at the current index. item.index provides the
                              // zero-based position from the ListView builder.
                              UpdateAppState.updateItemAtIndex(
                                'items',
                                listItem.index,
                                Struct(item, {
                                  'title': listItem['title'],
                                  'done': Not(listItem['done']),
                                }),
                              ),
                            ],
                          ),
                          Expanded(
                            Text(listItem['title'], style: Styles.bodyLarge),
                          ),
                          // Delete — uses removeAtIndex + item.index
                          IconButton(
                            'close',
                            size: 20,
                            color: Colors.error,
                            onTap: [
                              // KEY PATTERN: removeAtIndex + item.index deletes
                              // the specific item the user tapped on.
                              UpdateAppState.removeAtIndex(
                                'items',
                                listItem.index,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
              ),
            ),

            // ---------------------------------------------------------------
            // Clear all — the only option without removeWhere
            // ---------------------------------------------------------------
            Button(
              'Clear all',
              variant: ButtonVariant.text,
              icon: 'delete_sweep',
              width: double.infinity,
              onTap: [
                // Note: ClearAppState clears the ENTIRE list. There is no
                // removeWhere primitive in the DSL yet. If you need "clear
                // completed", you would need a ForEach loop that builds a
                // filtered list — but that pattern is not yet supported for
                // state replacement. Label your button accurately.
                ClearAppState('items'),
                Snackbar('All items cleared'),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
