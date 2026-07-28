/// Ndu Project — Pixel-perfect app definition in the FlutterFlow AI DSL.
/// Matches the actual source code UI exactly: colors, spacing, typography,
/// data models, and screen layouts from the Ndu Project Flutter app.
library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  try {
    await flutterFlowAI(
      buildNduProject,
      apiKey: options.apiKey,
      baseUrl: options.baseUrl,
      projectName: options.projectName,
      projectId: options.projectId,
      findOrCreate: options.findOrCreate,
      allowNewProject: options.allowNewProject,
      dryRun: options.dryRun,
      commitMessage: options.commitMessage,
    );
  } catch (error) {
    stderr.writeln('Error: ${formatFlutterFlowAIError(error)}');
    exit(1);
  }
}

final class _CliOptions {
  const _CliOptions({
    this.apiKey,
    this.baseUrl,
    this.projectName,
    this.projectId,
    this.findOrCreate = false,
    this.allowNewProject = false,
    this.dryRun = false,
    this.commitMessage,
  });
  final String? apiKey;
  final String? baseUrl;
  final String? projectName;
  final String? projectId;
  final bool findOrCreate;
  final bool allowNewProject;
  final bool dryRun;
  final String? commitMessage;
}

_CliOptions _parseCliOptions(List<String> args) {
  String? apiKey, baseUrl, projectName, projectId, commitMessage;
  var findOrCreate = false, allowNewProject = false, dryRun = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--api-key': apiKey = args[++i];
      case '--base-url': baseUrl = args[++i];
      case '--project-name': projectName = args[++i];
      case '--project-id': projectId = args[++i];
      case '--commit-message': commitMessage = args[++i];
      case '--find-or-create': findOrCreate = true;
      case '--allow-new-project': allowNewProject = true;
      case '--dry-run': dryRun = true;
      default: stderr.writeln('Unknown: ${args[i]}'); exit(64);
    }
  }
  return _CliOptions(
    apiKey: apiKey, baseUrl: baseUrl, projectName: projectName,
    projectId: projectId, findOrCreate: findOrCreate,
    allowNewProject: allowNewProject, dryRun: dryRun,
    commitMessage: commitMessage,
  );
}

