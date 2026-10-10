// Role description bank.
//
// [roleDescriptionFor] and [roleWorkstreamFor] guarantee that *every* role in
// `role_catalogue.dart` auto-fills a description and a discipline when it is
// picked, so no role ever leaves the dialog blank.
//
// Resolution order:
//   1. [curatedRoleDescriptions] — wording this app has always shown.
//   2. `roleDescriptions` (lib/utils/role_descriptions.dart) — the wider
//      hand-written bank, where it covers the title.
//   3. A discipline-aware composed sentence, for the remaining titles.

import 'package:ndu_project/utils/role_catalogue.dart';
import 'package:ndu_project/utils/role_descriptions.dart';

/// Bespoke descriptions for the roles the Organisation Plan screens have
/// always auto-filled, kept verbatim so existing behaviour does not drift.
const Map<String, String> curatedRoleDescriptions = <String, String>{
  'Project Manager':
      'Overall project leadership, planning, and coordination across all phases.',
  'Program Manager':
      'Multi-project program coordination and strategic alignment.',
  'Product Owner':
      'Agile product owner — backlog prioritization and stakeholder representation.',
  'Scrum Master':
      'Facilitates Agile ceremonies, removes impediments, and coaches the team on Scrum practices.',
  'Business Analyst':
      'Elicits, documents, and manages requirements. Bridges business stakeholders and delivery teams.',
  'PMO Lead':
      'Project Management Office oversight, governance, and standards.',
  'Delivery Manager':
      'Coordinates delivery across teams, manages dependencies, and ensures timely execution.',
  'Operations Manager':
      'Manages day-to-day operations, resource allocation, and process optimization.',
  'Risk Manager':
      'Identifies, assesses, and mitigates project risks. Maintains the risk register.',
  'Quality Assurance Lead':
      'Owns quality planning, QA/QC processes, and compliance with standards.',
  'Change Manager':
      'Manages organizational change, stakeholder adoption, and transition planning.',
  'Stakeholder Manager':
      'Manages stakeholder engagement, communication, and alignment throughout the project.',
  'Planning Engineer':
      'Develops and maintains project schedules, WBS, and progress tracking.',
  'Project Coordinator':
      'Supports project administration, documentation, and meeting coordination.',
  'Portfolio Manager':
      'Oversees portfolio of projects, prioritizes investments, and aligns with strategic objectives.',
};

/// Discipline labels for the curated roles, matching the wording the screens
/// already produced.
const Map<String, String> curatedRoleWorkstreams = <String, String>{
  'Project Manager': 'Management',
  'Program Manager': 'Management',
  'Product Owner': 'Management',
  'Scrum Master': 'Management',
  'Business Analyst': 'Management',
  'PMO Lead': 'Management',
  'Delivery Manager': 'Management',
  'Operations Manager': 'Operations',
  'Risk Manager': 'Management',
  'Quality Assurance Lead': 'Quality',
  'Change Manager': 'Management',
  'Stakeholder Manager': 'Management',
  'Planning Engineer': 'Engineering',
  'Project Coordinator': 'Management',
  'Portfolio Manager': 'Management',
};

/// Natural-language phrasing of each catalogue discipline, so composed
/// descriptions read as sentences ("...across quality assurance...") rather
/// than echoing a heading ("...across Quality & Testing...").
const Map<String, String> _focusByDiscipline = <String, String>{
  'Leadership & Project Management': 'project management',
  'Executive & Portfolio': 'portfolio and executive governance',
  'PMO, Governance & Controls': 'PMO governance and project controls',
  'Planning & Scheduling': 'project planning and scheduling',
  'Product & Requirements': 'product and requirements analysis',
  'Architecture & Systems': 'solution architecture',
  'Software Delivery': 'software engineering',
  'Data & AI': 'data and AI',
  'Cloud & Infrastructure': 'cloud and infrastructure',
  'Security & Compliance': 'security and compliance',
  'Quality & Testing': 'quality assurance',
  'Risk & Audit': 'risk, audit, and assurance',
  'Procurement & Commercial': 'procurement and contract management',
  'Finance & Cost': 'cost engineering and financial control',
  'Engineering & Construction': 'engineering and construction',
  'Design & Creative': 'design and creative work',
  'Agile & Delivery': 'agile delivery',
  'Operations & Service': 'operations and service delivery',
  'Change & Communications': 'change management and communications',
  'Stakeholders & Customers': 'stakeholder and customer engagement',
  'People & Workforce': 'people and workforce management',
  'HSE & Sustainability': 'health, safety, and environmental management',
  'Legal & Regulatory': 'legal and regulatory compliance',
  'Consulting & Specialists': 'consulting and advisory',
};

