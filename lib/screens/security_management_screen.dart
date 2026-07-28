import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/inner_page_navigation_hint.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

enum _SecurityTab { dashboard, roles, permissions, settings, accessLogs }

class SecurityManagementScreen extends StatefulWidget {
  const SecurityManagementScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SecurityManagementScreen()),
    );
  }

  @override
  State<SecurityManagementScreen> createState() =>
      _SecurityManagementScreenState();
}

class _SecurityManagementScreenState extends State<SecurityManagementScreen> {
  _SecurityTab _selectedTab = _SecurityTab.dashboard;
  final List<_RoleRowData> _roles = [];
  final List<_PermissionRowData> _permissions = [];
  final List<_SettingEntry> _settings = [];
  final List<_AccessLogEntry> _accessLogs = [];
  _SystemSettingsData _systemSettings = _SystemSettingsData.defaults();
  bool _loadingData = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSecurityData());
  }

  Future<void> _loadSecurityData() async {
    final projectId = ProjectDataHelper.getData(context).projectId;
    if (projectId == null || projectId.isEmpty) return;
    setState(() => _loadingData = true);
    try {
      final projectRef =
          FirebaseFirestore.instance.collection('projects').doc(projectId);
      final rolesSnap = await projectRef
          .collection('security_roles')
          .orderBy('createdAt', descending: true)
          .get();
      final permissionsSnap = await projectRef
          .collection('security_permissions')
          .orderBy('createdAt', descending: true)
          .get();
      final settingsSnap = await projectRef
          .collection('security_settings')
          .orderBy('createdAt', descending: true)
          .get();
      final logsSnap = await projectRef
          .collection('security_access_logs')
          .orderBy('time', descending: true)
          .get();
      final systemSnap = await projectRef
          .collection('security_settings_system')
          .doc('current')
          .get();

      final roles =
          rolesSnap.docs.map((doc) => _RoleRowData.fromFirestore(doc)).toList();
      final permissions = permissionsSnap.docs
          .map((doc) => _PermissionRowData.fromFirestore(doc))
          .toList();
      final settings = settingsSnap.docs
          .map((doc) => _SettingEntry.fromFirestore(doc))
          .toList();
      final logs = logsSnap.docs
          .map((doc) => _AccessLogEntry.fromFirestore(doc))
          .toList();
      final systemSettings =
          _SystemSettingsData.fromFirestore(systemSnap.data());

      if (!mounted) return;
      setState(() {
        _roles
          ..clear()
          ..addAll(roles);
        _permissions
          ..clear()
          ..addAll(permissions);
        _settings
          ..clear()
          ..addAll(settings);
        _accessLogs
          ..clear()
          ..addAll(logs);
        _systemSettings = systemSettings;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Unable to load security data from Firestore')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  void _handleTabSelected(_SecurityTab tab) {
    if (_selectedTab == tab) return;
    setState(() => _selectedTab = tab);
  }

  void _logAccess({
    required String action,
    required String resource,
    String status = 'Success',
  }) {
    final entry = _AccessLogEntry(
      id: _newDocId('security_access_logs'),
      time: DateTime.now(),
      user: FirebaseAuth.instance.currentUser?.email ?? 'Current user',
      action: action,
      resource: resource,
      status: status,
      ipAddress: '10.24.0.12',
    );
    _accessLogs.insert(0, entry);
    _persistAccessLog(entry);
  }

  Future<void> _openRoleDialog() async {
    final nameController = TextEditingController();
    final tierController = TextEditingController(text: 'Tier 1');
    final descriptionController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add role'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VoiceTextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Role name'),
                ),
                const SizedBox(height: 12),
                VoiceTextField(
                  controller: tierController,
                  decoration: const InputDecoration(labelText: 'Tier label'),
                ),
                const SizedBox(height: 12),
                VoiceTextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Add')),
          ],
        );
      },
    );
    if (result != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    final tier = tierController.text.trim().isEmpty
        ? 'Tier 1'
        : tierController.text.trim();
    final tierVariant = tier.toLowerCase().contains('1')
        ? _TierBadgeVariant.primary
        : tier.toLowerCase().contains('2')
            ? _TierBadgeVariant.text
            : _TierBadgeVariant.neutral;
    final role = _RoleRowData(
      id: _newDocId('security_roles'),
      name: name,
      tierLabel: tier,
      tierVariant: tierVariant,
      description: descriptionController.text.trim().isEmpty
          ? 'Custom role'
          : descriptionController.text.trim(),
      created: _formatShortDate(DateTime.now()),
    );
    setState(() => _roles.add(role));
    await _persistRole(role);
    _logAccess(action: 'Created role', resource: name);
  }

  Future<void> _openPermissionDialog() async {
    final nameController = TextEditingController();
    final resourceController = TextEditingController();
    final actionController = TextEditingController();
    final descriptionController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add permission'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VoiceTextField(
                  controller: nameController,
                  decoration:
                      const InputDecoration(labelText: 'Permission name'),
                ),
                const SizedBox(height: 12),
                VoiceTextField(
                  controller: resourceController,
                  decoration: const InputDecoration(labelText: 'Resource'),
                ),
                const SizedBox(height: 12),
                VoiceTextField(
                  controller: actionController,
                  decoration: const InputDecoration(labelText: 'Action'),
                ),
                const SizedBox(height: 12),
                VoiceTextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Add')),
          ],
        );
      },
    );
    if (result != true) return;
    final name = nameController.text.trim();
    final resource = resourceController.text.trim();
    final action = actionController.text.trim();
    if (name.isEmpty || resource.isEmpty || action.isEmpty) return;
    final permission = _PermissionRowData(
      id: _newDocId('security_permissions'),
      name: name,
      resource: resource,
      action: action,
      description: descriptionController.text.trim().isEmpty
          ? 'Custom permission'
          : descriptionController.text.trim(),
    );
    setState(() => _permissions.add(permission));
    await _persistPermission(permission);
    _logAccess(action: 'Granted permission', resource: '$resource:$action');
  }

  Future<void> _openSettingDialog() async {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    final descriptionController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add setting'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VoiceTextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Setting name'),
                ),
                const SizedBox(height: 12),
                VoiceTextField(
                  controller: valueController,
                  decoration: const InputDecoration(labelText: 'Value'),
                ),
                const SizedBox(height: 12),
                VoiceTextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Add')),
          ],
        );
      },
    );
    if (result != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    final entry = _SettingEntry(
      id: _newDocId('security_settings'),
      name: name,
      value: valueController.text.trim().isEmpty
          ? 'Enabled'
          : valueController.text.trim(),
      description: descriptionController.text.trim().isEmpty
          ? 'Custom setting'
          : descriptionController.text.trim(),
      updated: _formatShortDate(DateTime.now()),
    );
    setState(() => _settings.add(entry));
    await _persistSetting(entry);
    _logAccess(action: 'Updated setting', resource: name);
  }

  Future<void> _handleSettingsSaved(_SystemSettingsData data) async {
    setState(() => _systemSettings = data);
    await _persistSystemSettings(data);
    _logAccess(action: 'Saved settings', resource: 'Security settings');
  }

  String _newDocId(String collection) {
    final projectId = ProjectDataHelper.getData(context).projectId;
    if (projectId == null || projectId.isEmpty)
      return DateTime.now().millisecondsSinceEpoch.toString();
    return FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection(collection)
        .doc()
        .id;
  }

  Future<void> _persistRole(_RoleRowData role) async {
    final projectId = ProjectDataHelper.getData(context).projectId;
    if (projectId == null || projectId.isEmpty) return;
    final projectRef =
        FirebaseFirestore.instance.collection('projects').doc(projectId);
    await projectRef
        .collection('security_roles')
        .doc(role.id)
        .set(role.toFirestore());
  }

  Future<void> _persistPermission(_PermissionRowData permission) async {
    final projectId = ProjectDataHelper.getData(context).projectId;
    if (projectId == null || projectId.isEmpty) return;
    final projectRef =
        FirebaseFirestore.instance.collection('projects').doc(projectId);
    await projectRef
        .collection('security_permissions')
        .doc(permission.id)
        .set(permission.toFirestore());
  }

  Future<void> _persistSetting(_SettingEntry entry) async {
    final projectId = ProjectDataHelper.getData(context).projectId;
    if (projectId == null || projectId.isEmpty) return;
    final projectRef =
        FirebaseFirestore.instance.collection('projects').doc(projectId);
    await projectRef
        .collection('security_settings')
        .doc(entry.id)
        .set(entry.toFirestore());
  }

  Future<void> _persistAccessLog(_AccessLogEntry entry) async {
    final projectId = ProjectDataHelper.getData(context).projectId;
    if (projectId == null || projectId.isEmpty) return;
    final projectRef =
        FirebaseFirestore.instance.collection('projects').doc(projectId);
    await projectRef
        .collection('security_access_logs')
        .doc(entry.id)
        .set(entry.toFirestore());
  }

  Future<void> _persistSystemSettings(_SystemSettingsData data) async {
    final projectId = ProjectDataHelper.getData(context).projectId;
    if (projectId == null || projectId.isEmpty) return;
    final projectRef =
        FirebaseFirestore.instance.collection('projects').doc(projectId);
    await projectRef
        .collection('security_settings_system')
        .doc('current')
        .set(data.toFirestore());
  }

  @override
  Widget build(BuildContext context) {
    final double horizontalPadding = AppBreakpoints.isMobile(context) ? 20 : 32;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                  activeItemLabel: 'Security Management'),
            ),
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding, vertical: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlanningPhaseHeader(
                            title: 'Security Management',
                            onExportPdf: _exportPdf),
                        const SizedBox(height: 16),
                        const _PageHeader(),
                        if (_loadingData) ...[
                          const SizedBox(height: 12),
                          const LinearProgressIndicator(minHeight: 3),
                        ],
                        const SizedBox(height: 24),
                        const _SecurityNotesCard(),
                        const SizedBox(height: 24),
                        _TabStrip(
                            selectedTab: _selectedTab,
                            onSelected: _handleTabSelected),
                        const SizedBox(height: 16),
                        InnerPageNavigationHint(
                          pageId: 'security_management',
                          pageTitle: 'Security Management',
                          description: 'Navigate between security sections',
                          currentSectionId: _selectedTab.name,
                          sections: [
                            InnerPageSection(
                                id: _SecurityTab.dashboard.name,
                                label: 'Dashboard',
                                icon: Icons.dashboard_customize,
                                status: _selectedTab == _SecurityTab.dashboard
                                    ? InnerPageSectionStatus.current
                                    : InnerPageSectionStatus.available,
                                stepNumber: 1),
                            InnerPageSection(
                                id: _SecurityTab.roles.name,
                                label: 'Roles',
                                icon: Icons.badge_outlined,
                                status: _selectedTab == _SecurityTab.roles
                                    ? InnerPageSectionStatus.current
                                    : InnerPageSectionStatus.available,
                                stepNumber: 2),
                            InnerPageSection(
                                id: _SecurityTab.permissions.name,
                                label: 'Permissions',
                                icon: Icons.lock_open_outlined,
                                status: _selectedTab == _SecurityTab.permissions
                                    ? InnerPageSectionStatus.current
                                    : InnerPageSectionStatus.available,
                                stepNumber: 3),
                            InnerPageSection(
                                id: _SecurityTab.settings.name,
                                label: 'Settings',
                                icon: Icons.settings_outlined,
                                status: _selectedTab == _SecurityTab.settings
                                    ? InnerPageSectionStatus.current
                                    : InnerPageSectionStatus.available,
                                stepNumber: 4),
                            InnerPageSection(
                                id: _SecurityTab.accessLogs.name,
                                label: 'Access Logs',
                                icon: Icons.receipt_long_outlined,
                                status: _selectedTab == _SecurityTab.accessLogs
                                    ? InnerPageSectionStatus.current
                                    : InnerPageSectionStatus.available,
                                stepNumber: 5),
                          ],
                          onSectionTap: (sectionId) {
                            final tab = _SecurityTab.values
                                .firstWhere((t) => t.name == sectionId);
                            _handleTabSelected(tab);
                          },
                        ),
                        const SizedBox(height: 28),
                        _TabContent(
                          selectedTab: _selectedTab,
                          roles: _roles,
                          permissions: _permissions,
                          settings: _settings,
                          accessLogs: _accessLogs,
                          onAddRole: _openRoleDialog,
                          onAddPermission: _openPermissionDialog,
                          onAddSetting: _openSettingDialog,
                          onSaveSettings: _handleSettingsSaved,
                          systemSettings: _systemSettings,
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel: 'Security Management',
                    ),
                  ),
                  const KazAiChatBubble(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Security Management',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName ?? 'N/A'},
          {'Solution Title': projectData.solutionTitle ?? 'N/A'},
        ]),
        PdfSection.text(
            'Notes',
            projectData.planningNotes['planning_security_management_notes'] ??
                'No data recorded.'),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Security Management',
          style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827)),
        ),
        SizedBox(height: 8),
        Text(
          'Control access, monitor activity, and configure security settings',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}

