import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/openai/openai_config.dart';
import 'package:ndu_project/models/user_role.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/services/permission_service.dart';
import 'package:ndu_project/services/subscription_service.dart';
import 'package:ndu_project/widgets/api_key_input_dialog.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/services/currency_service.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/providers/app_content_provider.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/utils/web_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/providers/theme_provider.dart';
import 'package:ndu_project/services/hint_service.dart';
import 'package:ndu_project/services/auth_nav.dart';
import 'package:ndu_project/services/security_services.dart';
import 'package:ndu_project/screens/mfa_enrollment_screen.dart';
import 'package:ndu_project/screens/recovery_codes_screen.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/inner_page_navigation_hint.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static void open(BuildContext context) {
    try {
      // Prefer URL-aware navigation when available
      // ignore: invalid_use_of_visible_for_testing_member
      context.pushNamed(AppRoutes.settings);
    } catch (e) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    }
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  // Removed 'Account' and 'Team' tabs per request
  bool get _isAdminDomain => getCurrentHostname() == 'admin.nduproject.com';

  List<String> get _tabs {
    final tabs = <String>[
      'Preferences',
      'Access & Collaborators',
      'Billing & Subscription',
      'Report & Analysis',
    ];
    // Add Integrations and Edit Content tabs only for admin domain
    if (_isAdminDomain) {
      tabs.insert(1, 'Integrations');
      tabs.add('Security');
      tabs.add('Edit Content');
    }
    return tabs;
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── SharedPreferences keys ──
  static const _prefLanguage = 'pref_language';
  static const _prefTimezone = 'pref_timezone';
  static const _prefDateFormat = 'pref_date_format';
  static const _prefEmailNotif = 'pref_email_notif';
  static const _prefPushNotif = 'pref_push_notif';
  static const _prefWeeklyDigest = 'pref_weekly_digest';
  static const _prefProjectUpdates = 'pref_project_updates';
  static const _prefSecurityAlerts = 'pref_security_alerts';
  static const _prefFontSize = 'pref_font_size';
  static const _prefCompactMode = 'pref_compact_mode';
  static const _prefReduceAnimations = 'pref_reduce_animations';

  // ── Preference state ──
  String _language = 'English';
  String _timezone = 'UTC';
  String _dateFormat = 'MM/dd/yyyy';
  bool _emailNotif = true;
  bool _pushNotif = true;
  bool _weeklyDigest = false;
  bool _projectUpdates = true;
  bool _securityAlerts = true;
  String _fontSize = 'medium'; // 'small', 'medium', 'large'
  bool _compactMode = false;
  bool _reduceAnimations = false;
  bool _twoFactorEnabled = false;
  bool _twoFactorLoading = true;
  bool _passwordLoginEnabled = true;
  bool _passwordlessEmailEnabled = false;
  bool _mfaEnabledPolicy = true;
  MfaMethod _defaultMfaMethod = MfaMethod.authenticator;
  final Set<MfaMethod> _backupMfaMethods = {
    MfaMethod.sms,
    MfaMethod.emailCode,
  };
  MfaRequirement _mfaRequirement = MfaRequirement.everyLogin;
  int _rememberDeviceDays = 30;

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _language = prefs.getString(_prefLanguage) ?? 'English';
      _timezone = prefs.getString(_prefTimezone) ?? 'UTC';
      _dateFormat = prefs.getString(_prefDateFormat) ?? 'MM/dd/yyyy';
      _emailNotif = prefs.getBool(_prefEmailNotif) ?? true;
      _pushNotif = prefs.getBool(_prefPushNotif) ?? true;
      _weeklyDigest = prefs.getBool(_prefWeeklyDigest) ?? false;
      _projectUpdates = prefs.getBool(_prefProjectUpdates) ?? true;
      _securityAlerts = prefs.getBool(_prefSecurityAlerts) ?? true;
      _fontSize = prefs.getString(_prefFontSize) ?? 'medium';
      _compactMode = prefs.getBool(_prefCompactMode) ?? false;
      _reduceAnimations = prefs.getBool(_prefReduceAnimations) ?? false;
    });
    // Load 2FA status
    try {
      final enabled = await TwoFactorAuthService.isEnabled();
      final policy = await TwoFactorAuthService.loadPolicy();
      if (mounted) {
        setState(() {
          _twoFactorEnabled = enabled;
          _twoFactorLoading = false;
          _passwordLoginEnabled = policy.passwordLoginEnabled;
          _passwordlessEmailEnabled = policy.passwordlessEmailEnabled;
          _mfaEnabledPolicy = policy.mfaEnabled;
          _defaultMfaMethod = policy.defaultMfaMethod;
          _backupMfaMethods
            ..clear()
            ..addAll(policy.backupMethods);
          _mfaRequirement = policy.requireMfaEveryLogin
              ? MfaRequirement.everyLogin
              : policy.requireMfaNewDeviceOnly
                  ? MfaRequirement.newDeviceOnly
                  : policy.requireMfaHighRiskOnly
                      ? MfaRequirement.highRiskOnly
                      : MfaRequirement.adminOnly;
          _rememberDeviceDays = policy.rememberDeviceDays;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _twoFactorLoading = false);
    }
  }

  Future<void> _setPref(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    // Load saved preferences
    _loadPreferences();
    // Load default currency
    CurrencyService.instance.load().then((_) {
      if (mounted) setState(() {});
    });
    // Ensure user-specific OpenAI key is loaded from Firestore if present
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ApiKeyManager.ensureLoadedForSignedInUser();
      if (mounted) setState(() {});
    });
    // Removed auto banner popup on page load per request
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fromRoute = GoRouterState.of(context).uri.queryParameters['from'];
    final openedFromDashboard = fromRoute == AppRoutes.dashboard ||
        fromRoute == AppRoutes.programDashboard ||
        fromRoute == AppRoutes.portfolioDashboard;
    void handleBackNavigation() {
      if (openedFromDashboard && (fromRoute ?? '').isNotEmpty) {
        context.go('/$fromRoute');
        return;
      }
      context.go('/${AppRoutes.dashboard}');
    }

    return ResponsiveScaffold(
      activeItemLabel: 'Settings',
      showSidebar: false,
      backgroundColor: Colors.white,
      appBarTitle: 'Settings',
      floatingActionButton: const KazAiChatBubble(positioned: false),
      body: Column(
        children: [
          // TopAppBar
          _TopAppBar(onBack: handleBackNavigation),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InnerPageNavigationHint(
                        pageId: 'settings',
                        pageTitle: 'Settings',
                        description: 'Navigate between settings sections',
                        currentSectionId: _tabs[_tabController.index],
                        sections: [
                          InnerPageSection(
                              id: 'Preferences',
                              label: 'Preferences',
                              icon: Icons.tune,
                              status: _tabController.index ==
                                      _tabs.indexOf('Preferences')
                                  ? InnerPageSectionStatus.current
                                  : InnerPageSectionStatus.available,
                              stepNumber: 1),
                          if (_isAdminDomain)
                            InnerPageSection(
                                id: 'Integrations',
                                label: 'Integrations',
                                icon: Icons.integration_instructions,
                                status: _tabController.index ==
                                        _tabs.indexOf('Integrations')
                                    ? InnerPageSectionStatus.current
                                    : InnerPageSectionStatus.available,
                                stepNumber: 2),
                          InnerPageSection(
                              id: 'Access & Collaborators',
                              label: 'Access & Collaborators',
                              icon: Icons.people,
                              status: _tabController.index ==
                                      _tabs.indexOf('Access & Collaborators')
                                  ? InnerPageSectionStatus.current
                                  : InnerPageSectionStatus.available,
                              stepNumber: _isAdminDomain ? 3 : 2),
                          InnerPageSection(
                              id: 'Billing & Subscription',
                              label: 'Billing & Subscription',
                              icon: Icons.credit_card,
                              status: _tabController.index ==
                                      _tabs.indexOf('Billing & Subscription')
                                  ? InnerPageSectionStatus.current
                                  : InnerPageSectionStatus.available,
                              stepNumber: _isAdminDomain ? 4 : 3),
                          InnerPageSection(
                              id: 'Report & Analysis',
                              label: 'Report & Analysis',
                              icon: Icons.analytics,
                              status: _tabController.index ==
                                      _tabs.indexOf('Report & Analysis')
                                  ? InnerPageSectionStatus.current
                                  : InnerPageSectionStatus.available,
                              stepNumber: _isAdminDomain ? 5 : 4),
                          if (_isAdminDomain)
                            InnerPageSection(
                                id: 'Security',
                                label: 'Security',
                                icon: Icons.security,
                                status: _tabController.index ==
                                        _tabs.indexOf('Security')
                                    ? InnerPageSectionStatus.current
                                    : InnerPageSectionStatus.available,
                                stepNumber: 6),
                          if (_isAdminDomain)
                            InnerPageSection(
                                id: 'Edit Content',
                                label: 'Edit Content',
                                icon: Icons.edit_note,
                                status: _tabController.index ==
                                        _tabs.indexOf('Edit Content')
                                    ? InnerPageSectionStatus.current
                                    : InnerPageSectionStatus.available,
                                stepNumber: 7),
                        ],
                        onSectionTap: (sectionId) {
                          final index = _tabs.indexOf(sectionId);
                          if (index >= 0) {
                            _tabController.animateTo(index);
                            setState(() {});
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      _builderForTab(_tabController.index),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSecurityPolicy() async {
    final policy = SecurityPolicy(
      passwordLoginEnabled: _passwordLoginEnabled,
      passwordlessEmailEnabled: _passwordlessEmailEnabled,
      mfaEnabled: _mfaEnabledPolicy,
      requireMfaEveryLogin: _mfaRequirement == MfaRequirement.everyLogin,
      requireMfaNewDeviceOnly: _mfaRequirement == MfaRequirement.newDeviceOnly,
      requireMfaHighRiskOnly: _mfaRequirement == MfaRequirement.highRiskOnly,
      requireMfaAdminOnly: _mfaRequirement == MfaRequirement.adminOnly,
      defaultMfaMethod: _defaultMfaMethod,
      backupMethods: _backupMfaMethods.toList(),
      rememberDeviceDays: _rememberDeviceDays,
    );
    await TwoFactorAuthService.savePolicy(policy);
  }

  void _handleLogout() {
    AuthNav.signOutAndExit(context);
  }

  Widget _builderForTab(int index) {
    final tab = _tabs[index];
    switch (tab) {
      case 'Preferences':
        return _preferencesPanel();
      case 'Integrations':
        return _integrationsPanel();
      case 'Access & Collaborators':
        return const _AccessCollaboratorsPanel();
      case 'Billing & Subscription':
        return _billingSubscriptionPanel();
      case 'Report & Analysis':
        return _reportAnalysisPanel();
      case 'Security':
        return const _SecuritySettingsTab();
      case 'Edit Content':
        return _editContentPanel();
      default:
        return _preferencesPanel();
    }
  }

  // ────────────────────────────────────────────────────────────────
  //  PREFERENCES PANEL
  // ────────────────────────────────────────────────────────────────
  Widget _preferencesPanel() {
    const accent = Color(0xFFFFC107);
    final theme = Theme.of(context);

    Widget sectionCard(
        {required String title,
        required IconData icon,
        required List<Widget> children}) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white,
          border: Border.all(color: Colors.grey.withOpacity(0.12)),
          boxShadow: const [
            BoxShadow(
                blurRadius: 18, offset: Offset(0, 14), color: Color(0x0F000000))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      );
    }

    Widget toggleRow(String label, bool value, ValueChanged<bool> onChanged,
        {IconData? icon}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: Colors.black54),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: accent,
              trackColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? accent.withOpacity(0.4)
                      : null),
            ),
          ],
        ),
      );
    }

    Widget dropdownRow(String label, String value, List<String> options,
        ValueChanged<String?> onChanged,
        {IconData? icon}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: Colors.black54),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.25)),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButton<String>(
                value: value,
                underline: const SizedBox(),
                borderRadius: BorderRadius.circular(12),
                items: options
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildDefaultCurrencyRow() {
      final currencyService = CurrencyService.instance;
      final currentCode = currencyService.defaultCurrencyCode;
      final currencies = CurrencyService.supportedCurrencies;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.attach_money, size: 20, color: Colors.black54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Default Currency',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('Used across all cost estimates and financial displays',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.25)),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButton<String>(
                value: currentCode,
                underline: const SizedBox(),
                borderRadius: BorderRadius.circular(12),
                items: currencies
                    .map((c) => DropdownMenuItem(
                          value: c.code,
                          child: Text('${c.code} (${c.symbol})',
                              style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (code) async {
                  if (code == null) return;
                  await currencyService.setDefaultCurrency(code);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Default currency set to $code'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 860;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero banner ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF020617), Color(0xFF1E1B4B)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('Preferences',
                              style: theme.textTheme.labelMedium?.copyWith(
                                  color: accent, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.tune, color: accent, size: 20),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Customize Your Experience',
                        style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Text(
                        'Personalize appearance, notifications, and privacy settings to match your workflow.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withOpacity(0.78),
                            height: 1.45)),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Appearance ──
              sectionCard(
                title: 'Appearance',
                icon: Icons.palette_outlined,
                children: [
                  const Text('Theme mode',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, _) {
                      final currentLabel = themeProvider.themeModeLabel;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _ThemeModeOption(
                            label: 'Light',
                            icon: Icons.light_mode,
                            selected: currentLabel == 'light',
                            accent: accent,
                            onTap: () {
                              themeProvider.setThemeMode(ThemeMode.light);
                            },
                          ),
                          _ThemeModeOption(
                            label: 'Dark',
                            icon: Icons.dark_mode,
                            selected: currentLabel == 'dark',
                            accent: accent,
                            onTap: () {
                              themeProvider.setThemeMode(ThemeMode.dark);
                            },
                          ),
                          _ThemeModeOption(
                            label: 'System',
                            icon: Icons.settings_suggest,
                            selected: currentLabel == 'system',
                            accent: accent,
                            onTap: () {
                              themeProvider.setThemeMode(ThemeMode.system);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Language & Region ──
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: sectionCard(
                        title: 'Language & Region',
                        icon: Icons.language,
                        children: [
                          dropdownRow('Language', _language, [
                            'English',
                            'French',
                            'Spanish',
                            'German',
                            'Portuguese',
                            'Arabic',
                            'Chinese',
                            'Japanese'
                          ], (v) {
                            if (v != null) {
                              setState(() => _language = v);
                              _setPref(_prefLanguage, v);
                            }
                          }, icon: Icons.translate),
                          const SizedBox(height: 8),
                          dropdownRow('Timezone', _timezone, [
                            'UTC',
                            'America/New_York',
                            'America/Chicago',
                            'America/Denver',
                            'America/Los_Angeles',
                            'Europe/London',
                            'Europe/Paris',
                            'Asia/Tokyo',
                            'Asia/Shanghai',
                            'Africa/Kinshasa'
                          ], (v) {
                            if (v != null) {
                              setState(() => _timezone = v);
                              _setPref(_prefTimezone, v);
                            }
                          }, icon: Icons.schedule),
                          const SizedBox(height: 8),
                          dropdownRow('Date format', _dateFormat, [
                            'MM/dd/yyyy',
                            'dd/MM/yyyy',
                            'yyyy-MM-dd',
                            'dd MMM yyyy',
                            'MMM dd, yyyy'
                          ], (v) {
                            if (v != null) {
                              setState(() => _dateFormat = v);
                              _setPref(_prefDateFormat, v);
                            }
                          }, icon: Icons.calendar_today),
                          const SizedBox(height: 8),
                          _buildDefaultCurrencyRow(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: sectionCard(
                        title: 'Notifications',
                        icon: Icons.notifications_outlined,
                        children: [
                          toggleRow('Email notifications', _emailNotif, (v) {
                            setState(() => _emailNotif = v);
                            _setPref(_prefEmailNotif, v);
                          }, icon: Icons.email_outlined),
                          toggleRow('Push notifications', _pushNotif, (v) {
                            setState(() => _pushNotif = v);
                            _setPref(_prefPushNotif, v);
                          }, icon: Icons.notifications_active_outlined),
                          toggleRow('Weekly digest', _weeklyDigest, (v) {
                            setState(() => _weeklyDigest = v);
                            _setPref(_prefWeeklyDigest, v);
                          }, icon: Icons.article_outlined),
                          toggleRow('Project updates', _projectUpdates, (v) {
                            setState(() => _projectUpdates = v);
                            _setPref(_prefProjectUpdates, v);
                          }, icon: Icons.update),
                          toggleRow('Security alerts', _securityAlerts, (v) {
                            setState(() => _securityAlerts = v);
                            _setPref(_prefSecurityAlerts, v);
                          }, icon: Icons.security_outlined),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                sectionCard(
                  title: 'Language & Region',
                  icon: Icons.language,
                  children: [
                    dropdownRow('Language', _language, [
                      'English',
                      'French',
                      'Spanish',
                      'German',
                      'Portuguese',
                      'Arabic',
                      'Chinese',
                      'Japanese'
                    ], (v) {
                      if (v != null) {
                        setState(() => _language = v);
                        _setPref(_prefLanguage, v);
                      }
                    }, icon: Icons.translate),
                    const SizedBox(height: 8),
                    dropdownRow('Timezone', _timezone, [
                      'UTC',
                      'America/New_York',
                      'America/Chicago',
                      'America/Denver',
                      'America/Los_Angeles',
                      'Europe/London',
                      'Europe/Paris',
                      'Asia/Tokyo',
                      'Asia/Shanghai',
                      'Africa/Kinshasa'
                    ], (v) {
                      if (v != null) {
                        setState(() => _timezone = v);
                        _setPref(_prefTimezone, v);
                      }
                    }, icon: Icons.schedule),
                    const SizedBox(height: 8),
                    dropdownRow('Date format', _dateFormat, [
                      'MM/dd/yyyy',
                      'dd/MM/yyyy',
                      'yyyy-MM-dd',
                      'dd MMM yyyy',
                      'MMM dd, yyyy'
                    ], (v) {
                      if (v != null) {
                        setState(() => _dateFormat = v);
                        _setPref(_prefDateFormat, v);
                      }
                    }, icon: Icons.calendar_today),
                    const SizedBox(height: 8),
                    _buildDefaultCurrencyRow(),
                  ],
                ),
                const SizedBox(height: 20),
                sectionCard(
                  title: 'Notifications',
                  icon: Icons.notifications_outlined,
                  children: [
                    toggleRow('Email notifications', _emailNotif, (v) {
                      setState(() => _emailNotif = v);
                      _setPref(_prefEmailNotif, v);
                    }, icon: Icons.email_outlined),
                    toggleRow('Push notifications', _pushNotif, (v) {
                      setState(() => _pushNotif = v);
                      _setPref(_prefPushNotif, v);
                    }, icon: Icons.notifications_active_outlined),
                    toggleRow('Weekly digest', _weeklyDigest, (v) {
                      setState(() => _weeklyDigest = v);
                      _setPref(_prefWeeklyDigest, v);
                    }, icon: Icons.article_outlined),
                    toggleRow('Project updates', _projectUpdates, (v) {
                      setState(() => _projectUpdates = v);
                      _setPref(_prefProjectUpdates, v);
                    }, icon: Icons.update),
                    toggleRow('Security alerts', _securityAlerts, (v) {
                      setState(() => _securityAlerts = v);
                      _setPref(_prefSecurityAlerts, v);
                    }, icon: Icons.security_outlined),
                  ],
                ),
              ],
              const SizedBox(height: 20),

              // ── Display & Accessibility ──
              sectionCard(
                title: 'Display & Accessibility',
                icon: Icons.accessibility_new,
                children: [
                  const Text('Font size',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('A',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      Expanded(
                        child: Slider(
                          value: _fontSize == 'small'
                              ? 0
                              : _fontSize == 'medium'
                                  ? 0.5
                                  : 1.0,
                          divisions: 2,
                          activeColor: accent,
                          label: _fontSize == 'small'
                              ? 'Small'
                              : _fontSize == 'medium'
                                  ? 'Medium'
                                  : 'Large',
                          onChanged: (v) {
                            final size = v == 0
                                ? 'small'
                                : v == 0.5
                                    ? 'medium'
                                    : 'large';
                            setState(() => _fontSize = size);
                            _setPref(_prefFontSize, size);
                          },
                        ),
                      ),
                      const Text('A',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  toggleRow('Compact mode', _compactMode, (v) {
                    setState(() => _compactMode = v);
                    _setPref(_prefCompactMode, v);
                  }, icon: Icons.view_compact),
                  toggleRow('Reduce animations', _reduceAnimations, (v) {
                    setState(() => _reduceAnimations = v);
                    _setPref(_prefReduceAnimations, v);
                  }, icon: Icons.animation),
                ],
              ),
              const SizedBox(height: 20),

              // ── Data & Privacy ──
              sectionCard(
                title: 'Data & Privacy',
                icon: Icons.shield_outlined,
                children: [
                  _PrefActionTile(
                    icon: Icons.cleaning_services_outlined,
                    label: 'Clear cache',
                    subtitle: 'Free up local storage',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cache cleared')),
                      );
                    },
                  ),
                  _PrefActionTile(
                    icon: Icons.download_outlined,
                    label: 'Export data',
                    subtitle: 'Download your data as JSON',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Export started – you will be notified when ready.')),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _PrefActionTile(
                    icon: Icons.delete_forever,
                    label: 'Delete account',
                    subtitle: 'Permanently remove your account and all data',
                    labelColor: Colors.red,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Account?'),
                          content: const Text(
                              'This action cannot be undone. All your data will be permanently deleted.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel')),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red),
                              onPressed: () {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Account deletion requested.')),
                                );
                              },
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Security ──
              sectionCard(
                title: 'Security',
                icon: Icons.shield_outlined,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _twoFactorEnabled
                                ? Colors.green.withOpacity(0.18)
                                : Colors.grey.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            _twoFactorEnabled ? Icons.check : Icons.lock_open,
                            size: 14,
                            color: _twoFactorEnabled
                                ? Colors.green
                                : Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Two-Factor Authentication (2FA)',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              Text(
                                _twoFactorEnabled
                                    ? 'Your account is protected with email verification'
                                    : 'Add an extra layer of security to your account',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_twoFactorLoading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Switch(
                            value: _twoFactorEnabled,
                            onChanged: _handleTwoFactorToggle,
                            activeColor: accent,
                            trackColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                        ? accent.withOpacity(0.4)
                                        : null),
                          ),
                      ],
                    ),
                  ),
                  if (_twoFactorEnabled) ...[
                    const Divider(height: 1),
                    _PrefActionTile(
                      icon: Icons.mark_email_read,
                      label: 'Send test code',
                      subtitle: 'Verify your 2FA email is working',
                      onTap: _sendTestTwoFactorCode,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // ── About ──
              sectionCard(
                title: 'About',
                icon: Icons.info_outline,
                children: [
                  _PrefInfoRow(label: 'App version', value: '1.0.0'),
                  _PrefInfoRow(label: 'Build', value: '2024.12'),
                  const SizedBox(height: 8),
                  _PrefActionTile(
                    icon: Icons.description_outlined,
                    label: 'Open source licenses',
                    subtitle: 'View third-party licenses',
                    onTap: () {
                      showLicensePage(context: context);
                    },
                  ),
                  _PrefActionTile(
                    icon: Icons.gavel,
                    label: 'Terms of service',
                    subtitle: 'Read our terms',
                    onTap: () {},
                  ),
                  _PrefActionTile(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy policy',
                    subtitle: 'How we handle your data',
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Account actions (log out) ──
              _AccountActionsSection(onLogout: _handleLogout),
            ],
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────────
  // BILLING & SUBSCRIPTION PANEL
  // ────────────────────────────────────────────────────────────────
  Widget _billingSubscriptionPanel() {
    const accent = Color(0xFFFFC107);
    return FutureBuilder<Subscription?>(
      future: SubscriptionService.getCurrentSubscription(),
      builder: (context, snapshot) {
        final subscription = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return FutureBuilder<List<Invoice>>(
          future: SubscriptionService.getInvoiceHistory(),
          builder: (context, invoiceSnapshot) {
            final invoices = invoiceSnapshot.data ?? [];

            return LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1180;
                final isTablet = constraints.maxWidth >= 860;

                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BillingHeroBanner(
                        accent: accent,
                        subscription: subscription,
                        isLoading: isLoading,
                      ),
                      const SizedBox(height: 24),
                      if (isTablet)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _CurrentSubscriptionCard(
                                accent: accent,
                                subscription: subscription,
                                isLoading: isLoading,
                              ),
                            ),
                            const SizedBox(width: 20),
                            SizedBox(
                              width: isDesktop ? 380 : 320,
                              child: _PaymentMethodsCard(
                                accent: accent,
                                subscription: subscription,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _CurrentSubscriptionCard(
                          accent: accent,
                          subscription: subscription,
                          isLoading: isLoading,
                        ),
                        const SizedBox(height: 20),
                        _PaymentMethodsCard(
                          accent: accent,
                          subscription: subscription,
                        ),
                      ],
                      const SizedBox(height: 24),
                      _InvoicesCard(
                        accent: accent,
                        invoices: invoices,
                        isLoading: invoiceSnapshot.connectionState ==
                            ConnectionState.waiting,
                      ),
                      const SizedBox(height: 24),
                      _UpgradePlanCard(
                        accent: accent,
                        currentTier: subscription?.tier,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _integrationsPanel() {
    final bool isEnvManaged =
        const String.fromEnvironment('OPENAI_PROXY_API_KEY').trim().isNotEmpty;
    final bool isConfigured = OpenAiConfig.isConfigured;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _openAiIntegrationTile(
            isConfigured: isConfigured, isEnvManaged: isEnvManaged),
      ],
    );
  }

  Widget _reportAnalysisPanel() {
    const accent = Color(0xFFFFC107);
    final metrics = <_MetricCardData>[
      const _MetricCardData(
        title: 'Overall Health',
        primaryValue: 'Healthy',
        annotation: '+8.2%',
        annotationLabel: 'vs last review',
        annotationIsPositive: true,
        description:
            'Momentum improved across delivery, quality, and sentiment metrics.',
        icon: Icons.monitor_heart,
        progress: 0.82,
      ),
      const _MetricCardData(
        title: 'Delivery Velocity',
        primaryValue: '89%',
        annotation: '+6.4%',
        annotationLabel: 'Sprint gain',
        annotationIsPositive: true,
        description:
            '42 story points closed out of 47 committed for Sprint 14.',
        icon: Icons.speed,
        progress: 0.89,
      ),
      const _MetricCardData(
        title: 'Budget Utilisation',
        primaryValue: '72%',
        annotation: '1.2M',
        annotationLabel: 'Remaining USD',
        annotationIsPositive: false,
        description: 'Forecast indicates runway of 11 weeks at current burn.',
        icon: Icons.account_balance_wallet_outlined,
        progress: 0.72,
      ),
      const _MetricCardData(
        title: 'Risk Exposure',
        primaryValue: 'Low',
        annotation: '2 alerts',
        annotationLabel: 'Needs review',
        annotationIsPositive: false,
        description:
            'Mitigations in place for security hardening and data residency.',
        icon: Icons.shield_moon_outlined,
        progress: 0.32,
      ),
    ];

    final actionItems = const <_ActionItemData>[
      _ActionItemData(
        title: 'Finalize migration test plan for release 7.2',
        owner: 'Product Ops',
        dueLabel: 'Due in 2 days',
        priority: _ActionPriority.high,
      ),
      _ActionItemData(
        title: 'Circulate KPI dashboard to steering committee',
        owner: 'PMO Team',
        dueLabel: 'Review Friday',
        priority: _ActionPriority.medium,
      ),
      _ActionItemData(
        title: 'Capture post-mortem insights from onboarding pilot',
        owner: 'Change Management',
        dueLabel: 'Due next week',
        priority: _ActionPriority.low,
      ),
    ];

    const insightBadges = <_HeroBadgeData>[
      _HeroBadgeData(label: 'Customer sentiment', value: 'Up 11%'),
      _HeroBadgeData(label: 'Escalations', value: 'Down 3'),
      _HeroBadgeData(label: 'Compliance', value: 'Cleared'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1180;
        final isTablet = constraints.maxWidth >= 860;
        final metricWidth = isDesktop
            ? (constraints.maxWidth - 60) / 4
            : isTablet
                ? (constraints.maxWidth - 40) / 2
                : constraints.maxWidth;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reportHeroBanner(accent: accent, insightBadges: insightBadges),
              const SizedBox(height: 28),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                children: metrics
                    .map(
                      (metric) => SizedBox(
                        width: metricWidth,
                        child: _reportMetricCard(data: metric, accent: accent),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 32),
              if (isTablet)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _deliveryPerformanceCard(accent: accent)),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: isDesktop ? 360 : 320,
                      child: _riskHeatCard(accent: accent),
                    ),
                  ],
                )
              else ...[
                _deliveryPerformanceCard(accent: accent),
                const SizedBox(height: 20),
                _riskHeatCard(accent: accent),
              ],
              const SizedBox(height: 32),
              if (isTablet)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _actionableInsightsCard(
                            actionItems: actionItems, accent: accent)),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: isDesktop ? 360 : 320,
                      child: _reportDownloadsCard(accent: accent),
                    ),
                  ],
                )
              else ...[
                _actionableInsightsCard(
                    actionItems: actionItems, accent: accent),
                const SizedBox(height: 20),
                _reportDownloadsCard(accent: accent),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _reportHeroBanner(
      {required Color accent, required List<_HeroBadgeData> insightBadges}) {
    final theme = Theme.of(context);
    final summaryContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Executive Summary',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: accent, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Icon(Icons.trending_up, color: accent, size: 20),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Report & Analysis Overview',
          style: theme.textTheme.headlineSmall
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          'StackOne delivery is pacing ahead of target, with stakeholder sentiment at an all-time high.\nWe are on track for the Q4 milestone with strong compliance posture and predictable burn.',
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: Colors.white.withOpacity(0.78), height: 1.45),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: insightBadges
              .map((badge) => _InsightBadge(badge: badge, accent: accent))
              .toList(),
        ),
      ],
    );

    final highlightCard = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Confidence score',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('94%',
                    style: theme.textTheme.displaySmall?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Icon(Icons.verified, color: accent, size: 28),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: 0.94,
                minHeight: 10,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
                'Momentum sustained for 6 weeks across velocity, quality, and CX metrics.',
                style: TextStyle(color: Colors.white70, height: 1.4)),
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF020617), Color(0xFF1E1B4B)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isStacked = constraints.maxWidth < 720;
          if (isStacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                summaryContent,
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, child: highlightCard),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: summaryContent),
              const SizedBox(width: 24),
              SizedBox(width: 260, child: highlightCard),
            ],
          );
        },
      ),
    );
  }

  Widget _reportMetricCard(
      {required _MetricCardData data, required Color accent}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
              blurRadius: 20, offset: Offset(0, 18), color: Color(0x11000000)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: accent, size: 24),
          ),
          const SizedBox(height: 20),
          Text(data.title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(data.primaryValue,
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                  data.annotationIsPositive
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 16,
                  color: data.annotationIsPositive ? Colors.green : Colors.red),
              const SizedBox(width: 6),
              Text(data.annotation,
                  style: TextStyle(
                      color:
                          data.annotationIsPositive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Text(data.annotationLabel,
                  style: const TextStyle(color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: data.progress,
              minHeight: 10,
              backgroundColor: Colors.grey.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: 14),
          Text(data.description,
              style: const TextStyle(color: Colors.black54, height: 1.4)),
        ],
      ),
    );
  }

  Widget _deliveryPerformanceCard({required Color accent}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
        boxShadow: const [
          BoxShadow(
              blurRadius: 18, offset: Offset(0, 14), color: Color(0x0F000000))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delivery performance',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(
              'Velocity trend across the past six sprints with forecast confidence.',
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: _VelocitySparkline(accent: accent),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: const [
              _TrendStat(
                  label: 'Throughput',
                  value: '42 pts',
                  change: '+11%',
                  isPositive: true),
              _TrendStat(
                  label: 'Predictability',
                  value: '92%',
                  change: '+4%',
                  isPositive: true),
              _TrendStat(
                  label: 'Cycle time',
                  value: '2.4d',
                  change: '-0.8d',
                  isPositive: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _riskHeatCard({required Color accent}) {
    final theme = Theme.of(context);
    const categories = ['Delivery', 'Security', 'People'];
    const likelihood = ['High', 'Medium', 'Low'];
    final heatMap = {
      'Delivery': {
        'High': accent,
        'Medium': accent.withOpacity(0.6),
        'Low': accent.withOpacity(0.25)
      },
      'Security': {
        'High': Colors.redAccent,
        'Medium': Colors.orangeAccent,
        'Low': Colors.orange.withOpacity(0.4)
      },
      'People': {
        'High': const Color(0xFFD97706),
        'Medium': Colors.blueAccent.withOpacity(0.6),
        'Low': Colors.blueAccent.withOpacity(0.3)
      },
    };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
        boxShadow: const [
          BoxShadow(
              blurRadius: 18, offset: Offset(0, 14), color: Color(0x0F000000))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Risk heat map',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(
              'Risk posture for current delivery window, mapped by likelihood vs per-domain impact.',
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 20),
          Table(
            border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.withOpacity(0.2))),
            columnWidths: const {0: IntrinsicColumnWidth()},
            children: [
              TableRow(
                children: [
                  const SizedBox(),
                  ...likelihood.map((label) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(label,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      )),
                ],
              ),
              ...categories.map((category) {
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(category,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    ...likelihood.map((level) {
                      final color = heatMap[category]![level]!;
                      return Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          level == 'High'
                              ? 'Monitor'
                              : level == 'Medium'
                                  ? 'Watchlist'
                                  : 'Stable',
                          style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600),
                        ),
                      );
                    }),
                  ],
                );
              }),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
              'Latest mitigations: SOC2 controls verified • Production deploy freeze scheduled • Headcount secured.'),
        ],
      ),
    );
  }

  Widget _actionableInsightsCard(
      {required List<_ActionItemData> actionItems, required Color accent}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
        boxShadow: const [
          BoxShadow(
              blurRadius: 18, offset: Offset(0, 14), color: Color(0x0F000000))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Actionable insights',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
              'Prioritized interventions to sustain momentum and de-risk the next release.',
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 20),
          ...actionItems
              .map((item) => _ActionItemRow(item: item, accent: accent)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add action item'),
            style: TextButton.styleFrom(
                foregroundColor: accent,
                textStyle: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _reportDownloadsCard({required Color accent}) {
    final theme = Theme.of(context);
    const downloads = <_DownloadItemData>[
      _DownloadItemData(
          title: 'Executive summary.pdf', subtitle: 'Last shared 2d ago'),
      _DownloadItemData(
          title: 'Delivery KPI dashboard.xlsx', subtitle: 'Updated 4h ago'),
      _DownloadItemData(
          title: 'Risk register.csv', subtitle: 'Refreshed 1d ago'),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
        boxShadow: const [
          BoxShadow(
              blurRadius: 18, offset: Offset(0, 14), color: Color(0x0F000000))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Report & exports',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(
              'Latest artefacts ready to distribute to project leadership and partners.',
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          ...downloads.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.insert_drive_file_outlined,
                        color: Colors.black87),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(item.subtitle,
                            style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.download_outlined),
                    color: accent,
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.cloud_download_outlined),
            label: const Text('Download full report'),
          ),
        ],
      ),
    );
  }

  Widget _editContentPanel() {
    final contentProvider = Provider.of<AppContentProvider>(context);
    final isEditMode = contentProvider.isEditMode;
    final canEdit = AdminEditToggle.isAdmin();
    const accent = Color(0xFFFFC107);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Card(
          margin: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.edit_note, color: accent, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Inline Content Editor',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                            'Edit text content directly on any page in your application.',
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isEditMode
                        ? Colors.green.withOpacity(0.08)
                        : Colors.grey.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isEditMode
                            ? Colors.green.withOpacity(0.3)
                            : Colors.grey.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isEditMode
                              ? Colors.green.withOpacity(0.18)
                              : Colors.grey.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEditMode ? Icons.edit : Icons.edit_off,
                          color: isEditMode ? Colors.green : Colors.black54,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditMode
                                  ? 'Edit Mode Enabled'
                                  : 'Edit Mode Disabled',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color:
                                    isEditMode ? Colors.green : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isEditMode
                                  ? 'Navigate to any page and click on text elements to edit them in place.'
                                  : 'Enable edit mode to start modifying content across all pages.',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            if (!canEdit) ...[
                              const SizedBox(height: 6),
                              const Text(
                                'Admin access required to enable edit mode.',
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Switch(
                        value: isEditMode,
                        onChanged: canEdit
                            ? (_) => contentProvider.toggleEditMode()
                            : null,
                        thumbColor: WidgetStateProperty.resolveWith((states) =>
                            states.contains(WidgetState.selected)
                                ? Colors.green
                                : null),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('How it works',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                const _EditInstructionStep(
                  number: '1',
                  title: 'Enable Edit Mode',
                  description: 'Toggle edit mode using the switch above.',
                  accent: Color(0xFFFFC107),
                ),
                const SizedBox(height: 12),
                const _EditInstructionStep(
                  number: '2',
                  title: 'Navigate to Any Page',
                  description:
                      'Visit the page containing content you want to edit.',
                  accent: Color(0xFFFFC107),
                ),
                const SizedBox(height: 12),
                const _EditInstructionStep(
                  number: '3',
                  title: 'Click Text to Edit',
                  description:
                      'Editable text will show blue borders. Click any text element to open the editor.',
                  accent: Color(0xFFFFC107),
                ),
                const SizedBox(height: 12),
                const _EditInstructionStep(
                  number: '4',
                  title: 'Save Changes',
                  description:
                      'Your changes are saved to Firestore and synced across all users in real-time.',
                  accent: Color(0xFFFFC107),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: const Color(0xFFD97706), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Admin Only',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFD97706)),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Only users with admin privileges can access edit mode. Regular users will see the published content without editing capabilities.',
                              style:
                                  TextStyle(color: Colors.black87, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: contentProvider.showEditButton
                        ? Colors.red.withOpacity(0.08)
                        : Colors.green.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: contentProvider.showEditButton
                            ? Colors.red.withOpacity(0.3)
                            : Colors.green.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: contentProvider.showEditButton
                              ? Colors.red.withOpacity(0.18)
                              : Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          contentProvider.showEditButton
                              ? Icons.visibility_off
                              : Icons.remove_red_eye,
                          color: contentProvider.showEditButton
                              ? Colors.red
                              : Colors.green,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Remove Content Modification Button',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              contentProvider.showEditButton
                                  ? 'The "Edit Content" button is currently hidden from all pages.'
                                  : 'The "Edit Content" button is currently visible on all pages.',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            if (!canEdit) ...[
                              const SizedBox(height: 6),
                              const Text(
                                'Admin access required to change this setting.',
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Switch(
                        value: contentProvider.showEditButton,
                        onChanged: canEdit
                            ? (_) =>
                                contentProvider.toggleEditButtonVisibility()
                            : null,
                        thumbColor: WidgetStateProperty.resolveWith((states) =>
                            states.contains(WidgetState.selected)
                                ? Colors.red
                                : null),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _openAiIntegrationTile(
      {required bool isConfigured, required bool isEnvManaged}) {
    final theme = Theme.of(context);
    final statusColor = isConfigured ? Colors.green : Colors.red;
    final statusLabel = isConfigured ? 'Configured' : 'Not Configured';
    final subtitle = isEnvManaged
        ? 'API key is set via environment and used across the app.'
        : isConfigured
            ? 'A runtime API key is active and used by all AI features.'
            : 'Add an API key to enable AI features across the app.';

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bolt, color: const Color(0xFFD97706)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('KAZ AI',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                isConfigured
                                    ? Icons.check_circle
                                    : Icons.error_outline,
                                size: 14,
                                color: statusColor),
                            const SizedBox(width: 4),
                            Text(statusLabel,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  if (isConfigured && !isEnvManaged) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.grey.withOpacity(0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.vpn_key,
                              size: 18, color: Colors.black54),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText(
                              OpenAiConfig.apiKeyValue,
                              style: const TextStyle(
                                  fontFamily: appFontFamily, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _onAddOrUpdateKey,
                        icon: const Icon(Icons.vpn_key),
                        label: Text(isConfigured && !isEnvManaged
                            ? 'Update API Key'
                            : 'Add API Key'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            isEnvManaged || !isConfigured ? null : _onRemoveKey,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove API Key'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: BorderSide(color: Colors.grey.withOpacity(0.4)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAddOrUpdateKey() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const ApiKeyInputDialog(),
    );
    if (result == true && mounted) {
      setState(() {});
    }
  }

  // ── 2FA Toggle ──
  Future<void> _handleTwoFactorToggle(bool enabled) async {
    if (enabled) {
      // Show confirmation dialog before enabling
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enable Two-Factor Authentication'),
          content: const Text(
              'A verification code will be sent to your email each time you sign in. '
              'You\'ll need to enter this code to complete sign-in.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enable'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      try {
        await TwoFactorAuthService.enable();
        if (mounted) {
          setState(() => _twoFactorEnabled = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Two-factor authentication enabled'),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to enable 2FA: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    } else {
      // Show confirmation dialog before disabling
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Disable Two-Factor Authentication'),
          content: const Text(
              'Your account will no longer require a verification code at sign-in. '
              'This reduces the security of your account.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Disable'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      try {
        await TwoFactorAuthService.disable();
        if (mounted) {
          setState(() => _twoFactorEnabled = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Two-factor authentication disabled'),
                backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to disable 2FA: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _sendTestTwoFactorCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No email found for current user'),
            backgroundColor: Colors.red),
      );
      return;
    }
    try {
      await TwoFactorAuthService.sendCode(email: user.email!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Test code sent to ${user.email}'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to send code: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onRemoveKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove KAZ AI API Key'),
        content: const Text(
            'This will disable KAZ AI features until you add a new key. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed == true) {
      await ApiKeyManager.removeForCurrentUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('KAZ AI API key removed'),
              backgroundColor: Colors.red),
        );
        setState(() {});
      }
    }
  }
}

// ── New Settings UI Widgets ──────────────────────────────────────────────

class _TopAppBar extends StatelessWidget {
  const _TopAppBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: Colors.white,
      child: Row(
        children: [
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 22),
              color: const Color(0xFF005bb3),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Settings',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF005bb3),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 48), // balance the back button
        ],
      ),
    );
  }
}

class _AccountPlanCard extends StatelessWidget {
  const _AccountPlanCard();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Subscription?>(
      future: SubscriptionService.getCurrentSubscription(),
      builder: (context, snapshot) {
        final subscription = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final tierName = subscription != null
            ? SubscriptionService.getTierName(subscription.tier)
            : 'Free';
        final renewalDate = subscription?.nextBillingDate;
        final renewalText = renewalDate != null
            ? 'Renews on ${DateFormat.yMMMd().format(renewalDate)}'
            : 'No active subscription';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                blurRadius: 8,
                offset: const Offset(0, 2),
                color: Colors.black.withOpacity(0.06),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isLoading)
                          const SizedBox(
                            width: 80,
                            height: 20,
                            child: LinearProgressIndicator(),
                          )
                        else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFABD00),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PREMIUM',
                              style: TextStyle(
                                color: Color(0xFF261A00),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$tierName Plan',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF191C1E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            renewalText,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF414754),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF005bb3).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.workspace_premium,
                      color: Color(0xFF005bb3),
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () {
                    context.go('/${AppRoutes.pricing}');
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFC0C6D6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Manage Subscription'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BillingPaymentCard extends StatelessWidget {
  const _BillingPaymentCard();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Invoice>>(
      future: SubscriptionService.getInvoiceHistory(),
      builder: (context, snapshot) {
        final invoices = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                blurRadius: 8,
                offset: const Offset(0, 2),
                color: Colors.black.withOpacity(0.06),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Billing & Payment',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF191C1E),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      context.go('/${AppRoutes.pricing}');
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF005bb3),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Update'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Payment method row
              Row(
                children: [
                  const Icon(Icons.credit_card,
                      color: Color(0xFF717786), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Visa ending in 4242',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF191C1E),
                          ),
                        ),
                        Text(
                          'Expires 12/25',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF414754).withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Recent invoices header
              const Text(
                'RECENT INVOICES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF414754),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              // Invoice rows
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (invoices.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No invoices yet',
                    style: TextStyle(color: Color(0xFF414754), fontSize: 14),
                  ),
                )
              else
                ...invoices.take(3).map((invoice) {
                  final dateStr = DateFormat.yMMMd().format(invoice.createdAt);
                  final amountStr = '\$${invoice.amount.toStringAsFixed(2)}';
                  final isPaid = invoice.status.toLowerCase() == 'paid' ||
                      invoice.status.toLowerCase() == 'succeeded';
                  return _InvoiceRow(
                    date: dateStr,
                    amount: amountStr,
                    isPaid: isPaid,
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.date,
    required this.amount,
    required this.isPaid,
  });

  final String date;
  final String amount;
  final bool isPaid;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE0E3E5), width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF191C1E),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        amount,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF414754),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFDAD6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPaid ? 'Paid' : 'Pending',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isPaid
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFBA1A1A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.download_outlined, size: 20),
              color: const Color(0xFF717786),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalTermsCard extends StatelessWidget {
  const _LegalTermsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: const Offset(0, 2),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegalTile(
            title: 'Terms and Conditions',
            onTap: () => context.go('/${AppRoutes.termsConditions}'),
          ),
          _LegalTile(
            title: 'Privacy Policy',
            onTap: () => context.go('/${AppRoutes.privacyPolicy}'),
          ),
          _LegalTile(
            title: 'Data Processing Agreement',
            onTap: () {
              // Could navigate to a DPA screen or open a URL
            },
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _LegalTile extends StatelessWidget {
  const _LegalTile({
    required this.title,
    required this.onTap,
    this.isLast = false,
  });

  final String title;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(
                    bottom: BorderSide(color: Color(0xFFE0E3E5), width: 1),
                  ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF191C1E),
                  ),
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: Color(0xFF717786), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountActionsSection extends StatelessWidget {
  const _AccountActionsSection({required this.onLogout});
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Change Password
        SizedBox(
          height: 44,
          child: OutlinedButton(
            onPressed: () {
              // Navigate to password reset or show dialog
              final user = FirebaseAuth.instance.currentUser;
              if (user != null && user.email != null) {
                FirebaseAuth.instance
                    .sendPasswordResetEmail(email: user.email!);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Password reset email sent. Please check your inbox.'),
                  ),
                );
              }
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFC0C6D6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Change Password',
              style: TextStyle(
                color: Color(0xFF191C1E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Log Out
        SizedBox(
          height: 44,
          child: TextButton(
            onPressed: onLogout,
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: const Color(0xFFBA1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFFECEEF0),
        boxShadow: [
          BoxShadow(
            blurRadius: 4,
            offset: const Offset(0, -1),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Home',
            isActive: false,
            onTap: () => context.go('/${AppRoutes.dashboard}'),
          ),
          _BottomNavItem(
            icon: Icons.folder_outlined,
            activeIcon: Icons.folder,
            label: 'Projects',
            isActive: false,
            onTap: () => context.go('/${AppRoutes.dashboard}'),
          ),
          _BottomNavItem(
            icon: Icons.timeline_outlined,
            activeIcon: Icons.timeline,
            label: 'Reports',
            isActive: false,
            onTap: () => context.go('/${AppRoutes.dashboard}'),
          ),
          _BottomNavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: 'Settings',
            isActive: true,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 64,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFABD00) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 22,
              color:
                  isActive ? const Color(0xFF261A00) : const Color(0xFF414754),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? const Color(0xFF261A00)
                    : const Color(0xFF414754),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.title,
    required this.primaryValue,
    required this.annotation,
    required this.annotationLabel,
    required this.annotationIsPositive,
    required this.description,
    required this.icon,
    required this.progress,
  });

  final String title;
  final String primaryValue;
  final String annotation;
  final String annotationLabel;
  final bool annotationIsPositive;
  final String description;
  final IconData icon;
  final double progress;
}

class _ActionItemData {
  const _ActionItemData({
    required this.title,
    required this.owner,
    required this.dueLabel,
    required this.priority,
  });

  final String title;
  final String owner;
  final String dueLabel;
  final _ActionPriority priority;
}

enum _ActionPriority { high, medium, low }

class _HeroBadgeData {
  const _HeroBadgeData({required this.label, required this.value});

  final String label;
  final String value;
}

class _DownloadItemData {
  const _DownloadItemData({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

class _InsightBadge extends StatelessWidget {
  const _InsightBadge({required this.badge, required this.accent});

  final _HeroBadgeData badge;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.12),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(badge.label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(badge.value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _VelocitySparkline extends StatelessWidget {
  const _VelocitySparkline({required this.accent});

  final Color accent;

  static const _data = [42.0, 45.0, 47.0, 52.0, 55.0, 53.0, 58.0];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.grey.withOpacity(0.08),
        border: Border.all(color: Colors.grey.withOpacity(0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: CustomPaint(
          painter: _VelocitySparklinePainter(data: _data, accent: accent),
        ),
      ),
    );
  }
}

class _VelocitySparklinePainter extends CustomPainter {
  _VelocitySparklinePainter({required this.data, required this.accent});

  final List<double> data;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final paint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final double horizontalStep =
        data.length == 1 ? size.width : size.width / (data.length - 1);

    Offset? lastPoint;
    for (var i = 0; i < data.length; i++) {
      final progress = maxValue == minValue
          ? 0.5
          : (data[i] - minValue) / (maxValue - minValue);
      final dx = i * horizontalStep;
      final dy = size.height - (progress * size.height);
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
      lastPoint = Offset(dx, dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accent.withOpacity(0.28), accent.withOpacity(0.04)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    if (lastPoint != null) {
      final indicatorFill = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final indicatorStroke = Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(lastPoint, 6, indicatorFill);
      canvas.drawCircle(lastPoint, 6, indicatorStroke);
    }
  }

  @override
  bool shouldRepaint(covariant _VelocitySparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.accent != accent;
  }
}

class _TrendStat extends StatelessWidget {
  const _TrendStat(
      {required this.label,
      required this.value,
      required this.change,
      required this.isPositive});

  final String label;
  final String value;
  final String change;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey.withOpacity(0.08),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  color: color, size: 14),
              const SizedBox(width: 4),
              Text(change,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditInstructionStep extends StatelessWidget {
  const _EditInstructionStep({
    required this.number,
    required this.title,
    required this.description,
    required this.accent,
  });

  final String number;
  final String title;
  final String description;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionItemRow extends StatelessWidget {
  const _ActionItemRow({required this.item, required this.accent});

  final _ActionItemData item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    late final String priorityLabel;
    late final Color priorityColor;
    switch (item.priority) {
      case _ActionPriority.high:
        priorityLabel = 'High';
        priorityColor = Colors.redAccent;
        break;
      case _ActionPriority.medium:
        priorityLabel = 'Medium';
        priorityColor = Colors.orangeAccent;
        break;
      case _ActionPriority.low:
        priorityLabel = 'Low';
        priorityColor = Colors.green;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.grey.withOpacity(0.06),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Priority $priorityLabel',
                    style: TextStyle(
                        color: priorityColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(item.dueLabel,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 12)),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_horiz),
                color: accent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(item.title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, height: 1.4)),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: accent.withOpacity(0.2),
                child: const Icon(Icons.person_outline, color: Colors.black87),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(item.owner,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(foregroundColor: accent),
                child: const Text('View brief'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Billing & Subscription Widgets

class _BillingHeroBanner extends StatelessWidget {
  const _BillingHeroBanner(
      {required this.accent, this.subscription, this.isLoading = false});

  final Color accent;
  final Subscription? subscription;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSubscription = subscription != null;
    final planName = hasSubscription
        ? SubscriptionService.getTierName(subscription!.tier)
        : 'No Plan';
    final status = hasSubscription
        ? (subscription!.isActive ? 'Active' : subscription!.status.name)
        : 'Inactive';
    final nextBilling = hasSubscription && subscription!.nextBillingDate != null
        ? DateFormat('MMM d, yyyy').format(subscription!.nextBillingDate!)
        : hasSubscription && subscription!.endDate != null
            ? DateFormat('MMM d, yyyy').format(subscription!.endDate!)
            : 'N/A';
    final priceInfo = hasSubscription
        ? SubscriptionService.getPriceForTier(subscription!.tier,
            annual: subscription!.isAnnual)
        : {'price': '\$0', 'period': 'per month'};
    final price = priceInfo['price'] ?? '\$0';
    final period = subscription?.isAnnual == true ? '/year' : '/month';

    // Calculate billing cycle progress
    double billingProgress = 0.0;
    String progressLabel = 'No active billing cycle';
    if (hasSubscription) {
      final now = DateTime.now();
      final end = subscription!.nextBillingDate ?? subscription!.endDate;
      if (end != null && end.isAfter(subscription!.startDate)) {
        final totalDays = end.difference(subscription!.startDate).inDays;
        final elapsedDays = now.difference(subscription!.startDate).inDays;
        billingProgress = (elapsedDays / totalDays).clamp(0.0, 1.0);
        progressLabel =
            '${(billingProgress * 100).round()}% of billing cycle completed';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF020617), Color(0xFF1E1B4B)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isStacked = constraints.maxWidth < 720;
          final summaryContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('Billing & Subscription',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: accent, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.credit_card, color: accent, size: 20),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Manage Your Subscription',
                style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                'View your current plan, manage payment methods, and access your billing history.\nUpgrade anytime to unlock premium features.',
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withOpacity(0.78), height: 1.45),
              ),
              const SizedBox(height: 18),
              if (isLoading)
                const CircularProgressIndicator(color: Colors.white54)
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _BillingStatBadge(
                        label: 'Current Plan',
                        value: planName.replaceAll(' Plan', ''),
                        accent: accent),
                    _BillingStatBadge(
                        label: 'Status', value: status, accent: accent),
                    _BillingStatBadge(
                        label: 'Next Billing',
                        value: nextBilling,
                        accent: accent),
                  ],
                ),
            ],
          );

          final highlightCard = DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: Colors.white.withOpacity(0.12),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      subscription?.isAnnual == true
                          ? 'Annual Spend'
                          : 'Monthly Spend',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(price,
                          style: theme.textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(width: 4),
                      Text(period,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(color: Colors.white70)),
                      const Spacer(),
                      Icon(
                          hasSubscription && subscription!.isActive
                              ? Icons.verified
                              : Icons.info_outline,
                          color: accent,
                          size: 28),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: billingProgress,
                      minHeight: 10,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation(accent),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(progressLabel,
                      style:
                          const TextStyle(color: Colors.white70, height: 1.4)),
                ],
              ),
            ),
          );

          if (isStacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                summaryContent,
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, child: highlightCard),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: summaryContent),
              const SizedBox(width: 24),
              SizedBox(width: 260, child: highlightCard),
            ],
          );
        },
      ),
    );
  }
}

class _BillingStatBadge extends StatelessWidget {
  const _BillingStatBadge(
      {required this.label, required this.value, required this.accent});

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.12),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _CurrentSubscriptionCard extends StatelessWidget {
  const _CurrentSubscriptionCard(
      {required this.accent, this.subscription, this.isLoading = false});

  final Color accent;
  final Subscription? subscription;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSubscription = subscription != null;
    final planName = hasSubscription
        ? SubscriptionService.getTierName(subscription!.tier)
        : 'No Active Plan';
    final isActive = hasSubscription && subscription!.isActive;
    final statusText = hasSubscription
        ? (subscription!.isTrial
            ? 'Trial'
            : (isActive ? 'Active' : subscription!.status.name))
        : 'Inactive';
    final statusColor = isActive
        ? Colors.green
        : (hasSubscription && subscription!.isTrial
            ? Colors.blue
            : Colors.grey);
    final billingCycle = hasSubscription
        ? (subscription!.isAnnual ? 'Annual' : 'Monthly')
        : 'N/A';
    final startDate = hasSubscription
        ? DateFormat('MMM d, yyyy').format(subscription!.startDate)
        : 'N/A';
    final renewalDate = hasSubscription && subscription!.nextBillingDate != null
        ? DateFormat('MMM d, yyyy').format(subscription!.nextBillingDate!)
        : hasSubscription && subscription!.endDate != null
            ? DateFormat('MMM d, yyyy').format(subscription!.endDate!)
            : 'N/A';
    final priceInfo = hasSubscription
        ? SubscriptionService.getPriceForTier(subscription!.tier,
            annual: subscription!.isAnnual)
        : {'price': '\$0', 'period': 'per month'};
    final amount =
        '${priceInfo['price']}/${subscription?.isAnnual == true ? 'year' : 'month'}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
        boxShadow: const [
          BoxShadow(
              blurRadius: 18, offset: Offset(0, 14), color: Color(0x0F000000))
        ],
      ),
      child: isLoading
          ? const Center(
              child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator()))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.workspace_premium,
                          color: accent, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current Subscription',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(planName,
                              style: TextStyle(
                                  color: accent, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              isActive
                                  ? Icons.check_circle
                                  : Icons.info_outline,
                              size: 16,
                              color: statusColor),
                          const SizedBox(width: 6),
                          Text(statusText,
                              style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.12)),
                  ),
                  child: Column(
                    children: [
                      _SubscriptionDetailRow(
                          label: 'Billing Cycle', value: billingCycle),
                      const Divider(height: 24),
                      _SubscriptionDetailRow(
                          label: 'Start Date', value: startDate),
                      const Divider(height: 24),
                      _SubscriptionDetailRow(
                          label: 'Renewal Date', value: renewalDate),
                      const Divider(height: 24),
                      _SubscriptionDetailRow(label: 'Amount', value: amount),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: hasSubscription && isActive
                            ? () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Cancel Subscription'),
                                    content: const Text(
                                        'Are you sure you want to cancel your subscription? You will lose access at the end of your billing period.'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child:
                                              const Text('Keep Subscription')),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white),
                                        child: const Text('Cancel'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await SubscriptionService
                                      .cancelSubscription();
                                }
                              }
                            : null,
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Cancel Subscription'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.upgrade, size: 18),
                        label: const Text('Upgrade Plan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _SubscriptionDetailRow extends StatelessWidget {
  const _SubscriptionDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.black54, fontSize: 14)),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }
}

class _PaymentMethodsCard extends StatelessWidget {
  const _PaymentMethodsCard({required this.accent, this.subscription});

  final Color accent;
  final Subscription? subscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
        boxShadow: const [
          BoxShadow(
              blurRadius: 18, offset: Offset(0, 14), color: Color(0x0F000000))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Methods',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Connect your preferred payment provider',
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 20),
          _PaymentProviderTile(
            name: 'Stripe',
            description: 'Credit/Debit Card payments',
            iconColor: const Color(0xFF635BFF),
            icon: Icons.credit_card,
            isConnected: subscription?.provider == PaymentProvider.stripe,
            accent: accent,
          ),
          const SizedBox(height: 12),
          _PaymentProviderTile(
            name: 'PayPal',
            description: 'PayPal account payments',
            iconColor: const Color(0xFF003087),
            icon: Icons.account_balance_wallet,
            isConnected: subscription?.provider == PaymentProvider.paypal,
            accent: accent,
          ),
          const SizedBox(height: 12),
          _PaymentProviderTile(
            name: 'Paystack',
            description: 'African payment gateway',
            iconColor: const Color(0xFF00C3F7),
            icon: Icons.payments_outlined,
            isConnected: subscription?.provider == PaymentProvider.paystack,
            accent: accent,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Add Payment Method'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentProviderTile extends StatelessWidget {
  const _PaymentProviderTile({
    required this.name,
    required this.description,
    required this.iconColor,
    required this.icon,
    required this.isConnected,
    required this.accent,
  });

  final String name;
  final String description;
  final Color iconColor;
  final IconData icon;
  final bool isConnected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isConnected
            ? accent.withOpacity(0.08)
            : Colors.grey.withOpacity(0.06),
        border: Border.all(
            color: isConnected
                ? accent.withOpacity(0.3)
                : Colors.grey.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    if (isConnected) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('Connected',
                            style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(description,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(isConnected ? Icons.settings_outlined : Icons.link,
                color: isConnected ? Colors.black54 : accent),
            tooltip: isConnected ? 'Manage' : 'Connect',
          ),
        ],
      ),
    );
  }
}

class _InvoicesCard extends StatelessWidget {
  const _InvoicesCard(
      {required this.accent, required this.invoices, this.isLoading = false});

  final Color accent;
  final List<Invoice> invoices;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
        boxShadow: const [
          BoxShadow(
              blurRadius: 18, offset: Offset(0, 14), color: Color(0x0F000000))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.receipt_long, color: accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invoice History',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('View and download past invoices',
                          style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: invoices.isEmpty ? null : () {},
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Export All'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (invoices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('No invoices yet',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Text('Your payment history will appear here',
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final mediaWidth = MediaQuery.of(context).size.width;
                final bool hasBoundedWidth = constraints.hasBoundedWidth &&
                    constraints.maxWidth.isFinite;
                final double tableWidth =
                    hasBoundedWidth ? constraints.maxWidth : mediaWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: DataTable(
                      headingRowColor:
                          WidgetStateProperty.all(const Color(0xFFF9FAFB)),
                      headingTextStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280)),
                      dataTextStyle: const TextStyle(
                          fontSize: 13, color: Color(0xFF374151)),
                      horizontalMargin: 24,
                      columnSpacing: 48,
                      columns: const [
                        DataColumn(label: Text('Invoice ID')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Amount')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: invoices
                          .take(5)
                          .map((invoice) => DataRow(
                                cells: [
                                  DataCell(Text(
                                      invoice.id.length > 15
                                          ? '${invoice.id.substring(0, 15)}...'
                                          : invoice.id,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600))),
                                  DataCell(Text(DateFormat('MMM d, yyyy')
                                      .format(invoice.createdAt))),
                                  DataCell(Text(invoice.formattedAmount,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600))),
                                  DataCell(_InvoiceStatusBadge(
                                      status: invoice.isPaid
                                          ? 'Paid'
                                          : invoice.status)),
                                  DataCell(
                                    IconButton(
                                      onPressed: invoice.receiptUrl != null
                                          ? () {
                                              openUrlInNewWindow(
                                                  invoice.receiptUrl!);
                                            }
                                          : null,
                                      icon: Icon(Icons.download_outlined,
                                          color: invoice.receiptUrl != null
                                              ? accent
                                              : Colors.grey,
                                          size: 20),
                                      tooltip: 'Download',
                                    ),
                                  ),
                                ],
                              ))
                          .toList(),
                    ),
                  ),
                );
              },
            ),
          if (invoices.length > 5)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.history, size: 18),
                  label: Text('View All ${invoices.length} Invoices'),
                  style: TextButton.styleFrom(foregroundColor: accent),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InvoiceStatusBadge extends StatelessWidget {
  const _InvoiceStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    switch (status.toLowerCase()) {
      case 'paid':
        bgColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF16A34A);
        break;
      case 'pending':
        bgColor = const Color(0xFFFEF9C3);
        textColor = const Color(0xFFCA8A04);
        break;
      case 'overdue':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFDC2626);
        break;
      default:
        bgColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF6B7280);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}

class _UpgradePlanCard extends StatelessWidget {
  const _UpgradePlanCard({required this.accent, this.currentTier});

  final Color accent;
  final SubscriptionTier? currentTier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMaxTier = currentTier == SubscriptionTier.portfolio;
    final upgradeTitle = isMaxTier
        ? 'You have the highest plan'
        : currentTier == SubscriptionTier.program
            ? 'Upgrade to Portfolio'
            : 'Upgrade to Program or Portfolio';
    final upgradePrice =
        currentTier == SubscriptionTier.program ? '\$449' : '\$189';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withOpacity(0.15), accent.withOpacity(0.05)],
        ),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rocket_launch, color: accent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(upgradeTitle,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                isMaxTier
                    ? 'You have access to all features including unlimited projects, priority support, and advanced analytics.'
                    : 'Unlock advanced features, priority support, and unlimited team members with a higher tier plan.',
                style: const TextStyle(color: Colors.black87, height: 1.5),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _FeatureChip(label: 'Unlimited Projects', accent: accent),
                  _FeatureChip(label: 'Priority Support', accent: accent),
                  _FeatureChip(label: 'Advanced Analytics', accent: accent),
                  _FeatureChip(label: 'Custom Integrations', accent: accent),
                ],
              ),
            ],
          );

          final actionSection = Column(
            crossAxisAlignment:
                isWide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMaxTier) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(upgradePrice,
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('/month',
                          style: const TextStyle(color: Colors.black54)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.upgrade, size: 18),
                  label: const Text('Upgrade Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ] else
                Icon(Icons.check_circle, color: Colors.green, size: 48),
            ],
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: content),
                const SizedBox(width: 24),
                actionSection,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              content,
              const SizedBox(height: 20),
              actionSection,
            ],
          );
        },
      ),
    );
  }
}

