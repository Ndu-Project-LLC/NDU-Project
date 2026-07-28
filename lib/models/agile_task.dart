import 'package:ndu_project/services/kanban_config_service.dart';

/// Model for an agile task/user story in Agile Development Iterations page
class AgileTask {
  final String id;
  String userStory; // User Story/Task name
  String assignedRole; // Role from Staff Needs
  int storyPoints; // 1, 2, 3, 5, 8
  String priority; // Critical, High, Medium, Low
  String status; // To-Do, In-Progress, Testing, Done
  String taskDescription; // Prose description
  String acceptanceCriteria; // "." bullet format
  String iterationNotes; // Prose, no bullets, manual input only
  String epicId;
  String featureId;
  String wbsId; // WBS node ID for Level 3 traceability
  String plannedSprintId; // Planning-phase target sprint allocation
  String plannedReleaseId; // Planning-phase target release allocation
  String workflowState; // Cross-phase kanban / execution workflow state
  String readinessStatus; // Draft, Ready for Refinement, Ready for Sprint
  List<String> dependencyTaskIds; // Related story/task dependencies
  int backlogOrder; // Planning-phase ordering within feature backlog
  List<String> milestoneIds; // FEP milestone IDs linked to this task

  AgileTask({
    String? id,
    this.userStory = '',
    this.assignedRole = '',
    this.storyPoints = 1,
    this.priority = 'Medium',
    this.status = 'To Do',
    this.taskDescription = '',
    this.acceptanceCriteria = '',
    this.iterationNotes = '',
    this.epicId = '',
    this.featureId = '',
    this.wbsId = '',
    this.plannedSprintId = '',
    this.plannedReleaseId = '',
    this.workflowState = 'backlog',
    this.readinessStatus = 'Draft',
    List<String>? dependencyTaskIds,
    this.backlogOrder = 0,
    List<String>? milestoneIds,
  })  : dependencyTaskIds = dependencyTaskIds ?? [],
        milestoneIds = milestoneIds ?? [],
        id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  AgileTask copyWith({
    String? userStory,
    String? assignedRole,
    int? storyPoints,
    String? priority,
    String? status,
    String? taskDescription,
    String? acceptanceCriteria,
    String? iterationNotes,
    String? epicId,
    String? featureId,
    String? wbsId,
    String? plannedSprintId,
    String? plannedReleaseId,
    String? workflowState,
    String? readinessStatus,
    List<String>? dependencyTaskIds,
    int? backlogOrder,
    List<String>? milestoneIds,
  }) {
    return AgileTask(
      id: id,
      userStory: userStory ?? this.userStory,
      assignedRole: assignedRole ?? this.assignedRole,
      storyPoints: storyPoints ?? this.storyPoints,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      taskDescription: taskDescription ?? this.taskDescription,
      acceptanceCriteria: acceptanceCriteria ?? this.acceptanceCriteria,
      iterationNotes: iterationNotes ?? this.iterationNotes,
      epicId: epicId ?? this.epicId,
      featureId: featureId ?? this.featureId,
      wbsId: wbsId ?? this.wbsId,
      plannedSprintId: plannedSprintId ?? this.plannedSprintId,
      plannedReleaseId: plannedReleaseId ?? this.plannedReleaseId,
      workflowState: workflowState ?? this.workflowState,
      readinessStatus: readinessStatus ?? this.readinessStatus,
      dependencyTaskIds:
          dependencyTaskIds ?? List<String>.from(this.dependencyTaskIds),
      backlogOrder: backlogOrder ?? this.backlogOrder,
      milestoneIds: milestoneIds ?? List<String>.from(this.milestoneIds),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userStory': userStory,
        'assignedRole': assignedRole,
        'storyPoints': storyPoints,
        'priority': priority,
        'status': status,
        'taskDescription': taskDescription,
        'acceptanceCriteria': acceptanceCriteria,
        'iterationNotes': iterationNotes,
        'epicId': epicId,
        'featureId': featureId,
        if (wbsId.isNotEmpty) 'wbsId': wbsId,
        if (plannedSprintId.isNotEmpty) 'plannedSprintId': plannedSprintId,
        if (plannedReleaseId.isNotEmpty) 'plannedReleaseId': plannedReleaseId,
        'workflowState': workflowState,
        'readinessStatus': readinessStatus,
        'dependencyTaskIds': dependencyTaskIds,
        'milestoneIds': milestoneIds,
        'backlogOrder': backlogOrder,
      };

  factory AgileTask.fromJson(Map<String, dynamic> json) {
    int parseStoryPoints(dynamic v) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 1;
    }

    return AgileTask(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      userStory: json['userStory']?.toString() ?? '',
      assignedRole: json['assignedRole']?.toString() ?? '',
      storyPoints: parseStoryPoints(json['storyPoints']),
      priority: json['priority']?.toString() ?? 'Medium',
      status: KanbanConfigService.normalizeStatus(
          json['status']?.toString() ?? 'To Do'),
      taskDescription: json['taskDescription']?.toString() ?? '',
      acceptanceCriteria: json['acceptanceCriteria']?.toString() ?? '',
      iterationNotes: json['iterationNotes']?.toString() ?? '',
      epicId: json['epicId']?.toString() ?? '',
      featureId: json['featureId']?.toString() ?? '',
      wbsId: json['wbsId']?.toString() ?? '',
      plannedSprintId: json['plannedSprintId']?.toString() ?? '',
      plannedReleaseId: json['plannedReleaseId']?.toString() ?? '',
      workflowState: json['workflowState']?.toString() ?? 'backlog',
      readinessStatus: json['readinessStatus']?.toString() ?? 'Draft',
      dependencyTaskIds: (json['dependencyTaskIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      milestoneIds: (json['milestoneIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      backlogOrder: json['backlogOrder'] is num
          ? (json['backlogOrder'] as num).toInt()
          : int.tryParse(json['backlogOrder']?.toString() ?? '') ?? 0,
    );
  }
}
