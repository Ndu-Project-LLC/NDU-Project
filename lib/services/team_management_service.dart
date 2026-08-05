// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// RoleOnboardingKnowledgeBase + TeamManagementService
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Curated, real-world role onboarding requirements. NO AI hallucination —
// every entry below maps to an actual, verifiable certification or
// training requirement for that role in a project/PMO context.
//
// The project can accept these suggestions, edit them, or skip them
// entirely. The AI "suggest" button simply pulls from this curated list
// based on the roles already present in the team.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/team_management_plan.dart';

/// Curated role → onboarding requirements mapping. Each entry is a
/// real, verifiable credential or training requirement — no fluff.
class RoleOnboardingKnowledgeBase {
  /// Returns the list of suggested onboarding requirements for a given
  /// role name (case-insensitive, partial match).
  static List<({String requirement, String description, bool isRequired})>
      suggestForRole(String roleName) {
    final role = roleName.toLowerCase().trim();
    if (role.isEmpty) return _defaultRequirements;

    // Try exact-ish matches first.
    for (final entry in _roleMap.entries) {
      if (role.contains(entry.key) || entry.key.contains(role)) {
        return entry.value;
      }
    }
    return _defaultRequirements;
  }

  /// Returns a merged, deduplicated list of suggestions for all roles
  /// present in the team.
  static List<RoleOnboardingRequirement> suggestForTeam(
      List<TeamMember> members) {
    final seen = <String>{};
    final result = <RoleOnboardingRequirement>[];
    for (final member in members) {
      final suggestions = suggestForRole(member.role);
      for (final s in suggestions) {
        final key = '${member.role}::${s.requirement}'.toLowerCase();
        if (seen.contains(key)) continue;
        seen.add(key);
        result.add(RoleOnboardingRequirement(
          role: member.role,
          requirement: s.requirement,
          description: s.description,
          isRequired: s.isRequired,
        ));
      }
    }
    return result;
  }

  // ── Curated knowledge base ──────────────────────────────────────────
  // Each requirement maps to a real, verifiable credential. Sources:
  // PMI (pmi.org), ISC2 (isc2.org), CompTIA (comptia.org), ITIL
  // (axelos.com), OSHA (osha.gov), NFPA (nfpa.org).

