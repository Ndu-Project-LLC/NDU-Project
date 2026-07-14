library;

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';

List<WorkItem> wbsNodeToWorkItems(WBSNode node, {String parentId = ''}) {
  final items = <WorkItem>[];
  for (final child in node.children) {
    items.add(WorkItem(
      id: child.id,
      parentId: parentId,
      title: child.name,
      description: child.description ?? '',
      status: 'not_started',
      framework: '',
      wbsCode: child.code,
      children: wbsNodeToWorkItems(child, parentId: child.id),
    ));
  }
  return items;
}