void buildNduProject(App app) {
  // ═══════════════════════════════════════════════════════════════════════
  // THEME — Matches theme.dart exactly
  // ═══════════════════════════════════════════════════════════════════════
  app.themeColor('primary', 0xFFFFC812);           // Brand yellow
  app.themeColor('secondary', 0xFF2563EB);         // Info blue
  app.themeColor('tertiary', 0xFF16A34A);          // Success green
  app.themeColor('primaryBackground', 0xFFF7FAFC); // Light surface
  app.themeColor('secondaryBackground', 0xFFFFFFFF); // White cards
  app.themeColor('primaryText', 0xFF0F172A);       // Slate 900
  app.themeColor('secondaryText', 0xFF64748B);     // Slate 500
  app.themeColor('error', 0xFFBA1A1A);             // Error red
  app.themeColor('success', 0xFF22C55E);           // Green 500
  app.primaryFont('Satoshi');
  app.breakpoints(small: 479, medium: 991, large: 1200);

  // ═══════════════════════════════════════════════════════════════════════
  // ENUMS
  // ═══════════════════════════════════════════════════════════════════════
  final severity = app.enum_('Severity', ['critical', 'high', 'medium', 'low']);
  final actionStatus = app.enum_('ActionStatus', ['open', 'in_progress', 'resolved', 'closed']);
  final riskLevel = app.enum_('RiskLevel', ['critical', 'high', 'medium', 'low']);
  final complianceStatus = app.enum_('ComplianceStatus', ['compliant', 'non_compliant', 'pending_review', 'exempt']);
  final projectPhase = app.enum_('ProjectPhase', ['initiation', 'planning', 'design', 'execution', 'launch', 'closeout']);
  final pricingTier = app.enum_('PricingTier', ['basic_project', 'project', 'program', 'portfolio']);

  // ═══════════════════════════════════════════════════════════════════════
  // DATA STRUCTS — Matches model classes in the Flutter app
  // ═══════════════════════════════════════════════════════════════════════
  final distributionRow = app.struct('DistributionRow', {
    'category': string, 'openItems': int_, 'critical': int_,
    'high': int_, 'medium': int_, 'low': int_, 'closed': int_,
    'owner': string, 'status': string, 'lastUpdated': string,
  });
  final velocityRow = app.struct('ActionVelocityRow', {
    'workstream': string, 'openItems': int_, 'closedThisSprint': int_,
    'velocity': double_, 'throughput': double_, 'delta': string,
    'avgCycleTime': string, 'period': string, 'owner': string, 'status': string,
  });
  final capacityRow = app.struct('CapacityHealthRow', {
    'team': string, 'plannedFte': double_, 'allocatedFte': double_,
    'availableFte': double_, 'utilization': double_, 'overallocated': int_,
    'fteVariance': double_, 'burnRate': string, 'productivityIndex': double_,
    'overtimeHrs': double_, 'absenteeismRate': double_, 'skillGap': string,
    'backlogWeeks': double_, 'costVariance': double_, 'riskLevel': string,
    'owner': string, 'status': string, 'lastUpdated': string,
  });
  final shiftRow = app.struct('ShiftCoverageRow', {
    'shift': string, 'requiredHeadcount': int_, 'actualHeadcount': int_,
    'coveragePercent': double_, 'gap': int_, 'shiftPattern': string,
    'overtimeHrs': double_, 'contractorFill': int_, 'agencyStaff': int_,
    'absenceCount': int_, 'complianceStatus': string, 'nextRotation': string,
    'supervisor': string, 'riskFlag': string, 'status': string, 'lastUpdated': string,
  });
  final complianceRow = app.struct('ComplianceRegRow', {
    'regId': string, 'regulationName': string, 'category': string,
    'complianceStatus': string, 'responsibleParty': string, 'dueDate': string,
    'riskLevel': string, 'auditStatus': string, 'lastUpdated': string,
  });
  final insightStruct = app.struct('PunchlistInsight', {
    'title': string, 'owner': string, 'dueIn': string,
    'severity': string, 'status': string,
  });
  final projectStruct = app.struct('ProjectData', {
    'id': string, 'name': string, 'phase': string, 'sprint': string,
    'program': string, 'portfolio': string, 'completionPercent': double_, 'status': string,
  });
  final riskStruct = app.struct('RiskItem', {
    'id': string, 'description': string, 'probability': string,
    'impact': string, 'mitigation': string, 'owner': string, 'status': string,
  });
  final milestoneStruct = app.struct('MilestoneItem', {
    'name': string, 'dueDate': string, 'status': string,
    'owner': string, 'percentComplete': double_,
  });

  // ═══════════════════════════════════════════════════════════════════════
  // APP STATE
  // ═══════════════════════════════════════════════════════════════════════
  app.constant('appName', 'Ndu Project');
  app.constant('tagline', 'INITIATE. DELIVER. ITERATE.');
  app.state('currentProject', projectStruct, persisted: true);
  app.state('distributionData', listOf(distributionRow), persisted: true);
  app.state('velocityData', listOf(velocityRow), persisted: true);
  app.state('capacityData', listOf(capacityRow), persisted: true);
  app.state('shiftData', listOf(shiftRow), persisted: true);
  app.state('complianceData', listOf(complianceRow), persisted: true);
  app.state('insightsData', listOf(insightStruct), persisted: true);
  app.state('risksData', listOf(riskStruct), persisted: true);
  app.state('milestonesData', listOf(milestoneStruct), persisted: true);
  app.state('isLoggedIn', bool_.withDefault(false), persisted: true);

  // ═══════════════════════════════════════════════════════════════════════
  // REUSABLE COMPONENTS
  // ═══════════════════════════════════════════════════════════════════════

  // Stat Card — matches DashboardStatCard in the Flutter app
  final dynamic statCard = app.component(
    'StatCard',
    params: {
      'label': string,
      'value': string,
      'subLabel': string.withDefault(''),
    },
    body: Card(
      elevation: 0,
      borderRadius: 16,
      color: Colors.secondaryBackground,
      child: Container(
        padding: 16,
        child: Column(
          crossAxis: CrossAxis.start,
          spacing: 4,
          children: [
            Text(Param('value'), style: Styles.headlineMedium),
            Text(Param('label'), style: Styles.bodySmall, color: Colors.secondaryText),
            Text(Param('subLabel'), style: Styles.labelSmall, color: Colors.secondaryText),
          ],
        ),
      ),
    ),
  );

  // Context Chip — matches _ContextChip in the Flutter app
  final dynamic contextChip = app.component(
    'ContextChip',
    params: {
      'label': string,
    },
    body: Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      borderRadius: 22,
      color: Colors.primary,
      child: Text(Param('label'), style: Styles.labelSmall, color: Colors.primaryText),
    ),
  );

  // Severity Badge
  final dynamic severityBadge = app.component(
    'SeverityBadge',
    params: {
      'label': string,
    },
    body: Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      borderRadius: 999,
      color: Colors.error,
      child: Text(Param('label'), style: Styles.labelSmall, color: Colors.secondaryBackground),
    ),
  );

  // Insight Card — matches the punchlist insight cards in the Flutter app
  final dynamic insightCard = app.component(
    'InsightCard',
    params: {
      'title': string,
      'severity': string.withDefault('medium'),
      'owner': string.withDefault(''),
      'dueIn': string.withDefault(''),
    },
    body: Container(
      padding: 12,
      borderRadius: 8,
      borderColor: Colors.hex(0xFFE5E7EB),
      borderWidth: 1,
      child: Row(
        spacing: 10,
        crossAxis: CrossAxis.start,
        children: [
          Container(
            width: 4,
            height: 40,
            borderRadius: 2,
            color: Colors.primary,
          ),
          Flexible(
            Column(
              crossAxis: CrossAxis.start,
              spacing: 4,
              children: [
                Text(Param('title'), style: Styles.titleSmall),
                Row(
                  spacing: 8,
                  children: [
                    Text(Param('owner'), style: Styles.labelSmall, color: Colors.secondaryText),
                    Text(Param('dueIn'), style: Styles.labelSmall, color: Colors.secondaryText),
                  ],
                ),
                severityBadge(label: Param('severity')),
              ],
            ),
            flex: 1,
          ),
        ],
      ),
    ),
  );

  // Compliance Row Card — matches the compliance table rows
  final dynamic complianceCard = app.component(
    'ComplianceCard',
    params: {
      'regId': string,
      'regulationName': string,
      'category': string,
      'complianceStatus': string,
      'responsibleParty': string,
      'dueDate': string,
      'riskLevel': string,
      'auditStatus': string,
      'lastUpdated': string.withDefault(''),
    },
    body: Container(
      padding: 12,
      borderRadius: 8,
      borderColor: Colors.hex(0xFFE5E7EB),
      borderWidth: 1,
      color: Colors.secondaryBackground,
      child: Column(
        crossAxis: CrossAxis.start,
        spacing: 6,
        children: [
          Row(
            mainAxis: MainAxis.spaceBetween,
            children: [
              Text(Param('regId'), style: Styles.labelSmall, color: Colors.secondaryText),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                borderRadius: 999,
                color: Colors.tertiary,
                child: Text(Param('complianceStatus'), style: Styles.labelSmall, color: Colors.secondaryBackground),
              ),
            ],
          ),
          Text(Param('regulationName'), style: Styles.titleSmall),
          Row(
            spacing: 8,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                borderRadius: 999,
                color: Colors.hex(0xFFF1F5F9),
                child: Text(Param('category'), style: Styles.labelSmall, color: Colors.secondaryText),
              ),
              Text('Risk: ${Param('riskLevel')}', style: Styles.labelSmall, color: Colors.error),
            ],
          ),
          Row(
            mainAxis: MainAxis.spaceBetween,
            children: [
              Text(Param('responsibleParty'), style: Styles.bodySmall, color: Colors.secondaryText),
              Text(Param('dueDate'), style: Styles.bodySmall, color: Colors.secondaryText),
            ],
          ),
          Row(
            mainAxis: MainAxis.spaceBetween,
            children: [
              Text('Audit: ${Param('auditStatus')}', style: Styles.labelSmall, color: Colors.secondaryText),
              Text(Param('lastUpdated'), style: Styles.labelSmall, color: Colors.secondaryText),
            ],
          ),
        ],
      ),
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════
  // PAGES — Matches actual screen layouts
  // ═══════════════════════════════════════════════════════════════════════

  // ── Landing Page — Dark theme, marketing page
  app.page(
    'LandingPage',
    route: '/',
    isInitial: true,
    state: {
      'showSignIn': bool_.withDefault(false),
    },
    body: Scaffold(
      body: Container(
        color: Colors.hex(0xFF040404),
        child: Column(
          scrollable: true,
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Row(
                mainAxis: MainAxis.spaceBetween,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      Icon('construction', size: 28, color: Colors.primary),
                      Text('Ndu Project', style: Styles.titleLarge, color: Colors.secondaryBackground),
                    ],
                  ),
                  Row(
                    spacing: 12,
                    children: [
                      Button('Platform', variant: ButtonVariant.text, color: Colors.hex(0xFFE5E7EB), onTap: Snackbar('Scroll to platform')),
                      Button('Solutions', variant: ButtonVariant.text, color: Colors.hex(0xFFE5E7EB), onTap: Snackbar('Scroll to solutions')),
                      Button('Pricing', variant: ButtonVariant.text, color: Colors.hex(0xFFE5E7EB), onTap: Navigate('PricingPage')),
                      Button(
                        'Sign In',
                        variant: ButtonVariant.outlined,
                        color: Colors.primary,
                        textColor: Colors.primary,
                        borderRadius: 22,
                        onTap: Navigate('SignInPage'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Hero
            Container(
              padding: EdgeInsets.symmetric(horizontal: 32),
              alignment: Alignment.center,
              child: Column(
                spacing: 20,
                children: [
                  Container(height: 8),
                  Text('INITIATE. DELIVER. ITERATE.', style: Styles.labelMedium, color: Colors.primary),
                  Text('Project management\nfor the built environment', style: Styles.headlineMedium, color: Colors.secondaryBackground, textAlign: TextAlign.center),
                  Text('End-to-end delivery tracking from front-end planning through close-out. Built for teams that build.', style: Styles.bodyMedium, color: Colors.hex(0xFF94A3B8), textAlign: TextAlign.center),
                  Button(
                    'Start Your Project',
                    color: Colors.primary,
                    textColor: Colors.primaryText,
                    borderRadius: 22,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    onTap: Navigate('PricingPage'),
                  ),
                ],
              ),
            ),
            // Metric Cards — inlined from _metricCard
            Container(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 32),
              child: Row(
                spacing: 16,
                children: [
                  Flexible(Container(
                    padding: 20,
                    borderRadius: 16,
                    borderColor: Colors.hex(0xFF1F2937),
                    borderWidth: 1,
                    child: Column(
                      crossAxis: CrossAxis.start,
                      spacing: 8,
                      children: [
                        Text('30%', style: Styles.headlineMedium, color: Colors.primary),
                        Text('Faster Delivery', style: Styles.titleSmall, color: Colors.secondaryBackground),
                        Text('Reduce project cycle times with structured execution', style: Styles.bodySmall, color: Colors.hex(0xFF94A3B8)),
                      ],
                    ),
                  ), flex: 1),
                  Flexible(Container(
                    padding: 20,
                    borderRadius: 16,
                    borderColor: Colors.hex(0xFF1F2937),
                    borderWidth: 1,
                    child: Column(
                      crossAxis: CrossAxis.start,
                      spacing: 8,
                      children: [
                        Text('88%', style: Styles.headlineMedium, color: Colors.primary),
                        Text('On-Time Completion', style: Styles.titleSmall, color: Colors.secondaryBackground),
                        Text('Industry-leading schedule adherence', style: Styles.bodySmall, color: Colors.hex(0xFF94A3B8)),
                      ],
                    ),
                  ), flex: 1),
                  Flexible(Container(
                    padding: 20,
                    borderRadius: 16,
                    borderColor: Colors.hex(0xFF1F2937),
                    borderWidth: 1,
                    child: Column(
                      crossAxis: CrossAxis.start,
                      spacing: 8,
                      children: [
                        Text('40-60%', style: Styles.headlineMedium, color: Colors.primary),
                        Text('Cost Variance Reduction', style: Styles.titleSmall, color: Colors.secondaryBackground),
                        Text('Real-time budget tracking and control', style: Styles.bodySmall, color: Colors.hex(0xFF94A3B8)),
                      ],
                    ),
                  ), flex: 1),
                  Flexible(Container(
                    padding: 20,
                    borderRadius: 16,
                    borderColor: Colors.hex(0xFF1F2937),
                    borderWidth: 1,
                    child: Column(
                      crossAxis: CrossAxis.start,
                      spacing: 8,
                      children: [
                        Text('96%', style: Styles.headlineMedium, color: Colors.primary),
                        Text('Stakeholder Satisfaction', style: Styles.titleSmall, color: Colors.secondaryBackground),
                        Text('Transparent reporting and collaboration', style: Styles.bodySmall, color: Colors.hex(0xFF94A3B8)),
                      ],
                    ),
                  ), flex: 1),
                ],
              ),
            ),
            // Platform Capabilities — inlined from _capabilityCard
            Container(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                crossAxis: CrossAxis.start,
                spacing: 20,
                children: [
                  Text('PLATFORM CAPABILITIES', style: Styles.labelMedium, color: Colors.primary),
                  Text('Everything your project needs', style: Styles.headlineSmall, color: Colors.secondaryBackground),
                  Row(
                    spacing: 16,
                    children: [
                      Flexible(Container(
                        padding: 20,
                        borderRadius: 16,
                        borderColor: Colors.hex(0xFF1F2937),
                        borderWidth: 1,
                        child: Column(
                          crossAxis: CrossAxis.start,
                          spacing: 8,
                          children: [
                            Text('Front-End Planning', style: Styles.titleSmall, color: Colors.secondaryBackground),
                            Text('Requirements, scope, risk, and procurement planning in one workspace', style: Styles.bodySmall, color: Colors.hex(0xFF94A3B8)),
                          ],
                        ),
                      ), flex: 1),
                      Flexible(Container(
                        padding: 20,
                        borderRadius: 16,
                        borderColor: Colors.hex(0xFF1F2937),
                        borderWidth: 1,
                        child: Column(
                          crossAxis: CrossAxis.start,
                          spacing: 8,
                          children: [
                            Text('Risk & SSHER', style: Styles.titleSmall, color: Colors.secondaryBackground),
                            Text('Safety, security, health, environment, and risk management', style: Styles.bodySmall, color: Colors.hex(0xFF94A3B8)),
                          ],
                        ),
                      ), flex: 1),
                      Flexible(Container(
                        padding: 20,
                        borderRadius: 16,
                        borderColor: Colors.hex(0xFF1F2937),
                        borderWidth: 1,
                        child: Column(
                          crossAxis: CrossAxis.start,
                          spacing: 8,
                          children: [
                            Text('Team Collaboration', style: Styles.titleSmall, color: Colors.secondaryBackground),
                            Text('Roles, meetings, training, and resource management', style: Styles.bodySmall, color: Colors.hex(0xFF94A3B8)),
                          ],
                        ),
                      ), flex: 1),
                    ],
                  ),
                  Row(
                    spacing: 16,
                    children: [
                      Flexible(Container(
                        padding: 20,
                        borderRadius: 16,
                        borderColor: Colors.hex(0xFF1F2937),
                        borderWidth: 1,
                        child: Column(
                          crossAxis: CrossAxis.start,
                          spacing: 8,
                          children: [
                            Text('WBS & Scheduling', style: Styles.titleSmall, color: Colors.secondaryBackground),
                            Text('Work breakdown structures and milestone tracking', style: Styles.bodySmall, color: Colors.hex(0xFF94A3B8)),
                          ],
                        ),
                      ), flex: 1),
                      Flexible(Container(
                        padding: 20,
                        borderRadius: 16,
                        borderColor: Colors.hex(0xFF1F2937),
                        borderWidth: 1,
                        child: Column(
                          crossAxis: CrossAxis.start,
                          spacing: 8,
                          children: [
                            Text('Finance & Procurement', style: Styles.titleSmall, color: Colors.secondaryBackground),
                            Text('Budget tracking, cost analysis, and vendor management', style: Styles.bodySmall, color: Colors.hex(0xFF94A3B8)),
                          ],
                        ),
                      ), flex: 1),
                      Flexible(Container(
                        padding: 20,
                        borderRadius: 16,
                        borderColor: Colors.hex(0xFF1F2937),
                        borderWidth: 1,
                        child: Column(
                          crossAxis: CrossAxis.start,
                          spacing: 8,
                          children: [
                            Text('KAZ AI', style: Styles.titleSmall, color: Colors.secondaryBackground),
                            Text('AI-powered insights, recommendations, and chat support', style: Styles.bodySmall, color: Colors.hex(0xFF94A3B8)),
                          ],
                        ),
                      ), flex: 1),
                    ],
                  ),
                ],
              ),
            ),
            // CTA
            Container(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              alignment: Alignment.center,
              child: Column(
                spacing: 16,
                children: [
                  Text('Ready to transform your project delivery?', style: Styles.headlineSmall, color: Colors.secondaryBackground),
                  Row(
                    mainAxis: MainAxis.center,
                    spacing: 12,
                    children: [
                      Button('Start Your Project', color: Colors.primary, textColor: Colors.primaryText, borderRadius: 22, padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14), onTap: Navigate('PricingPage')),
                      Button('Schedule Consultation', variant: ButtonVariant.outlined, color: Colors.hex(0xFFE5E7EB), textColor: Colors.hex(0xFFE5E7EB), borderRadius: 22, padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14), onTap: Snackbar('Consultation form')),
                    ],
                  ),
                ],
              ),
            ),
            // Footer
            Container(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              borderColor: Colors.hex(0xFF1F2937),
              borderWidth: 1,
              child: Row(
                mainAxis: MainAxis.spaceBetween,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      Icon('construction', size: 20, color: Colors.primary),
                      Text('Ndu Project', style: Styles.bodyMedium, color: Colors.hex(0xFF94A3B8)),
                    ],
                  ),
                  Row(
                    spacing: 16,
                    children: [
                      Button('Terms', variant: ButtonVariant.text, color: Colors.hex(0xFF64748B), onTap: Snackbar('Terms page')),
                      Button('Privacy', variant: ButtonVariant.text, color: Colors.hex(0xFF64748B), onTap: Snackbar('Privacy page')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ── Sign In — Matches sign_in_screen.dart layout
  app.page(
    'SignInPage',
    route: '/sign-in',
    state: {
      'email': string.withDefault(''),
      'password': string.withDefault(''),
      'isLoading': bool_.withDefault(false),
    },
    body: Scaffold(
      body: Container(
        color: Colors.secondaryBackground,
        alignment: Alignment.center,
        child: Container(
          width: 480,
          padding: 32,
          child: Column(
            mainAxis: MainAxis.center,
            crossAxis: CrossAxis.start,
            spacing: 20,
            children: [
              // Logo
              Container(
                alignment: Alignment.center,
                child: Column(
                  spacing: 8,
                  children: [
                    Icon('construction', size: 48, color: Colors.primary),
                    Text('Ndu Project', style: Styles.headlineSmall),
                  ],
                ),
              ),
              Text('Welcome back', style: Styles.headlineMedium),
              TextField(
                label: 'Email',
                hint: 'you@company.com',
                prefixIcon: 'email',
                keyboard: Keyboard.email,
                name: 'SignInEmail',
                onChanged: SetState('email', TextValue()),
              ),
              TextField(
                label: 'Password',
                hint: 'Enter your password',
                prefixIcon: 'lock',
                obscureText: true,
                name: 'SignInPassword',
                onChanged: SetState('password', TextValue()),
              ),
              Row(
                mainAxis: MainAxis.spaceBetween,
                children: [
                  Checkbox(label: 'Remember me', value: false, onChanged: Snackbar('Remember me toggled')),
                  Button('Forgot password?', variant: ButtonVariant.text, onTap: Snackbar('Password reset email sent')),
                ],
              ),
              Button(
                'Sign In',
                icon: 'login',
                width: double.infinity,
                height: 54,
                color: Colors.hex(0xFFFFC107),
                textColor: Colors.primaryText,
                borderRadius: 12,
                onTap: [
                  UpdateAppState.set('isLoggedIn', true),
                  Navigate('DashboardPage'),
                ],
              ),
              Container(alignment: Alignment.center, child: Text('or', style: Styles.bodySmall, color: Colors.secondaryText)),
              Button(
                'Continue with Google',
                icon: 'g_mobiledata',
                variant: ButtonVariant.outlined,
                width: double.infinity,
                height: 54,
                borderRadius: 12,
                onTap: [
                  UpdateAppState.set('isLoggedIn', true),
                  Navigate('DashboardPage'),
                ],
              ),
              Row(
                mainAxis: MainAxis.center,
                spacing: 4,
                children: [
                  Text("Don't have an account?", style: Styles.bodySmall, color: Colors.secondaryText),
                  Button('Create Account', variant: ButtonVariant.text, onTap: Navigate('CreateAccountPage')),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // ── Create Account — Matches create_account_screen.dart
  app.page(
    'CreateAccountPage',
    route: '/create-account',
    state: {
      'firstName': string.withDefault(''),
      'lastName': string.withDefault(''),
      'company': string.withDefault(''),
      'email': string.withDefault(''),
      'password': string.withDefault(''),
    },
    body: Scaffold(
      appBar: AppBar(title: ''),
      body: Container(
        color: Colors.secondaryBackground,
        alignment: Alignment.center,
        child: Container(
          width: 520,
          padding: 32,
          child: Column(
            mainAxis: MainAxis.center,
            crossAxis: CrossAxis.start,
            spacing: 16,
            children: [
              Container(alignment: Alignment.center, child: Icon('construction', size: 40, color: Colors.primary)),
              Text('Create Account', style: Styles.headlineSmall),
              Row(
                spacing: 12,
                children: [
                  Flexible(TextField(label: 'First Name', hint: 'John', name: 'FirstName', onChanged: SetState('firstName', TextValue())), flex: 1),
                  Flexible(TextField(label: 'Last Name', hint: 'Doe', name: 'LastName', onChanged: SetState('lastName', TextValue())), flex: 1),
                ],
              ),
              TextField(label: 'Company Name', hint: 'Your organization', name: 'CompanyName', onChanged: SetState('company', TextValue())),
              TextField(label: 'Email', hint: 'you@company.com', prefixIcon: 'email', keyboard: Keyboard.email, name: 'CreateEmail', onChanged: SetState('email', TextValue())),
              TextField(label: 'Password', hint: 'Min. 8 characters', prefixIcon: 'lock', obscureText: true, name: 'CreatePassword', onChanged: SetState('password', TextValue())),
              Checkbox(label: 'I agree to the Privacy Policy and Terms of Service', value: false, onChanged: Snackbar('Terms agreement toggled')),
              Button(
                'Get Started',
                icon: 'person_add',
                width: double.infinity,
                height: 54,
                color: Colors.hex(0xFFFFC107),
                textColor: Colors.primaryText,
                borderRadius: 12,
                onTap: [
                  UpdateAppState.set('isLoggedIn', true),
                  Navigate('DashboardPage'),
                ],
              ),
              Row(mainAxis: MainAxis.center, spacing: 4, children: [
                Text('Already have an account?', style: Styles.bodySmall, color: Colors.secondaryText),
                Button('Sign in', variant: ButtonVariant.text, onTap: Navigate('SignInPage')),
              ]),
            ],
          ),
        ),
      ),
    ),
  );

  // ── Pricing — Matches pricing_screen.dart (4 tiers) — inlined from _planCard
  app.page(
    'PricingPage',
    route: '/pricing',
    state: {
      'isAnnual': bool_.withDefault(false),
    },
    body: Scaffold(
      appBar: AppBar(title: 'Pricing'),
      body: Container(
        color: Colors.primaryBackground,
        padding: 20,
        child: Column(
          crossAxis: CrossAxis.start,
          spacing: 20,
          children: [
            Text('Choose your plan', style: Styles.headlineSmall),
            Text('Scale from projects to full portfolios', style: Styles.bodyMedium, color: Colors.secondaryText),
            // Billing toggle
            Row(
              mainAxis: MainAxis.center,
              spacing: 12,
              children: [
                Text('Monthly', style: Styles.bodyMedium, color: Colors.secondaryText),
                Toggle(label: 'Annual (save 1 month)', value: State('isAnnual'), onChanged: SetState('isAnnual', const WidgetValue())),
              ],
            ),
            // Plan cards — inlined from _planCard
            Row(
              spacing: 12,
              children: [
                Flexible(Card(
                  elevation: 0,
                  borderRadius: 16,
                  color: Colors.secondaryBackground,
                  child: Container(
                    padding: 20,
                    child: Column(
                      crossAxis: CrossAxis.start,
                      spacing: 12,
                      children: [
                        Text('Regular Project', style: Styles.titleMedium),
                        Row(spacing: 2, children: [
                          Text('\$39', style: Styles.headlineMedium),
                          Text('/mo', style: Styles.bodySmall, color: Colors.secondaryText),
                        ]),
                        Divider(),
                        Row(spacing: 8, children: [Icon('check_circle', size: 16, color: Colors.tertiary), Text('1 active project', style: Styles.bodySmall)]),
                        Row(spacing: 8, children: [Icon('check_circle', size: 16, color: Colors.tertiary), Text('Basic dashboards & reports', style: Styles.bodySmall)]),
                        Row(spacing: 8, children: [Icon('check_circle', size: 16, color: Colors.tertiary), Text('Email support', style: Styles.bodySmall)]),
                        Spacer(flex: 1, name: 'PlanSpacer'),
                        Button('Select Plan', width: double.infinity, borderRadius: 12, color: Colors.hex(0xFFFFC107), textColor: Colors.hex(0xFF0F172A), onTap: Snackbar('Plan selected: Regular Project')),
                      ],
                    ),
                  ),
                ), flex: 1),
                Flexible(Card(
                  elevation: 0,
                  borderRadius: 16,
                  color: Colors.secondaryBackground,
                  child: Container(
                    padding: 20,
                    child: Column(
                      crossAxis: CrossAxis.start,
                      spacing: 12,
                      children: [
                        Text('Project', style: Styles.titleMedium),
                        Row(spacing: 2, children: [
                          Text('\$129', style: Styles.headlineMedium),
                          Text('/mo', style: Styles.bodySmall, color: Colors.secondaryText),
                        ]),
                        Divider(),
                        Row(spacing: 8, children: [Icon('check_circle', size: 16, color: Colors.tertiary), Text('5 active projects', style: Styles.bodySmall)]),
                        Row(spacing: 8, children: [Icon('check_circle', size: 16, color: Colors.tertiary), Text('Advanced analytics & CRUD tables', style: Styles.bodySmall)]),
                        Row(spacing: 8, children: [Icon('check_circle', size: 16, color: Colors.tertiary), Text('Priority support', style: Styles.bodySmall)]),
                        Spacer(flex: 1, name: 'PlanSpacer'),
                        Button('Select Plan', width: double.infinity, borderRadius: 12, color: Colors.hex(0xFFFFC107), textColor: Colors.hex(0xFF0F172A), onTap: Snackbar('Plan selected: Project')),
                      ],
                    ),
                  ),
                ), flex: 1),
                Flexible(Card(
                  elevation: 0,
                  borderRadius: 16,
                  color: Colors.secondaryBackground,
                  child: Container(
                    padding: 20,
                    child: Column(
                      crossAxis: CrossAxis.start,
                      spacing: 12,
                      children: [
                        Text('Program', style: Styles.titleMedium),
                        Row(spacing: 2, children: [
                          Text('\$319', style: Styles.headlineMedium),
                          Text('/mo', style: Styles.bodySmall, color: Colors.secondaryText),
                        ]),
                        Divider(),
                        Row(spacing: 8, children: [Icon('check_circle', size: 16, color: Colors.tertiary), Text('Unlimited projects', style: Styles.bodySmall)]),
                        Row(spacing: 8, children: [Icon('check_circle', size: 16, color: Colors.tertiary), Text('Program-level views & KAZ AI', style: Styles.bodySmall)]),
                        Row(spacing: 8, children: [Icon('check_circle', size: 16, color: Colors.tertiary), Text('Dedicated account manager', style: Styles.bodySmall)]),
                        Spacer(flex: 1, name: 'PlanSpacer'),
                        Button('Select Plan', width: double.infinity, borderRadius: 12, color: Colors.hex(0xFFFFC107), textColor: Colors.hex(0xFF0F172A), onTap: Snackbar('Plan selected: Program')),
                      ],
                    ),
                  ),
                ), flex: 1),
                Flexible(Card(
                  elevation: 0,
                  borderRadius: 16,
                  color: Colors.secondaryBackground,
                  child: Container(
                    padding: 20,
                    child: Column(
                      crossAxis: CrossAxis.start,
                      spacing: 12,
                      children: [
                        Text('Portfolio', style: Styles.titleMedium),
                        Row(spacing: 2, children: [
                          Text('\$750', style: Styles.headlineMedium),
                          Text('/mo', style: Styles.bodySmall, color: Colors.secondaryText),
                        ]),
                        Divider(),
                        Row(spacing: 8, children: [Icon('check_circle', size: 16, color: Colors.tertiary), Text('Unlimited programs', style: Styles.bodySmall)]),
                        Row(spacing: 8, children: [Icon('check_circle', size: 16, color: Colors.tertiary), Text('Full portfolio governance & SSHER', style: Styles.bodySmall)]),
                        Row(spacing: 8, children: [Icon('check_circle', size: 16, color: Colors.tertiary), Text('24/7 enterprise support', style: Styles.bodySmall)]),
                        Spacer(flex: 1, name: 'PlanSpacer'),
                        Button('Select Plan', width: double.infinity, borderRadius: 12, color: Colors.hex(0xFFFFC107), textColor: Colors.hex(0xFF0F172A), onTap: Snackbar('Plan selected: Portfolio')),
                      ],
                    ),
                  ),
                ), flex: 1),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  // ── Dashboard — Matches project_dashboard_screen.dart
  app.page(
    'DashboardPage',
    route: '/dashboard',
    state: {
      'selectedNav': string.withDefault('dashboard'),
    },
    body: Scaffold(
      appBar: AppBar(title: 'Ndu Project Dashboard'),
      body: Container(
        color: Colors.hex(0xFFF4F7FB),
        padding: 24,
        child: Column(
          crossAxis: CrossAxis.start,
          spacing: 16,
          children: [
            // Status strip — matches _StatusStrip
            Row(
              spacing: 12,
              children: [
                Flexible(statCard(label: 'Regular Projects', value: '7', subLabel: 'In progress'), flex: 1),
                Flexible(statCard(label: 'Projects', value: '3', subLabel: 'Active'), flex: 1),
                Flexible(statCard(label: 'Programs', value: '2', subLabel: 'Running'), flex: 1),
                Flexible(statCard(label: 'Portfolios', value: '1', subLabel: 'Active'), flex: 1),
              ],
            ),
            // Quick actions — matches _ProjectHeader buttons
            Row(
              spacing: 12,
              children: [
                Flexible(Button('Punchlist Actions', icon: 'checklist', width: double.infinity, borderRadius: 12, color: Colors.hex(0xFFFFC107), textColor: Colors.primaryText, onTap: Navigate('PunchlistActionsPage')), flex: 1),
                Flexible(Button('Project Plan', icon: 'description', variant: ButtonVariant.outlined, width: double.infinity, borderRadius: 12, onTap: Navigate('ProjectPlanPage')), flex: 1),
                Flexible(Button('Risk Assessment', icon: 'shield', variant: ButtonVariant.outlined, width: double.infinity, borderRadius: 12, onTap: Navigate('RiskAssessmentPage')), flex: 1),
                Flexible(Button('Team Management', icon: 'groups', variant: ButtonVariant.outlined, width: double.infinity, borderRadius: 12, onTap: Navigate('TeamManagementPage')), flex: 1),
              ],
            ),
            // Recent insights
            Text('Recent Punchlist Items', style: Styles.titleMedium),
            Expanded(
              ListView(
                source: AppState('insightsData'),
                spacing: 8,
                itemBuilder: (item) => insightCard(
                  title: item['title'],
                  severity: item['severity'],
                  owner: item['owner'],
                  dueIn: item['dueIn'],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ── Punchlist Actions — THE KEY SCREEN — Matches punchlist_actions_screen.dart
  app.page(
    'PunchlistActionsPage',
    route: '/punchlist-actions',
    state: {
      'selectedTab': string.withDefault('distribution'),
    },
    body: Scaffold(
      appBar: AppBar(title: 'Punchlist Actions'),
      body: Container(
        color: Colors.hex(0xFFF4F7FB),
        padding: EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          crossAxis: CrossAxis.start,
          spacing: 16,
          children: [
            // Context header — matches _buildContextHeader
            Row(
              spacing: 8,
              children: [
                contextChip(label: 'Program: Infrastructure'),
                contextChip(label: 'Phase: Execution'),
                contextChip(label: 'Sprint 4'),
              ],
            ),
            // Page header — matches _buildPageHeader
            Row(
              mainAxis: MainAxis.spaceBetween,
              children: [
                Text('Punchlist Actions', style: Styles.headlineSmall),
                Row(
                  spacing: 8,
                  children: [
                    Button('Export tracker', icon: 'file_download', variant: ButtonVariant.outlined, borderRadius: 12, onTap: Snackbar('Export initiated')),
                    Button('Share status', icon: 'share', variant: ButtonVariant.outlined, borderRadius: 12, onTap: Snackbar('Share link copied')),
                  ],
                ),
              ],
            ),
            // Completion Health — matches _buildSummaryGrid first panel
            Card(
              elevation: 0,
              borderRadius: 16,
              color: Colors.secondaryBackground,
              child: Container(
                padding: 20,
                child: Row(
                  spacing: 20,
                  children: [
                    ProgressBar.circular(size: 72, thickness: 7),
                    Flexible(
                      Column(
                        crossAxis: CrossAxis.start,
                        spacing: 6,
                        children: [
                          Text('Punchlist Completion Health', style: Styles.titleMedium),
                          Text('62% overall completion — on track for sprint target', style: Styles.bodySmall, color: Colors.secondaryText),
                          Row(
                            spacing: 20,
                            children: [
                              Row(spacing: 4, children: [Icon('circle', size: 8, color: Colors.error), Text('Open: 94', style: Styles.bodySmall, color: Colors.secondaryText)]),
                              Row(spacing: 4, children: [Icon('circle', size: 8, color: Colors.primary), Text('In Progress: 38', style: Styles.bodySmall, color: Colors.secondaryText)]),
                              Row(spacing: 4, children: [Icon('circle', size: 8, color: Colors.tertiary), Text('Closed: 153', style: Styles.bodySmall, color: Colors.secondaryText)]),
                            ],
                          ),
                        ],
                      ),
                      flex: 1,
                    ),
                  ],
                ),
              ),
            ),
            // Tabbed data tables — matches all 5 table sections
            TabBar(
              name: 'PunchlistDataTabs',
              tabs: [
                TabItem('Distribution', Column(
                  crossAxis: CrossAxis.start,
                  spacing: 8,
                  children: [
                    Row(mainAxis: MainAxis.spaceBetween, children: [
                      Text('Item Distribution by Category', style: Styles.titleSmall),
                      Button('Add Item', icon: 'add', borderRadius: 12, onTap: Snackbar('Add distribution item')),
                    ]),
                    Expanded(ListView(
                      source: AppState('distributionData'),
                      spacing: 6,
                      itemBuilder: (item) => Container(
                        padding: 10,
                        borderRadius: 8,
                        borderColor: Colors.hex(0xFFE5E7EB),
                        borderWidth: 1,
                        color: Colors.secondaryBackground,
                        child: Row(
                          mainAxis: MainAxis.spaceBetween,
                          children: [
                            Flexible(Column(crossAxis: CrossAxis.start, spacing: 2, children: [
                              Text(item['category'], style: Styles.titleSmall),
                              Text(item['owner'], style: Styles.labelSmall, color: Colors.secondaryText),
                            ]), flex: 1),
                            Row(spacing: 6, children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                borderRadius: 999,
                                color: Colors.error,
                                child: Text('C:${item['critical']}', style: Styles.labelSmall, color: Colors.secondaryBackground),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                borderRadius: 999,
                                color: Colors.primary,
                                child: Text('H:${item['high']}', style: Styles.labelSmall, color: Colors.secondaryBackground),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                borderRadius: 999,
                                color: Colors.secondary,
                                child: Text('M:${item['medium']}', style: Styles.labelSmall, color: Colors.secondaryBackground),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                borderRadius: 999,
                                color: Colors.tertiary,
                                child: Text('L:${item['low']}', style: Styles.labelSmall, color: Colors.secondaryBackground),
                              ),
                            ]),
                            Column(crossAxis: CrossAxis.end, spacing: 2, children: [
                              Text('Open: ${item['openItems']}', style: Styles.labelSmall),
                              Text(item['status'], style: Styles.labelSmall, color: Colors.tertiary),
                            ]),
                          ],
                        ),
                      ),
                    )),
                  ],
                )),
                TabItem('Velocity', Column(
                  crossAxis: CrossAxis.start,
                  spacing: 8,
                  children: [
                    Row(mainAxis: MainAxis.spaceBetween, children: [
                      Text('Action Velocity by Workstream', style: Styles.titleSmall),
                      Button('Add Entry', icon: 'add', borderRadius: 12, onTap: Snackbar('Add velocity entry')),
                    ]),
                    Expanded(ListView(
                      source: AppState('velocityData'),
                      spacing: 6,
                      itemBuilder: (item) => Container(
                        padding: 10,
                        borderRadius: 8,
                        borderColor: Colors.hex(0xFFE5E7EB),
                        borderWidth: 1,
                        color: Colors.secondaryBackground,
                        child: Column(
                          crossAxis: CrossAxis.start,
                          spacing: 4,
                          children: [
                            Row(mainAxis: MainAxis.spaceBetween, children: [
                              Text(item['workstream'], style: Styles.titleSmall),
                              Text('${item['velocity']} pts/sprint', style: Styles.labelSmall, color: Colors.primary),
                            ]),
                            Row(mainAxis: MainAxis.spaceBetween, children: [
                              Text('Open: ${item['openItems']}  Closed: ${item['closedThisSprint']}', style: Styles.bodySmall, color: Colors.secondaryText),
                              Text('Cycle: ${item['avgCycleTime']}', style: Styles.bodySmall, color: Colors.secondaryText),
                            ]),
                            Row(mainAxis: MainAxis.spaceBetween, children: [
                              Text(item['owner'], style: Styles.labelSmall, color: Colors.secondaryText),
                              Text(item['status'], style: Styles.labelSmall, color: Colors.tertiary),
                            ]),
                          ],
                        ),
                      ),
                    )),
                  ],
                )),
                TabItem('Capacity', Column(
                  crossAxis: CrossAxis.start,
                  spacing: 8,
                  children: [
                    Row(mainAxis: MainAxis.spaceBetween, children: [
                      Text('Capacity Health by Team', style: Styles.titleSmall),
                      Button('Add Team', icon: 'add', borderRadius: 12, onTap: Snackbar('Add capacity team')),
                    ]),
                    Expanded(ListView(
                      source: AppState('capacityData'),
                      spacing: 6,
                      itemBuilder: (item) => Container(
                        padding: 10,
                        borderRadius: 8,
                        borderColor: Colors.hex(0xFFE5E7EB),
                        borderWidth: 1,
                        color: Colors.secondaryBackground,
                        child: Column(
                          crossAxis: CrossAxis.start,
                          spacing: 4,
                          children: [
                            Row(mainAxis: MainAxis.spaceBetween, children: [
                              Text(item['team'], style: Styles.titleSmall),
                              Text('${item['utilization']}% utilized', style: Styles.labelSmall, color: Colors.primary),
                            ]),
                            Row(spacing: 12, children: [
                              Text('Planned: ${item['plannedFte']} FTE', style: Styles.bodySmall, color: Colors.secondaryText),
                              Text('Allocated: ${item['allocatedFte']}', style: Styles.bodySmall, color: Colors.secondaryText),
                              Text('Available: ${item['availableFte']}', style: Styles.bodySmall, color: Colors.tertiary),
                            ]),
                            Row(spacing: 12, children: [
                              Text('PI: ${item['productivityIndex']}', style: Styles.bodySmall, color: Colors.secondaryText),
                              Text('Burn: ${item['burnRate']}', style: Styles.bodySmall, color: Colors.secondaryText),
                              Text('Risk: ${item['riskLevel']}', style: Styles.bodySmall, color: Colors.error),
                            ]),
                            Row(mainAxis: MainAxis.spaceBetween, children: [
                              Text(item['owner'], style: Styles.labelSmall, color: Colors.secondaryText),
                              Text(item['status'], style: Styles.labelSmall, color: Colors.tertiary),
                            ]),
                          ],
                        ),
                      ),
                    )),
                  ],
                )),
                TabItem('Shift Coverage', Column(
                  crossAxis: CrossAxis.start,
                  spacing: 8,
                  children: [
                    Row(mainAxis: MainAxis.spaceBetween, children: [
                      Text('Shift Coverage Analysis', style: Styles.titleSmall),
                      Button('Add Shift', icon: 'add', borderRadius: 12, onTap: Snackbar('Add shift entry')),
                    ]),
                    Expanded(ListView(
                      source: AppState('shiftData'),
                      spacing: 6,
                      itemBuilder: (item) => Container(
                        padding: 10,
                        borderRadius: 8,
                        borderColor: Colors.hex(0xFFE5E7EB),
                        borderWidth: 1,
                        color: Colors.secondaryBackground,
                        child: Column(
                          crossAxis: CrossAxis.start,
                          spacing: 4,
                          children: [
                            Row(mainAxis: MainAxis.spaceBetween, children: [
                              Text(item['shift'], style: Styles.titleSmall),
                              Text('${item['coveragePercent']}% coverage', style: Styles.labelSmall, color: Colors.primary),
                            ]),
                            Row(spacing: 12, children: [
                              Text('Required: ${item['requiredHeadcount']}', style: Styles.bodySmall, color: Colors.secondaryText),
                              Text('Actual: ${item['actualHeadcount']}', style: Styles.bodySmall, color: Colors.secondaryText),
                              Text('Gap: ${item['gap']}', style: Styles.bodySmall, color: Colors.error),
                            ]),
                            Row(spacing: 12, children: [
                              Text('OT: ${item['overtimeHrs']}h', style: Styles.bodySmall, color: Colors.secondaryText),
                              Text('Contractors: ${item['contractorFill']}', style: Styles.bodySmall, color: Colors.secondaryText),
                              Text('Pattern: ${item['shiftPattern']}', style: Styles.bodySmall, color: Colors.secondaryText),
                            ]),
                            Row(mainAxis: MainAxis.spaceBetween, children: [
                              Text('Supervisor: ${item['supervisor']}', style: Styles.labelSmall, color: Colors.secondaryText),
                              Text(item['riskFlag'], style: Styles.labelSmall, color: Colors.error),
                            ]),
                          ],
                        ),
                      ),
                    )),
                  ],
                )),
                TabItem('Compliance', Column(
                  crossAxis: CrossAxis.start,
                  spacing: 8,
                  children: [
                    Row(mainAxis: MainAxis.spaceBetween, children: [
                      Text('Compliance & Regulations', style: Styles.titleSmall),
                      Button('Add Regulation', icon: 'add', borderRadius: 12, onTap: Snackbar('Add compliance regulation')),
                    ]),
                    Expanded(ListView(
                      source: AppState('complianceData'),
                      spacing: 6,
                      itemBuilder: (item) => complianceCard(
                        regId: item['regId'],
                        regulationName: item['regulationName'],
                        category: item['category'],
                        complianceStatus: item['complianceStatus'],
                        responsibleParty: item['responsibleParty'],
                        dueDate: item['dueDate'],
                        riskLevel: item['riskLevel'],
                        auditStatus: item['auditStatus'],
                        lastUpdated: item['lastUpdated'],
                      ),
                    )),
                  ],
                )),
              ],
            ),
            // Navigation — matches LaunchPhaseNavigation
            Row(
              mainAxis: MainAxis.spaceBetween,
              children: [
                Button('Gap Analysis', icon: 'arrow_back', variant: ButtonVariant.outlined, borderRadius: 12, onTap: Navigate('GapAnalysisPage')),
                Button('Tech Debt Mgmt', icon: 'arrow_forward', borderRadius: 12, color: Colors.hex(0xFFFFC107), textColor: Colors.primaryText, onTap: Navigate('TechDebtPage')),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  // ── Project Plan
  app.page(
    'ProjectPlanPage',
    route: '/project-plan',
    body: Scaffold(
      appBar: AppBar(title: 'Project Plan'),
      body: Container(
        color: Colors.hex(0xFFF4F7FB),
        padding: 24,
        child: Column(
          crossAxis: CrossAxis.start,
          spacing: 16,
          children: [
            Row(spacing: 8, children: [
              contextChip(label: 'Phase: Execution'),
              contextChip(label: 'Sprint 4'),
            ]),
            Text('Key Milestones', style: Styles.titleMedium),
            Expanded(
              ListView(
                source: AppState('milestonesData'),
                spacing: 8,
                itemBuilder: (item) => Container(
                  padding: 12,
                  borderRadius: 12,
                  borderColor: Colors.hex(0xFFE5E7EB),
                  borderWidth: 1,
                  color: Colors.secondaryBackground,
                  child: Row(
                    mainAxis: MainAxis.spaceBetween,
                    children: [
                      Flexible(Column(crossAxis: CrossAxis.start, spacing: 4, children: [
                        Text(item['name'], style: Styles.titleSmall),
                        Text(item['owner'], style: Styles.bodySmall, color: Colors.secondaryText),
                      ]), flex: 1),
                      Column(crossAxis: CrossAxis.end, spacing: 4, children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          borderRadius: 999,
                          color: Colors.tertiary,
                          child: Text(item['status'], style: Styles.labelSmall, color: Colors.secondaryBackground),
                        ),
                        Text(item['dueDate'], style: Styles.labelSmall, color: Colors.secondaryText),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ── Risk Assessment
  app.page(
    'RiskAssessmentPage',
    route: '/risk-assessment',
    state: { 'filter': string.withDefault('all') },
    body: Scaffold(
      appBar: AppBar(title: 'Risk Assessment'),
      body: Container(
        color: Colors.hex(0xFFF4F7FB),
        padding: 24,
        child: Column(
          crossAxis: CrossAxis.start,
          spacing: 16,
          children: [
            Row(spacing: 12, children: [
              Flexible(statCard(label: 'Total Risks', value: '24', subLabel: '4 critical'), flex: 1),
              Flexible(statCard(label: 'Mitigated', value: '16', subLabel: '67% resolved'), flex: 1),
            ]),
            Dropdown(
              options: const ['all', 'critical', 'high', 'medium', 'low'],
              label: 'Risk Level',
              hint: 'Filter by risk level',
              value: State('filter'),
              onChanged: SetState('filter', const WidgetValue()),
            ),
            Expanded(
              ListView(
                source: AppState('risksData'),
                spacing: 8,
                itemBuilder: (item) => Container(
                  padding: 12,
                  borderRadius: 12,
                  borderColor: Colors.hex(0xFFE5E7EB),
                  borderWidth: 1,
                  color: Colors.secondaryBackground,
                  child: Column(
                    crossAxis: CrossAxis.start,
                    spacing: 6,
                    children: [
                      Row(mainAxis: MainAxis.spaceBetween, children: [
                        Text(item['id'], style: Styles.labelSmall, color: Colors.secondaryText),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          borderRadius: 999,
                          color: Colors.error,
                          child: Text(item['probability'], style: Styles.labelSmall, color: Colors.secondaryBackground),
                        ),
                      ]),
                      Text(item['description'], style: Styles.titleSmall),
                      Text('Impact: ${item['impact']}', style: Styles.bodySmall, color: Colors.secondaryText),
                      Text('Mitigation: ${item['mitigation']}', style: Styles.bodySmall, color: Colors.secondaryText, maxLines: 2),
                      Row(mainAxis: MainAxis.spaceBetween, children: [
                        Text(item['owner'], style: Styles.labelSmall, color: Colors.secondaryText),
                        Text(item['status'], style: Styles.labelSmall, color: Colors.tertiary),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ── Team Management
  app.page(
    'TeamManagementPage',
    route: '/team-management',
    body: Scaffold(
      appBar: AppBar(title: 'Team Management'),
      body: Container(
        color: Colors.hex(0xFFF4F7FB),
        padding: 24,
        child: Column(
          crossAxis: CrossAxis.start,
          spacing: 16,
          children: [
            Row(spacing: 12, children: [
              Flexible(statCard(label: 'Team Size', value: '28', subLabel: '4 roles'), flex: 1),
              Flexible(statCard(label: 'Avg Allocation', value: '87%', subLabel: '3 over-allocated'), flex: 1),
            ]),
            Text('Team Members', style: Styles.titleMedium),
          ],
        ),
      ),
    ),
  );

  // ── Gap Analysis
  app.page(
    'GapAnalysisPage',
    route: '/gap-analysis',
    body: Scaffold(
      appBar: AppBar(title: 'Gap Analysis'),
      body: Container(
        color: Colors.hex(0xFFF4F7FB),
        padding: 24,
        child: Column(
          crossAxis: CrossAxis.start,
          spacing: 16,
          children: [
            Text('Actual vs Planned Gap Analysis', style: Styles.headlineSmall),
            Text('Reconciliation of scope, schedule, and cost variances between planned and actual execution.', style: Styles.bodyMedium, color: Colors.secondaryText),
          ],
        ),
      ),
    ),
  );

  // ── Tech Debt Management
  app.page(
    'TechDebtPage',
    route: '/tech-debt',
    body: Scaffold(
      appBar: AppBar(title: 'Technical Debt Management'),
      body: Container(
        color: Colors.hex(0xFFF4F7FB),
        padding: 24,
        child: Column(
          crossAxis: CrossAxis.start,
          spacing: 16,
          children: [
            statCard(label: 'Tech Debt', value: '14 items', subLabel: '3 critical — remediation in progress'),
            Expanded(
              ListView(
                source: AppState('insightsData'),
                spacing: 8,
                itemBuilder: (item) => insightCard(
                  title: item['title'],
                  severity: item['severity'],
                  owner: item['owner'],
                  dueIn: item['dueIn'],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ── SSHER
  app.page(
    'SSHERPage',
    route: '/ssher',
    body: Scaffold(
      appBar: AppBar(title: 'SSHER Management'),
      body: Container(
        color: Colors.hex(0xFFF4F7FB),
        padding: 24,
        child: Column(
          crossAxis: CrossAxis.start,
          spacing: 16,
          children: [
            Row(spacing: 12, children: [
              Flexible(statCard(label: 'Safety Incidents', value: '2', subLabel: 'This month'), flex: 1),
              Flexible(statCard(label: 'Open Hazards', value: '7', subLabel: '3 high priority'), flex: 1),
            ]),
            Text('SSHER Categories', style: Styles.titleMedium),
            Row(spacing: 12, children: [
              Flexible(Button('Safety', icon: 'shield', width: double.infinity, borderRadius: 12, onTap: Snackbar('Safety section')), flex: 1),
              Flexible(Button('Security', icon: 'lock', width: double.infinity, borderRadius: 12, onTap: Snackbar('Security section')), flex: 1),
              Flexible(Button('Health', icon: 'favorite', width: double.infinity, borderRadius: 12, onTap: Snackbar('Health section')), flex: 1),
              Flexible(Button('Environment', icon: 'eco', width: double.infinity, borderRadius: 12, onTap: Snackbar('Environment section')), flex: 1),
            ]),
          ],
        ),
      ),
    ),
  );

  // ── Settings — Matches settings_screen.dart
  app.page(
    'SettingsPage',
    route: '/settings',
    state: {
      'darkMode': bool_.withDefault(false),
      'notifications': bool_.withDefault(true),
    },
    body: Scaffold(
      appBar: AppBar(title: 'Settings'),
      body: Container(
        color: Colors.hex(0xFFF4F7FB),
        padding: 24,
        child: Column(
          crossAxis: CrossAxis.start,
          spacing: 16,
          children: [
            Text('Preferences', style: Styles.titleLarge),
            Card(
              elevation: 0,
              borderRadius: 16,
              color: Colors.secondaryBackground,
              child: Container(
                padding: 16,
                child: Column(spacing: 12, children: [
                  Toggle(label: 'Dark Mode', value: State('darkMode'), onChanged: SetState('darkMode', const WidgetValue())),
                  Toggle(label: 'Notifications', value: State('notifications'), onChanged: SetState('notifications', const WidgetValue())),
                ]),
              ),
            ),
            Text('Account', style: Styles.titleLarge),
            Card(
              elevation: 0,
              borderRadius: 16,
              color: Colors.secondaryBackground,
              child: Container(
                padding: 16,
                child: Column(spacing: 12, children: [
                  Row(spacing: 8, children: [Icon('person', size: 20, color: Colors.secondaryText), Text('user@company.com', style: Styles.bodyMedium, color: Colors.secondaryText)]),
                  Row(spacing: 8, children: [Icon('badge', size: 20, color: Colors.secondaryText), Text('Project Manager', style: Styles.bodyMedium, color: Colors.secondaryText)]),
                ]),
              ),
            ),
            Button(
              'Sign Out',
              icon: 'logout',
              variant: ButtonVariant.outlined,
              width: double.infinity,
              borderRadius: 12,
              color: Colors.error,
              onTap: [
                UpdateAppState.set('isLoggedIn', false),
                Navigate('SignInPage'),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
