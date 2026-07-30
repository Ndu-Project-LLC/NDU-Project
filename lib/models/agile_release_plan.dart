class AgileReleasePlan {
  AgileReleasePlan({
    String? id,
    this.releaseLabel = '',
    this.releaseDate,
    this.releaseGoal = '',
    this.scope = '',
    this.status = 'Draft',
    this.version = '',
    this.piNumber,
    this.trainName = '',
    this.epicIds = const [],
    this.featureIds = const [],
    this.storyIds = const [],
    this.cadenceType = '',
    this.sprintLengthDays,
    this.numberOfSprintsInRelease,
    this.releaseFrequency = '',
    this.definitionOfDone = '',
    this.qualityGates = '',
    this.testingRequirements = '',
    this.approvalRequirements = '',
    this.deploymentStrategy = '',
    this.deploymentEnvironments = '',
    this.featureFlagPlan = '',
    this.keyDependencies = '',
    this.assumptions = '',
    this.releaseRisks = '',
    this.rollbackPlan = '',
    this.recoveryProcedures = '',
    this.communicationPlan = '',
    this.trainingPlan = '',
    this.monitoringPlan = '',
    this.feedbackCollection = '',
    this.continuousImprovement = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  final String id;
  String releaseLabel;
  DateTime? releaseDate;
  String releaseGoal;
  String scope;
  String status;
  String version;
  int? piNumber;
  String trainName;
  List<String> epicIds;
  List<String> featureIds;
  List<String> storyIds;
  String cadenceType;
  int? sprintLengthDays;
  int? numberOfSprintsInRelease;
  String releaseFrequency;
  String definitionOfDone;
  String qualityGates;
  String testingRequirements;
  String approvalRequirements;
  String deploymentStrategy;
  String deploymentEnvironments;
  String featureFlagPlan;
  String keyDependencies;
  String assumptions;
  String releaseRisks;
  String rollbackPlan;
  String recoveryProcedures;
  String communicationPlan;
  String trainingPlan;
  String monitoringPlan;
  String feedbackCollection;
  String continuousImprovement;

  AgileReleasePlan copyWith({
    String? releaseLabel,
    DateTime? releaseDate,
    String? releaseGoal,
    String? scope,
    String? status,
    String? version,
    int? piNumber,
    String? trainName,
    List<String>? epicIds,
    List<String>? featureIds,
    List<String>? storyIds,
    String? cadenceType,
    int? sprintLengthDays,
    int? numberOfSprintsInRelease,
    String? releaseFrequency,
    String? definitionOfDone,
    String? qualityGates,
    String? testingRequirements,
    String? approvalRequirements,
    String? deploymentStrategy,
    String? deploymentEnvironments,
    String? featureFlagPlan,
    String? keyDependencies,
    String? assumptions,
    String? releaseRisks,
    String? rollbackPlan,
    String? recoveryProcedures,
    String? communicationPlan,
    String? trainingPlan,
    String? monitoringPlan,
    String? feedbackCollection,
    String? continuousImprovement,
  }) {
    return AgileReleasePlan(
      id: id,
      releaseLabel: releaseLabel ?? this.releaseLabel,
      releaseDate: releaseDate ?? this.releaseDate,
      releaseGoal: releaseGoal ?? this.releaseGoal,
      scope: scope ?? this.scope,
      status: status ?? this.status,
      version: version ?? this.version,
      piNumber: piNumber ?? this.piNumber,
      trainName: trainName ?? this.trainName,
      epicIds: epicIds ?? this.epicIds,
      featureIds: featureIds ?? this.featureIds,
      storyIds: storyIds ?? this.storyIds,
      cadenceType: cadenceType ?? this.cadenceType,
      sprintLengthDays: sprintLengthDays ?? this.sprintLengthDays,
      numberOfSprintsInRelease: numberOfSprintsInRelease ?? this.numberOfSprintsInRelease,
      releaseFrequency: releaseFrequency ?? this.releaseFrequency,
      definitionOfDone: definitionOfDone ?? this.definitionOfDone,
      qualityGates: qualityGates ?? this.qualityGates,
      testingRequirements: testingRequirements ?? this.testingRequirements,
      approvalRequirements: approvalRequirements ?? this.approvalRequirements,
      deploymentStrategy: deploymentStrategy ?? this.deploymentStrategy,
      deploymentEnvironments: deploymentEnvironments ?? this.deploymentEnvironments,
      featureFlagPlan: featureFlagPlan ?? this.featureFlagPlan,
      keyDependencies: keyDependencies ?? this.keyDependencies,
      assumptions: assumptions ?? this.assumptions,
      releaseRisks: releaseRisks ?? this.releaseRisks,
      rollbackPlan: rollbackPlan ?? this.rollbackPlan,
      recoveryProcedures: recoveryProcedures ?? this.recoveryProcedures,
      communicationPlan: communicationPlan ?? this.communicationPlan,
      trainingPlan: trainingPlan ?? this.trainingPlan,
      monitoringPlan: monitoringPlan ?? this.monitoringPlan,
      feedbackCollection: feedbackCollection ?? this.feedbackCollection,
      continuousImprovement: continuousImprovement ?? this.continuousImprovement,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'releaseLabel': releaseLabel,
        'releaseDate': releaseDate?.toIso8601String(),
        'releaseGoal': releaseGoal,
        'scope': scope,
        'status': status,
        'version': version,
        'piNumber': piNumber,
        'trainName': trainName,
        'epicIds': epicIds,
        'featureIds': featureIds,
        'storyIds': storyIds,
        'cadenceType': cadenceType,
        'sprintLengthDays': sprintLengthDays,
        'numberOfSprintsInRelease': numberOfSprintsInRelease,
        'releaseFrequency': releaseFrequency,
        'definitionOfDone': definitionOfDone,
        'qualityGates': qualityGates,
        'testingRequirements': testingRequirements,
        'approvalRequirements': approvalRequirements,
        'deploymentStrategy': deploymentStrategy,
        'deploymentEnvironments': deploymentEnvironments,
        'featureFlagPlan': featureFlagPlan,
        'keyDependencies': keyDependencies,
        'assumptions': assumptions,
        'releaseRisks': releaseRisks,
        'rollbackPlan': rollbackPlan,
        'recoveryProcedures': recoveryProcedures,
        'communicationPlan': communicationPlan,
        'trainingPlan': trainingPlan,
        'monitoringPlan': monitoringPlan,
        'feedbackCollection': feedbackCollection,
        'continuousImprovement': continuousImprovement,
      };

  factory AgileReleasePlan.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic raw) {
      final value = raw?.toString() ?? '';
      if (value.isEmpty) return null;
      return DateTime.tryParse(value);
    }

    int? parseInt(dynamic raw) {
      if (raw == null) return null;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw.toString());
    }

    return AgileReleasePlan(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      releaseLabel: json['releaseLabel']?.toString() ?? '',
      releaseDate: parseDate(json['releaseDate']),
      releaseGoal: json['releaseGoal']?.toString() ?? '',
      scope: json['scope']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Draft',
      version: json['version']?.toString() ?? '',
      piNumber: json['piNumber'] as int?,
      trainName: json['trainName']?.toString() ?? '',
      epicIds: (json['epicIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      featureIds: (json['featureIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      storyIds: (json['storyIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      cadenceType: json['cadenceType']?.toString() ?? '',
      sprintLengthDays: parseInt(json['sprintLengthDays']),
      numberOfSprintsInRelease: parseInt(json['numberOfSprintsInRelease']),
      releaseFrequency: json['releaseFrequency']?.toString() ?? '',
      definitionOfDone: json['definitionOfDone']?.toString() ?? '',
      qualityGates: json['qualityGates']?.toString() ?? '',
      testingRequirements: json['testingRequirements']?.toString() ?? '',
      approvalRequirements: json['approvalRequirements']?.toString() ?? '',
      deploymentStrategy: json['deploymentStrategy']?.toString() ?? '',
      deploymentEnvironments: json['deploymentEnvironments']?.toString() ?? '',
      featureFlagPlan: json['featureFlagPlan']?.toString() ?? '',
      keyDependencies: json['keyDependencies']?.toString() ?? '',
      assumptions: json['assumptions']?.toString() ?? '',
      releaseRisks: json['releaseRisks']?.toString() ?? '',
      rollbackPlan: json['rollbackPlan']?.toString() ?? '',
      recoveryProcedures: json['recoveryProcedures']?.toString() ?? '',
      communicationPlan: json['communicationPlan']?.toString() ?? '',
      trainingPlan: json['trainingPlan']?.toString() ?? '',
      monitoringPlan: json['monitoringPlan']?.toString() ?? '',
      feedbackCollection: json['feedbackCollection']?.toString() ?? '',
      continuousImprovement: json['continuousImprovement']?.toString() ?? '',
    );
  }
}
