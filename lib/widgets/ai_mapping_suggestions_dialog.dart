import 'package:flutter/material.dart';
import '../services/spec_mapping_ai_service.dart';

/// Dialog widget for displaying and managing AI mapping suggestions
///
/// Features:
/// - Displays AI-generated mapping suggestions with confidence scores
/// - Accept/reject individual suggestions
/// - Visual feedback for accepted (green) and rejected (red) items
/// - Summary bar showing accepted/rejected counts
/// - Filter by confidence level
/// - Batch operations for quick processing
class AiMappingSuggestionsDialog extends StatefulWidget {
  /// List of AI mapping suggestions to display
  final List<AiMappingSuggestion> suggestions;

  /// Callback when user accepts or rejects a suggestion
  final Function(AiMappingSuggestion suggestion, bool accepted) onAction;

  /// Optional title for the dialog
  final String? title;

  const AiMappingSuggestionsDialog({
    super.key,
    required this.suggestions,
    required this.onAction,
    this.title,
  });

  /// Show the dialog and return the list of accepted suggestions
  static Future<List<AiMappingSuggestion>> show(
    BuildContext context, {
    required List<AiMappingSuggestion> suggestions,
    required Function(AiMappingSuggestion suggestion, bool accepted) onAction,
    String? title,
  }) async {
    final result = await showDialog<List<AiMappingSuggestion>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AiMappingSuggestionsDialog(
        suggestions: suggestions,
        onAction: onAction,
        title: title,
      ),
    );
    return result ?? [];
  }

  @override
  State<AiMappingSuggestionsDialog> createState() =>
      _AiMappingSuggestionsDialogState();
}

