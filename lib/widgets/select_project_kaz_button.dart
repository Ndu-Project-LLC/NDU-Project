import 'package:flutter/material.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
/// A world-class "Select Project" button styled with KAZ AI chat bubble theme.
/// Features smooth animations, gradient backgrounds, and exceptional visual design.
class SelectProjectKazButton extends StatefulWidget {
  final List<SolutionOption> solutions;
  final ValueChanged<SolutionOption>? onSolutionSelected;
  final VoidCallback? onClosed;
  final String title;
  final String subtitle;

  const SelectProjectKazButton({
    super.key,
    required this.solutions,
    this.onSolutionSelected,
    this.onClosed,
    this.title = 'Choose a project to progress',
    this.subtitle = 'Pick the solution you want to advance and give your project a memorable name.',
  });

  @override
  State<SelectProjectKazButton> createState() => _SelectProjectKazButtonState();
}

class _SelectProjectKazButtonState extends State<SelectProjectKazButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showSelectionDialog() {
    _animationController.forward();
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (context) => _SelectProjectDialog(
        solutions: widget.solutions,
        title: widget.title,
        subtitle: widget.subtitle,
        onSolutionSelected: (solution) {
          widget.onSolutionSelected?.call(solution);
          Navigator.of(context).pop();
        },
      ),
    ).then((_) {
      _animationController.reverse();
      widget.onClosed?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showSelectionDialog,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFC812),
                  Color(0xFFFFB200),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFC812).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xFFFFB200).withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Animated background shimmer effect
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                    ),
                  ),
                ),
                // Button content
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        child: const Icon(
                          Icons.psychology_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Project',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Choose from ${widget.solutions.length} solutions',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontWeight: FontWeight.w500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white.withOpacity(0.9),
                        size: 18,
                      ),
                    ],
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

class _SelectProjectDialog extends StatefulWidget {
  final List<SolutionOption> solutions;
  final String title;
  final String subtitle;
  final ValueChanged<SolutionOption> onSolutionSelected;

  const _SelectProjectDialog({
    required this.solutions,
    required this.title,
    required this.subtitle,
    required this.onSolutionSelected,
  });

  @override
  State<_SelectProjectDialog> createState() => _SelectProjectDialogState();
}

class _SelectProjectDialogState extends State<_SelectProjectDialog> with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  late TabController _tabController;
  late TextEditingController _projectNameController;
  String? _projectNameError;

  @override
  void initState() {
    super.initState();
    _projectNameController = TextEditingController();
    _tabController = TabController(length: widget.solutions.length, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Prefill project name if the project already has a name in the current data
    try {
      final data = ProjectDataHelper.getData(context);
  final existing = data.projectName;
      if (existing.isNotEmpty && _projectNameController.text.isEmpty) {
        _projectNameController.text = existing;
      }
    } catch (_) {
      // ignore if provider not available in this context
    }
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _confirmSelection() {
    if (_selectedIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a solution')),
      );
      return;
    }

    final projectName = _projectNameController.text.trim();
    if (projectName.isEmpty) {
      setState(() => _projectNameError = 'Project name is required');
      return;
    }

    final selected = widget.solutions[_selectedIndex!];
    widget.onSolutionSelected(SolutionOption(
      title: selected.title,
      description: selected.description,
      projectName: projectName,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: isMobile ? double.infinity : 540,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with KAZ AI theme
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFC812),
                    Color(0xFFFFB200),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        child: const Icon(
                          Icons.psychology_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'KAZ AI Solution Selection',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Pick your preferred approach',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            // Solutions selection
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available Solutions',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(
                      widget.solutions.length,
                      (index) => _SolutionCard(
                        solution: widget.solutions[index],
                        isSelected: _selectedIndex == index,
                        onTap: () => setState(() => _selectedIndex = index),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Project name field
                    const Text(
                      'Project Name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    VoiceTextField(
                      controller: _projectNameController,
                      onChanged: (_) {
                        if (_projectNameError != null) {
                          setState(() => _projectNameError = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: _selectedIndex != null
                            ? 'e.g., ${widget.solutions[_selectedIndex!].title} Initiative'
                            : 'Enter project name',
                        errorText: _projectNameError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.grey, width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFFC812), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            // Action buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.withOpacity(0.15)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFFC812),
                            Color(0xFFFFB200),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFC812).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _confirmSelection,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Select Solution',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SolutionCard extends StatelessWidget {
  final _SolutionOption solution;
  final bool isSelected;
  final VoidCallback onTap;

  const _SolutionCard({
    required this.solution,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? const Color(0xFFFFC812) : Colors.grey.withOpacity(0.2),
          width: isSelected ? 2 : 1,
        ),
        color: isSelected ? const Color(0xFFFFF8DC) : Colors.white,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFFFFC812).withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Selection indicator
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFFFFC812) : Colors.grey.withOpacity(0.4),
                      width: 2,
                    ),
                    color: isSelected ? const Color(0xFFFFC812) : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                      : null,
                ),
                const SizedBox(width: 12),
                // Solution content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        solution.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? const Color(0xFFFFC812) : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        solution.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Arrow indicator
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFC812).withOpacity(0.1),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFFFFC812),
                      size: 16,
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

/// Public model for solution options (exported for use in this widget)
class _SolutionOption {
  final String title;
  final String description;
  final String? projectName;

  _SolutionOption({
    required this.title,
    required this.description,
    this.projectName,
  });
}

/// Alias for external use - same as _SolutionOption
class SolutionOption extends _SolutionOption {
  SolutionOption({
    required super.title,
    required super.description,
    super.projectName,
  });
}
