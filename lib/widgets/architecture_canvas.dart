import 'package:flutter/material.dart';
import 'package:ndu_project/theme.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';

// ─── Data Models ────────────────────────────────────────────────────────────

enum ArchitectureNodeType {
  service,
  database,
  api,
  queue,
  cache,
  auth,
  mobileApp,
  webApp,
  adminPortal,
  thirdParty,
  loadBalancer,
  cdn,
  storage,
  container,
  iotDevice,
  custom,
}

extension ArchitectureNodeTypeX on ArchitectureNodeType {
  IconData get icon => switch (this) {
        ArchitectureNodeType.service => Icons.settings_suggest,
        ArchitectureNodeType.database => Icons.storage,
        ArchitectureNodeType.api => Icons.cloud_sync_outlined,
        ArchitectureNodeType.queue => Icons.sync_alt,
        ArchitectureNodeType.cache => Icons.memory,
        ArchitectureNodeType.auth => Icons.verified_user,
        ArchitectureNodeType.mobileApp => Icons.phone_android,
        ArchitectureNodeType.webApp => Icons.language,
        ArchitectureNodeType.adminPortal => Icons.admin_panel_settings,
        ArchitectureNodeType.thirdParty => Icons.link,
        ArchitectureNodeType.loadBalancer => Icons.shuffle,
        ArchitectureNodeType.cdn => Icons.cloud_queue,
        ArchitectureNodeType.storage => Icons.folder_outlined,
        ArchitectureNodeType.container => Icons.widgets,
        ArchitectureNodeType.iotDevice => Icons.device_hub,
        ArchitectureNodeType.custom => Icons.apps,
      };

  String get label => switch (this) {
        ArchitectureNodeType.service => 'Service',
        ArchitectureNodeType.database => 'Database',
        ArchitectureNodeType.api => 'API Gateway',
        ArchitectureNodeType.queue => 'Message Queue',
        ArchitectureNodeType.cache => 'Cache',
        ArchitectureNodeType.auth => 'Auth Service',
        ArchitectureNodeType.mobileApp => 'Mobile App',
        ArchitectureNodeType.webApp => 'Web App',
        ArchitectureNodeType.adminPortal => 'Admin Portal',
        ArchitectureNodeType.thirdParty => '3rd Party',
        ArchitectureNodeType.loadBalancer => 'Load Balancer',
        ArchitectureNodeType.cdn => 'CDN',
        ArchitectureNodeType.storage => 'Object Storage',
        ArchitectureNodeType.container => 'Container',
        ArchitectureNodeType.iotDevice => 'IoT Device',
        ArchitectureNodeType.custom => 'Custom',
      };

  Color get accentColor => switch (this) {
        ArchitectureNodeType.service => const Color(0xFFD97706),
        ArchitectureNodeType.database => const Color(0xFF059669),
        ArchitectureNodeType.api => const Color(0xFF7C3AED),
        ArchitectureNodeType.queue => const Color(0xFFD97706),
        ArchitectureNodeType.cache => const Color(0xFFDC2626),
        ArchitectureNodeType.auth => const Color(0xFF0891B2),
        ArchitectureNodeType.mobileApp => const Color(0xFF4F46E5),
        ArchitectureNodeType.webApp => const Color(0xFFD97706),
        ArchitectureNodeType.adminPortal => const Color(0xFF374151),
        ArchitectureNodeType.thirdParty => const Color(0xFFB45309),
        ArchitectureNodeType.loadBalancer => const Color(0xFF65A30D),
        ArchitectureNodeType.cdn => const Color(0xFF6D28D9),
        ArchitectureNodeType.storage => const Color(0xFF0D9488),
        ArchitectureNodeType.container => const Color(0xFFD97706),
        ArchitectureNodeType.iotDevice => const Color(0xFF9333EA),
        ArchitectureNodeType.custom => const Color(0xFF6B7280),
      };

