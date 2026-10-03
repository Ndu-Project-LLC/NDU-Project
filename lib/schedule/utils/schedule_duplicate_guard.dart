/// One rule for "are these two schedule rows the same item?", shared by the
/// Schedule provider (which persists the tree) and the Schedule views (which
/// render it).
///
/// The Schedule list showed "Platform Foundation Engineering Work Package" twice
/// because an import run re-generated chains under fresh ids, so id-based
/// filters never caught the copy. Names are therefore the primary signal — but
/// a name alone is not proof: two activities linked to *different* WBS nodes,
/// stories or sprints are two real pieces of work that merely read alike, and
/// collapsing them would delete the user's schedule.
///
/// The rule:
/// - same name, and the external link is missing on either side → the same item
///   (the copy an import produced),
/// - same name, same external link → the same item,
/// - same name, different external links → different items, both kept.
library;

import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/utils/item_name_key.dart';

/// The external record a schedule activity stands for, e.g. `wbs:n42`.
///
/// Null when the activity was hand-written or carries no link at all, in which
/// case only its name can decide whether it is a copy.
String? scheduleItemIdentity(
  ScheduleActivity activity, {
  String? wbsNodeId,
  String? agileTaskId,
  String? sprintId,
  String? releaseId,
}) {
  final links = <String, String?>{
    'wbs': wbsNodeId ?? activity.wbsNodeId,
    'agile': agileTaskId ?? activity.agileTaskId,
    'sprint': sprintId ?? activity.sprintId,
    'release': releaseId ?? activity.releaseId,
  };
  for (final entry in links.entries) {
    final value = (entry.value ?? '').trim();
    if (value.isNotEmpty) return '${entry.key}:$value';
  }
  return null;
}

/// Whether a row named [name]/[identity] is a copy of [otherName]/[otherIdentity].
bool isDuplicateScheduleItem({
  required String name,
  required String? identity,
  required String otherName,
  required String? otherIdentity,
}) {
  if (!isSameItemName(name, otherName)) return false;
  if (identity == null || otherIdentity == null) return true;
  return identity == otherIdentity;
}

/// [items] with copies of the same item collapsed to the first.
///
/// Blank names are always kept — they carry nothing to compare.
List<T> dedupeScheduleItems<T>(
  Iterable<T> items, {
  required String Function(T) nameOf,
  required String? Function(T) identityOf,
}) {
  // Per name, the links already kept. A name that has been seen unlinked
  // matches everything else with that name (nothing proved they differ); a name
  // whose rows all carry links matches only the same link.
  final linksByKey = <String, Set<String>>{};
  final unlinkedKeys = <String>{};
  final out = <T>[];
  for (final item in items) {
    final key = itemNameKey(nameOf(item));
    if (key.isEmpty) {
      out.add(item);
      continue;
    }
    final identity = identityOf(item);
    final links = linksByKey.putIfAbsent(key, () => <String>{});
    if (identity == null) {
      if (links.isNotEmpty || unlinkedKeys.contains(key)) continue;
      unlinkedKeys.add(key);
      out.add(item);
      continue;
    }
    if (unlinkedKeys.contains(key) || !links.add(identity)) continue;
    out.add(item);
  }
  return out;
}