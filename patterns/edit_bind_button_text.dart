import 'package:flutterflow_ai/flutterflow_ai.dart';

void buildBindButtonTextPattern(App app) {
  app.editPageState('TaskListPage', (state) {
    state.ensureField('ctaLabel', string.withDefault('Reload'));
  });

  app.editPage('TaskListPage', (page) {
    page.bindText(
      EditPatternTarget.singleExistingButton().toSelection(page),
      State('ctaLabel'),
    );
  });
}