  Color get bgColor => switch (this) {
        ArchitectureNodeType.service => const Color(0xFFFFF7E6),
        ArchitectureNodeType.database => const Color(0xFFECFDF5),
        ArchitectureNodeType.api => const Color(0xFFF5F3FF),
        ArchitectureNodeType.queue => const Color(0xFFFFFBEB),
        ArchitectureNodeType.cache => const Color(0xFFFEF2F2),
        ArchitectureNodeType.auth => const Color(0xFFECFEFF),
        ArchitectureNodeType.mobileApp => const Color(0xFFEEF2FF),
        ArchitectureNodeType.webApp => const Color(0xFFFFF7E6),
        ArchitectureNodeType.adminPortal => const Color(0xFFF9FAFB),
        ArchitectureNodeType.thirdParty => const Color(0xFFFFFBEB),
        ArchitectureNodeType.loadBalancer => const Color(0xFFF7FEE7),
        ArchitectureNodeType.cdn => const Color(0xFFF5F3FF),
        ArchitectureNodeType.storage => const Color(0xFFF0FDFA),
        ArchitectureNodeType.container => const Color(0xFFFFF7E6),
        ArchitectureNodeType.iotDevice => const Color(0xFFFAF5FF),
        ArchitectureNodeType.custom => const Color(0xFFF9FAFB),
      };
}

class ArchitectureNode {
  ArchitectureNode({
    required this.id,
    required this.label,
    required this.position,
    this.nodeType = ArchitectureNodeType.custom,
    this.description = '',
    this.technology = '',
    this.color,
    this.icon,
    this.width = 180,
    this.height = 72,
  });

  final String id;
  String label;
  Offset position;
  ArchitectureNodeType nodeType;
  String description;
  String technology;
  Color? color;
  IconData? icon;
  double width;
  double height;
}

enum EdgeStyle { solid, dashed, dotted }

class ArchitectureEdge {
  ArchitectureEdge({
    required this.fromId,
    required this.toId,
    this.label = '',
    this.edgeStyle = EdgeStyle.solid,
    this.color,
  });
  final String fromId;
  final String toId;
  String label;
  EdgeStyle edgeStyle;
  Color? color;
}

// ─── Convenience payload ────────────────────────────────────────────────────

class ArchitectureDragPayload {
  ArchitectureDragPayload(this.label, {this.icon, this.color, this.nodeType});
  final String label;
  final IconData? icon;
  final Color? color;
  final ArchitectureNodeType? nodeType;
}

// ─── Main Canvas Widget ─────────────────────────────────────────────────────

class ArchitectureCanvas extends StatefulWidget {
  const ArchitectureCanvas({
    super.key,
    required this.onRequestAddNodeFromDrop,
    required this.nodes,
    required this.edges,
    required this.onNodesChanged,
    required this.onEdgesChanged,
  });

  final ArchitectureNode Function(Offset canvasPosition, dynamic payload)
      onRequestAddNodeFromDrop;
  final List<ArchitectureNode> nodes;
  final List<ArchitectureEdge> edges;
  final ValueChanged<List<ArchitectureNode>> onNodesChanged;
  final ValueChanged<List<ArchitectureEdge>> onEdgesChanged;

  @override
  State<ArchitectureCanvas> createState() => _ArchitectureCanvasState();
}

class _ArchitectureCanvasState extends State<ArchitectureCanvas> {
  late TransformationController _transform;
  bool _connectMode = false;
  String? _selectedForConnection;
  String? _selectedNodeId;
  String? _hoveredNodeId;
  bool _showGrid = true;
  Offset? _connectionDragEnd;
  bool _isPanning = false;

  @override
  void initState() {
    super.initState();
    _transform = TransformationController();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleConnectMode() {
    setState(() {
      _connectMode = !_connectMode;
      _selectedForConnection = null;
      _connectionDragEnd = null;
    });
  }

  void _resetView() {
    setState(() {
      _transform.value = Matrix4.identity();
    });
  }

  void _zoom(double factor) {
    final next = Matrix4.copy(_transform.value)
      ..multiply(Matrix4.diagonal3Values(factor, factor, 1.0));
    setState(() => _transform.value = next);
  }

  void _toggleGrid() {
    setState(() => _showGrid = !_showGrid);
  }

  void _selectNode(String id) {
    setState(() => _selectedNodeId = id);
  }

  void _editSelectedNode() {
    final id = _selectedNodeId;
    if (id == null) return;
    final node =
        widget.nodes.firstWhere((n) => n.id == id, orElse: () => widget.nodes.first);
    _openNodeEditor(node);
  }

  Future<void> _deleteSelectedNode() async {
    final id = _selectedNodeId;
    if (id == null) return;
    final node = widget.nodes.firstWhere((n) => n.id == id,
        orElse: () => widget.nodes.first);
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Component',
      itemLabel: node.label,
    );
    if (!confirmed) return;
    final newNodes = widget.nodes.where((e) => e.id != id).toList();
    final newEdges =
        widget.edges.where((e) => e.fromId != id && e.toId != id).toList();
    widget.onNodesChanged(newNodes);
    widget.onEdgesChanged(newEdges);
    setState(() => _selectedNodeId = null);
  }

