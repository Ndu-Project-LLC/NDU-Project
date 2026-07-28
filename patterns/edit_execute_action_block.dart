import 'package:flutterflow_ai/flutterflow_ai.dart';

void buildExecuteExistingActionBlockPattern(App app) {
  app.editPage('StarterPage', (page) {
    page.ensureActions(
      EditPatternTarget.singleExistingButton().toSelection(page),
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [
        ExecuteActionBlock(
          ActionBlock.named(
            'addToFavorites',
            scope: ActionBlockLookupScope.app,
          ),
          params: {'itemId': 'starter'},
          outputAs: 'favoritedId',
          shouldSetState: true,
        ),
        Snackbar('Triggered shared action block'),
      ],
    );
  });
}