class _SecurityNotesCard extends StatefulWidget {
  const _SecurityNotesCard();

  @override
  State<_SecurityNotesCard> createState() => _SecurityNotesCardState();
}

class _SecurityNotesCardState extends State<_SecurityNotesCard> {
  final TextEditingController _controller = TextEditingController();
  final _saveDebounce = _Debouncer();
  bool _saving = false;
  DateTime? _lastSavedAt;
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    final data = ProjectDataHelper.getData(context);
    _controller.text =
        data.planningNotes['planning_security_management_notes'] ?? '';
    _didInit = true;
  }

  @override
  void dispose() {
    _saveDebounce.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    final trimmed = value.trim();
    final provider = ProjectDataHelper.getProvider(context);
    provider.updateField(
      (data) => data.copyWith(
        planningNotes: {
          ...data.planningNotes,
          'planning_security_management_notes': trimmed,
        },
      ),
    );
    _saveDebounce.run(() async {
      if (!mounted) return;
      setState(() => _saving = true);
      final success = await ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: 'security_management',
        dataUpdater: (data) => data.copyWith(
          planningNotes: {
            ...data.planningNotes,
            'planning_security_management_notes': trimmed,
          },
        ),
        showSnackbar: false,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (success) _lastSavedAt = DateTime.now();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final savedAt = _lastSavedAt;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 18, offset: Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.note_outlined,
                    color: Color(0xFF475569), size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Notes',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827)),
                ),
              ),
              if (_saving)
                const _StatusChip(label: 'Saving...', color: Color(0xFF64748B))
              else if (savedAt != null)
                _StatusChip(
                  label:
                      'Saved ${TimeOfDay.fromDateTime(savedAt).format(context)}',
                  color: const Color(0xFF16A34A),
                  background: const Color(0xFFECFDF3),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Summarize security priorities, access controls, and monitoring needs.',
            style:
                TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
          ),
          const SizedBox(height: 16),
          VoiceTextField(
            controller: _controller,
            onChanged: _handleChanged,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Capture security notes here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(
      {required this.label, required this.color, this.background});

  final String label;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _Debouncer {
  _Debouncer({Duration? delay})
      : delay = delay ?? const Duration(milliseconds: 700);

  final Duration delay;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() => _timer?.cancel();
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.selectedTab, required this.onSelected});

  final _SecurityTab selectedTab;
  final ValueChanged<_SecurityTab> onSelected;

  @override
  Widget build(BuildContext context) {
    const tabs = [
      _TabData(
          label: 'Dashboard',
          icon: Icons.dashboard_customize,
          tab: _SecurityTab.dashboard),
      _TabData(
          label: 'Roles', icon: Icons.badge_outlined, tab: _SecurityTab.roles),
      _TabData(
          label: 'Permissions',
          icon: Icons.lock_open_outlined,
          tab: _SecurityTab.permissions),
      _TabData(
          label: 'Settings',
          icon: Icons.settings_outlined,
          tab: _SecurityTab.settings),
      _TabData(
          label: 'Access Logs',
          icon: Icons.receipt_long_outlined,
          tab: _SecurityTab.accessLogs),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 18,
              offset: const Offset(0, 12)),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < tabs.length; i++) ...[
              _TabChip(
                data: tabs[i],
                selected: tabs[i].tab == selectedTab,
                onTap: () => onSelected(tabs[i].tab),
              ),
              if (i != tabs.length - 1) const SizedBox(width: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _TabData {
  const _TabData({required this.label, required this.icon, required this.tab});

  final String label;
  final IconData icon;
  final _SecurityTab tab;
}

class _TabChip extends StatelessWidget {
  const _TabChip(
      {required this.data, required this.selected, required this.onTap});

  final _TabData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color background =
        selected ? const Color(0xFFFFC044) : Colors.transparent;
    final Color textColor =
        selected ? const Color(0xFF1A1D1F) : const Color(0xFF4B5563);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(data.icon, color: textColor, size: 18),
              const SizedBox(width: 10),
              Text(
                data.label,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.selectedTab,
    required this.roles,
    required this.permissions,
    required this.settings,
    required this.accessLogs,
    required this.onAddRole,
    required this.onAddPermission,
    required this.onAddSetting,
    required this.onSaveSettings,
    required this.systemSettings,
  });

  final _SecurityTab selectedTab;
  final List<_RoleRowData> roles;
  final List<_PermissionRowData> permissions;
  final List<_SettingEntry> settings;
  final List<_AccessLogEntry> accessLogs;
  final VoidCallback onAddRole;
  final VoidCallback onAddPermission;
  final VoidCallback onAddSetting;
  final ValueChanged<_SystemSettingsData> onSaveSettings;
  final _SystemSettingsData systemSettings;

  @override
  Widget build(BuildContext context) {
    switch (selectedTab) {
      case _SecurityTab.dashboard:
        return _DashboardView(
          roles: roles,
          permissions: permissions,
          settings: settings,
          accessLogs: accessLogs,
        );
      case _SecurityTab.roles:
        return _RolesView(roles: roles, onAdd: onAddRole);
      case _SecurityTab.permissions:
        return _PermissionsView(
            permissions: permissions, onAdd: onAddPermission);
      case _SecurityTab.settings:
        return _SettingsView(
          settings: settings,
          onAddSetting: onAddSetting,
          onSave: onSaveSettings,
          initialSettings: systemSettings,
        );
      case _SecurityTab.accessLogs:
        return _AccessLogsView(logs: accessLogs);
    }
  }
}

// ignore: unused_element
class _EmptySecurityState extends StatelessWidget {
  const _EmptySecurityState(
      {required this.title, required this.message, required this.icon});

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFFF59E0B)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827))),
                const SizedBox(height: 6),
                Text(message,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView({
    required this.roles,
    required this.permissions,
    required this.settings,
    required this.accessLogs,
  });

  final List<_RoleRowData> roles;
  final List<_PermissionRowData> permissions;
  final List<_SettingEntry> settings;
  final List<_AccessLogEntry> accessLogs;

  @override
  Widget build(BuildContext context) {
    final roleCount = roles.length;
    final permissionCount = permissions.length;
    final settingsCount = settings.length;
    final latestLog = accessLogs.isNotEmpty ? accessLogs.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final double maxWidth = constraints.maxWidth;
            double cardWidth;
            if (maxWidth >= 1080) {
              cardWidth = (maxWidth - 32) / 3;
            } else if (maxWidth >= 720) {
              cardWidth = (maxWidth - 16) / 2;
            } else {
              cardWidth = maxWidth;
            }

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(width: cardWidth, child: _RoleTiersCard(roles: roles)),
                SizedBox(
                    width: cardWidth,
                    child: _ResourcePermissionsCard(permissions: permissions)),
                SizedBox(
                  width: cardWidth,
                  child: _SecurityStatusCard(
                    rolesCount: roleCount,
                    permissionsCount: permissionCount,
                    settingsCount: settingsCount,
                    latestLog: latestLog,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        _RecentActivityCard(logs: accessLogs),
      ],
    );
  }
}

