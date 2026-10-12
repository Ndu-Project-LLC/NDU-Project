// Shared harness for auditing a screen's layout at phone widths.
//
// Every page in the app is reachable on a phone — the router has no
// desktop-only gate — so "does it fit in 360px?" is a property of every screen,
// not of a handful of them. This harness renders one screen inside the app's own
// provider stack at a given phone viewport and reports:
//
//   * `overflows` — RenderFlex overflow errors, i.e. content the user cannot
//     see (Flutter paints its yellow/black stripe over it in debug builds).
//   * `blockers`  — any other error, which means the page never laid out at
//     all. These are reported rather than silently treated as "responsive".
//
// Errors are collected through [FlutterError.onError] instead of
// [WidgetTester.takeException], because the binding collapses a burst of layout
// errors into a single `Multiple exceptions (N)` report that drops the widget
// location — and the location is the only way to find the widget to fix.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/pbs/providers/pbs_provider.dart';
import 'package:ndu_project/project_controls/providers/change_management_provider.dart';
import 'package:ndu_project/project_controls/providers/project_controls_provider.dart';
import 'package:ndu_project/providers/app_content_provider.dart';
import 'package:ndu_project/providers/display_preferences_provider.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/providers/theme_provider.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/services/currency_service.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

/// The phone viewports every screen is audited at.
///
/// 360x800 is the narrowest phone we support (Galaxy A series, most Androids in
/// the field) and 427x952 is the Pixel 9 Pro the design reviews are done on.
const List<Size> kAuditViewports = <Size>[
  Size(360, 800),
  Size(427, 952),
];

/// The result of laying one screen out at one phone viewport.
class MobileLayoutReport {
  const MobileLayoutReport({
    required this.page,
    required this.viewport,
    required this.overflows,
    required this.blockers,
    this.rawBlockers = const <String>[],
  });

  final String page;
  final Size viewport;

  /// One entry per overflow: the message plus the widget and its source
  /// location, so the offending widget can be found without a bisect.
  final List<String> overflows;

  /// Errors that stopped the page from laying out at all. A page with blockers
  /// was never actually audited, so it must not be reported as responsive.
  final List<String> blockers;

  /// The same errors, uncondensed — the framework's full report, for when the
  /// one-line summary is not enough to locate the cause.
  final List<String> rawBlockers;

  bool get isResponsive => overflows.isEmpty && blockers.isEmpty;

  String get summary =>
      '$page @ ${viewport.width.toInt()}x${viewport.height.toInt()}'
      '${overflows.isEmpty ? '' : ' — ${overflows.length} overflow(s): '
          '${overflows.first}'}'
      '${blockers.isEmpty ? '' : ' — blocked: ${blockers.first}'}';
}

/// A project with real content in the collections the phase screens read.
///
/// Empty-state pages almost never overflow — the dense layouts are the ones
/// that break — so the audit runs against content, not against a blank project.
ProjectDataModel auditProject() {
  const long = 'Zambia Youth Agri-Fintech Platform — phase two rollout '
      'across Lusaka, Copperbelt and Southern provinces';

  return ProjectDataModel(
    projectName: long,
    solutionTitle: 'Agri-Fintech Platform',
    solutionDescription: long,
    businessCase:
        'Slum upgrading and food security programmes depend on a reliable, '
        'affordable digital payments rail with offline fallback.',
    notes: long,
    opportunities: [
      for (var i = 1; i <= 12; i++) 'Opportunity $i with a long descriptive label',
    ],
    assumptions: [
      for (var i = 1; i <= 8; i++) 'Assumption $i: the assumption text users type',
    ],
    constraints: [
      for (var i = 1; i <= 8; i++) 'Constraint $i: the constraint text users type',
    ],
    withinScope: [
      for (var i = 1; i <= 8; i++) 'In-scope item $i with a long descriptive label',
    ],
    outOfScope: [
      for (var i = 1; i <= 6; i++) 'Out-of-scope item $i with a long label',
    ],
    projectObjective: long,
    projectGoals: [
      for (var i = 1; i <= 6; i++)
        ProjectGoal(
          name: 'Goal $i with a long title that wraps on a phone',
          description: 'Goal $i description with the detail a user would type.',
        ),
    ],
    teamMembers: [
      for (var i = 1; i <= 15; i++)
        TeamMember(
          name: 'Team Member $i With A Long Name',
          role: 'Senior Workstream Lead $i',
          email: 'member$i@example.com',
          responsibilities: 'Responsible for workstream $i delivery.',
        ),
    ],
    tags: const ['water', 'fintech', 'phase-2'],
  );
}

