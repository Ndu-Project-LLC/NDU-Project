import 'package:flutterflow_ai/flutterflow_ai.dart';

/// Tiny edit pattern for using an existing app event by name.
void buildTriggerExistingEventPattern(
  App app, {
  required StructHandle selectionData,
}) {
  app.editPage('StarterPage', (page) {
    page.ensureActions(
      EditPatternTarget.singleExistingButton().toSelection(page),
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [
        AddLocalEventHandler(
          AppEvent.named('PreviewRequested'),
          actionBlock: ActionBlock.named(
            'handlePreviewRequest',
            scope: ActionBlockLookupScope.app,
          ),
        ),
        TriggerEvent(
          AppEvent.named('FavoriteSelected'),
          data: Struct(selectionData, {
            'itemId': 'alpha',
            'source': 'edit_flow',
          }),
          waitForCompletion: true,
        ),
        CancelLocalEventHandler(AppEvent.named('PreviewRequested')),
      ],
    );
  });
}
