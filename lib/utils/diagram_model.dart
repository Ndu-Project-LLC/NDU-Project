import 'package:flutter/material.dart';

/// Color palette for node types. Each type gets a distinct fill, border, and
/// icon so the diagram is immediately scannable without reading every label.
class DiagramNodeTypeStyle {
  final Color fill;
  final Color border;
  final Color text;
  final IconData icon;

  const DiagramNodeTypeStyle({
    required this.fill,
    required this.border,
    required this.text,
    required this.icon,
  });
}

// Static look-up used by _DiagramPainter and the tooltip overlay.
const Map<String, DiagramNodeTypeStyle> diagramNodeStyles = {
  'start': DiagramNodeTypeStyle(
    fill: Color(0xFFDCFCE7),
    border: Color(0xFF16A34A),
    text: Color(0xFF14532D),
    icon: Icons.play_arrow_rounded,
  ),
  'objective': DiagramNodeTypeStyle(
    fill: Color(0xFFDBEAFE),
    border: Color(0xFF2563EB),
    text: Color(0xFF1E3A5F),
    icon: Icons.flag_rounded,
  ),
  'analysis': DiagramNodeTypeStyle(
    fill: Color(0xFFE0E7FF),
    border: Color(0xFF6366F1),
    text: Color(0xFF312E81),
    icon: Icons.analytics_rounded,
  ),
  'decision': DiagramNodeTypeStyle(
    fill: Color(0xFFFEF3C7),
    border: Color(0xFFD97706),
    text: Color(0xFF78350F),
    icon: Icons.call_split_rounded,
  ),
  'action': DiagramNodeTypeStyle(
    fill: Color(0xFFE0F2FE),
    border: Color(0xFF0284C7),
    text: Color(0xFF0C4A6E),
    icon: Icons.arrow_forward_rounded,
  ),
  'validation': DiagramNodeTypeStyle(
    fill: Color(0xFFF3E8FF),
    border: Color(0xFF9333EA),
    text: Color(0xFF3B0764),
    icon: Icons.verified_rounded,
  ),
  'milestone': DiagramNodeTypeStyle(
    fill: Color(0xFFD1FAE5),
    border: Color(0xFF059669),
    text: Color(0xFF064E3B),
    icon: Icons.flag_rounded,
  ),
  'risk': DiagramNodeTypeStyle(
    fill: Color(0xFFFEE2E2),
    border: Color(0xFFDC2626),
    text: Color(0xFF7F1D1D),
    icon: Icons.warning_amber_rounded,
  ),
  'output': DiagramNodeTypeStyle(
    fill: Color(0xFFFCE7F3),
    border: Color(0xFFDB2777),
    text: Color(0xFF831843),
    icon: Icons.output_rounded,
  ),
  'end': DiagramNodeTypeStyle(
    fill: Color(0xFFF3F4F6),
    border: Color(0xFF6B7280),
    text: Color(0xFF1F2937),
    icon: Icons.stop_circle_rounded,
  ),
  'process': DiagramNodeTypeStyle(
    fill: Color(0xFFF9FAFB),
    border: Color(0xFF9CA3AF),
    text: Color(0xFF111827),
    icon: Icons.circle_rounded,
  ),
  'system': DiagramNodeTypeStyle(
    fill: Color(0xFFECFDF5),
    border: Color(0xFF34D399),
    text: Color(0xFF064E3B),
    icon: Icons.dns_rounded,
  ),
};

// Default / fallback style for unknown types.
const DiagramNodeTypeStyle _defaultStyle = DiagramNodeTypeStyle(
  fill: Color(0xFFF9FAFB),
  border: Color(0xFF9CA3AF),
  text: Color(0xFF111827),
  icon: Icons.circle_rounded,
);

DiagramNodeTypeStyle styleForType(String type) =>
    diagramNodeStyles[type] ?? _defaultStyle;

class DiagramNode {
  final String id;
  final String label;
  final String type; // e.g., start, process, decision, system, output, end
  const DiagramNode(
      {required this.id, required this.label, this.type = 'process'});
}

class DiagramEdge {
  final String from;
  final String to;
  final String label;
  const DiagramEdge({required this.from, required this.to, this.label = ''});
}