class _SettingsView extends StatefulWidget {
  const _SettingsView({
    required this.settings,
    required this.onAddSetting,
    required this.onSave,
    required this.initialSettings,
  });

  final List<_SettingEntry> settings;
  final VoidCallback onAddSetting;
  final ValueChanged<_SystemSettingsData> onSave;
  final _SystemSettingsData initialSettings;

  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  late final TextEditingController _sessionTimeoutController;
  late final TextEditingController _minPasswordLengthController;
  late bool _requireMfa;
  late bool _requireUppercase;
  late bool _requireNumbers;
  late bool _requireSpecial;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSettings;
    _sessionTimeoutController =
        TextEditingController(text: initial.sessionTimeoutMinutes.toString());
    _minPasswordLengthController =
        TextEditingController(text: initial.minPasswordLength.toString());
    _requireMfa = initial.requireMfa;
    _requireUppercase = initial.requireUppercase;
    _requireNumbers = initial.requireNumbers;
    _requireSpecial = initial.requireSpecial;
  }

  @override
  void didUpdateWidget(covariant _SettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSettings != widget.initialSettings) {
      final initial = widget.initialSettings;
      _sessionTimeoutController.text = initial.sessionTimeoutMinutes.toString();
      _minPasswordLengthController.text = initial.minPasswordLength.toString();
      _requireMfa = initial.requireMfa;
      _requireUppercase = initial.requireUppercase;
      _requireNumbers = initial.requireNumbers;
      _requireSpecial = initial.requireSpecial;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _sessionTimeoutController.dispose();
    _minPasswordLengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 14)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.settings_outlined,
                    color: Color(0xFFB45309), size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Security Settings',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827)),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Configure system-wide security options',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _SettingsSection(
            icon: Icons.verified_user_outlined,
            iconBackground: const Color(0xFFFFF7E6),
            iconColor: const Color(0xFFD97706),
            title: 'Authentication',
            subtitle: 'Enforce login security and session controls',
            children: [
              _SettingToggleRow(
                title: 'Require Multi-Factor Authentication',
                subtitle: 'Enforce MFA for all users when logging in',
                value: _requireMfa,
                onChanged: (value) => setState(() => _requireMfa = value),
              ),
              _SettingInputRow(
                title: 'Session Timeout (minutes)',
                subtitle: 'How long before an inactive session expires',
                controller: _sessionTimeoutController,
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 32),
          _SettingsSection(
            icon: Icons.lock_outline,
            iconBackground: const Color(0xFFF0F9F9),
            iconColor: const Color(0xFF0F766E),
            title: 'Password Policy',
            subtitle: 'Set the minimum required characters for passwords',
            children: [
              _SettingInputRow(
                title: 'Minimum Password Length',
                subtitle: 'Set the minimum required characters for passwords',
                controller: _minPasswordLengthController,
              ),
              _SettingToggleRow(
                title: 'Require Uppercase Characters',
                subtitle:
                    'Passwords must contain at least one uppercase letter',
                value: _requireUppercase,
                onChanged: (value) => setState(() => _requireUppercase = value),
              ),
              _SettingToggleRow(
                title: 'Require Numbers',
                subtitle: 'Passwords must contain at least one number',
                value: _requireNumbers,
                onChanged: (value) => setState(() => _requireNumbers = value),
              ),
              _SettingToggleRow(
                title: 'Require Special Characters',
                subtitle:
                    'Passwords must contain at least one special character',
                value: _requireSpecial,
                onChanged: (value) => setState(() => _requireSpecial = value),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.tune_outlined,
                    color: Color(0xFFD97706), size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom Security Settings',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827)),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Add organization-specific controls and safeguards',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              OutlinedButton.icon(
                onPressed: widget.onAddSetting,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1F2937),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Setting'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                color: Colors.white,
              ),
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFFF9FAFB),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Row(
                      children: const [
                        _TableHeaderCell(label: 'Setting', flex: 2),
                        _TableHeaderCell(label: 'Value', flex: 2),
                        _TableHeaderCell(label: 'Description', flex: 3),
                        _TableHeaderCell(label: 'Updated', flex: 2),
                      ],
                    ),
                  ),
                  if (widget.settings.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      alignment: Alignment.center,
                      child: const Text(
                        'No custom security settings yet',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    )
                  else
                    for (int i = 0; i < widget.settings.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 20),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                widget.settings[i].name,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                widget.settings[i].value,
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF4B5563)),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                widget.settings[i].description,
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF4B5563)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                widget.settings[i].updated,
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF4B5563)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i != widget.settings.length - 1)
                        const Divider(
                            height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                    ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final data = _SystemSettingsData(
                  sessionTimeoutMinutes:
                      int.tryParse(_sessionTimeoutController.text) ?? 30,
                  minPasswordLength:
                      int.tryParse(_minPasswordLengthController.text) ?? 10,
                  requireMfa: _requireMfa,
                  requireUppercase: _requireUppercase,
                  requireNumbers: _requireNumbers,
                  requireSpecial: _requireSpecial,
                );
                widget.onSave(data);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB020),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Save All Settings'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessLogsView extends StatefulWidget {
  const _AccessLogsView({required this.logs});

  final List<_AccessLogEntry> logs;

  @override
  State<_AccessLogsView> createState() => _AccessLogsViewState();
}

