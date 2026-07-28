import 'package:flutterflow_ai/flutterflow_ai.dart';

void buildAddTriggerPattern(App app) {
  app.editPage('TaskListPage', (page) {
    page.ensureActions(
      page.findByType('Button'),
      triggerType: FFActionTriggerType.ON_LONG_PRESS,
      actions: [Snackbar('Long press detected')],
    );
  });
}
