import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';

/// Card widget for displaying a potential solution with summary information
class SolutionCard extends StatefulWidget {
  const SolutionCard({
    super.key,
    required this.solution,
    required this.onViewDetails,
    required this.onSelectPreferred,
    this.onDelete,
    this.riskCount = 0,
    this.itConsiderationsCount = 0,
    this.infrastructureStatus = 'Not specified',
    this.costBenefitSummary = 'Not calculated',
    this.stakeholderCount = 0,
    this.scopeBrief = '',
    this.isSelected = false,
    this.isSaving = false,
  });

  final PotentialSolution solution;
  final VoidCallback onViewDetails;
  final VoidCallback onSelectPreferred;
  final VoidCallback? onDelete;
  final int riskCount;
  final int itConsiderationsCount;
  final String infrastructureStatus;
  final String costBenefitSummary;
  final int stakeholderCount;
  final String scopeBrief;
  final bool isSelected;
  final bool isSaving;

  @override
  State<SolutionCard> createState() => _SolutionCardState();
}

class _SolutionCardState extends State<SolutionCard> with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseBorderColor = widget.isSelected
        ? const Color(0xFFFFD700).withOpacity(0.9)
        : Colors.grey.shade300;
    final hoverBorderColor = const Color(0xFFFFD700).withOpacity(0.6);
    final borderColor = _isHovering && !widget.isSelected 
        ? hoverBorderColor 
        : baseBorderColor;
    final elevation = widget.isSelected ? 6 : (_isHovering ? 4 : 2);

    return MouseRegion(
      onEnter: (_) {
        Future.microtask(() {
          if (mounted) setState(() => _isHovering = true);
        });
        _animationController.forward();
      },
      onExit: (_) {
        Future.microtask(() {
          if (mounted) setState(() => _isHovering = false);
        });
        _animationController.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Card(
          elevation: elevation.toDouble(),
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: borderColor, 
              width: _isHovering ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Solution #${widget.solution.number}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: widget.onDelete,
                    tooltip: 'Delete solution',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (widget.solution.title.isNotEmpty)
              Text(
                widget.solution.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 10),
            _buildSummaryRow(Icons.description, 'Scope', widget.scopeBrief.isNotEmpty ? widget.scopeBrief : 'Not specified'),
            _buildSummaryRow(Icons.warning, 'Risks', '${widget.riskCount} identified'),
            _buildSummaryRow(Icons.computer, 'IT', '${widget.itConsiderationsCount} items'),
            _buildSummaryRow(Icons.construction, 'Infrastructure', widget.infrastructureStatus),
            _buildSummaryRow(Icons.attach_money, 'Cost Benefit', widget.costBenefitSummary),
            _buildSummaryRow(Icons.people, 'Stakeholders', '${widget.stakeholderCount} identified'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.isSaving ? null : widget.onViewDetails,
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('View Details'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
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

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