class _AiMappingSuggestionsDialogState
    extends State<AiMappingSuggestionsDialog> {
  final Set<int> _accepted = {};
  final Set<int> _rejected = {};
  double _confidenceFilter = 0.0;
  String _searchQuery = '';
  bool _showOnlyPending = false;

  @override
  Widget build(BuildContext context) {
    // Filter suggestions based on search and confidence
    final filteredSuggestions = _getFilteredSuggestions();

    return Dialog(
      child: Container(
        width: 750,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(),
            
            Divider(height: 1),
            
            // Filters toolbar
            _buildFiltersToolbar(filteredSuggestions.length),
            
            Divider(height: 1),
            
            // Suggestions list
            Expanded(
              child: filteredSuggestions.isEmpty
                  ? _buildEmptyState()
                  : _buildSuggestionsList(filteredSuggestions),
            ),
            
            // Summary bar
            _buildSummaryBar(),
          ],
        ),
      ),
    );
  }

  /// Build the dialog header
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF4154F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Color(0xFF4154F1),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title ?? 'AI Mapping Suggestions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '${widget.suggestions.length} total suggestions',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(_getAcceptedSuggestions()),
          ),
        ],
      ),
    );
  }

  /// Build the filters toolbar
  Widget _buildFiltersToolbar(int filteredCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search suggestions...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Confidence filter dropdown
          DropdownButton<double>(
            value: _confidenceFilter,
            items: [
              const DropdownMenuItem(value: 0.0, child: Text('All confidence')),
              const DropdownMenuItem(value: 0.7, child: Text('High (≥70%)')),
              const DropdownMenuItem(value: 0.4, child: Text('Medium (≥40%)')),
              const DropdownMenuItem(value: 0.25, child: Text('Low (≥25%)')),
            ],
            onChanged: (val) => setState(() => _confidenceFilter = val ?? 0.0),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(width: 8),
          
          // Show pending only toggle
          FilterChip(
            label: const Text('Pending only', style: TextStyle(fontSize: 12)),
            selected: _showOnlyPending,
            onSelected: (val) => setState(() => _showOnlyPending = val),
            visualDensity: VisualDensity.compact,
          ),
          
          const SizedBox(width: 8),
          
          // Showing count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFFFFC812).shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Showing $filteredCount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFFB8860B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get filtered list of suggestions
  List<AiMappingSuggestion> _getFilteredSuggestions() {
    var filtered = widget.suggestions.where((s) {
      // Apply confidence filter
      if (s.confidence < _confidenceFilter) return false;
      
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!s.targetTitle.toLowerCase().contains(query) &&
            !s.reasoning.toLowerCase().contains(query) &&
            !s.sourceId.toLowerCase().contains(query)) {
          return false;
        }
      }
      
      // Apply pending filter
      if (_showOnlyPending) {
        final index = widget.suggestions.indexOf(s);
        if (_accepted.contains(index) || _rejected.contains(index)) {
          return false;
        }
      }
      
      return true;
    }).toList();
    
    return filtered;
  }

  /// Build empty state widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No suggestions match your filters',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _confidenceFilter = 0.0;
              _searchQuery = '';
              _showOnlyPending = false;
            }),
            child: const Text('Clear all filters'),
          ),
        ],
      ),
    );
  }

  /// Build the suggestions list
  Widget _buildSuggestionsList(List<AiMappingSuggestion> suggestions) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        // Find original index for tracking accept/reject state
        final originalIndex = widget.suggestions.indexOf(suggestion);
        final isAccepted = _accepted.contains(originalIndex);
        final isRejected = _rejected.contains(originalIndex);

        return _SuggestionCard(
          suggestion: suggestion,
          isAccepted: isAccepted,
          isRejected: isRejected,
          onAccept: isAccepted || isRejected
              ? null
              : () {
                  setState(() => _accepted.add(originalIndex));
                  widget.onAction(suggestion, true);
                },
          onReject: isAccepted || isRejected
              ? null
              : () {
                  setState(() => _rejected.add(originalIndex));
                  widget.onAction(suggestion, false);
                },
        );
      },
    );
  }

  /// Build the summary bar at the bottom
  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        color: Colors.grey.shade50,
      ),
      child: Row(
        children: [
          // Stats
          if (_accepted.isNotEmpty)
            _StatBadge(
              icon: Icons.check_circle,
              label: '$_accepted accepted',
              color: Colors.green,
            ),
          if (_rejected.isNotEmpty) ...[
            const SizedBox(width: 12),
            _StatBadge(
              icon: Icons.cancel,
              label: '$_rejected rejected',
              color: Colors.red,
            ),
          ],
          const Spacer(),
          
          // Batch actions
          if (_showOnlyPending == false) ...[
            TextButton.icon(
              onPressed: _acceptAllVisible,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Accept All Visible'),
              style: TextButton.styleFrom(foregroundColor: Colors.green),
            ),
            const SizedBox(width: 8),
          ],
          
          // Done button
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pop(_getAcceptedSuggestions()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4154F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  /// Get list of accepted suggestions
  List<AiMappingSuggestion> _getAcceptedSuggestions() {
    return _accepted
        .map((index) => widget.suggestions[index])
        .toList();
  }

  /// Accept all currently visible suggestions
  void _acceptAllVisible() {
    final visible = _getFilteredSuggestions();
    for (final suggestion in visible) {
      final index = widget.suggestions.indexOf(suggestion);
      if (!_accepted.contains(index) && !_rejected.contains(index)) {
        _accepted.add(index);
        widget.onAction(suggestion, true);
      }
    }
    setState(() {});
  }
}

/// Individual suggestion card widget
class _SuggestionCard extends StatelessWidget {
  final AiMappingSuggestion suggestion;
  final bool isAccepted;
  final bool isRejected;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const _SuggestionCard({
    required this.suggestion,
    required this.isAccepted,
    required this.isRejected,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    Color? cardColor;
    if (isAccepted) {
      cardColor = Colors.green.shade50;
    } else if (isRejected) {
      cardColor = Colors.red.shade50;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: isAccepted || isRejected ? 0 : 1,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isAccepted
            ? BorderSide(color: Colors.green.shade200)
            : isRejected
                ? BorderSide(color: Colors.red.shade200)
                : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Confidence indicator
            _ConfidenceBadge(confidence: suggestion.confidence),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Target title
                  Text(
                    suggestion.targetTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Reasoning
                  Text(
                    suggestion.reasoning,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // Type chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        label: Text(
                          suggestion.sourceType.toUpperCase(),
                          style: const TextStyle(fontSize: 10),
                        ),
                        backgroundColor: Color(0xFFFFC812).shade50,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                      Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      Chip(
                        label: Text(
                          suggestion.targetType.toUpperCase(),
                          style: const TextStyle(fontSize: 10),
                        ),
                        backgroundColor: Color(0xFFB8860B).shade50,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Action buttons
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.check_circle,
                    color: isAccepted ? Colors.green : Colors.green.shade300,
                  ),
                  tooltip: 'Accept mapping',
                  onPressed: onAccept,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.cancel,
                    color: isRejected ? Colors.red : Colors.red.shade300,
                  ),
                  tooltip: 'Reject mapping',
                  onPressed: onReject,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular confidence badge showing percentage
class _ConfidenceBadge extends StatelessWidget {
  final double confidence;
  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    
    if (confidence >= 0.7) {
      color = Colors.green;
      label = 'High';
    } else if (confidence >= 0.4) {
      color = Colors.orange;
      label = 'Med';
    } else {
      color = Colors.red;
      label = 'Low';
    }

    return Tooltip(
      message: '$label confidence: ${(confidence * 100).toStringAsFixed(0)}%',
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(confidence * 100).toInt()}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 13,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 8,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small stat badge for summary bar
class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