class DiagramModel {
  final List<DiagramNode> nodes;
  final List<DiagramEdge> edges;
  const DiagramModel({required this.nodes, required this.edges});

  /// Serialize to a JSON-safe map for Firestore persistence.
  Map<String, dynamic> toJson() => {
        'nodes': nodes
            .map((n) => {'id': n.id, 'label': n.label, 'type': n.type})
            .toList(),
        'edges': edges
            .map((e) => {'from': e.from, 'to': e.to, 'label': e.label})
            .toList(),
      };

  /// Hit-test: returns the [DiagramNode] at [scenePosition] (diagram-local
  /// coordinates after inverse-transforming through the viewer), or null.
  static DiagramNode? hitTest(DiagramModel model, Offset scenePosition) {
    final nodes = model.nodes;
    final edges = model.edges;
    if (nodes.isEmpty) return null;

    // ── Topological level assignment (mirrors _DiagramLayout.fromModel) ──
    final incoming = <String, int>{for (final n in nodes) n.id: 0};
    final outgoing = <String, List<DiagramEdge>>{
      for (final n in nodes) n.id: <DiagramEdge>[],
    };
    for (final e in edges) {
      if (incoming.containsKey(e.to)) {
        incoming[e.to] = (incoming[e.to] ?? 0) + 1;
      }
      outgoing[e.from]?.add(e);
    }
    final level = <String, int>{};
    final queue = <String>[
      ...incoming.entries.where((e) => e.value == 0).map((e) => e.key),
    ];
    for (int qi = 0; qi < queue.length; qi++) {
      final id = queue[qi];
      final currentLevel = level[id] ?? 0;
      for (final e in outgoing[id] ?? const <DiagramEdge>[]) {
        final next = e.to;
        if (!incoming.containsKey(next)) continue;
        final nextLevel = level[next] ?? 0;
        if (currentLevel + 1 > nextLevel) level[next] = currentLevel + 1;
        incoming[next] = (incoming[next] ?? 0) - 1;
        if (incoming[next] == 0) queue.add(next);
      }
    }

    // ── Compute node rectangles ──
    const double nodeW = 160;
    const double nodeH = 60;
    const double hGap = 60;
    const double vGap = 90;
    const double pad = 40;

    final groups = <int, List<DiagramNode>>{};
    for (final n in nodes) {
      final l = level[n.id] ?? 0;
      groups.putIfAbsent(l, () => []).add(n);
    }
    final levels = groups.keys.toList()..sort();
    double maxRowWidth = 0;
    final rowWidths = <int, double>{};
    for (var i = 0; i < levels.length; i++) {
      final row = groups[levels[i]]!;
      final rw = row.length * nodeW + (row.length - 1) * hGap;
      rowWidths[levels[i]] = rw;
      if (rw > maxRowWidth) maxRowWidth = rw;
    }
    final contentWidth = (maxRowWidth + 2 * pad).clamp(600.0, 4000.0);
    for (var i = 0; i < levels.length; i++) {
      final row = groups[levels[i]]!;
      final startX = (contentWidth - rowWidths[levels[i]]!) / 2;
      for (var j = 0; j < row.length; j++) {
        final x = startX + j * (nodeW + hGap);
        final y = pad + i * (nodeH + vGap);
        if (Rect.fromLTWH(x, y, nodeW, nodeH).contains(scenePosition)) {
          return row[j];
        }
      }
    }
    return null;
  }

  /// Deserialize from a Firestore document map.
  static DiagramModel fromJson(Map<String, dynamic> json) {
    final rawNodes = (json['nodes'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final rawEdges = (json['edges'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return DiagramModel(
      nodes: rawNodes
          .asMap()
          .entries
          .map((e) => DiagramNode(
                id: (e.value['id'] ?? 'n${e.key + 1}').toString().trim(),
                label: (e.value['label'] ?? '').toString().trim(),
                type: (e.value['type'] ?? 'process').toString().trim(),
              ))
          .toList(),
      edges: rawEdges
          .map((e) => DiagramEdge(
                from: (e['from'] ?? '').toString().trim(),
                to: (e['to'] ?? '').toString().trim(),
                label: (e['label'] ?? '').toString().trim(),
              ))
          .where((e) => e.from.isNotEmpty && e.to.isNotEmpty)
          .toList(),
    );
  }
}
