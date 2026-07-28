import 'package:flutterflow_ai/flutterflow_ai.dart';

void buildBindButtonVisibilityPattern(App app) {
  app.editPageState('TaskListPage', (state) {
    state.ensureField('showPrimaryButton', bool_.withDefault(true));
  });

  app.editPage('TaskListPage', (page) {
    page.bindVisible(page.findByType('Button'), State('showPrimaryButton'));
  });
}
