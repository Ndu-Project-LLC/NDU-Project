/// Architecture Basis — module naming and explanation.
///
/// Product rule (Lusaka 25 (copy) voice note, 2026-09-17): on the Architecture
/// Basis page the owner could not tell what he was looking at —
/// **"model 1, 2, 3 … it is not intelligible"** — and asked for a **"pop-out
/// table"** so the rows could be read together.
///
/// The rows are architecture *modules*, not "models", and they were labelled
/// with a bare ordinal. A row the user had named "Payments service" still
/// displayed as "Module 2", so the label actively hid the one thing that would
/// have made it readable. The number is kept — it is a useful position cue —
/// but the name now leads when there is one.
library;

import 'package:ndu_project/utils/design_planning_document.dart';

/// Plain-language explanation of what this section is asking for.
///
/// Shown above the rows so the numbered cards have a meaning before they are
/// read.
const String architectureModuleExplainer =
    'A module is one separable part of the solution you are designing — the '
    'payments service, the reporting layer, the mobile client. Give each one a '
    'name and a purpose, and say who owns it. The numbers are just their order '
    'in this list, not a ranking.';

/// Label for one architecture module row.
///
/// Returns `"Module 2 — Payments service"` when the row has a name, and
/// `"Module 2 (unnamed)"` when it does not — so a user can see at a glance which
/// rows still need naming instead of reading a wall of ordinals.
String architectureModuleLabel(DesignPlanningWorkItem? item, int index) {
  final position = index + 1;
  final name = item?.name.trim() ?? '';
  if (name.isEmpty) return 'Module $position (unnamed)';
  return 'Module $position — $name';
}

/// Whether a module row still needs a name.
bool architectureModuleNeedsName(DesignPlanningWorkItem? item) =>
    (item?.name.trim() ?? '').isEmpty;