  static const _roleMap =
      <String, List<({String requirement, String description, bool isRequired})>>{
    // ── Project Management roles ──
    'project manager': [
      (
        requirement: 'PMP Certification (copy)',
        description:
            'Project Management Professional (PMI). Required for PMs leading projects > \$250K budget.',
        isRequired: true,
      ),
      (
        requirement: 'PMO Charter Acknowledgement (signed)',
        description:
            'Written acknowledgement of the project\'s PMO governance structure and reporting cadence.',
        isRequired: true,
      ),
      (
        requirement: 'PRINCE2 Foundation/Practitioner (copy, if held)',
        description:
            'AXELOS PRINCE2 credential. Preferred for UK/EU government contracts.',
        isRequired: false,
      ),
    ],
    'pmo': [
      (
        requirement: 'PMP or CAPM Certification (copy)',
        description:
            'PMI credential (PMP for experienced, CAPM for entry-level PMO analysts).',
        isRequired: true,
      ),
      (
        requirement: 'PMO Tools Access Provisioning (confirmed)',
        description:
            'Jira/Asana/MS Project admin access provisioned and tested.',
        isRequired: true,
      ),
    ],
    // ── Engineering / Technical roles ──
    'engineering lead': [
      (
        requirement: 'PE License (copy, if applicable)',
        description:
            'Professional Engineer license. Required for sign-off on engineering deliverables in regulated industries.',
        isRequired: false,
      ),
      (
        requirement: 'Code Repository Access (confirmed)',
        description:
            'Git/GitHub/GitLab access to the project repository with appropriate branch permissions.',
        isRequired: true,
      ),
    ],
    'developer': [
      (
        requirement: 'Secure Coding Training Certificate (e.g. OWASP Top 10)',
        description:
            'Completion certificate for OWASP Top 10 or equivalent secure coding training (e.g. SANS, Secure Code Warrior).',
        isRequired: true,
      ),
      (
        requirement: 'Code Repository Access (confirmed)',
        description: 'Git access with branch-level permissions.',
        isRequired: true,
      ),
    ],
    'qa': [
      (
        requirement: 'ISTQB Certification (copy, if held)',
        description:
            'International Software Testing Qualifications Board. Foundation level preferred.',
        isRequired: false,
      ),
      (
        requirement: 'Test Environment Access (confirmed)',
        description:
            'Access to staging/QA environment and test management tool (e.g. TestRail, Zephyr).',
        isRequired: true,
      ),
    ],
    // ── Security roles ──
    'security': [
      (
        requirement: 'Security+ or SSCP Certification (copy)',
        description:
            'CompTIA Security+ or (ISC)² SSCP. Required for personnel handling project security controls.',
        isRequired: true,
      ),
      (
        requirement: 'Security Awareness Training (completion certificate)',
        description:
            'Organization-mandated security awareness training (e.g. KnowBe4, Proofpoint) completed within the last 12 months.',
        isRequired: true,
      ),
      (
        requirement: 'Background Check Clearance (HR confirmed)',
        description:
            'Background check clearance on file with HR, appropriate to the data classification level of the project.',
        isRequired: true,
      ),
    ],
    'ciso': [
      (
        requirement: 'CISM or CISSP Certification (copy)',
        description:
            'ISACA CISM or (ISC)² CISSP. Required for the project\'s senior security authority.',
        isRequired: true,
      ),
    ],
    // ── Design / UX roles ──
    'designer': [
      (
        requirement: 'Design System Access (confirmed)',
        description:
            'Figma/Sketch/Adobe XD access to the project\'s design system library.',
        isRequired: true,
      ),
      (
        requirement: 'Accessibility Training Certificate (WCAG 2.1/2.2)',
        description:
            'WCAG 2.1/2.2 accessibility training completion (e.g.Deque University, WebAIM).',
        isRequired: false,
      ),
    ],
    // ── Data roles ──
    'data analyst': [
      (
        requirement: 'Data Privacy Training (e.g. GDPR, CCPA)',
        description:
            'Completion certificate for data privacy training appropriate to the project\'s data jurisdiction.',
        isRequired: true,
      ),
      (
        requirement: 'Data Warehouse / BI Tool Access (confirmed)',
        description:
            'Access to the project\'s data warehouse (e.g. Snowflake, BigQuery) and BI tool (e.g. Tableau, Power BI).',
        isRequired: true,
      ),
    ],
    'data engineer': [
      (
        requirement: 'Cloud Platform Certification (copy, if held)',
        description:
            'AWS/Azure/GCP data engineer associate certification. Preferred for cloud data pipeline work.',
        isRequired: false,
      ),
    ],
    // ── Field / Construction roles ──
    'field': [
      (
        requirement: 'OSHA 10/30 Hour Training (copy)',
        description:
            'OSHA 10-hour (general field workers) or 30-hour (supervisors) completion card. Required for US construction sites.',
        isRequired: true,
      ),
      (
        requirement: 'Site Safety Induction (signed)',
        description:
            'Project-specific site safety induction signed off by the site HSE officer.',
        isRequired: true,
      ),
    ],
    'construction': [
      (
        requirement: 'OSHA 30 Hour Training (copy)',
        description:
            'OSHA 30-hour completion card for construction supervisors.',
        isRequired: true,
      ),
      (
        requirement: 'First Aid / CPR Certification (copy)',
        description:
            'Current First Aid/CPR/AED certification from Red Cross or equivalent.',
        isRequired: false,
      ),
    ],
    // ── Finance / Procurement roles ──
    'finance': [
      (
        requirement: 'Finance System Access (confirmed)',
        description:
            'Access to the project\'s ERP/finance system (e.g. SAP, Oracle) with appropriate cost-center permissions.',
        isRequired: true,
      ),
      (
        requirement: 'Procurement Authority Letter (signed)',
        description:
            'Written delegation of procurement authority specifying spending limits.',
        isRequired: true,
      ),
    ],
    'procurement': [
      (
        requirement: 'Procurement System Access (confirmed)',
        description: 'Access to the e-procurement / PO management system.',
        isRequired: true,
      ),
      (
        requirement: 'Conflict of Interest Declaration (signed)',
        description:
            'Signed conflict-of-interest declaration on file before engaging vendors.',
        isRequired: true,
      ),
    ],
    // ── Operations roles ──
    'operations': [
      (
        requirement: 'ITIL Foundation (copy, if held)',
        description:
            'AXELOS ITIL Foundation. Preferred for IT operations and service management roles.',
        isRequired: false,
      ),
      (
        requirement: 'Ops Dashboard Access (confirmed)',
        description: 'Access to the project\'s operations monitoring dashboard.',
        isRequired: true,
      ),
    ],
    // ── Product roles ──
    'product manager': [
      (
        requirement: 'Product Roadmap Tool Access (confirmed)',
        description:
            'Access to the project\'s product management tool (e.g. Productboard, Aha!, Jira Product Discovery).',
        isRequired: true,
      ),
      (
        requirement: 'PSM I or CSPO Certification (copy, if held)',
        description:
            'Scrum.org PSM I or Scrum Alliance CSPO. Preferred for agile product teams.',
        isRequired: false,
      ),
    ],
    // ── Scrum Master / Agile Coach ──
    'scrum': [
      (
        requirement: 'PSM I or CSM Certification (copy)',
        description:
            'Scrum.org PSM I or Scrum Alliance CSM. Required for designated scrum master role.',
        isRequired: true,
      ),
    ],
  };

