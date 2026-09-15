library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/pbs/models/pbs_models.dart';
import 'package:ndu_project/pbs/providers/pbs_provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

class PBSModuleScreen extends StatefulWidget {
  const PBSModuleScreen({super.key});

  @override
  State<PBSModuleScreen> createState() => _PBSModuleScreenState();
}

class _PBSModuleScreenState extends State<PBSModuleScreen> {
  /// Guards the build-time project sync so a project change triggers exactly
  /// one load pass (the next build sees a mismatched scope until it finishes).
  bool _projectSyncScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncActiveProject());
  }

  /// Project id the PBS storage is scoped by right now — `'default'` when no
  /// project is loaded.
  static String _scopeIdFor(String? projectId) {
    final trimmed = (projectId ?? '').trim();
    return trimmed.isEmpty ? 'default' : trimmed;
  }

  /// The active project's data, or null when this screen is rendered without a
  /// project context (e.g. a standalone preview).
  ProjectDataModel? get _projectData {
    try {
      return ProjectDataHelper.getData(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  String get _activeProjectId => (_projectData?.projectId ?? '').trim();

  /// Display name used for a newly created PBS.
  String get _activeProjectName {
    final name = (_projectData?.projectName ?? '').trim();
    return name.isEmpty ? 'Project Products' : name;
  }

  /// Loads THIS project's PBS before the module renders.
  ///
  /// Storage is project-scoped, so this runs on entry AND whenever the active
  /// project changes — otherwise the module would keep showing the previously
  /// opened project's product breakdown.
  Future<void> _syncActiveProject() async {
    if (!mounted) return;
    final provider = context.read<PBSProvider>();
    final projectId = _activeProjectId;
    if (provider.activeProjectId == _scopeIdFor(projectId)) return;
    final name = (_projectData?.projectName ?? '').trim();
    await provider.ensureProjectLoaded(projectId,
        projectName: name.isEmpty ? null : name);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PBSProvider>(
      builder: (context, pbsProvider, _) {
        // Storage is project-scoped: if the provider is still bound to another
        // project (or to none yet), load THIS project's PBS. Driven from build
        // as well as initState, so switching projects while the module stays
        // mounted re-scopes it.
        final scopeId = _scopeIdFor(_activeProjectId);
        if (pbsProvider.activeProjectId != scopeId &&
            !_projectSyncScheduled) {
          _projectSyncScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            _projectSyncScheduled = false;
            await _syncActiveProject();
          });
        }
        if (pbsProvider.isLoadingFromStorage) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!pbsProvider.setupComplete || pbsProvider.pbs == null) {
          return _buildEmptyState(context, pbsProvider);
        }
        return _buildPBSView(context, pbsProvider);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, PBSProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppSemanticColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 48, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 12),
          const Text(
            'No Product Breakdown Structure',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a PBS to decompose the project into physical products.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () =>
                provider.initPBS(_activeProjectId, _activeProjectName),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Initialize PBS'),
          ),
        ],
      ),
    );
  }

  Widget _buildPBSView(BuildContext context, PBSProvider provider) {
    final pbs = provider.pbs!;
    final flatNodes = PBS.flatten(pbs.root);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppSemanticColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Product Breakdown Structure',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827)),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () =>
                    _showAddNodeDialog(context, provider, pbs.root.id),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Product'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  final count = flatNodes.length;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$count product(s) in breakdown'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline, size: 16),
                label: Text('${flatNodes.length} products'),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Reinitialize PBS',
                onPressed: () => _confirmReinit(context, provider),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [_buildNodeTile(context, provider, pbs.root, 0)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeTile(
      BuildContext context, PBSProvider provider, PBSNode node, int depth) {
    final children = node.children;
    final hasChildren = children.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _showNodeDetail(context, provider, node),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.only(left: (depth * 24).toDouble()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color:
                    depth == 0 ? const Color(0xFFF3F4F6) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: depth == 0
                    ? Border.all(color: AppSemanticColors.border)
                    : null,
              ),
              child: Row(
                children: [
                  Icon(node.productType.icon,
                      size: 18, color: node.productType.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                depth <= 1 ? FontWeight.w700 : FontWeight.w500,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        if (node.code.isNotEmpty)
                          Text(
                            node.code,
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF6B7280)),
                          ),
                      ],
                    ),
                  ),
                  _statusChip(node.status),
                  if (node.quantity > 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '${node.quantity.toInt()} ${node.unitOfMeasure}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                    ),
                  if (node.linkedWBSNodeIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(Icons.link,
                          size: 14, color: node.productType.color),
                    ),
                  PopupMenuButton<String>(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'add', child: Text('Add Child')),
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (node.id != 'root')
                        const PopupMenuItem(
                            value: 'delete', child: Text('Delete')),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'add':
                          _showAddNodeDialog(context, provider, node.id);
                        case 'edit':
                          _showNodeDetail(context, provider, node);
                        case 'delete':
                          _confirmDelete(context, provider, node);
                      }
                    },
                    icon: const Icon(Icons.more_vert, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasChildren)
          ...children
              .map((c) => _buildNodeTile(context, provider, c, depth + 1)),
      ],
    );
  }

  Widget _statusChip(PBSStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600, color: status.color),
      ),
    );
  }

  Future<void> _showAddNodeDialog(
      BuildContext context, PBSProvider provider, String parentId) async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    ProductType selectedType = ProductType.component;
    double quantity = 1;
    String uom = 'EA';

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add Product'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Product Name'),
                  ),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                        labelText: 'PBS Code (e.g. PBS.1.2)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ProductType>(
                    initialValue: selectedType,
                    decoration:
                        const InputDecoration(labelText: 'Product Type'),
                    items: ProductType.values.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t.label));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedType = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration:
                              const InputDecoration(labelText: 'Quantity'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => quantity = double.tryParse(v) ?? 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(labelText: 'UoM'),
                          onChanged: (v) => uom = v,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  provider.addNode(
                    parentId,
                    PBSNode(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      parentId: parentId,
                      code: codeCtrl.text.trim().isNotEmpty
                          ? codeCtrl.text.trim()
                          : 'PBS.${DateTime.now().millisecondsSinceEpoch}',
                      name: nameCtrl.text.trim(),
                      productType: selectedType,
                      quantity: quantity,
                      unitOfMeasure: uom,
                    ),
                  );
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
    nameCtrl.dispose();
    codeCtrl.dispose();
  }

  Future<void> _showNodeDetail(
      BuildContext context, PBSProvider provider, PBSNode node) async {
    final nameCtrl = TextEditingController(text: node.name);
    final descCtrl = TextEditingController(text: node.description);
    PBSStatus selectedStatus = node.status;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
              node.code.isNotEmpty ? '${node.code}: ${node.name}' : node.name),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PBSStatus>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: PBSStatus.values.map((s) {
                    return DropdownMenuItem(value: s, child: Text(s.label));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedStatus = v);
                  },
                ),
                const SizedBox(height: 12),
                Text('Product Type: ${node.productType.label}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280))),
                Text('Quantity: ${node.quantity} ${node.unitOfMeasure}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280))),
                if (node.linkedWBSNodeIds.isNotEmpty)
                  Text('Linked WBS: ${node.linkedWBSNodeIds.length} node(s)',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                provider.updateNode(
                  node.id,
                  node.copyWith(
                    name: nameCtrl.text.trim().isNotEmpty
                        ? nameCtrl.text.trim()
                        : node.name,
                    description: descCtrl.text.trim(),
                    status: selectedStatus,
                  ),
                );
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    descCtrl.dispose();
  }

  void _confirmDelete(
      BuildContext context, PBSProvider provider, PBSNode node) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Remove "${node.name}" and all its children?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              provider.removeNode(node.id);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmReinit(BuildContext context, PBSProvider provider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reinitialize PBS'),
        content: const Text('This will clear all product data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.clearPBS();
              provider.initPBS(_activeProjectId, _activeProjectName);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Reinitialize'),
          ),
        ],
      ),
    );
  }
}
