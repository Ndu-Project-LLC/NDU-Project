import 'package:flutter/material.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/utils/design_planning_document.dart';

/// Edits the existing architecture modules, not a second diagram-only register.
class ArchitectureWhiteboard extends StatefulWidget {
  const ArchitectureWhiteboard({
    super.key,
    required this.document,
    required this.onChanged,
  });

  final DesignPlanningDocument document;
  final VoidCallback onChanged;

  @override
  State<ArchitectureWhiteboard> createState() => _ArchitectureWhiteboardState();
}

class _ArchitectureWhiteboardState extends State<ArchitectureWhiteboard> {
  static const _canvasSize = Size(1800, 1200);
  static const _nodeSize = Size(220, 120);
  String? _connectionSource;

  Offset _position(DesignPlanningWorkItem module, int index) => Offset(
        (module.diagramX ?? 40 + (index % 5) * 300)
            .clamp(0, _canvasSize.width - _nodeSize.width).toDouble(),
        (module.diagramY ?? 40 + (index ~/ 5) * 180)
            .clamp(0, _canvasSize.height - _nodeSize.height).toDouble(),
      );

  void _change(VoidCallback update) {
    setState(update);
    widget.onChanged();
  }

  Future<void> _editModule([DesignPlanningWorkItem? module]) async {
    final name = TextEditingController(text: module?.name ?? '');
    final purpose = TextEditingController(text: module?.purpose ?? '');
    final accepted = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(module == null ? 'Add architecture module' : 'Edit module'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name,
                decoration: const InputDecoration(labelText: 'Module name')),
            TextField(controller: purpose, maxLines: 3,
                decoration: const InputDecoration(labelText: 'Purpose')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Save module')),
        ],
      ),
    );
    if (accepted == true && mounted) {
      _change(() {
        final row = module ?? DesignPlanningWorkItem();
        row.name = name.text.trim();
        row.purpose = purpose.text.trim();
        if (module == null) widget.document.modules.add(row);
      });
    }
    // Wait for the dialog's exit transition before disposing field controllers.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    purpose.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modules = widget.document.modules;
    final positions = <String, Offset>{
      for (var i = 0; i < modules.length; i++)
        modules[i].id: _position(modules[i], i),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
          children: [
        FilledButton.icon(onPressed: () => _editModule(),
            icon: const Icon(Icons.add), label: const Text('Add module')),
        OutlinedButton.icon(
          onPressed: modules.isEmpty ? null : () => _change(() {
            for (final module in modules) {
              module.diagramX = null;
              module.diagramY = null;
            }
          }),
          icon: const Icon(Icons.grid_view), label: const Text('Arrange modules')),
        if (_connectionSource != null)
          TextButton(onPressed: () => setState(() => _connectionSource = null),
              child: const Text('Cancel connection')),
      ]),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Drag modules to move them. Pan or zoom the board. '
            'Use Connect on a source, then select a destination. '
            'Select an existing connection below to remove it. Changes autosave.'),
      ),
      Expanded(
        child: DecoratedBox(
          decoration: BoxDecoration(color: const Color(0xFFF3F4F6),
              border: Border.all(color: const Color(0xFFD1D5DB))),
          child: InteractiveViewer(
            constrained: false, minScale: 0.3, maxScale: 2,
            child: SizedBox(width: _canvasSize.width, height: _canvasSize.height,
              child: Stack(children: [
                Positioned.fill(child: CustomPaint(painter: _ConnectionsPainter(
                    modules: modules, positions: positions, nodeSize: _nodeSize))),
                for (var i = 0; i < modules.length; i++)
                  Positioned(
                    left: positions[modules[i].id]!.dx,
                    top: positions[modules[i].id]!.dy,
                    width: _nodeSize.width, height: _nodeSize.height,
                    child: GestureDetector(
                      key: ValueKey('architecture-node-${modules[i].id}'),
                      onPanUpdate: (details) => _change(() {
                        final position = _position(modules[i], i) + details.delta;
                        modules[i].diagramX = position.dx
                            .clamp(0, _canvasSize.width - _nodeSize.width).toDouble();
                        modules[i].diagramY = position.dy
                            .clamp(0, _canvasSize.height - _nodeSize.height).toDouble();
                      }),
                      onTap: _connectionSource == null ? null : () {
                        final source = modules.firstWhere(
                            (module) => module.id == _connectionSource);
                        if (source.id == modules[i].id) return;
                        _change(() {
                          if (!source.connectedModuleIds.contains(modules[i].id)) {
                            source.connectedModuleIds.add(modules[i].id);
                          }
                          _connectionSource = null;
                        });
                      },
                      child: Card(
                        color: _connectionSource == modules[i].id
                            ? const Color(0xFFFFF8E1) : Colors.white,
                        child: Padding(padding: const EdgeInsets.all(8),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(modules[i].name.trim().isEmpty
                                  ? 'Unnamed module ${i + 1}' : modules[i].name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(child: Text(modules[i].purpose,
                                  maxLines: 2, overflow: TextOverflow.ellipsis)),
                              Row(children: [
                                Expanded(child: TextButton(onPressed: () => setState(
                                    () => _connectionSource = modules[i].id),
                                    child: const Text('Connect'))),
                                IconButton(tooltip: 'Edit module',
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () => _editModule(modules[i])),
                                IconButton(tooltip: 'Delete module',
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    onPressed: () => _change(() {
                                      final id = modules[i].id;
                                      if (_connectionSource == id) _connectionSource = null;
                                      widget.document.removeArchitectureModule(id);
                                    })),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (modules.isEmpty)
                  const Positioned(left: 40, top: 40,
                      child: Text('Add a module to start sketching your architecture.')),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(height: 52, child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final source in modules)
            for (final target in modules.where(
                (module) => source.connectedModuleIds.contains(module.id)))
              Padding(padding: const EdgeInsets.only(right: 8),
                child: InputChip(
                  label: Text('${source.name.isEmpty ? 'Unnamed' : source.name} → '
                      '${target.name.isEmpty ? 'Unnamed' : target.name}'),
                  onDeleted: () => _change(
                      () => source.connectedModuleIds.remove(target.id)),
                ),
              ),
        ]),
      )),
    ]);
  }
}

class _ConnectionsPainter extends CustomPainter {
  _ConnectionsPainter({required this.modules, required this.positions,
    required this.nodeSize});
  final List<DesignPlanningWorkItem> modules;
  final Map<String, Offset> positions;
  final Size nodeSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFB8860B)..strokeWidth = 2;
    for (final source in modules) {
      for (final target in source.connectedModuleIds) {
        if (!positions.containsKey(target) || target == source.id) continue;
        final start = positions[source.id]! + Offset(nodeSize.width / 2, nodeSize.height / 2);
        final end = positions[target]! + Offset(nodeSize.width / 2, nodeSize.height / 2);
        canvas.drawLine(start, end, paint);
        // Arrow at the destination's boundary, not underneath its card.
        final delta = end - start;
        if (delta.distance == 0) continue;
        final extent = (delta.dx.abs() / (nodeSize.width / 2))
            .clamp(delta.dy.abs() / (nodeSize.height / 2), double.infinity);
        final tip = end - delta / extent;
        final unit = delta / delta.distance;
        final normal = Offset(-unit.dy, unit.dx);
        canvas.drawLine(tip, tip - unit * 12 + normal * 6, paint);
        canvas.drawLine(tip, tip - unit * 12 - normal * 6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectionsPainter oldDelegate) => true;
}
