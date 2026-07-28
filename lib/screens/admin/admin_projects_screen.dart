import 'package:flutter/material.dart';
import 'package:ndu_project/services/project_service.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/services/navigation_context_service.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';

class AdminProjectsScreen extends StatelessWidget {
  const AdminProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Record admin dashboard context for logo navigation
    NavigationContextService.instance
        .setLastAdminDashboard(AppRoutes.adminProjects);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: Row(
          children: [
            const Icon(Icons.folder_open, color: Color(0xFF9C27B0), size: 28),
            const SizedBox(width: 12),
            const Text('Project Overview',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black)),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: UnifiedProfileMenu(compact: true),
          ),
        ],
      ),
      body: SafeArea(
        top: true,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: ProjectService.watchAllProjects(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                  ],
                ),
              );
            }

            final projects = snapshot.data ?? [];

            if (projects.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.folder_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('No projects found',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(32),
              itemCount: projects.length,
              itemBuilder: (context, index) =>
                  _ProjectCard(project: projects[index]),
            );
          },
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final Map<String, dynamic> project;

  @override
  Widget build(BuildContext context) {
    final projectName =
        project['name'] ?? project['projectName'] ?? 'Untitled Project';
    final projectId = project['projectId'] ?? 'N/A';
    final createdAt = _parseDate(project['createdAt']);
    final updatedAt = _parseDate(project['updatedAt']);
    final userId = project['userId'] ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.folder,
                      color: Color(0xFF9C27B0), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(projectName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('ID: $projectId',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey.withOpacity(0.2)),
            const SizedBox(height: 16),
            Row(
              children: [
                _InfoChip(icon: Icons.person, label: 'Owner: $userId'),
                const SizedBox(width: 16),
                if (createdAt != null)
                  _InfoChip(
                      icon: Icons.calendar_today,
                      label: 'Created ${_formatDate(createdAt)}'),
              ],
            ),
            if (updatedAt != null) ...[
              const SizedBox(height: 8),
              _InfoChip(
                  icon: Icons.update,
                  label: 'Updated ${_formatDate(updatedAt)}'),
            ],
          ],
        ),
      ),
    );
  }

  DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is DateTime) return date;
    if (date is String) {
      try {
        return DateTime.parse(date);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) return '${diff.inMinutes}m ago';
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
