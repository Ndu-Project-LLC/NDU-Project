import 'package:flutterflow_ai/flutterflow_ai.dart';

void buildSingleExistingButtonPattern(App app) {
  app.editPageState('StarterPage', (state) {
    state.ensureField('ctaLabel', string.withDefault('Open Starter'));
    state.ensureField('showCta', bool_.withDefault(true));
  });

  app.ensureButtonBindings(
    page: 'StarterPage',
    button: EditPatternTarget.singleExistingButton(),
    text: State('ctaLabel'),
    visibleWhen: State('showCta'),
  );
}