class _AccessLogsViewState extends State<_AccessLogsView> {
  final TextEditingController _searchController = TextEditingController();
  String? _statusFilter;
  late final VoidCallback _searchListener;

  @override
  void initState() {
    super.initState();
    _searchListener = () => setState(() {});
    _searchController.addListener(_searchListener);
  }

  @override
  void dispose() {
    _searchController.removeListener(_searchListener);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.logs.where((entry) {
      final matchesStatus =
          _statusFilter == null || entry.status == _statusFilter;
      if (!matchesStatus) return false;
      if (query.isEmpty) return true;
      final haystack = [
        entry.user,
        entry.action,
        entry.resource,
        entry.ipAddress,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 14)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.receipt_long_outlined,
                    color: Color(0xFFD97706), size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Access Logs',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827)),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'System access and security event history',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isCompact = constraints.maxWidth < 780;
              final searchField = isCompact
                  ? SizedBox(
                      width: double.infinity,
                      child: _LogsSearchField(
                        controller: _searchController,
                        onClear: () =>
                            setState(() => _searchController.clear()),
                      ),
                    )
                  : Expanded(
                      child: _LogsSearchField(
                        controller: _searchController,
                        onClear: () =>
                            setState(() => _searchController.clear()),
                      ),
                    );
              final statusDropdown = SizedBox(
                width: isCompact ? double.infinity : 150,
                child: _StatusDropdown(
                  value: _statusFilter,
                  onChanged: (value) => setState(() => _statusFilter = value),
                ),
              );
              final searchButton = SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Search'),
                ),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    searchField,
                    const SizedBox(height: 16),
                    searchButton,
                    const SizedBox(height: 16),
                    statusDropdown,
                  ],
                );
              }

              return Row(
                children: [
                  searchField,
                  const SizedBox(width: 12),
                  searchButton,
                  const Spacer(),
                  statusDropdown,
                ],
              );
            },
          ),
          const SizedBox(height: 26),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                color: Colors.white,
              ),
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFFF9FAFB),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Row(
                      children: const [
                        _TableHeaderCell(label: 'Time', flex: 2),
                        _TableHeaderCell(label: 'User', flex: 2),
                        _TableHeaderCell(label: 'Action', flex: 2),
                        _TableHeaderCell(label: 'Resource', flex: 2),
                        _TableHeaderCell(label: 'Status', flex: 2),
                        _TableHeaderCell(label: 'IP Address', flex: 2),
                      ],
                    ),
                  ),
                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 68),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text('No access logs available',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF9CA3AF))),
                          SizedBox(height: 6),
                          Text(
                              'System access history will appear here once recorded',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF9CA3AF))),
                        ],
                      ),
                    )
                  else
                    for (int i = 0; i < filtered.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 20),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                _formatTime(filtered[i].time),
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF4B5563)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                filtered[i].user,
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF1F2937)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                filtered[i].action,
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF4B5563)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                filtered[i].resource,
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF4B5563)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                filtered[i].status,
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF4B5563)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                filtered[i].ipAddress,
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF4B5563)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i != filtered.length - 1)
                        const Divider(
                            height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        for (int i = 0; i < children.length; i++) ...[
          if (i != 0) const SizedBox(height: 20),
          children[i],
        ],
      ],
    );
  }
}