class _SecuritySettingsTab extends StatefulWidget {
  const _SecuritySettingsTab();

  @override
  State<_SecuritySettingsTab> createState() => _SecuritySettingsTabState();
}

class _SecuritySettingsTabState extends State<_SecuritySettingsTab> {
  bool _passwordLoginEnabled = true;
  bool _passwordlessEmailEnabled = false;
  bool _mfaEnabledPolicy = true;
  MfaMethod _defaultMfaMethod = MfaMethod.authenticator;
  final Set<MfaMethod> _backupMfaMethods = {
    MfaMethod.sms,
    MfaMethod.emailCode,
  };
  MfaRequirement _mfaRequirement = MfaRequirement.everyLogin;
  int _rememberDeviceDays = 30;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    final policy = await TwoFactorAuthService.loadPolicy();
    if (!mounted) return;
    setState(() {
      _passwordLoginEnabled = policy.passwordLoginEnabled;
      _passwordlessEmailEnabled = policy.passwordlessEmailEnabled;
      _mfaEnabledPolicy = policy.mfaEnabled;
      _defaultMfaMethod = policy.defaultMfaMethod;
      _backupMfaMethods
        ..clear()
        ..addAll(policy.backupMethods);
      _mfaRequirement = policy.requireMfaEveryLogin
          ? MfaRequirement.everyLogin
          : policy.requireMfaNewDeviceOnly
              ? MfaRequirement.newDeviceOnly
              : policy.requireMfaHighRiskOnly
                  ? MfaRequirement.highRiskOnly
                  : MfaRequirement.adminOnly;
      _rememberDeviceDays = policy.rememberDeviceDays;
    });
  }

  Future<void> _saveSecurityPolicy() async {
    await TwoFactorAuthService.savePolicy(
      SecurityPolicy(
        passwordLoginEnabled: _passwordLoginEnabled,
        passwordlessEmailEnabled: _passwordlessEmailEnabled,
        mfaEnabled: _mfaEnabledPolicy,
        requireMfaEveryLogin: _mfaRequirement == MfaRequirement.everyLogin,
        requireMfaNewDeviceOnly:
            _mfaRequirement == MfaRequirement.newDeviceOnly,
        requireMfaHighRiskOnly: _mfaRequirement == MfaRequirement.highRiskOnly,
        requireMfaAdminOnly: _mfaRequirement == MfaRequirement.adminOnly,
        defaultMfaMethod: _defaultMfaMethod,
        backupMethods: _backupMfaMethods.toList(),
        rememberDeviceDays: _rememberDeviceDays,
      ),
    );
  }

  Widget _mfaChoice(MfaMethod method, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _defaultMfaMethod == method,
      onSelected: (value) async {
        if (!value) return;
        setState(() => _defaultMfaMethod = method);
        await _saveSecurityPolicy();
      },
    );
  }

  Widget _backupChoice(MfaMethod method, String label) {
    return FilterChip(
      label: Text(label),
      selected: _backupMfaMethods.contains(method),
      onSelected: (value) async {
        setState(() {
          if (value) {
            _backupMfaMethods.add(method);
          } else {
            _backupMfaMethods.remove(method);
          }
        });
        await _saveSecurityPolicy();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _RbacCard(
      title: 'Security Settings',
      subtitle:
          'Configure authentication method, MFA defaults, trusted devices, and backup verification methods.',
      icon: Icons.security,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilterChip(
                label: const Text('Password Login'),
                selected: _passwordLoginEnabled,
                onSelected: (v) async {
                  setState(() => _passwordLoginEnabled = v);
                  await _saveSecurityPolicy();
                },
              ),
              FilterChip(
                label: const Text('Passwordless Email'),
                selected: _passwordlessEmailEnabled,
                onSelected: (v) async {
                  setState(() => _passwordlessEmailEnabled = v);
                  await _saveSecurityPolicy();
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Default MFA Method',
              style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 12,
            children: [
              _mfaChoice(MfaMethod.authenticator, 'Authenticator App'),
              _mfaChoice(MfaMethod.sms, 'Text Message'),
              _mfaChoice(MfaMethod.emailCode, 'Email Code'),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Backup methods',
              style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 12,
            children: [
              _backupChoice(MfaMethod.sms, 'SMS'),
              _backupChoice(MfaMethod.emailCode, 'Email Code'),
            ],
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<MfaRequirement>(
            initialValue: _mfaRequirement,
            items: const [
              DropdownMenuItem(
                  value: MfaRequirement.everyLogin, child: Text('Every Login')),
              DropdownMenuItem(
                  value: MfaRequirement.newDeviceOnly,
                  child: Text('New Device Only')),
              DropdownMenuItem(
                  value: MfaRequirement.highRiskOnly,
                  child: Text('High Risk Login Only')),
              DropdownMenuItem(
                  value: MfaRequirement.adminOnly,
                  child: Text('Administrator Accounts Only')),
            ],
            onChanged: (value) async {
              if (value == null) return;
              setState(() => _mfaRequirement = value);
              await _saveSecurityPolicy();
            },
            decoration: const InputDecoration(labelText: 'Require MFA'),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<int>(
            initialValue: _rememberDeviceDays,
            items: const [
              DropdownMenuItem(value: 7, child: Text('7 days')),
              DropdownMenuItem(value: 30, child: Text('30 days')),
              DropdownMenuItem(value: 60, child: Text('60 days')),
            ],
            onChanged: (value) async {
              if (value == null) return;
              setState(() => _rememberDeviceDays = value);
              await _saveSecurityPolicy();
            },
            decoration:
                const InputDecoration(labelText: 'Remember this device'),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => context.pushNamed(AppRoutes.securityManagement),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Security Management'),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MfaEnrollmentScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Enroll MFA'),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RecoveryCodesScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.confirmation_number_outlined),
              label: const Text('Recovery Codes'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessCollaboratorsPanel extends StatefulWidget {
  const _AccessCollaboratorsPanel();

  @override
  State<_AccessCollaboratorsPanel> createState() =>
      _AccessCollaboratorsPanelState();
}

class _AccessCollaboratorsPanelState extends State<_AccessCollaboratorsPanel> {
  static const _accent = Color(0xFFFFC107);
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _messageController = TextEditingController(
    text: 'You have been invited to collaborate in NDU Project.',
  );

  SiteRole _selectedRole = SiteRole.editor;
  ResourceAccessLevel _selectedAccess = ResourceAccessLevel.editor;
  String _selectedScope = 'Current project';
  String _selectedExpiry = '30 days';
  bool _requireMfa = true;
  bool _notifyOnAccessChange = true;
  bool _passwordLoginEnabled = true;
  bool _passwordlessEmailEnabled = false;
  bool _mfaEnabledPolicy = true;
  MfaMethod _defaultMfaMethod = MfaMethod.authenticator;
  final Set<MfaMethod> _backupMfaMethods = {
    MfaMethod.sms,
    MfaMethod.emailCode,
  };
  MfaRequirement _mfaRequirement = MfaRequirement.everyLogin;
  int _rememberDeviceDays = 30;
  bool _isSending = false;
  final Set<Permission> _customPermissions = {
    Permission.viewAnalytics,
    Permission.exportData,
  };

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final email = _emailController.text.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showSnack('Enter a valid collaborator email address.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null || user.email!.isEmpty) {
      _showSnack('You must be signed in to send invitations.');
      return;
    }

    // ── Email verification flow ────────────────────────────────────────
    // Before creating the invitation, verify the inviter's identity via
    // a 6-digit OTP sent to their own email address. This mirrors the
    // TwoFactorVerificationScreen pattern and prevents unauthorized
    // invitation creation even if the inviter's session is hijacked.
    setState(() => _isSending = true);
    try {
      // Step 1: Send OTP to the inviter's email
      await TwoFactorAuthService.sendCode(email: user.email!);

      if (!mounted) return;

      // Step 2: Show the verification dialog and wait for the user to
      // enter the 6-digit code. The dialog returns true if verification
      // succeeded, false if the user cancelled or verification failed.
      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => InviteVerificationDialog(
          email: user.email!,
          inviteeEmail: email,
          inviteeName: _nameController.text.trim(),
        ),
      );

      if (verified != true) {
        // User cancelled or verification failed
        if (mounted) {
          _showSnack('Invitation cancelled — email not verified.');
        }
        return;
      }

      // Step 3: OTP verified — proceed to create the invitation
      final project = ProjectDataInherited.maybeOf(context)?.projectData;
      final expiresAt = _expiryDate(_selectedExpiry);

      final payload = {
        'email': email,
        'displayName': _nameController.text.trim(),
        'siteRole': _selectedRole.name,
        'resourceAccessLevel': _selectedAccess.name,
        'scope': _selectedScope,
        'projectId': project?.projectId ?? '',
        'projectName': project?.projectName ?? '',
        'customPermissions': _customPermissions.map((p) => p.name).toList(),
        'message': _messageController.text.trim(),
        'status': 'pending',
        'requireMfa': _requireMfa,
        'notifyOnAccessChange': _notifyOnAccessChange,
        'invitedByUid': user.uid,
        'invitedByEmail': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
      };

      await FirebaseFirestore.instance
          .collection('collaboration_invites')
          .add(payload);

      await FirebaseFirestore.instance.collection('rbac_audit_events').add({
        'action': 'collaborator_invited',
        'targetEmail': email,
        'role': _selectedRole.name,
        'scope': _selectedScope,
        'projectId': project?.projectId ?? '',
        'actorUid': user.uid,
        'actorEmail': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _emailController.clear();
      _nameController.clear();
      _showSnack('Invitation sent to $email.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not create invitation: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  DateTime? _expiryDate(String value) {
    final now = DateTime.now();
    switch (value) {
      case '7 days':
        return now.add(const Duration(days: 7));
      case '30 days':
        return now.add(const Duration(days: 30));
      case '90 days':
        return now.add(const Duration(days: 90));
      default:
        return null;
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1080;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _accessHeader(context),
              const SizedBox(height: 24),
              _securityStrip(),
              const SizedBox(height: 24),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: _inviteCard()),
                    const SizedBox(width: 20),
                    Expanded(flex: 10, child: _collaboratorsCard()),
                  ],
                )
              else ...[
                _inviteCard(),
                const SizedBox(height: 20),
                _collaboratorsCard(),
              ],
              const SizedBox(height: 24),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _rolePresetCard()),
                    const SizedBox(width: 20),
                    Expanded(child: _pendingInvitesCard()),
                  ],
                )
              else ...[
                _rolePresetCard(),
                const SizedBox(height: 20),
                _pendingInvitesCard(),
              ],
              const SizedBox(height: 24),
              _permissionMatrixCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _accessHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 760;
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.admin_panel_settings_outlined,
                    color: _accent, size: 26),
              ),
              const SizedBox(height: 18),
              Text(
                'Access & Collaborators',
                style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Invite collaborators, assign least-privilege roles, control project-level access, and review the RBAC policy before changes reach delivery data.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.72), height: 1.45),
              ),
            ],
          );
          final stats = Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _AccessStat(label: 'Role tiers', value: '5'),
              _AccessStat(label: 'Access levels', value: '5'),
              _AccessStat(label: 'Policy gates', value: '22'),
            ],
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 20), stats],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: title),
              const SizedBox(width: 24),
              stats,
            ],
          );
        },
      ),
    );
  }

  Widget _securityStrip() {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _PolicyToggle(
          icon: Icons.verified_user_outlined,
          title: 'Require MFA',
          subtitle: 'Applies to account sign-ins',
          value: _mfaEnabledPolicy,
          onChanged: (value) async {
            setState(() => _mfaEnabledPolicy = value);
            await _saveSecurityPolicy();
          },
        ),
        _PolicyToggle(
          icon: Icons.notifications_active_outlined,
          title: 'Access-change alerts',
          subtitle: 'Notify admins and owners',
          value: _notifyOnAccessChange,
          onChanged: (value) => setState(() => _notifyOnAccessChange = value),
        ),
      ],
    );
  }

  Future<void> _saveSecurityPolicy() async {
    await TwoFactorAuthService.savePolicy(
      SecurityPolicy(
        passwordLoginEnabled: _passwordLoginEnabled,
        passwordlessEmailEnabled: _passwordlessEmailEnabled,
        mfaEnabled: _mfaEnabledPolicy,
        requireMfaEveryLogin: _mfaRequirement == MfaRequirement.everyLogin,
        requireMfaNewDeviceOnly:
            _mfaRequirement == MfaRequirement.newDeviceOnly,
        requireMfaHighRiskOnly: _mfaRequirement == MfaRequirement.highRiskOnly,
        requireMfaAdminOnly: _mfaRequirement == MfaRequirement.adminOnly,
        defaultMfaMethod: _defaultMfaMethod,
        backupMethods: _backupMfaMethods.toList(),
        rememberDeviceDays: _rememberDeviceDays,
      ),
    );
  }

  Widget _securitySettingsPanel() {
    return _RbacCard(
      title: 'Security Settings',
      subtitle:
          'Configure authentication method, MFA defaults, trusted devices, and backup verification methods.',
      icon: Icons.security,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilterChip(
                label: const Text('Password Login'),
                selected: _passwordLoginEnabled,
                onSelected: (v) async {
                  setState(() => _passwordLoginEnabled = v);
                  await _saveSecurityPolicy();
                },
              ),
              FilterChip(
                label: const Text('Passwordless Email'),
                selected: _passwordlessEmailEnabled,
                onSelected: (v) async {
                  setState(() => _passwordlessEmailEnabled = v);
                  await _saveSecurityPolicy();
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Default MFA Method',
              style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 12,
            children: [
              _mfaChoice(MfaMethod.authenticator, 'Authenticator App'),
              _mfaChoice(MfaMethod.sms, 'Text Message'),
              _mfaChoice(MfaMethod.emailCode, 'Email Code'),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Backup methods',
              style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 12,
            children: [
              _backupChoice(MfaMethod.sms, 'SMS'),
              _backupChoice(MfaMethod.emailCode, 'Email Code'),
            ],
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<MfaRequirement>(
            value: _mfaRequirement,
            items: const [
              DropdownMenuItem(
                  value: MfaRequirement.everyLogin, child: Text('Every Login')),
              DropdownMenuItem(
                  value: MfaRequirement.newDeviceOnly,
                  child: Text('New Device Only')),
              DropdownMenuItem(
                  value: MfaRequirement.highRiskOnly,
                  child: Text('High Risk Login Only')),
              DropdownMenuItem(
                  value: MfaRequirement.adminOnly,
                  child: Text('Administrator Accounts Only')),
            ],
            onChanged: (value) async {
              if (value == null) return;
              setState(() => _mfaRequirement = value);
              await _saveSecurityPolicy();
            },
            decoration: const InputDecoration(labelText: 'Require MFA'),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<int>(
            value: _rememberDeviceDays,
            items: const [
              DropdownMenuItem(value: 7, child: Text('7 days')),
              DropdownMenuItem(value: 30, child: Text('30 days')),
              DropdownMenuItem(value: 60, child: Text('60 days')),
            ],
            onChanged: (value) async {
              if (value == null) return;
              setState(() => _rememberDeviceDays = value);
              await _saveSecurityPolicy();
            },
            decoration:
                const InputDecoration(labelText: 'Remember this device'),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => context.pushNamed(AppRoutes.securityManagement),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Security Management'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mfaChoice(MfaMethod method, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _defaultMfaMethod == method,
      onSelected: (value) async {
        if (!value) return;
        setState(() => _defaultMfaMethod = method);
        await _saveSecurityPolicy();
      },
    );
  }

  Widget _backupChoice(MfaMethod method, String label) {
    return FilterChip(
      label: Text(label),
      selected: _backupMfaMethods.contains(method),
      onSelected: (value) async {
        setState(() {
          if (value) {
            _backupMfaMethods.add(method);
          } else {
            _backupMfaMethods.remove(method);
          }
        });
        await _saveSecurityPolicy();
      },
    );
  }

  Widget _inviteCard() {
    return _RbacCard(
      title: 'Invite Collaborator',
      subtitle:
          'Create a governed invitation with role, scope, expiry, and granular permissions.',
      icon: Icons.person_add_alt_1_outlined,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: VoiceTextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _fieldDecoration('Email address',
                      icon: Icons.alternate_email),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: VoiceTextField(
                  controller: _nameController,
                  decoration:
                      _fieldDecoration('Full name', icon: Icons.badge_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<SiteRole>(
                  value: _selectedRole,
                  isExpanded: true,
                  menuMaxHeight: 280,
                  decoration:
                      _fieldDecoration('Platform role', icon: Icons.shield),
                  items: SiteRole.values
                      .map((role) => DropdownMenuItem(
                            value: role,
                            child: Text(role.displayName),
                          ))
                      .toList(),
                  onChanged: (role) {
                    if (role == null) return;
                    setState(() {
                      _selectedRole = role;
                      _customPermissions
                        ..clear()
                        ..addAll(Permission.getPermissionsForRole(role)
                            .take(role == SiteRole.owner ? 8 : 5));
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<ResourceAccessLevel>(
                  value: _selectedAccess,
                  isExpanded: true,
                  menuMaxHeight: 280,
                  decoration: _fieldDecoration('Resource access',
                      icon: Icons.folder_shared_outlined),
                  items: ResourceAccessLevel.values
                      .where((level) => level != ResourceAccessLevel.none)
                      .map((level) => DropdownMenuItem(
                            value: level,
                            child: Text(level.displayName),
                          ))
                      .toList(),
                  onChanged: (level) {
                    if (level != null) setState(() => _selectedAccess = level);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedScope,
                  isExpanded: true,
                  menuMaxHeight: 280,
                  decoration: _fieldDecoration('Access scope',
                      icon: Icons.account_tree_outlined),
                  items: const [
                    'Current project',
                    'All projects',
                    'Program workspace',
                    'Portfolio workspace',
                    'Read-only external workspace',
                  ]
                      .map((scope) =>
                          DropdownMenuItem(value: scope, child: Text(scope)))
                      .toList(),
                  onChanged: (scope) {
                    if (scope != null) setState(() => _selectedScope = scope);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedExpiry,
                  isExpanded: true,
                  menuMaxHeight: 280,
                  decoration: _fieldDecoration('Invite expires',
                      icon: Icons.event_available_outlined),
                  items: const ['7 days', '30 days', '90 days', 'Never']
                      .map((expiry) =>
                          DropdownMenuItem(value: expiry, child: Text(expiry)))
                      .toList(),
                  onChanged: (expiry) {
                    if (expiry != null) {
                      setState(() => _selectedExpiry = expiry);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          VoiceTextField(
            controller: _messageController,
            minLines: 2,
            maxLines: 4,
            decoration:
                _fieldDecoration('Invite note', icon: Icons.notes_outlined),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Additional permissions',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Permission.values.take(12).map((permission) {
              final selected = _customPermissions.contains(permission);
              return FilterChip(
                selected: selected,
                label: Text(_permissionLabel(permission)),
                selectedColor: _accent.withOpacity(0.22),
                checkmarkColor: Colors.black,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _customPermissions.add(permission);
                    } else {
                      _customPermissions.remove(permission);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendInvite,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_isSending ? 'Creating Invite...' : 'Send Invite'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _collaboratorsCard() {
    return _RbacCard(
      title: 'Collaborators',
      subtitle:
          'Live roster with role posture, activation state, and recent access signal.',
      icon: Icons.groups_2_outlined,
      child: StreamBuilder<List<UserProfile>>(
        stream: PermissionService.instance.getAllUsersStream(),
        builder: (context, snapshot) {
          final users = snapshot.data ?? const <UserProfile>[];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _RbacLoadingRow(label: 'Loading collaborators...');
          }
          if (snapshot.hasError) {
            return _EmptyRbacState(
              icon: Icons.lock_outline,
              title: 'Roster unavailable',
              message:
                  'Firestore rules did not allow the collaborator roster to load for this session.',
            );
          }
          if (users.isEmpty) {
            return const _EmptyRbacState(
              icon: Icons.people_outline,
              title: 'No collaborators yet',
              message: 'Send an invite to start building the workspace roster.',
            );
          }

          return Column(
            children: users.take(8).map((user) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CollaboratorTile(user: user),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _rolePresetCard() {
    return _RbacCard(
      title: 'Role Presets',
      subtitle:
          'Pre-approved platform personas keep access assignment consistent.',
      icon: Icons.workspace_premium_outlined,
      child: Column(
        children: SiteRole.values.map((role) {
          final selected = role == _selectedRole;
          final permissions = Permission.getPermissionsForRole(role).length;
          return InkWell(
            onTap: () => setState(() => _selectedRole = role),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? _accent.withOpacity(0.12)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: selected ? _accent : Colors.grey.withOpacity(0.14)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: role.color.withOpacity(0.14),
                    child: Icon(_roleIcon(role), color: role.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(role.displayName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('$permissions permissions · Level ${role.level}',
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle, color: _accent, size: 20),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _pendingInvitesCard() {
    return _RbacCard(
      title: 'Pending Invites',
      subtitle: 'Invitation queue with expiry, role, and approval readiness.',
      icon: Icons.mark_email_unread_outlined,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('collaboration_invites')
            .orderBy('createdAt', descending: true)
            .limit(8)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _RbacLoadingRow(label: 'Loading invitations...');
          }
          if (snapshot.hasError) {
            return const _EmptyRbacState(
              icon: Icons.warning_amber_rounded,
              title: 'Invite queue unavailable',
              message:
                  'Check Firestore access rules for collaboration_invites.',
            );
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const _EmptyRbacState(
              icon: Icons.outgoing_mail,
              title: 'No pending invitations',
              message: 'New collaborator invitations will appear here.',
            );
          }
          return Column(
            children: docs.map((doc) {
              final data = doc.data();
              final role =
                  SiteRole.fromString(data['siteRole']?.toString() ?? '');
              return _InviteTile(
                email: data['email']?.toString() ?? 'Unknown email',
                role: role,
                scope: data['scope']?.toString() ?? 'Workspace',
                status: data['status']?.toString() ?? 'pending',
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _permissionMatrixCard() {
    final permissionGroups = <String, List<Permission>>{
      'Governance': [
        Permission.manageBilling,
        Permission.manageUsers,
        Permission.manageRoles,
        Permission.manageSiteSettings,
        Permission.viewAnalytics,
      ],
      'Delivery': [
        Permission.createProject,
        Permission.editAnyProject,
        Permission.deleteAnyProject,
        Permission.archiveProject,
        Permission.createProgram,
        Permission.editAnyProgram,
        Permission.createPortfolio,
        Permission.editAnyPortfolio,
      ],
      'Collaboration': [
        Permission.inviteUsers,
        Permission.moderateComments,
        Permission.exportData,
        Permission.useAiGeneration,
        Permission.useAdvancedAiFeatures,
      ],
    };

    return _RbacCard(
      title: 'Permission Matrix',
      subtitle:
          'Role inheritance map for every critical governance and delivery action.',
      icon: Icons.grid_view_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: permissionGroups.entries.map((entry) {
          return _permissionGroupTable(entry.key, entry.value);
        }).toList(),
      ),
    );
  }

  Widget _permissionGroupTable(String title, List<Permission> permissions) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minTableWidth =
              constraints.maxWidth < 760 ? 760.0 : constraints.maxWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: minTableWidth),
                  child: Table(
                    border: TableBorder(
                      horizontalInside:
                          BorderSide(color: Colors.grey.withOpacity(0.12)),
                    ),
                    columnWidths: const {
                      0: FlexColumnWidth(2.6),
                      1: FlexColumnWidth(),
                      2: FlexColumnWidth(),
                      3: FlexColumnWidth(),
                      4: FlexColumnWidth(),
                      5: FlexColumnWidth(),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        children: [
                          const _PermissionTableHeader('Permission',
                              alignment: Alignment.centerLeft),
                          ...SiteRole.values.map((role) =>
                              _PermissionTableHeader(role.displayName)),
                        ],
                      ),
                      ...permissions.map((permission) {
                        return TableRow(
                          children: [
                            _PermissionTableCell(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _permissionLabel(permission),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            ...SiteRole.values.map((role) {
                              final allowed =
                                  Permission.getPermissionsForRole(role)
                                      .contains(permission);
                              return _PermissionTableCell(
                                child: Icon(
                                  allowed
                                      ? Icons.check_circle
                                      : Icons.remove_circle_outline,
                                  color: allowed
                                      ? const Color(0xFF16A34A)
                                      : Colors.black26,
                                  size: 20,
                                ),
                              );
                            }),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, {required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.18)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 1.4),
      ),
    );
  }
}

class _RbacCard extends StatelessWidget {
  const _RbacCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.16)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 12),
            color: Color(0x0D000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107).withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFFFFC107), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.black54, height: 1.35)),
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

class _AccessStat extends StatelessWidget {
  const _AccessStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.65), fontSize: 12)),
        ],
      ),
    );
  }
}

class _PolicyToggle extends StatelessWidget {
  const _PolicyToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.28)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFB45309)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CollaboratorTile extends StatelessWidget {
  const _CollaboratorTile({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: user.siteRole.color.withOpacity(0.16),
            child: Text(user.initials,
                style: TextStyle(
                    color: user.siteRole.color, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName.isEmpty ? user.email : user.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                if (user.displayName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(user.email,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ],
            ),
          ),
          _RolePill(role: user.siteRole),
          const SizedBox(width: 8),
          Icon(
            user.isActive ? Icons.check_circle : Icons.pause_circle_outline,
            color: user.isActive ? const Color(0xFF16A34A) : Colors.orange,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({
    required this.email,
    required this.role,
    required this.scope,
    required this.status,
  });

  final String email;
  final SiteRole role;
  final String scope;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.outgoing_mail, color: Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(scope,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          _RolePill(role: role),
          const SizedBox(width: 8),
          Text(status.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFB45309),
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final SiteRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: role.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(role.displayName,
          style: TextStyle(
              color: role.color, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _PermissionTableHeader extends StatelessWidget {
  const _PermissionTableHeader(
    this.label, {
    this.alignment = Alignment.center,
  });

  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        label,
        textAlign: alignment == Alignment.center ? TextAlign.center : null,
        style: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PermissionTableCell extends StatelessWidget {
  const _PermissionTableCell({
    required this.child,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: child,
    );
  }
}

class _RbacLoadingRow extends StatelessWidget {
  const _RbacLoadingRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

class _EmptyRbacState extends StatelessWidget {
  const _EmptyRbacState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.black38, size: 28),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, height: 1.35)),
        ],
      ),
    );
  }
}

IconData _roleIcon(SiteRole role) {
  switch (role) {
    case SiteRole.owner:
      return Icons.workspace_premium;
    case SiteRole.admin:
      return Icons.admin_panel_settings;
    case SiteRole.editor:
      return Icons.edit_note;
    case SiteRole.user:
      return Icons.person;
    case SiteRole.guest:
      return Icons.visibility_outlined;
  }
}

String _permissionLabel(Permission permission) {
  final raw = permission.name;
  final words = raw
      .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
      .split(' ');
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Preferences helper widgets ──

class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? accent.withOpacity(0.12)
              : Colors.grey.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent : Colors.grey.withOpacity(0.2),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: selected ? accent : Colors.black54),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? accent : Colors.black87,
                  fontSize: 13,
                )),
          ],
        ),
      ),
    );
  }
}

class _PrefActionTile extends StatelessWidget {
  const _PrefActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.grey.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (labelColor ?? const Color(0xFFFFC107))
                        .withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(icon, color: labelColor ?? Colors.black54, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: labelColor ?? Colors.black87,
                          )),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: labelColor ?? Colors.black38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrefInfoRow extends StatelessWidget {
  const _PrefInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Colors.black87,
              )),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black54,
              )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// InviteVerificationDialog — Email OTP verification for the Invite Collaborator flow
// ═══════════════════════════════════════════════════════════════════════════
//
// Mirrors the TwoFactorVerificationScreen structure:
// • 6-digit OTP input fields (auto-advance, backspace navigation)
// • Resend code with 60-second cooldown
// • Verify button (auto-submits when all 6 digits entered)
// • Error message display
// • Cancel button
//
// The OTP is sent to the inviter's email (not the invitee's) to confirm
// the inviter is authorized to send invitations. Only after successful
// verification does the invitation get created in Firestore.

class InviteVerificationDialog extends StatefulWidget {
  final String email;
  final String inviteeEmail;
  final String inviteeName;

  const InviteVerificationDialog({
    super.key,
    required this.email,
    required this.inviteeEmail,
    required this.inviteeName,
  });

  @override
  State<InviteVerificationDialog> createState() =>
      _InviteVerificationDialogState();
}

class _InviteVerificationDialogState extends State<InviteVerificationDialog> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isSending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // OTP was already sent by _sendInvite() before showing this dialog.
    // Start the resend cooldown immediately.
    _resendCooldown = 60;
    _startCooldown();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _cooldownTimer?.cancel();
    super.dispose();
  }

  String get _enteredCode => _controllers.map((c) => c.text).join();

  // ── Resend OTP ──────────────────────────────────────────────────────
  Future<void> _resendCode() async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    try {
      await TwoFactorAuthService.sendCode(email: widget.email);
      if (mounted) {
        setState(() => _resendCooldown = 60);
        _startCooldown();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification code sent to ${widget.email}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => _errorMessage = 'Failed to resend code. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 0) {
        timer.cancel();
      } else if (mounted) {
        setState(() => _resendCooldown--);
      }
    });
  }

  // ── Verify OTP ──────────────────────────────────────────────────────
  Future<void> _verifyCode() async {
    final code = _enteredCode;
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the full 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await TwoFactorAuthService.verifyCode(
        code: code,
        email: widget.email,
      );
      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _errorMessage = 'Invalid code. Please try again.');
        _clearCode();
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => _errorMessage = 'Verification failed. Please try again.');
        _clearCode();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearCode() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    const primaryText = Color(0xFF1F2933);
    const secondaryText = Color(0xFF616E7C);
    const accent = Color(0xFFFFC107);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.mark_email_read_outlined,
                        color: Color(0xFF8A5800), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Verify Your Email',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Confirm invitation to ${widget.inviteeName.isNotEmpty ? widget.inviteeName : widget.inviteeEmail}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Description ───────────────────────────────────────
              Text(
                'Enter the 6-digit code sent to',
                style: const TextStyle(fontSize: 13, color: secondaryText),
              ),
              const SizedBox(height: 2),
              Text(
                widget.email,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
              const SizedBox(height: 20),

              // ── OTP Input Fields ──────────────────────────────────
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    return Container(
                      width: 44,
                      height: 52,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey ==
                                  LogicalKeyboardKey.backspace &&
                              _controllers[index].text.isEmpty &&
                              index > 0) {
                            _controllers[index - 1].clear();
                            _focusNodes[index - 1].requestFocus();
                          }
                        },
                        child: TextFormField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: primaryText,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFFD2D6DC),
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFFD2D6DC),
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: accent,
                                width: 2,
                              ),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            }
                            if (value.isNotEmpty && index == 5) {
                              _focusNodes[index].unfocus();
                              _verifyCode();
                            }
                          },
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),

              // ── Error Message ─────────────────────────────────────
              if (_errorMessage != null) ...[
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // ── Verify Button ─────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Text('Verify & Send Invite',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 14),

              // ── Resend & Cancel Row ───────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Resend code
                  _resendCooldown > 0
                      ? Text(
                          'Resend code in ${_resendCooldown}s',
                          style: const TextStyle(
                            color: secondaryText,
                            fontSize: 12.5,
                          ),
                        )
                      : GestureDetector(
                          onTap: _isSending ? null : _resendCode,
                          child: Text(
                            _isSending ? 'Sending...' : 'Resend Code',
                            style: const TextStyle(
                              color: accent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                  // Cancel
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12.5,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