  void _duplicateSelectedNode() {
    final id = _selectedNodeId;
    if (id == null) return;
    final node =
        widget.nodes.firstWhere((n) => n.id == id, orElse: () => widget.nodes.first);
    final newNode = ArchitectureNode(
      id: 'n_${DateTime.now().millisecondsSinceEpoch}',
      label: '${node.label} (copy)',
      position: node.position + const Offset(40, 40),
      nodeType: node.nodeType,
      description: node.description,
      technology: node.technology,
      color: node.color,
      icon: node.icon,
    );
    widget.onNodesChanged([...widget.nodes, newNode]);
  }

  void _autoLayout() {
    if (widget.nodes.isEmpty) return;
    final nodes = List<ArchitectureNode>.from(widget.nodes);
    const double spacingX = 220;
    const double spacingY = 120;
    final cols = (nodes.length / 3).ceil().clamp(1, nodes.length);
    for (int i = 0; i < nodes.length; i++) {
      final row = i ~/ cols;
      final col = i % cols;
      nodes[i].position = Offset(80 + col * spacingX, 60 + row * spacingY);
    }
    widget.onNodesChanged(nodes);
    _resetView();
  }

  Future<void> _openNodeEditor(ArchitectureNode node) async {
    final labelController = TextEditingController(text: node.label);
    final descController = TextEditingController(text: node.description);
    final techController = TextEditingController(text: node.technology);
    ArchitectureNodeType selectedType = node.nodeType;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              titlePadding: EdgeInsets.zero,
              contentPadding: const EdgeInsets.all(20),
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              title: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selectedType.accentColor.withOpacity(0.08),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Icon(selectedType.icon, color: selectedType.accentColor),
                    const SizedBox(width: 10),
                    const Text('Edit Component',
                        style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type selector
                    const Text('Component Type',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ArchitectureNodeType.values.map((type) {
                        final isSelected = type == selectedType;
                        return ChoiceChip(
                          avatar: Icon(type.icon, size: 14,
                              color: isSelected ? Colors.white : type.accentColor),
                          label: Text(type.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected ? Colors.white : null,
                              )),
                          selected: isSelected,
                          selectedColor: type.accentColor,
                          onSelected: (_) =>
                              setDialogState(() => selectedType = type),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: labelController,
                      decoration: const InputDecoration(
                        labelText: 'Label',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: techController,
                      decoration: const InputDecoration(
                        labelText: 'Technology Stack',
                        hintText: 'e.g., Node.js, PostgreSQL, Redis...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedType.accentColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result != true) return;
    node.label = labelController.text.trim().isEmpty
        ? node.label
        : labelController.text.trim();
    node.nodeType = selectedType;
    node.description = descController.text.trim();
    node.technology = techController.text.trim();
    node.icon = selectedType.icon;
    widget.onNodesChanged(List.of(widget.nodes));
  }

  Future<void> _openEdgeEditor(ArchitectureEdge edge) async {
    final controller = TextEditingController(text: edge.label);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Connection'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Connection Label',
            hintText: 'e.g., HTTP/REST, gRPC, WebSocket...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != true) return;
    edge.label = controller.text.trim();
    widget.onEdgesChanged(List.of(widget.edges));
  }

  Offset _toCanvasSpace(Offset globalPosition, RenderBox box) {
    final local = box.globalToLocal(globalPosition);
    final Matrix4 m = _transform.value;
    final Matrix4 inv = Matrix4.inverted(m);
    final vm.Vector3 v = vm.Vector3(local.dx, local.dy, 0);
    final vm.Vector3 t = inv.transform3(v);
    return Offset(t.x, t.y);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // Main canvas
          LayoutBuilder(
            builder: (context, constraints) {
              return DragTarget<Object>(
                onWillAcceptWithDetails: (data) => true,
                onAcceptWithDetails: (details) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final canvasPos = _toCanvasSpace(details.offset, box);
                  final newNode =
                      widget.onRequestAddNodeFromDrop(canvasPos, details.data);
                  widget.onNodesChanged([...widget.nodes, newNode]);
                },
                builder: (context, candidateData, rejectedData) {
                  return Container(
                    color: const Color(0xFFFAFBFD),
                    child: InteractiveViewer(
                      transformationController: _transform,
                      boundaryMargin: const EdgeInsets.all(4000),
                      minScale: 0.15,
                      maxScale: 3.0,
                      child: CustomPaint(
                        size: const Size(8000, 8000),
                        painter: _showGrid ? _DotGridPainter() : null,
                        child: Stack(children: [
                          // Edges
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _EdgePainter(
                                  widget.nodes,
                                  widget.edges,
                                  _selectedForConnection,
                                  _connectionDragEnd,
                                ),
                              ),
                            ),
                          ),
                          // Nodes
                          ...widget.nodes.map((n) => _ProNodeWidget(
                                key: ValueKey(n.id),
                                node: n,
                                connectMode: _connectMode,
                                selectedForConnection:
                                    _selectedForConnection == n.id,
                                isSelected: _selectedNodeId == n.id,
                                isHovered: _hoveredNodeId == n.id,
                                onDrag: (delta) =>
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  n.position += delta;
                                  widget
                                      .onNodesChanged(List.of(widget.nodes));
                                }),
                                onTap: () {
                                  if (_connectMode) {
                                    setState(() {
                                      if (_selectedForConnection == null) {
                                        _selectedForConnection = n.id;
                                      } else if (_selectedForConnection !=
                                          n.id) {
                                        final newEdges = [
                                          ...widget.edges,
                                          ArchitectureEdge(
                                            fromId: _selectedForConnection!,
                                            toId: n.id,
                                          )
                                        ];
                                        widget.onEdgesChanged(newEdges);
                                        _selectedForConnection = null;
                                        _connectMode = false;
                                        _connectionDragEnd = null;
                                      }
                                    });
                                    return;
                                  }
                                  _selectNode(n.id);
                                },
                                onDoubleTap: () => _openNodeEditor(n),
                                onHover: (hovering) => Future.microtask(() {
                                  if (!mounted) return;
                                  setState(() => _hoveredNodeId =
                                      hovering ? n.id : null);
                                }),
                                onDelete: () {
                                  final newNodes = widget.nodes
                                      .where((e) => e.id != n.id)
                                      .toList();
                                  final newEdges = widget.edges
                                      .where((e) =>
                                          e.fromId != n.id && e.toId != n.id)
                                      .toList();
                                  widget.onNodesChanged(newNodes);
                                  widget.onEdgesChanged(newEdges);
                                },
                              )),
                          // Empty state hint
                          if (widget.nodes.isEmpty)
                            Positioned.fill(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.hub_outlined,
                                        size: 56,
                                        color: Colors.grey.shade300),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Drag components here to build\nyour system architecture',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey.shade400,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ]),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // ─── Top Toolbar ─────────────────────────────────────────────────
          Positioned(
            left: 12,
            top: 12,
            right: 12,
            child: Row(
              children: [
                // Canvas title
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE4E7EC)),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 8,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7E6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.account_tree_outlined,
                            size: 14, color: Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 8),
                      const Text('Architecture Canvas',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${widget.nodes.length}',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF16A34A))),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Tool buttons
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE4E7EC)),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 8,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(children: [
                    _toolbarButton(
                      icon: Icons.zoom_in,
                      tooltip: 'Zoom In',
                      onTap: () => _zoom(1.15),
                    ),
                    _toolbarButton(
                      icon: Icons.zoom_out,
                      tooltip: 'Zoom Out',
                      onTap: () => _zoom(0.85),
                    ),
                    _toolbarButton(
                      icon: Icons.center_focus_weak,
                      tooltip: 'Reset View',
                      onTap: _resetView,
                    ),
                    const SizedBox(width: 2),
                    Container(
                        width: 1, height: 20, color: const Color(0xFFE4E7EC)),
                    const SizedBox(width: 2),
                    _toolbarToggle(
                      icon: Icons.trending_flat,
                      label: 'Connect',
                      isActive: _connectMode,
                      activeColor: const Color(0xFF7C3AED),
                      onTap: _toggleConnectMode,
                    ),
                    _toolbarToggle(
                      icon: Icons.grid_on_outlined,
                      label: 'Grid',
                      isActive: _showGrid,
                      activeColor: const Color(0xFF059669),
                      onTap: _toggleGrid,
                    ),
                    const SizedBox(width: 2),
                    Container(
                        width: 1, height: 20, color: const Color(0xFFE4E7EC)),
                    const SizedBox(width: 2),
                    _toolbarButton(
                      icon: Icons.auto_fix_high,
                      tooltip: 'Auto Layout',
                      onTap: _autoLayout,
                    ),
                    if (_selectedNodeId != null) ...[
                      const SizedBox(width: 2),
                      Container(
                          width: 1,
                          height: 20,
                          color: const Color(0xFFE4E7EC)),
                      const SizedBox(width: 2),
                      _toolbarButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit',
                        onTap: _editSelectedNode,
                      ),
                      _toolbarButton(
                        icon: Icons.content_copy,
                        tooltip: 'Duplicate',
                        onTap: _duplicateSelectedNode,
                      ),
                      _toolbarButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Delete',
                        color: const Color(0xFFEF4444),
                        onTap: _deleteSelectedNode,
                      ),
                    ],
                  ]),
                ),
              ],
            ),
          ),

          // ─── Bottom Status Bar ────────────────────────────────────────────
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE4E7EC)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    _connectMode
                        ? 'CONNECT MODE: Click first node, then click second node to create connection'
                        : _selectedNodeId != null
                            ? 'Selected: ${widget.nodes.where((n) => n.id == _selectedNodeId).firstOrNull?.label ?? "node"} • Double-click to edit • Drag to move'
                            : 'Drag components from library • Click to select • Double-click to edit • Scroll to zoom',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.nodes.length} nodes · ${widget.edges.length} connections',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),

          // ─── Minimap ──────────────────────────────────────────────────────
          if (widget.nodes.isNotEmpty)
            Positioned(
              right: 12,
              bottom: 44,
              child: _Minimap(
                nodes: widget.nodes,
                edges: widget.edges,
                selectedNodeId: _selectedNodeId,
                onTap: (id) => _selectNode(id),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 18, color: color ?? Colors.grey[700]),
          ),
        ),
      ),
    );
  }

  Widget _toolbarToggle({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: 'Toggle $label',
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: isActive ? activeColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16,
                    color: isActive ? activeColor : Colors.grey[600]),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? activeColor : Colors.grey[600],
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Dot Grid Painter ───────────────────────────────────────────────────────

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint dot = Paint()..color = const Color(0xFFD1D5DB);
    const double step = 24;
    const double dotRadius = 1.2;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), dotRadius, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Edge Painter ────────────────────────────────────────────────────────────

