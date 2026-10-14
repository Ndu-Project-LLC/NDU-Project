library;

/// Helpers for persisting a module's state **per project** instead of under a
/// single global key.
///
/// The Planning Phase modules (Cost Estimate, Schedule) used to write their
/// whole state to one global SharedPreferences entry. Every project in the
/// workspace then read back whichever project was edited last, so opening a
/// different project showed that other project's cost lines, activities,
/// baseline and reviewers. These helpers give that state a per-project key and
/// define exactly when a record written before scoping may be adopted — once,
/// by the project it actually belongs to.

/// Project id used by pre-scoping records, and by an app that has no project
/// loaded yet.
const String unattributedProjectId = 'default';

/// SharedPreferences key for [logicalName] scoped to [projectId].
///
/// `projectScopedPrefsKey('ndu_cost_estimate_v2', 'abc')` →
/// `ndu_cost_estimate_v2_project_abc`. An empty [projectId] maps to the
/// [unattributedProjectId] scope.
String projectScopedPrefsKey(String logicalName, String projectId) {
  final pid = projectId.trim();
  return '${logicalName}_project_${pid.isEmpty ? unattributedProjectId : pid}';
}

/// Whether the record stored under a legacy global key may be adopted by the
/// project identified by [projectId] / [projectName].
///
/// A legacy record belongs to the project it recorded itself
/// ([legacyProjectId] == [projectId]), or — for records written before project
/// ids were persisted, which all carry `'default'` — the project whose name it
/// was created with ([legacyProjectName] == [projectName]).
///
/// Everything else returns `false`: the caller must start empty for
/// [projectId] and leave the legacy record untouched, so a record can never be
/// shown inside a project it does not belong to. Adoption is one-way — the
/// caller moves the record onto the project's own key and clears the legacy
/// entry, so only one project can ever claim it.
bool legacyRecordBelongsToProject({
  required String projectId,
  String? projectName,
  required String? legacyProjectId,
  required String? legacyProjectName,
}) {
  final pid = projectId.trim();
  // No active project: there is nothing to attribute the record to, so it may
  // not be adopted (and must not be shown as if it were this project's).
  if (pid.isEmpty || pid == unattributedProjectId) return false;

  final recordedId = (legacyProjectId ?? '').trim();
  if (recordedId.isNotEmpty && recordedId == pid) return true;

  // A record that names a *different* concrete project is never ours.
  if (recordedId.isNotEmpty && recordedId != unattributedProjectId) {
    return false;
  }

  // Pre-scoping writers stored no useful project id (or `'default'`), so the
  // project name they captured is the only surviving signal. Require both
  // names to be present so an unattributable record is never claimed.
  final recordedName = (legacyProjectName ?? '').trim().toLowerCase();
  final activeName = (projectName ?? '').trim().toLowerCase();
  if (recordedName.isEmpty || activeName.isEmpty) return false;
  return recordedName == activeName;
}