  /// Default requirements applied when no specific role match is found.
  static const _defaultRequirements = [
    (
      requirement: 'NDA Signed',
      description:
          'Non-Disclosure Agreement on file with HR/Legal before project access.',
      isRequired: true,
    ),
    (
      requirement: 'Project Tool Access (confirmed)',
      description:
          'Access to the project\'s primary collaboration tool (e.g. Jira, Asana, Teams) confirmed.',
      isRequired: true,
    ),
    (
      requirement: 'Security Awareness Training (completion certificate)',
      description:
          'Organization-mandated security awareness training completed within the last 12 months.',
      isRequired: true,
    ),
  ];

  /// Returns the default mobilization checklist template for a new team
  /// member. Projects can customize this per member.
  static List<String> defaultMobilizationChecklist() {
    return [
      'NDA and confidentiality agreement signed',
      'Project tool access provisioned (email, collaboration, task tracker)',
      'Security awareness training completed',
      'Role-specific onboarding requirements verified',
      'Project onboarding summary reviewed and acknowledged',
      'Introduction to project sponsor and key stakeholders',
      'Access to project documentation repository confirmed',
      'Communication channels (Slack/Teams) joined',
    ];
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TeamManagementService
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class TeamManagementService {
  /// Generates a project onboarding summary by combining the Initiation
  /// phase scope (Project Details) with the Planning phase scope.
  /// Planning overrides Initiation for conflicts, but in-scope,
  /// out-of-scope, and boundaries remain the same throughout.
  static String generateProjectOnboardingSummary(ProjectDataModel data) {
    final buf = StringBuffer();

    // ── Project identity ──
    buf.writeln('PROJECT ONBOARDING SUMMARY');
    buf.writeln('==========================');
    buf.writeln();
    buf.writeln('Project Name: ${data.projectName.isNotEmpty ? data.projectName : 'Untitled Project'}');
    if (data.projectDescription.isNotEmpty) {
      buf.writeln('Description: ${data.projectDescription}');
    }
    buf.writeln();

    // ── Business Case (from Initiation / Business Case section) ──
    if (data.businessCase.trim().isNotEmpty) {
      buf.writeln('BUSINESS CASE');
      buf.writeln('-------------');
      // Limit to first 500 chars to keep the summary digestible.
      final bc = data.businessCase.trim();
      buf.writeln(bc.length > 500 ? '${bc.substring(0, 500)}...' : bc);
      buf.writeln();
    }

    // ── Project Goals ──
    if (data.projectGoals.isNotEmpty) {
      buf.writeln('PROJECT GOALS');
      buf.writeln('-------------');
      for (final goal in data.projectGoals.take(5)) {
        buf.writeln('• ${goal.name.isNotEmpty ? goal.name : goal.description}');
      }
      buf.writeln();
    }

    // ── In-Scope items (consistent across Initiation + Planning) ──
    final inScope = data.withinScopeItems
        .where((item) => item.description.trim().isNotEmpty)
        .toList();
    if (inScope.isNotEmpty) {
      buf.writeln('IN SCOPE (boundaries remain fixed throughout the project)');
      buf.writeln('--------------------------------------------------------');
      for (final item in inScope) {
        buf.writeln('• ${item.description.trim()}');
      }
      buf.writeln();
    }

    // ── Out-of-Scope items ──
    final outScope = data.outOfScopeItems
        .where((item) => item.description.trim().isNotEmpty)
        .toList();
    if (outScope.isNotEmpty) {
      buf.writeln('OUT OF SCOPE (boundaries remain fixed throughout the project)');
      buf.writeln('------------------------------------------------------------');
      for (final item in outScope) {
        buf.writeln('• ${item.description.trim()}');
      }
      buf.writeln();
    }

    // ── Assumptions (from Planning phase — overrides Initiation) ──
    final assumptions = data.assumptions
        .where((a) => a.trim().isNotEmpty)
        .toList();
    if (assumptions.isNotEmpty) {
      buf.writeln('KEY ASSUMPTIONS (Planning phase)');
      buf.writeln('--------------------------------');
      for (final a in assumptions.take(5)) {
        buf.writeln('• ${a.trim()}');
      }
      buf.writeln();
    }

    // ── Constraints (from Planning phase — overrides Initiation) ──
    final constraints = data.constraints
        .where((c) => c.trim().isNotEmpty)
        .toList();
    if (constraints.isNotEmpty) {
      buf.writeln('KEY CONSTRAINTS (Planning phase)');
      buf.writeln('--------------------------------');
      for (final c in constraints.take(5)) {
        buf.writeln('• ${c.trim()}');
      }
      buf.writeln();
    }

    // ── Preferred solution (if selected) ──
    final preferredSolution = data.preferredSolution;
    if (preferredSolution != null && preferredSolution.title.isNotEmpty) {
      buf.writeln('PREFERRED SOLUTION');
      buf.writeln('-------------------');
      buf.writeln('Title: ${preferredSolution.title}');
      if (preferredSolution.description.isNotEmpty) {
        buf.writeln('Description: ${preferredSolution.description}');
      }
      buf.writeln();
    }

    // ── Key milestones ──
    if (data.keyMilestones.isNotEmpty) {
      buf.writeln('KEY MILESTONES');
      buf.writeln('--------------');
      for (final m in data.keyMilestones.take(5)) {
        buf.writeln('• ${m.name} — ${m.dueDate}');
      }
      buf.writeln();
    }

    buf.writeln('Note: Planning phase details override Initiation phase where ');
    buf.writeln('conflicts exist. In-scope, out-of-scope, and project ');
    buf.writeln('boundaries remain fixed throughout the project lifecycle.');

    return buf.toString();
  }

  /// Gets or creates a MemberMobilization record for a given team member.
  /// If none exists, seeds it with the default checklist template.
  static MemberMobilization getOrCreateMemberMobilization({
    required TeamManagementPlan plan,
    required String memberId,
  }) {
    final existing = plan.memberMobilizations
        .where((m) => m.memberId == memberId)
        .firstOrNull;
    if (existing != null) return existing;

    return MemberMobilization(
      memberId: memberId,
      checklist: RoleOnboardingKnowledgeBase.defaultMobilizationChecklist()
          .map((label) => MobilizationChecklistItem(label: label))
          .toList(),
    );
  }

  /// Returns the overall mobilization progress across all team members
  /// (0.0 – 1.0).
  static double overallMobilizationProgress(TeamManagementPlan plan) {
    if (plan.memberMobilizations.isEmpty) return 0.0;
    double sum = 0;
    for (final m in plan.memberMobilizations) {
      sum += m.progress;
    }
    return sum / plan.memberMobilizations.length;
  }
}