class _SettingToggleRow extends StatelessWidget {
  const _SettingToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937))),
              const SizedBox(height: 6),
              Text(subtitle,
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          thumbColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? const Color(0xFFD97706)
                  : null),
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? const Color(0xFFD97706)
                  : null),
        ),
      ],
    );
  }
}

class _SettingInputRow extends StatelessWidget {
  const _SettingInputRow({
    required this.title,
    required this.subtitle,
    required this.controller,
  });

  final String title;
  final String subtitle;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937))),
              const SizedBox(height: 6),
              Text(subtitle,
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            ],
          ),
        ),
        const SizedBox(width: 20),
        SizedBox(
          width: 120,
          child: VoiceTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFFD700)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LogsSearchField extends StatelessWidget {
  const _LogsSearchField({required this.controller, required this.onClear});

  final TextEditingController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return VoiceTextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Search logs.',
            prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close,
                        size: 18, color: Color(0xFF9CA3AF)),
                  ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFFD700)),
            ),
          ),
        );
      },
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: value,
            hint: const Text('Status',
                style: TextStyle(fontSize: 14, color: Color(0xFF4B5563))),
            icon: const Icon(Icons.expand_more, color: Color(0xFF9CA3AF)),
            items: const [
              DropdownMenuItem<String?>(
                  value: null, child: Text('All statuses')),
              DropdownMenuItem<String?>(
                  value: 'Success', child: Text('Success')),
              DropdownMenuItem<String?>(
                  value: 'Failure', child: Text('Failure')),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _RolesView extends StatelessWidget {
  const _RolesView({required this.roles, required this.onAdd});

  final List<_RoleRowData> roles;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    const roles = [
      _RoleRowData(
        name: 'Admin',
        tierLabel: 'Tier 1',
        tierVariant: _TierBadgeVariant.primary,
        description: 'Full system access',
        created: '4/9/2025',
      ),
      _RoleRowData(
        name: 'Manager',
        tierLabel: 'Tier 2',
        tierVariant: _TierBadgeVariant.text,
        description: 'Contract approvals and team management',
        created: '4/9/2025',
      ),
      _RoleRowData(
        name: 'Contractor',
        tierLabel: 'Tier 3',
        tierVariant: _TierBadgeVariant.neutral,
        description: 'Basic contract viewing and updates',
        created: '4/9/2025',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 14)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.groups_outlined,
                    color: Color(0xFFD97706), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Role Management',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827)),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Configure user access roles and permissions',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Create Role'),
              ),
            ],
          ),
          const SizedBox(height: 30),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                color: Colors.white,
              ),
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFFF9FAFB),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Row(
                      children: const [
                        _TableHeaderCell(label: 'Role Name', flex: 2),
                        _TableHeaderCell(label: 'Tier'),
                        _TableHeaderCell(label: 'Description', flex: 3),
                        _TableHeaderCell(label: 'Created'),
                        _TableHeaderCell(
                            label: 'Actions', flex: 2, align: TextAlign.right),
                      ],
                    ),
                  ),
                  if (roles.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      alignment: Alignment.center,
                      child: const Text(
                        'No roles added yet',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    )
                  else
                    for (int i = 0; i < roles.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 22),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                roles[i].name,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937)),
                              ),
                            ),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _RoleTierBadge(
                                  label: roles[i].tierLabel,
                                  variant: roles[i].tierVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                roles[i].description,
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF4B5563)),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                roles[i].created,
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF4B5563)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(
                                  spacing: 10,
                                  children: const [
                                    _TableActionButton(label: 'Edit'),
                                    _TableActionButton(label: 'Permissions'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i != roles.length - 1)
                        const Divider(
                            height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                    ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Available system roles',
            style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _PermissionsView extends StatefulWidget {
  const _PermissionsView({required this.permissions, required this.onAdd});

  final List<_PermissionRowData> permissions;
  final VoidCallback onAdd;

  @override
  State<_PermissionsView> createState() => _PermissionsViewState();
}

class _PermissionsViewState extends State<_PermissionsView> {
  String? _selectedResource;

  @override
  Widget build(BuildContext context) {
    const permissions = [
      _PermissionRowData(
          name: 'Create Contract',
          resource: 'contracts',
          action: 'create',
          description: 'Create new contracts'),
      _PermissionRowData(
          name: 'Read Contract',
          resource: 'contracts',
          action: 'read',
          description: 'View contract details'),
      _PermissionRowData(
          name: 'Update Contract',
          resource: 'contracts',
          action: 'update',
          description: 'Edit existing contracts'),
      _PermissionRowData(
          name: 'Delete Contract',
          resource: 'contracts',
          action: 'delete',
          description: 'Remove contracts from the system'),
      _PermissionRowData(
          name: 'Approve Contract',
          resource: 'contracts',
          action: 'approve',
          description: 'Approve contracts for execution'),
      _PermissionRowData(
          name: 'Create Bid',
          resource: 'bids',
          action: 'create',
          description: 'Create vendor bids'),
      _PermissionRowData(
          name: 'Read Bid',
          resource: 'bids',
          action: 'read',
          description: 'View bid details'),
      _PermissionRowData(
          name: 'Select Bid',
          resource: 'bids',
          action: 'select',
          description: 'Select winning bids'),
      _PermissionRowData(
          name: 'Access Reports',
          resource: 'reports',
          action: 'read',
          description: 'Access system reports and analytics'),
      _PermissionRowData(
          name: 'Manage Users',
          resource: 'users',
          action: 'manage',
          description: 'Create and edit user accounts'),
      _PermissionRowData(
          name: 'Manage Roles',
          resource: 'roles',
          action: 'manage',
          description: 'Create and edit roles'),
      _PermissionRowData(
          name: 'View Audit Log',
          resource: 'audit',
          action: 'read',
          description: 'Access system audit logs'),
    ];

    final filteredPermissions = _selectedResource == null
        ? permissions
        : permissions
            .where((permission) => permission.resource == _selectedResource)
            .toList();

    final resourceFilters = <String>{
      for (final item in permissions) item.resource
    }.toList()
      ..sort();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 14)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEFCE8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lock_open_outlined,
                    color: Color(0xFFB45309), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Permissions',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827)),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'System permissions for resources and actions',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              OutlinedButton.icon(
                onPressed: widget.onAdd,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1F2937),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Permission'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedResource,
                  hint: const Text('Filter by resource',
                      style: TextStyle(fontSize: 14, color: Color(0xFF4B5563))),
                  icon: const Icon(Icons.expand_more, color: Color(0xFF9CA3AF)),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All resources'),
                    ),
                    for (final resource in resourceFilters)
                      DropdownMenuItem<String?>(
                        value: resource,
                        child: Text(resource),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedResource = value);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                color: Colors.white,
              ),
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFFF9FAFB),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Row(
                      children: const [
                        _TableHeaderCell(label: 'Permission Name', flex: 2),
                        _TableHeaderCell(label: 'Resource'),
                        _TableHeaderCell(label: 'Action'),
                        _TableHeaderCell(label: 'Description', flex: 3),
                      ],
                    ),
                  ),
                  if (filteredPermissions.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      alignment: Alignment.center,
                      child: const Text(
                          'No permissions found for this resource',
                          style: TextStyle(color: Color(0xFF9CA3AF))),
                    )
                  else
                    for (int i = 0; i < filteredPermissions.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 20),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                filteredPermissions[i].name,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937)),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                filteredPermissions[i].resource,
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF4B5563)),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                filteredPermissions[i].action,
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF4B5563)),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                filteredPermissions[i].description,
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF4B5563)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i != filteredPermissions.length - 1)
                        const Divider(
                            height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                    ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'System permissions',
            style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _RoleRowData {
  const _RoleRowData({
    this.id = '',
    required this.name,
    required this.tierLabel,
    required this.tierVariant,
    required this.description,
    required this.created,
  });

  final String id;
  final String name;
  final String tierLabel;
  final _TierBadgeVariant tierVariant;
  final String description;
  final String created;

  factory _RoleRowData.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final tierLabel = data['tierLabel']?.toString() ?? 'Tier 1';
    return _RoleRowData(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      tierLabel: tierLabel,
      tierVariant: _tierVariantFromLabel(tierLabel),
      description: data['description']?.toString() ?? '',
      created: _formatShortDate(_readTimestamp(data['createdAt'])),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'tierLabel': tierLabel,
      'description': description,
      'createdAt': Timestamp.now(),
    };
  }
}

