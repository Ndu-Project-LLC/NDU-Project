/// Edit reference: Add form submission + detail navigation to a list app.
///
/// Demonstrates:
/// - app.editPageState() — add form state fields
/// - page.ensureInsertedAfter() — add form section after existing content
/// - page.ensureActions() with Navigate — wire navigation from list items
/// - app.ensureAppBarActions() — add icon buttons to the app bar
/// - page.bindText() — bind widget text to state/params
/// - EditPatternTarget selectors
/// - Adding a new create page alongside edit edits
///
/// Assumes a base project with a page called 'TasksPage' that has:
/// - A ListView named 'TaskList' showing tasks from app state
/// - A Button named 'AddButton'
library;

import 'package:flutterflow_ai/flutterflow_ai.dart';

// ---------------------------------------------------------------------------
// Base project
// ---------------------------------------------------------------------------

void buildBaseProject(App app) {
  final task = app.struct('Task', {
    'title': string,
    'description': string,
    'done': bool_,
  });

  app.state('tasks', listOf(task), persisted: true);

  app.page(
    'TasksPage',
    route: '/',
    isInitial: true,
    state: {'newTaskTitle': string},
    body: Scaffold(
      appBar: AppBar(title: 'Tasks'),
      body: Column(
        padding: 16,
        spacing: 12,
        children: [
          Expanded(
            ListView(
              source: AppState('tasks'),
              spacing: 8,
              name: 'TaskList',
              itemBuilder:
                  (item) => Container(
                    padding: 16,
                    color: Colors.secondaryBackground,
                    borderRadius: 8,
                    name: 'TaskItem',
                    child: Text(item['title'], style: Styles.bodyLarge),
                  ),
            ),
          ),
          Button(
            'Add Task',
            icon: 'add',
            width: double.infinity,
            name: 'AddButton',
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Edit flow — adds form, detail page, and navigation
// ---------------------------------------------------------------------------

// In edit, structs are already defined in the base project.
// Re-declare the handle so it can be used in Struct() constructors.
final _task = StructHandle('Task', {
  'title': string,
  'description': string,
  'done': bool_,
});

void applyFormAndDetailPatch(App app) {
  // -- Add form state to the existing page --
  app.editPageState('TasksPage', (state) {
    state.ensureField('formTitle', string.withDefault(''));
    state.ensureField('formDescription', string.withDefault(''));
    state.ensureField('showForm', bool_.withDefault(false));
  });

  // -- Wire the existing Add button to toggle form visibility --
  app.editPage('TasksPage', (page) {
    page.ensureActions(
      page.findByName('AddButton'),
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [SetState.toggle('showForm')],
    );

    // KEY PATTERN: ensureInsertedBefore adds the form above the button.
    page.ensureInsertedBefore(
      page.findByName('AddButton'),
      Container(
        name: 'NewTaskForm',
        borderColor: Colors.primary,
        borderWidth: 1,
        borderRadius: 12,
        padding: 16,
        visible: State('showForm'),
        child: Column(
          spacing: 12,
          children: [
            Text('New Task', style: Styles.titleMedium),
            TextField(
              label: 'Title',
              name: 'formTitleField',
              onChanged: SetState('formTitle', TextValue()),
            ),
            TextField(
              label: 'Description',
              name: 'formDescField',
              maxLines: 3,
              onChanged: SetState('formDescription', TextValue()),
            ),
            Row(
              spacing: 8,
              mainAxis: MainAxis.end,
              children: [
                Button(
                  'Cancel',
                  variant: ButtonVariant.outlined,
                  name: 'CancelFormButton',
                ),
                Button(
                  'Save',
                  color: Colors.primary,
                  textColor: Colors.primaryBackground,
                  name: 'SaveFormButton',
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // Wire cancel and save buttons
    page.ensureActions(
      page.findByName('CancelFormButton'),
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [
        SetState('showForm', false),
        ClearTextField('formTitleField'),
        ClearTextField('formDescField'),
      ],
    );

    page.ensureActions(
      page.findByName('SaveFormButton'),
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [
        UpdateAppState.addToList(
          'tasks',
          Struct(_task, {
            'title': WidgetState('formTitleField', WidgetStateProperty.text),
            'description': WidgetState(
              'formDescField',
              WidgetStateProperty.text,
            ),
            'done': false,
          }),
        ),
        SetState('showForm', false),
        ClearTextField('formTitleField'),
        ClearTextField('formDescField'),
        Snackbar('Task added'),
      ],
    );

    // KEY PATTERN: ensureActions with Navigate wires list item taps to a detail page.
    page.ensureActions(
      page.findByName('TaskItem'),
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [Navigate('TaskDetailPage')],
    );
  });

  // KEY PATTERN: ensureAppBarActions adds action buttons to the app bar.
  app.ensureAppBarActions(
    page: 'TasksPage',
    actions: [IconButton('search', name: 'AppBarSearch', size: 24)],
  );

  // -- Add a detail page (create addition alongside edit edits) --
  // You CAN mix create pages with edit flows in the same script.
  app.page(
    'TaskDetailPage',
    route: '/task-detail',
    state: {'selectedIndex': int_},
    body: Scaffold(
      appBar: AppBar(title: 'Task Detail'),
      body: Column(
        padding: 20,
        crossAxis: CrossAxis.start,
        spacing: 16,
        children: [
          Text('Task title goes here', style: Styles.headlineSmall),
          Text(
            'Task description goes here',
            style: Styles.bodyLarge,
            color: Colors.secondaryText,
          ),
          Button(
            'Back to List',
            variant: ButtonVariant.outlined,
            icon: 'arrow_back',
            width: double.infinity,
            onTap: NavigateBack(),
          ),
        ],
      ),
    ),
  );
}