class _EdgePainter extends CustomPainter {
  _EdgePainter(this.nodes, this.edges, this.connectingFromId, this.dragEnd);
  final List<ArchitectureNode> nodes;
  final List<ArchitectureEdge> edges;
  final String? connectingFromId;
  final Offset? dragEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final nodeById = {for (final n in nodes) n.id: n};

    // Draw existing edges
    for (final e in edges) {
      final a = nodeById[e.fromId];
      final b = nodeById[e.toId];
      if (a == null || b == null) continue;

      final fromCenter = a.position + Offset(a.width / 2, a.height / 2);
      final toCenter = b.position + Offset(b.width / 2, b.height / 2);

      // Determine connection points (auto-select nearest sides)
      final start = _getConnectionPoint(fromCenter, toCenter, a.width, a.height);
      final end = _getConnectionPoint(toCenter, fromCenter, b.width, b.height);

      final edgeColor = e.color ?? const Color(0xFF94A3B8);

      final paint = Paint()
        ..color = edgeColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final midX = (start.dx + end.dx) / 2;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(midX, start.dy, midX, end.dy, end.dx, end.dy);

      // Draw dashed/dotted by drawing the path in segments
      if (e.edgeStyle == EdgeStyle.dashed) {
        _drawDashedPath(canvas, path, paint, dashLength: 8, gapLength: 5);
      } else if (e.edgeStyle == EdgeStyle.dotted) {
        _drawDashedPath(canvas, path, paint, dashLength: 3, gapLength: 5);
      } else {
        canvas.drawPath(path, paint);
      }

      // Arrow head
      const double arrow = 8;
      final angle = (end - Offset(midX, end.dy)).direction;
      final p1 = end - Offset.fromDirection(angle - 0.4, arrow);
      final p2 = end - Offset.fromDirection(angle + 0.4, arrow);
      final tri = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();
      canvas.drawPath(tri, paint..style = PaintingStyle.fill..color = edgeColor);
      paint.style = PaintingStyle.stroke;

      // Edge label
      if (e.label.isNotEmpty) {
        final labelPos = Offset(
          (start.dx + end.dx) / 2,
          (start.dy + end.dy) / 2 - 10,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: e.label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final bgPaint = Paint()..color = const Color(0xFFFAFBFD);
        canvas.drawRRect(
          RRect.fromRectXY(
            Rect.fromCenter(
                center: labelPos,
                width: tp.width + 8,
                height: tp.height + 4),
            4,
            4,
          ),
          bgPaint,
        );
        tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // Draw in-progress connection line
    if (connectingFromId != null && dragEnd != null) {
      final a = nodeById[connectingFromId!];
      if (a != null) {
        final fromCenter = a.position + Offset(a.width / 2, a.height / 2);
        final paint = Paint()
          ..color = const Color(0xFF7C3AED).withOpacity(0.6)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawLine(fromCenter, dragEnd!, paint);
      }
    }
  }

  Offset _getConnectionPoint(
      Offset from, Offset to, double w, double h) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    if (dx.abs() > dy.abs()) {
      // Horizontal connection
      return dx > 0
          ? Offset(from.dx + w / 2, from.dy)
          : Offset(from.dx - w / 2, from.dy);
    } else {
      // Vertical connection
      return dy > 0
          ? Offset(from.dx, from.dy + h / 2)
          : Offset(from.dx, from.dy - h / 2);
    }
  }

  /// Draws a path with dashed pattern by approximating it as line segments
  void _drawDashedPath(Canvas canvas, Path path, Paint paint,
      {required double dashLength, required double gapLength}) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final length = draw ? dashLength : gapLength;
        if (distance + length > metric.length) {
          if (draw) {
            canvas.drawPath(
              metric.extractPath(distance, metric.length),
              paint,
            );
          }
          break;
        }
        if (draw) {
          canvas.drawPath(
            metric.extractPath(distance, distance + length),
            paint,
          );
        }
        distance += length;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) =>
      oldDelegate.nodes != nodes ||
      oldDelegate.edges != edges ||
      oldDelegate.connectingFromId != connectingFromId ||
      oldDelegate.dragEnd != dragEnd;
}