enum _TierBadgeVariant { primary, neutral, text }

class _RoleTierBadge extends StatelessWidget {
  const _RoleTierBadge({required this.label, required this.variant});

  final String label;
  final _TierBadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case _TierBadgeVariant.primary:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFD97706),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        );
      case _TierBadgeVariant.neutral:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        );
      case _TierBadgeVariant.text:
        return Text(label,
            style: const TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 14,
                fontWeight: FontWeight.w600));
    }
  }
}

class _PermissionRowData {
  const _PermissionRowData({
    this.id = '',
    required this.name,
    required this.resource,
    required this.action,
    required this.description,
  });

  final String id;
  final String name;
  final String resource;
  final String action;
  final String description;

  factory _PermissionRowData.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return _PermissionRowData(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      resource: data['resource']?.toString() ?? '',
      action: data['action']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'resource': resource,
      'action': action,
      'description': description,
      'createdAt': Timestamp.now(),
    };
  }
}

class _SettingEntry {
  const _SettingEntry({
    required this.id,
    required this.name,
    required this.value,
    required this.description,
    required this.updated,
  });

  final String id;
  final String name;
  final String value;
  final String description;
  final String updated;

  factory _SettingEntry.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return _SettingEntry(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      value: data['value']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      updated: _formatShortDate(_readTimestamp(data['createdAt'])),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'value': value,
      'description': description,
      'createdAt': Timestamp.now(),
    };
  }
}

class _AccessLogEntry {
  const _AccessLogEntry({
    required this.id,
    required this.time,
    required this.user,
    required this.action,
    required this.resource,
    required this.status,
    required this.ipAddress,
  });

  final String id;
  final DateTime time;
  final String user;
  final String action;
  final String resource;
  final String status;
  final String ipAddress;

