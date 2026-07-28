import 'package:ndu_project/models/project_data_model.dart' as data_model;
import 'package:ndu_project/schedule/models/schedule_models.dart';

class ScheduleActivityConverter {
  ScheduleActivityConverter._();

  static ScheduleActivity fromDataModel(
      data_model.ScheduleActivity dm,
      {List<ScheduleActivity> children = const []}) {
    ActivityType type;
    if (dm.isMilestone) {
      type = ActivityType.milestone;
    } else {
      switch (dm.workPackageType) {
        case 'design':
          type = ActivityType.ewp;
          break;
        case 'procurement':
          type = ActivityType.procurementPackage;
          break;
        case 'construction':
          type = ActivityType.cwp;
          break;
        default:
          type = ActivityType.activity;
      }
    }
    ScheduleDomain domain;
    switch (dm.phase) {
      case 'design':
        domain = ScheduleDomain.engineering;
        break;
      case 'execution':
        domain = ScheduleDomain.execution;
        break;
      case 'launch':
        domain = ScheduleDomain.commissioning;
        break;
      default:
        domain = ScheduleDomain.execution;
    }
    final deps = <ActivityDependency>[
      ...dm.predecessorIds.map((id) => ActivityDependency(
            activityId: id,
            type: DependencyType.finishToStart,
          )),
      ...dm.dependencyIds.map((id) => ActivityDependency(
            activityId: id,
            type: DependencyType.finishToStart,
          )),
    ];

    return ScheduleActivity(
      id: dm.id,
      wbsNodeId: dm.wbsId.isNotEmpty ? dm.wbsId : null,
      costLineId: dm.controlAccountId.isNotEmpty ? dm.controlAccountId : null,
      level: 0,
      code: '',
      name: dm.title,
      description: dm.milestone.isNotEmpty ? dm.milestone : null,
      type: type,
      domain: domain,
      duration: dm.durationDays.toDouble(),
      durationUnit: 'day',
      startDate: dm.startDate.isNotEmpty ? DateTime.tryParse(dm.startDate) : null,
      endDate: dm.dueDate.isNotEmpty ? DateTime.tryParse(dm.dueDate) : null,
      dependencies: deps,
      owner: dm.assignee.isNotEmpty ? dm.assignee : null,
      status: dm.status,
      progress: dm.progress,
      isCriticalPath: dm.isCriticalPath,
      aiGenerated: false,
      children: children,
    );
  }

  static data_model.ScheduleActivity toDataModel(
      ScheduleActivity node) {
    final result = data_model.ScheduleActivity(
      id: node.id,
      wbsId: node.wbsNodeId ?? '',
      title: node.name,
      durationDays: (node.duration ?? 5).round(),
      predecessorIds: node.dependencies
          .map((d) => d.activityId)
          .toList(),
      isMilestone: node.type == ActivityType.milestone,
      status: node.status ?? 'pending',
      assignee: node.owner ?? '',
      progress: node.progress ?? 0,
      startDate: node.startDate?.toIso8601String() ?? '',
      dueDate: node.endDate?.toIso8601String() ?? '',
      isCriticalPath: node.isCriticalPath,
      percentComplete: node.progress ?? 0,
    );
    switch (node.type) {
      case ActivityType.ewp:
        result.workPackageType = 'design';
        break;
      case ActivityType.procurementPackage:
        result.workPackageType = 'procurement';
        break;
      case ActivityType.cwp:
        result.workPackageType = 'construction';
        break;
      case ActivityType.milestone:
        result.milestone = node.name;
        break;
      default:
        result.workPackageType = 'execution';
    }
    switch (node.domain) {
      case ScheduleDomain.engineering:
        result.phase = 'design';
        break;
      case ScheduleDomain.commissioning:
        result.phase = 'launch';
        break;
      default:
        result.phase = 'execution';
    }
    return result;
  }
}