// ─── Professional Node Widget ────────────────────────────────────────────────

class _ProNodeWidget extends StatelessWidget {
  const _ProNodeWidget({
    super.key,
    required this.node,
    required this.onDrag,
    required this.onDelete,
    required this.onTap,
    required this.onDoubleTap,
    required this.onHover,
    required this.connectMode,
    required this.selectedForConnection,
    required this.isSelected,
    required this.isHovered,
  });

  final ArchitectureNode node;
  final void Function(Offset delta) onDrag;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final void Function(bool hovering) onHover;
  final bool connectMode;
  final bool selectedForConnection;
  final bool isSelected;
  final bool isHovered;

  @override
  Widget build(BuildContext context) {
    final accent = node.nodeType.accentColor;
    final bg = node.nodeType.bgColor;
    final effectiveBg = node.color ?? bg;

    return Positioned(
      left: node.position.dx,
      top: node.position.dy,
      child: MouseRegion(
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: GestureDetector(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onPanUpdate: (d) => onDrag(d.delta),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: node.width,
            decoration: BoxDecoration(
              color: effectiveBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selectedForConnection
                    ? const Color(0xFF7C3AED)
                    : isSelected
                        ? accent
                        : isHovered
                            ? accent.withOpacity(0.5)
                            : const Color(0xFFE4E7EC),
                width: selectedForConnection || isSelected ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? accent.withOpacity(0.15)
                      : const Color(0x08000000),
                  blurRadius: isSelected ? 16 : 8,
                  offset: const Offset(0, 4),
                  spreadRadius: isSelected ? 2 : 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header bar with icon and label
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.06),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(13)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child:
                            Icon(node.icon ?? node.nodeType.icon, size: 16, color: accent),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          node.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: accent.withOpacity(0.9),
                          ),
                        ),
                      ),
                      if (isSelected || isHovered)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onDelete,
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(Icons.close,
                                  size: 14, color: Colors.grey[500]),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Body with description / technology
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (node.technology.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            node.technology,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: accent.withOpacity(0.7),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (node.description.isNotEmpty)
                        Text(
                          node.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                        )
                      else
                        Text(
                          node.nodeType.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                // Connection ports (left & right dots)
                // Left port
                Positioned(
                  left: -5,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: connectMode
                            ? const Color(0xFF7C3AED)
                            : isSelected
                                ? accent
                                : const Color(0xFFE4E7EC),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Minimap ─────────────────────────────────────────────────────────────────

class _Minimap extends StatelessWidget {
  const _Minimap({
    required this.nodes,
    required this.edges,
    required this.selectedNodeId,
    required this.onTap,
  });

  final List<ArchitectureNode> nodes;
  final List<ArchitectureEdge> edges;
  final String? selectedNodeId;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) return const SizedBox.shrink();

    // Compute bounds
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final n in nodes) {
      minX = minX < n.position.dx ? minX : n.position.dx;
      minY = minY < n.position.dy ? minY : n.position.dy;
      maxX = maxX > n.position.dx + n.width ? maxX : n.position.dx + n.width;
      maxY = maxY > n.position.dy + 72 ? maxY : n.position.dy + 72;
    }
    final boundsW = (maxX - minX + 80).clamp(1.0, double.infinity);
    final boundsH = (maxY - minY + 80).clamp(1.0, double.infinity);
    const mapW = 160.0;
    final mapH = (boundsH / boundsW * mapW).clamp(80.0, 120.0);
    final scaleX = mapW / boundsW;
    final scaleY = mapH / boundsH;

    return Container(
      width: mapW + 12,
      height: mapH + 12,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: CustomPaint(
          size: Size(mapW, mapH),
          painter: _MinimapPainter(
            nodes: nodes,
            edges: edges,
            selectedNodeId: selectedNodeId,
            offsetX: minX - 40,
            offsetY: minY - 40,
            scaleX: scaleX,
            scaleY: scaleY,
          ),
        ),
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  _MinimapPainter({
    required this.nodes,
    required this.edges,
    required this.selectedNodeId,
    required this.offsetX,
    required this.offsetY,
    required this.scaleX,
    required this.scaleY,
  });

  final List<ArchitectureNode> nodes;
  final List<ArchitectureEdge> edges;
  final String? selectedNodeId;
  final double offsetX;
  final double offsetY;
  final double scaleX;
  final double scaleY;

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFF8FAFC));

    // Edges
    final nodeById = {for (final n in nodes) n.id: n};
    final edgePaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1;
    for (final e in edges) {
      final a = nodeById[e.fromId];
      final b = nodeById[e.toId];
      if (a == null || b == null) continue;
      canvas.drawLine(
        Offset((a.position.dx + a.width / 2 - offsetX) * scaleX,
            (a.position.dy + 36 - offsetY) * scaleY),
        Offset((b.position.dx + b.width / 2 - offsetX) * scaleX,
            (b.position.dy + 36 - offsetY) * scaleY),
        edgePaint,
      );
    }

    // Nodes
    for (final n in nodes) {
      final rect = Rect.fromLTWH(
        (n.position.dx - offsetX) * scaleX,
        (n.position.dy - offsetY) * scaleY,
        n.width * scaleX,
        72 * scaleY,
      );
      final isSelected = n.id == selectedNodeId;
      canvas.drawRRect(
        RRect.fromRectXY(rect, 3, 3),
        Paint()
          ..color = isSelected
              ? n.nodeType.accentColor.withOpacity(0.3)
              : n.nodeType.accentColor.withOpacity(0.12),
      );
      canvas.drawRRect(
        RRect.fromRectXY(rect, 3, 3),
        Paint()
          ..color = isSelected
              ? n.nodeType.accentColor
              : const Color(0xFFE4E7EC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 1.5 : 0.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) =>
      oldDelegate.nodes != nodes ||
      oldDelegate.edges != edges ||
      oldDelegate.selectedNodeId != selectedNodeId;
}