  factory _AccessLogEntry.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return _AccessLogEntry(
      id: doc.id,
      time: _readTimestamp(data['time']),
      user: data['user']?.toString() ?? '',
      action: data['action']?.toString() ?? '',
      resource: data['resource']?.toString() ?? '',
      status: data['status']?.toString() ?? '',
      ipAddress: data['ipAddress']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'time': Timestamp.fromDate(time),
      'user': user,
      'action': action,
      'resource': resource,
      'status': status,
      'ipAddress': ipAddress,
    };
  }
}

class _SystemSettingsData {
  const _SystemSettingsData({
    required this.sessionTimeoutMinutes,
    required this.minPasswordLength,
    required this.requireMfa,
    required this.requireUppercase,
    required this.requireNumbers,
    required this.requireSpecial,
  });

  final int sessionTimeoutMinutes;
  final int minPasswordLength;
  final bool requireMfa;
  final bool requireUppercase;
  final bool requireNumbers;
  final bool requireSpecial;

  factory _SystemSettingsData.defaults() {
    return const _SystemSettingsData(
      sessionTimeoutMinutes: 30,
      minPasswordLength: 10,
      requireMfa: true,
      requireUppercase: true,
      requireNumbers: true,
      requireSpecial: true,
    );
  }

  factory _SystemSettingsData.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return _SystemSettingsData.defaults();
    return _SystemSettingsData(
      sessionTimeoutMinutes:
          (data['sessionTimeoutMinutes'] as num?)?.toInt() ?? 30,
      minPasswordLength: (data['minPasswordLength'] as num?)?.toInt() ?? 10,
      requireMfa: data['requireMfa'] as bool? ?? true,
      requireUppercase: data['requireUppercase'] as bool? ?? true,
      requireNumbers: data['requireNumbers'] as bool? ?? true,
      requireSpecial: data['requireSpecial'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'sessionTimeoutMinutes': sessionTimeoutMinutes,
      'minPasswordLength': minPasswordLength,
      'requireMfa': requireMfa,
      'requireUppercase': requireUppercase,
      'requireNumbers': requireNumbers,
      'requireSpecial': requireSpecial,
      'updatedAt': Timestamp.now(),
    };
  }
}

class _TableHeaderCell extends StatelessWidget {
  const _TableHeaderCell(
      {required this.label, this.flex = 1, this.align = TextAlign.left});

  final String label;
  final int flex;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: align,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
            letterSpacing: 0.2),
      ),
    );
  }
}

class _TableActionButton extends StatelessWidget {
  const _TableActionButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1F2937),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label),
    );
  }
}

class _RoleTiersCard extends StatelessWidget {
  const _RoleTiersCard({required this.roles});

  final List<_RoleRowData> roles;

