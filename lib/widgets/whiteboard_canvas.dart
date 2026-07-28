import 'package:flutter/material.dart';
import 'package:ndu_project/theme.dart';

class WhiteboardCanvas extends StatefulWidget {
  const WhiteboardCanvas({super.key});

  @override
  State<WhiteboardCanvas> createState() => _WhiteboardCanvasState();
}

class _WhiteboardCanvasState extends State<WhiteboardCanvas> {
  final List<_SketchStroke> _strokes = [];
  final List<_SketchStroke> _undoStack = [];
  _SketchStroke? _activeStroke;
  Color _strokeColor = const Color(0xFF111827);
  double _strokeWidth = 3.0;
  bool _eraser = false;

  void _startStroke(Offset point) {
    final color = _eraser ? Colors.white : _strokeColor;
    final width = _eraser ? _strokeWidth * 2.2 : _strokeWidth;
    final stroke = _SketchStroke(
      points: [point],
      color: color,
      width: width,
    );
    setState(() {
      _activeStroke = stroke;
      _strokes.add(stroke);
      _undoStack.clear();
    });
  }

  void _extendStroke(Offset point) {
    if (_activeStroke == null) return;
    setState(() => _activeStroke!.points.add(point));
  }

  void _endStroke() {
    setState(() => _activeStroke = null);
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() {
      _undoStack.add(_strokes.removeLast());
    });
  }

  void _redo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _strokes.add(_undoStack.removeLast());
    });
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _undoStack.clear();
    });
  }

  void _setColor(Color color) {
    setState(() {
      _strokeColor = color;
      _eraser = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppSemanticColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onPanStart: (details) =>
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _startStroke(details.localPosition);
                }),
                onPanUpdate: (details) =>
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _extendStroke(details.localPosition);
                }),
                onPanEnd: (_) =>
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _endStroke();
                }),
                child: CustomPaint(
                  painter: _WhiteboardPainter(strokes: _strokes),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: _WhiteboardHeader(
                eraser: _eraser,
                strokeWidth: _strokeWidth,
                color: _strokeColor,
                onSelectColor: _setColor,
                onToggleEraser: () => setState(() => _eraser = !_eraser),
                onUndo: _undo,
                onRedo: _redo,
                onClear: _clear,
                onWidthChanged: (value) => setState(() => _strokeWidth = value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhiteboardHeader extends StatelessWidget {
  const _WhiteboardHeader({
    required this.eraser,
    required this.strokeWidth,
    required this.color,
    required this.onSelectColor,
    required this.onToggleEraser,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onWidthChanged,
  });

  final bool eraser;
  final double strokeWidth;
  final Color color;
  final ValueChanged<Color> onSelectColor;
  final VoidCallback onToggleEraser;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;
  final ValueChanged<double> onWidthChanged;

  @override
  Widget build(BuildContext context) {
    final swatches = [
      const Color(0xFF111827),
      const Color(0xFFD97706),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppSemanticColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Whiteboard', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[800])),
          const SizedBox(width: 12),
          Row(
            children: swatches.map((swatch) {
              final isSelected = swatch.toARGB32() == color.toARGB32() && !eraser;
              return GestureDetector(
                onTap: () => onSelectColor(swatch),
                child: Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.white,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Eraser',
            onPressed: onToggleEraser,
            icon: Icon(Icons.auto_fix_high, color: eraser ? Colors.black : Colors.grey[600]),
          ),
          SizedBox(
            width: 120,
            child: Slider(
              value: strokeWidth,
              min: 1.5,
              max: 10,
              onChanged: onWidthChanged,
              activeColor: LightModeColors.accent,
            ),
          ),
          IconButton(
            tooltip: 'Undo',
            onPressed: onUndo,
            icon: const Icon(Icons.undo, size: 18),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: onRedo,
            icon: const Icon(Icons.redo, size: 18),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: onClear,
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _WhiteboardPainter extends CustomPainter {
  _WhiteboardPainter({required this.strokes});

  final List<_SketchStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, background);

    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, stroke.width / 2, paint..style = PaintingStyle.fill);
      } else {
        final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (var i = 1; i < stroke.points.length; i++) {
          final p = stroke.points[i];
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WhiteboardPainter oldDelegate) =>
      oldDelegate.strokes != strokes;
}

class _SketchStroke {
  _SketchStroke({
    required this.points,
    required this.color,
    required this.width,
  });

  final List<Offset> points;
  final Color color;
  final double width;
}