/// Reverse index: role title → the discipline heading it sits under in the
/// catalogue. Built once from [roleTitlesByDiscipline].
final Map<String, String> _disciplineByTitle = <String, String>{
  for (final entry in roleTitlesByDiscipline.entries)
    for (final title in entry.value) title: entry.key,
};

/// The catalogue discipline a role belongs to, or an empty string when the
/// title is not catalogued.
String roleDisciplineFor(String title) => _disciplineByTitle[title] ?? '';

/// A description for [title]. Never empty for a catalogued role.
String roleDescriptionFor(String title) {
  final curated = curatedRoleDescriptions[title];
  if (curated != null && curated.trim().isNotEmpty) return curated;

  final banked = roleDescriptions[title];
  if (banked != null && banked.description.trim().isNotEmpty) {
    return banked.description;
  }

  return _composedDescription(title);
}

/// A discipline/workstream label for [title]. Never empty for a catalogued
/// role.
String roleWorkstreamFor(String title) {
  final curated = curatedRoleWorkstreams[title];
  if (curated != null && curated.trim().isNotEmpty) return curated;

  final banked = roleDescriptions[title];
  if (banked != null && banked.discipline.trim().isNotEmpty) {
    return banked.discipline;
  }

  return roleDisciplineFor(title);
}

String _composedDescription(String title) {
  final discipline = roleDisciplineFor(title);
  final focus = _focusByDiscipline[discipline] ??
      (discipline.isEmpty ? 'project delivery' : discipline.toLowerCase());
  final t = title.toLowerCase();

  if (_hasAny(t, const [
    'chief',
    'head of',
    'director',
    'vp of',
    'managing director',
    'general manager',
    'executive',
    'president',
  ])) {
    return 'Provides senior leadership and strategic direction for $focus across the project.';
  }

  if (t.contains('architect')) {
    return 'Defines the $focus architecture, standards, and design decisions.';
  }

  if (_hasAny(t, const [
    'trainer',
    'training',
    'coach',
    'learning',
    'instructional',
  ])) {
    return 'Designs and delivers $focus training, coaching, and capability building.';
  }

  if (_hasAny(t, const [
    'manager',
    'lead',
    'superintendent',
    'supervisor',
    'foreman',
    'champion',
    'coordinator',
    'administrator',
    'planner',
    'scheduler',
    'secretary',
    'controller',
  ])) {
    return 'Leads and coordinates $focus, managing people, plans, and outcomes.';
  }

  if (_hasAny(t, const [
    'engineer',
    'developer',
    'technician',
    'draughtsperson',
    'fabricator',
    'welder',
    'electrician',
    'plumber',
    'carpenter',
    'rigger',
    'scaffolder',
    'operator',
  ])) {
    return 'Delivers, maintains, and supports $focus outputs to the required standard.';
  }

  if (_hasAny(t, const ['analyst', 'scientist', 'statistician', 'research'])) {
    return 'Analyses $focus information and produces insights, reporting, and recommendations.';
  }

  if (_hasAny(t, const [
    'tester',
    'test ',
    'assurance',
    'auditor',
    'inspector',
    'verifier',
    'reviewer',
    'assessor',
    'quality control',
  ])) {
    return 'Verifies $focus deliverables against requirements and standards, reporting findings.';
  }

  if (t.contains('surveyor')) {
    return 'Measures, estimates, and reports on $focus scope, quantities, and cost impact.';
  }

  if (_hasAny(t, const ['estimator', 'estimating'])) {
    return 'Prepares estimates, budgets, and cost forecasts for $focus work.';
  }

  if (_hasAny(t, const [
    'consultant',
    'advisor',
    'expert',
    'specialist',
    'counsel',
    'officer',
  ])) {
    return 'Provides specialist $focus expertise and advice to the project team.';
  }

  return 'Supports $focus activities, deliverables, and reporting for the project.';
}

bool _hasAny(String haystack, List<String> needles) =>
    needles.any(haystack.contains);