/// Renders [build] at [viewport] inside the app's provider stack and reports
/// every layout error it produced.
///
/// [project] seeds the project the screen reads; [inspect] runs against the
/// mounted page before it is disposed.
Future<MobileLayoutReport> auditScreenAtPhoneWidth(
  WidgetTester tester,
  String page,
  Widget Function() build, {
  Size viewport = const Size(360, 800),
  ProjectDataModel? project,
  Future<void> Function(WidgetTester tester)? inspect,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final projectProvider = ProjectDataProvider();
  projectProvider.updateProjectData(project ?? auditProject());

  final messages = <String>[];
  final prior = FlutterError.onError;
  FlutterError.onError = (details) => messages.add(_describe(details));
  addTearDown(() => FlutterError.onError = prior);

  // A real router and a primary scroll controller, because screens reach for
  // both during layout: `context.go`/`GoRouterState.of` for their own links, and
  // an ambient controller for a `Scrollbar` that opts into a visible thumb.
  // Without them those screens fail to build at all and the audit would report
  // "blocked" rather than telling us anything about their layout.
  final scrollController = ScrollController();
  addTearDown(scrollController.dispose);
  final router = GoRouter(
    initialLocation: '/audit',
    routes: [
      GoRoute(
        path: '/audit',
        builder: (context, state) => Scaffold(body: build()),
      ),
      // Any link the page follows while laying out lands somewhere harmless
      // instead of throwing "no GoRouter / no route for …".
      GoRoute(
        path: '/:rest(.*)',
        builder: (context, state) => const Scaffold(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ProjectDataProvider>.value(value: projectProvider),
        ChangeNotifierProvider<AppContentProvider>.value(
            value: AppContentProvider()),
        ChangeNotifierProvider<CostEstimateProvider>.value(
            value: CostEstimateProvider()),
        ChangeNotifierProvider<WBSProvider>.value(value: WBSProvider()),
        ChangeNotifierProvider<ScheduleProvider>.value(value: ScheduleProvider()),
        ChangeNotifierProvider<PBSProvider>.value(value: PBSProvider()),
        ChangeNotifierProvider<ProjectControlsProvider>.value(
            value: ProjectControlsProvider()),
        ChangeNotifierProvider<ChangeManagementProvider>.value(
            value: ChangeManagementProvider()),
        // The same singletons `main.dart` wires: several phase shells read the
        // theme, the display preferences and the currency, and without them the
        // page throws a ProviderNotFound before laying anything out.
        ChangeNotifierProvider<ThemeProvider>.value(value: ThemeProvider()),
        ChangeNotifierProvider<DisplayPreferencesProvider>.value(
            value: DisplayPreferencesProvider()),
        ChangeNotifierProvider<CurrencyService>.value(
            value: CurrencyService.instance),
      ],
      child: ProjectDataInherited(
        provider: projectProvider,
        child: PrimaryScrollController(
          controller: scrollController,
          child: MaterialApp.router(
            theme: lightTheme,
            routerConfig: router,
          ),
        ),
      ),
    ),
  );

  // Two frames: the first lays the page out, the second lets anything that
  // depends on a post-frame callback (rail scrolls, tab controllers) settle.
  await tester.pump();
  await tester.pump();

  // Errors raised before the handler was installed, or queued by the binding,
  // still need draining so they do not fail the calling test.
  for (var i = 0; i < 50; i++) {
    final extra = tester.takeException();
    if (extra == null) break;
    messages.add(extra.toString());
  }

  // Screens arm short timers while they lay themselves out — the provider's
  // auto-save debounce, staggered "loading" delays, rotating tooltips. The
  // binding fails a test that ends with one still pending, which would be
  // reported as a layout blocker even though the layout was fine, so give them
  // all time to fire (repeatedly: a timer armed during a pump needs its own).
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  await projectProvider.flushAutoSave();

  // A caller that wants to assert something about the page *as laid out* — not
  // merely whether it overflowed — looks at it here, while the tree is still
  // mounted. Some defects never overflow: a table that scrolls sideways hides
  // its columns behind a gesture instead of past an edge, so the only way to
  // pin it down is to measure where the content ended up.
  //
  // [inspect] is expected to assert, so a failing `expect` is captured rather
  // than thrown from here: the tree still has to be disposed and the error
  // handler restored first, or the failure the caller wrote turns into the
  // framework's "a test overrode FlutterError.onError" assertion (and a page
  // with live timers fails at teardown for reasons unrelated to the layout).
  Object? inspectError;
  StackTrace? inspectStack;
  if (inspect != null) {
    try {
      await inspect(tester);
    } catch (error, stack) {
      inspectError = error;
      inspectStack = stack;
    }
  }

  // Then dispose the tree: screens that poll or run a live clock cancel their
  // timers in `dispose`, and a pending one is an assertion at teardown — a
  // failure that says nothing about whether the layout fits.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();

  final rawBlockers = <String>[
    for (final message in messages)
      if (!_isOverflow(message)) message,
  ];
  final overflows = <String>[
    for (final message in messages)
      if (_isOverflow(message)) _condense(message),
  ];
  final blockers = <String>[
    for (final message in rawBlockers) _condense(message),
  ];

  FlutterError.onError = prior;

  if (inspectError != null) {
    Error.throwWithStackTrace(inspectError, inspectStack ?? StackTrace.current);
  }

  return MobileLayoutReport(
    page: page,
    viewport: viewport,
    overflows: overflows,
    blockers: blockers,
    rawBlockers: rawBlockers,
  );
}

/// The full report for [details], including the widget and source location.
///
/// `FlutterErrorDetails.toString()` is the same text the framework dumps to the
/// console: it carries the creator chain (`Row ← Padding ← …`) and the
/// `file:///…:line:column` of the widget that overflowed, which is what makes a
/// failure fixable without bisecting the page.
String _describe(FlutterErrorDetails details) {
  try {
    return details.toString();
  } catch (_) {
    return details.exceptionAsString();
  }
}

bool _isOverflow(String message) => message.contains('overflowed');

/// Keeps a report readable: the first line plus the creator location.
String _condense(String message) {
  final lines = message
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.isEmpty) return message;

  // The framework report carries the widget and the `file:///…:line:col` of the
  // thing that overflowed, which is what makes a failure actionable.
  final location = lines.firstWhere(
    (line) => RegExp(r'^\S+:file:///.*\.dart:\d+:\d+$').hasMatch(line),
    orElse: () => '',
  );

  if (message.contains('overflowed')) {
    final summary = lines.firstWhere((line) => line.contains('overflowed'),
        orElse: () => lines.first);
    final detail = location.isEmpty ? summary : '$summary @ $location';
    return detail.length > 300 ? '${detail.substring(0, 300)}…' : detail;
  }

  // Anything else is a blocker. Its meaning is in the first line or two after
  // the decorated header, e.g. `Incorrect use of ParentDataWidget.`
  final informative = lines
      .where((line) => !line.startsWith('══') && !line.startsWith('╞'))
      .toList();
  final summary = informative.isEmpty ? lines.first : informative.first;
  final cause = informative.length > 1 ? informative[1] : '';
  final detail = [
    summary,
    if (cause.isNotEmpty && cause != summary) cause,
    if (location.isNotEmpty) '@ $location',
  ].join(' | ');
  return detail.length > 300 ? '${detail.substring(0, 300)}…' : detail;
}

/// Convenience for the audit's failure messages.
String overflowReport(MobileLayoutReport report) {
  final buffer = StringBuffer(report.summary);
  for (final overflow in report.overflows) {
    buffer.write('\n    $overflow');
  }
  return buffer.toString();
}

@visibleForTesting
bool isOverflowMessage(String message) => _isOverflow(message);
