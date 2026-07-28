/// Group Into Portfolio — expanded full-page view
///
/// This screen is opened when the user taps the "Group Into Portfolio" button
/// on the Portfolio dashboard. It shows the full project-selection list with
/// search, selection, and Create Portfolio action — but as a dedicated page
/// rather than an inline section on the dashboard.
library;

import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/services/portfolio_service.dart';
import 'package:ndu_project/services/project_service.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';

/// A self-contained screen that lets the user select up to 7 projects
/// and group them into a new portfolio.
///
/// Pass the list of [projects] from the parent dashboard so we don't
/// re-fetch from Firestore (the dashboard already has them loaded).
class GroupIntoPortfolioScreen extends StatefulWidget {
  final List<ProjectRecord> projects;

  const GroupIntoPortfolioScreen({super.key, required this.projects});

  /// Push this screen onto the navigator.
  static void open(BuildContext context, List<ProjectRecord> projects) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupIntoPortfolioScreen(projects: projects),
      ),
    );
  }

  @override
  State<GroupIntoPortfolioScreen> createState() =>
      _GroupIntoPortfolioScreenState();
}

class _GroupIntoPortfolioScreenState extends State<GroupIntoPortfolioScreen> {
  // ── Theme tokens (match Portfolio dashboard) ──
  static const _bg = Color(0xFFFFFFFF);
  static const _surface = Color(0xFFF8FAFC);
  static const _surfaceHigh = Color(0xFFF1F5F9);
  static const _surfaceHighest = Color(0xFFE2E8F0);
  static const _onSurface = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _outline = Color(0xFFE2E8F0);
  static const _blue = Color(0xFF6366F1);

  // ── State ──
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String> _selectedIds = {};

  List<ProjectRecord> get _filteredProjects {
    if (_searchQuery.isEmpty) return widget.projects;
    final q = _searchQuery.toLowerCase();
    return widget.projects.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.progressSnapshot.currentPhase.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        if (_selectedIds.length >= 7) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can select up to 7 projects for a portfolio.'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds = {});
  }

  Future<void> _handleCreatePortfolio() async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final portfolioName = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pie_chart_outline_rounded,
                    color: Color(0xFF4338CA), size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Name Your Portfolio'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Give a name to your new portfolio of ${_selectedIds.length} projects.',
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
                const SizedBox(height: 20),
                VoiceTextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Portfolio Name',
                    hintText: 'e.g., Infrastructure Portfolio',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    if (value.trim().length < 3) {
                      return 'Name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(nameController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4338CA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Create Portfolio'),
            ),
          ],
        );
      },
    );

    if (portfolioName == null || !mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await PortfolioService.createPortfolio(
        name: portfolioName,
        projectIds: _selectedIds.toList(),
        ownerId: user.uid,
      );

      if (!mounted) return;
      _clearSelection();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Portfolio created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      // Pop back to the dashboard after successful creation
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error creating portfolio: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      nameController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedIds.length;
    final projects = _filteredProjects;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Group Into Portfolio',
          style: TextStyle(
            color: _onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFamily: appFontFamily,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Heading ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Group Projects Into A Portfolio',
                          style: TextStyle(
                            color: _onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            fontFamily: appFontFamily,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'When you have multiple projects, select up to seven that share a strategic outcome to create a new portfolio.',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 14,
                            fontFamily: appFontFamily,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: _outline.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.filter_alt_outlined, size: 16, color: _muted),
                        const SizedBox(width: 6),
                        Text(
                          'Up to 7 projects',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _muted,
                            fontFamily: appFontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // ── Search bar ──
              Container(
                decoration: BoxDecoration(
                  color: _surface.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _outline.withValues(alpha: 0.2)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: TextStyle(
                    fontSize: 14,
                    color: _onSurface,
                    fontFamily: appFontFamily,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search projects to group...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: _muted.withValues(alpha: 0.6),
                      fontFamily: appFontFamily,
                    ),
                    prefixIcon: Icon(Icons.search, size: 20, color: _muted),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon:
                                Icon(Icons.close_rounded, size: 18, color: _muted),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // ── Selectable project rows ──
              if (projects.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.folder_off_outlined,
                            size: 48, color: _muted.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'No projects available to group',
                          style:
                              TextStyle(color: _muted, fontFamily: appFontFamily),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...projects.map((p) {
                  final isSelected = _selectedIds.contains(p.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => _toggleSelection(p.id),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFEEF2FF)
                              : _surface.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFA5B4FC)
                                : _outline.withValues(alpha: 0.15),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? _blue : _surfaceHighest,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name.isEmpty ? 'Untitled Project' : p.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: _onSurface,
                                      fontFamily: appFontFamily,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    p.progressSnapshot.currentPhase,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _muted,
                                      fontFamily: appFontFamily,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? _blue : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? _blue
                                      : _outline.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                isSelected ? 'Selected' : 'Tap to include',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isSelected ? Colors.white : _muted,
                                  fontFamily: appFontFamily,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 24),
              // ── Divider ──
              Divider(color: _outline.withValues(alpha: 0.2), height: 1),
              const SizedBox(height: 24),
              // ── Selection count + Create Portfolio button ──
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$selectedCount/7 projects selected. Select up to seven to create a portfolio.',
                          style: TextStyle(
                            color: _onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: appFontFamily,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (selectedCount > 0)
                          Text(
                            selectedCount == 7
                                ? 'Maximum number of projects selected.'
                                : '${7 - selectedCount} more project${7 - selectedCount == 1 ? '' : 's'} can be added.',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 12,
                              fontFamily: appFontFamily,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (selectedCount > 0)
                    TextButton(
                      onPressed: _clearSelection,
                      child: Text(
                        'Clear all',
                        style: TextStyle(
                          color: _muted,
                          fontFamily: appFontFamily,
                        ),
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: selectedCount >= 1 ? _handleCreatePortfolio : null,
                    icon:
                        const Icon(Icons.pie_chart_outline_rounded, size: 18),
                    label: Text(
                      selectedCount >= 1 ? 'Create Portfolio' : 'Select projects',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          _surfaceHighest.withValues(alpha: 0.5),
                      disabledForegroundColor: _muted,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