  @override
  Widget build(BuildContext context) {
    final tierCounts = <String, int>{
      'Tier 1': 0,
      'Tier 2': 0,
      'Tier 3': 0,
      'Other': 0
    };
    for (final role in roles) {
      final label = role.tierLabel.toLowerCase();
      if (label.contains('1')) {
        tierCounts['Tier 1'] = tierCounts['Tier 1']! + 1;
      } else if (label.contains('2')) {
        tierCounts['Tier 2'] = tierCounts['Tier 2']! + 1;
      } else if (label.contains('3')) {
        tierCounts['Tier 3'] = tierCounts['Tier 3']! + 1;
      } else {
        tierCounts['Other'] = tierCounts['Other']! + 1;
      }
    }
    final total = roles.isEmpty ? 1 : roles.length;
    final slices = [
      _PieSlice(
          color: const Color(0xFF0EA5E9),
          value: tierCounts['Tier 1']!.toDouble(),
          label: 'Tier 1'),
      _PieSlice(
          color: const Color(0xFFFBBF24),
          value: tierCounts['Tier 2']!.toDouble(),
          label: 'Tier 2'),
      _PieSlice(
          color: const Color(0xFF22D3EE),
          value: tierCounts['Tier 3']!.toDouble(),
          label: 'Tier 3'),
      _PieSlice(
          color: const Color(0xFFCBD5F5),
          value: tierCounts['Other']!.toDouble(),
          label: 'Other'),
    ].where((slice) => slice.value > 0).toList();

    return _MetricCard(
      headerIcon: Icons.radio_button_checked_outlined,
      headerTitle: 'Role Tiers',
      headerSubtitle: 'Access level distribution',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (roles.isEmpty)
            const _EmptyMetricState(
              icon: Icons.badge_outlined,
              title: 'No roles yet',
              message: 'Add roles to track tier distribution.',
            )
          else ...[
            _PieChart(slices: slices),
            const SizedBox(height: 18),
            _PieLegend(
              entries: [
                _LegendEntry(
                    label: 'Tier 1',
                    value: '${_percent(tierCounts['Tier 1']!, total)}%',
                    color: const Color(0xFF0EA5E9)),
                _LegendEntry(
                    label: 'Tier 2',
                    value: '${_percent(tierCounts['Tier 2']!, total)}%',
                    color: const Color(0xFFFBBF24)),
                _LegendEntry(
                    label: 'Tier 3',
                    value: '${_percent(tierCounts['Tier 3']!, total)}%',
                    color: const Color(0xFF22D3EE)),
                if (tierCounts['Other']! > 0)
                  _LegendEntry(
                      label: 'Other',
                      value: '${_percent(tierCounts['Other']!, total)}%',
                      color: const Color(0xFFCBD5F5)),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Total Roles: ${roles.length}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResourcePermissionsCard extends StatelessWidget {
  const _ResourcePermissionsCard({required this.permissions});

  final List<_PermissionRowData> permissions;

  @override
  Widget build(BuildContext context) {
    final Map<String, int> resourceCounts = {};
    for (final permission in permissions) {
      resourceCounts[permission.resource] =
          (resourceCounts[permission.resource] ?? 0) + 1;
    }
    final sorted = resourceCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();
    final total = permissions.isEmpty ? 1 : permissions.length;
    final slices = [
      for (int i = 0; i < top.length; i++)
        _PieSlice(
            color: _resourceColor(i),
            value: top[i].value.toDouble(),
            label: top[i].key),
    ];

    return _MetricCard(
      headerIcon: Icons.lock_person_outlined,
      headerTitle: 'Resource Permissions',
      headerSubtitle: 'Permissions by resource type',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (permissions.isEmpty)
            const _EmptyMetricState(
              icon: Icons.lock_open_outlined,
              title: 'No permissions yet',
              message: 'Add permissions to track resource coverage.',
            )
          else ...[
            _PieChart(slices: slices),
            const SizedBox(height: 18),
            _PieLegend(
              wrap: true,
              entries: [
                for (int i = 0; i < top.length; i++)
                  _LegendEntry(
                    label: top[i].key,
                    value: '${_percent(top[i].value, total)}%',
                    color: _resourceColor(i),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Total Permissions: ${permissions.length}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280)),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatShortDate(DateTime date) {
  return '${date.month}/${date.day}/${date.year}';
}

String _formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.month}/${date.day} $hour:$minute';
}

DateTime _readTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}

int _percent(int value, int total) {
  if (total == 0) return 0;
  return ((value / total) * 100).round();
}

Color _resourceColor(int index) {
  const palette = [
    Color(0xFF22D3EE),
    Color(0xFFF97316),
    Color(0xFF6366F1),
    Color(0xFFFB7185),
    Color(0xFF34D399),
  ];
  return palette[index % palette.length];
}

_TierBadgeVariant _tierVariantFromLabel(String tierLabel) {
  final label = tierLabel.toLowerCase();
  if (label.contains('1')) return _TierBadgeVariant.primary;
  if (label.contains('2')) return _TierBadgeVariant.text;
  if (label.contains('3')) return _TierBadgeVariant.neutral;
  return _TierBadgeVariant.neutral;
}

class _SecurityStatusCard extends StatelessWidget {
  const _SecurityStatusCard({
    required this.rolesCount,
    required this.permissionsCount,
    required this.settingsCount,
    required this.latestLog,
  });

  final int rolesCount;
  final int permissionsCount;
  final int settingsCount;
  final _AccessLogEntry? latestLog;

  @override
  Widget build(BuildContext context) {
    return _MetricCard(
      headerIcon: Icons.shield_outlined,
      headerTitle: 'Security Status',
      headerSubtitle: 'Critical security settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          _StatusTile(
            icon: Icons.badge_outlined,
            label: 'Roles configured',
            value: rolesCount.toString(),
          ),
          const SizedBox(height: 12),
          _StatusTile(
            icon: Icons.lock_open_outlined,
            label: 'Permissions defined',
            value: permissionsCount.toString(),
          ),
          const SizedBox(height: 12),
          _StatusTile(
            icon: Icons.settings_outlined,
            label: 'Custom settings',
            value: settingsCount.toString(),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.withOpacity(0.2), height: 1),
          const SizedBox(height: 16),
          Text(
            latestLog == null
                ? 'No security activity yet'
                : 'Latest activity ${_formatTime(latestLog!.time)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFD97706), size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1D1F))),
              const SizedBox(height: 4),
              const Text('Active',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF4FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD97706)),
          ),
        ),
      ],
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.logs});

  final List<_AccessLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    final recent = logs.take(5).toList();
    return _MetricCard(
      padding: const EdgeInsets.all(26),
      headerIcon: Icons.description_outlined,
      headerTitle: 'Recent Activity',
      headerSubtitle: 'System access and security events',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          if (recent.isEmpty)
            SizedBox(
              height: 200,
              child: _DashedBorderBox(
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: const Color(0xFFF9FAFB),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.timeline_outlined,
                          color: Color(0xFFD1D5DB), size: 42),
                      SizedBox(height: 12),
                      Text('No activity yet',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9CA3AF))),
                      SizedBox(height: 4),
                      Text('Security logs will appear here when available',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < recent.length; i++) ...[
                  _ActivityRow(entry: recent[i]),
                  if (i != recent.length - 1)
                    const Divider(
                        height: 18, thickness: 1, color: Color(0xFFE5E7EB)),
                ],
              ],
            ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: const [
              _LegendEntry(
                  label: 'Success',
                  value: '',
                  color: Color(0xFF10B981),
                  inline: true),
              _LegendEntry(
                  label: 'Failure',
                  value: '',
                  color: Color(0xFFEF4444),
                  inline: true),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                foregroundColor: const Color(0xFF1A1D1F),
                textStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('View All Logs'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});

  final _AccessLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final statusColor = entry.status.toLowerCase() == 'success'
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.event_note_outlined, color: statusColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.action,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827))),
              const SizedBox(height: 4),
              Text(
                '${entry.user} • ${entry.resource}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(entry.status,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor)),
            const SizedBox(height: 4),
            Text(_formatTime(entry.time),
                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          ],
        ),
      ],
    );
  }
}

class _EmptyMetricState extends StatelessWidget {
  const _EmptyMetricState(
      {required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFD1D5DB), size: 38),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF))),
            const SizedBox(height: 4),
            Text(message,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderBox extends StatelessWidget {
  const _DashedBorderBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFFE0E7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final RRect rrect =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18));
    final Path path = Path()..addRRect(rrect);

    for (final ui.PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      const double dashLength = 8;
      const double gapLength = 6;
      while (distance < metric.length) {
        final double next = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.headerIcon,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final IconData headerIcon;
  final String headerTitle;
  final String headerSubtitle;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 18,
              offset: const Offset(0, 10)),
        ],
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(headerIcon, size: 18, color: const Color(0xFFD97706)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headerTitle,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827))),
                    const SizedBox(height: 4),
                    Text(
                      headerSubtitle,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _PieChart extends StatelessWidget {
  const _PieChart({required this.slices});

  final List<_PieSlice> slices;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: CustomPaint(
        painter: _PieChartPainter(slices),
        child: Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 12,
                    offset: Offset(0, 6)),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              '100%',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827)),
            ),
          ),
        ),
      ),
    );
  }
}

class _PieSlice {
  const _PieSlice(
      {required this.color, required this.value, required this.label});

  final Color color;
  final double value;
  final String label;
}

class _PieChartPainter extends CustomPainter {
  const _PieChartPainter(this.slices);

  final List<_PieSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = math.min(size.width, size.height) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double total = slices.fold(0, (total, slice) => total + slice.value);
    double startRadian = -math.pi / 2;

    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (final slice in slices) {
      final double sweepRadian = (slice.value / total) * 2 * math.pi;
      paint.color = slice.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startRadian,
        sweepRadian,
        true,
        paint,
      );
      startRadian += sweepRadian;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PieLegend extends StatelessWidget {
  const _PieLegend({required this.entries, this.wrap = false});

  final List<_LegendEntry> entries;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final children = entries.map((entry) => entry).toList();
    if (wrap) {
      return Wrap(spacing: 16, runSpacing: 8, children: children);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry(
      {required this.label,
      required this.value,
      required this.color,
      this.inline = false});

  final String label;
  final String value;
  final Color color;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    if (inline) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 8),
          const SizedBox(width: 8),
          Text(label.toLowerCase(),
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827))),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      ],
    );
  }
}
