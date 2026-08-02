library;

import 'package:flutter/material.dart';

enum ProductType {
  system,
  subsystem,
  component,
  subcomponent,
  part;

  String get label => switch (this) {
        ProductType.system => 'System',
        ProductType.subsystem => 'Subsystem',
        ProductType.component => 'Component',
        ProductType.subcomponent => 'Subcomponent',
        ProductType.part => 'Part / Material',
      };

  IconData get icon => switch (this) {
        ProductType.system => Icons.precision_manufacturing,
        ProductType.subsystem => Icons.settings,
        ProductType.component => Icons.widgets,
        ProductType.subcomponent => Icons.cable,
        ProductType.part => Icons.inventory_2,
      };

  Color get color => switch (this) {
        ProductType.system => const Color(0xFF2563EB),
        ProductType.subsystem => const Color(0xFF059669),
        ProductType.component => const Color(0xFFD97706),
        ProductType.subcomponent => const Color(0xFF7C3AED),
        ProductType.part => const Color(0xFF6B7280),
      };
}

enum PBSStatus {
  planned,
  inProgress,
  fabricated,
  delivered,
  installed,
  complete;

  String get label => switch (this) {
        PBSStatus.planned => 'Planned',
        PBSStatus.inProgress => 'In Progress',
        PBSStatus.fabricated => 'Fabricated',
        PBSStatus.delivered => 'Delivered',
        PBSStatus.installed => 'Installed',
        PBSStatus.complete => 'Complete',
      };

  Color get color => switch (this) {
        PBSStatus.planned => const Color(0xFF9CA3AF),
        PBSStatus.inProgress => const Color(0xFF3B82F6),
        PBSStatus.fabricated => const Color(0xFF8B5CF6),
        PBSStatus.delivered => const Color(0xFFF59E0B),
        PBSStatus.installed => const Color(0xFF059669),
        PBSStatus.complete => const Color(0xFF10B981),
      };
}

class PBSNode {
  final String id;
  final String parentId;
  final List<PBSNode> children;
  final String code;
  final String name;
  final String description;
  final ProductType productType;
  final double quantity;
  final String unitOfMeasure;
  final List<String> specificationRefs;
  final List<String> linkedWBSNodeIds;
  final PBSStatus status;
  final String? plannedDeliveryDate;
  final double weight;

  const PBSNode({
    required this.id,
    this.parentId = '',
    this.children = const [],
    required this.code,
    required this.name,
    this.description = '',
    this.productType = ProductType.component,
    this.quantity = 1,
    this.unitOfMeasure = 'EA',
    this.specificationRefs = const [],
    this.linkedWBSNodeIds = const [],
    this.status = PBSStatus.planned,
    this.plannedDeliveryDate,
    this.weight = 1.0,
  });

  PBSNode copyWith({
    String? id,
    String? parentId,
    List<PBSNode>? children,
    String? code,
    String? name,
    String? description,
    ProductType? productType,
    double? quantity,
    String? unitOfMeasure,
    List<String>? specificationRefs,
    List<String>? linkedWBSNodeIds,
    PBSStatus? status,
    String? plannedDeliveryDate,
    double? weight,
  }) {
    return PBSNode(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      children: children ?? this.children,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      productType: productType ?? this.productType,
      quantity: quantity ?? this.quantity,
      unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
      specificationRefs: specificationRefs ?? this.specificationRefs,
      linkedWBSNodeIds: linkedWBSNodeIds ?? this.linkedWBSNodeIds,
      status: status ?? this.status,
      plannedDeliveryDate: plannedDeliveryDate ?? this.plannedDeliveryDate,
      weight: weight ?? this.weight,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'parentId': parentId,
        'children': children.map((c) => c.toJson()).toList(),
        'code': code,
        'name': name,
        'description': description,
        'productType': productType.name,
        'quantity': quantity,
        'unitOfMeasure': unitOfMeasure,
        'specificationRefs': specificationRefs,
        'linkedWBSNodeIds': linkedWBSNodeIds,
        'status': status.name,
        'plannedDeliveryDate': plannedDeliveryDate,
        'weight': weight,
      };

  factory PBSNode.fromJson(Map<String, dynamic> json) {
    return PBSNode(
      id: json['id'] as String,
      parentId: json['parentId'] as String? ?? '',
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => PBSNode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      productType: ProductType.values.firstWhere(
          (t) => t.name == json['productType'],
          orElse: () => ProductType.component),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unitOfMeasure: json['unitOfMeasure'] as String? ?? 'EA',
      specificationRefs: (json['specificationRefs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      linkedWBSNodeIds: (json['linkedWBSNodeIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: PBSStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => PBSStatus.planned),
      plannedDeliveryDate: json['plannedDeliveryDate'] as String?,
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class PBS {
  final String id;
  final String projectId;
  final String projectName;
  final PBSNode root;

  const PBS({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.root,
  });

  PBS copyWith({
    String? id,
    String? projectId,
    String? projectName,
    PBSNode? root,
  }) {
    return PBS(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      root: root ?? this.root,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'projectName': projectName,
        'root': root.toJson(),
      };

  factory PBS.fromJson(Map<String, dynamic> json) {
    return PBS(
      id: json['id'] as String,
      projectId: json['projectId'] as String? ?? 'default',
      projectName: json['projectName'] as String? ?? '',
      root: json['root'] != null
          ? PBSNode.fromJson(json['root'] as Map<String, dynamic>)
          : PBSNode(
              id: 'root',
              code: 'PBS.0',
              name: json['projectName'] as String? ?? 'Project'),
    );
  }

  static List<PBSNode> flatten(PBSNode node) {
    final result = <PBSNode>[node];
    for (final child in node.children) {
      result.addAll(flatten(child));
    }
    return result;
  }
}
