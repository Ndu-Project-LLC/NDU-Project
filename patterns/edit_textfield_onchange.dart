import 'package:flutterflow_ai/flutterflow_ai.dart';

void buildTextFieldOnChangePattern(App app) {
  app.editPageState('TaskListPage', (state) {
    state.ensureField('liveSearchQuery', string.withDefault(''));
  });

  app.editPage('TaskListPage', (page) {
    page.ensureActions(
      page.findByType('TextField'),
      triggerType: FFActionTriggerType.ON_TEXTFIELD_CHANGE,
      actions: [SetState('liveSearchQuery', TextValue())],
    );
  });
}
