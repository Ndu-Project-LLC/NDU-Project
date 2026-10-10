/// Human-readable labels for internal checkpoint identifiers.
///
/// Project records store their `milestone` (and dashboard chips) as the raw
/// checkpoint id — `fep_summary`, `design_management`, `business_case`, … —
/// which is an implementation detail. Rendering it verbatim leaked those keys
/// onto the dashboard, so every surface should route the value through
/// [friendlyCheckpointLabel] before showing it.
library;

const Map<String, String> _checkpointLabels = <String, String>{
  'initiation': 'Initiation',
  'business_case': 'Business Case',
  'scope_statement': 'Scope Statement',
  'potential_solutions': 'Potential Solutions',
  'risk_identification': 'Risk Identification',
  'it_considerations': 'IT Considerations',
  'infrastructure_considerations': 'Infrastructure Considerations',
  'core_stakeholders': 'Core Stakeholders',
  'initial_cost_estimate': 'Initial Cost Estimate',
  'preferred_solution_analysis': 'Preferred Solution Analysis',
  'preferred_solution': 'Preferred Solution',
  'project_decision_summary': 'Project Decision Summary',
  'fep_summary': 'Front End Planning',
  'fep_summary_end': 'Front End Planning',
  'project_charter': 'Project Charter',
  'work_breakdown_structure': 'Work Breakdown Structure',
  'design_management': 'Design Management',
  'project_activities_log': 'Project Activities Log',
  'cost_estimate': 'Cost Estimate',
  'agile_development_iterations': 'Agile Development Iterations',
  'risk_tracking': 'Risk Tracking',
  'planning': 'Planning',
  'design': 'Design',
  'execution': 'Execution',
  'launch': 'Launch',
};

/// Maps a checkpoint id to a display label.
///
/// Known ids use their canonical title; an empty value becomes `Starting up`;
/// anything unrecognised is title-cased with underscores/whitespace collapsed,
/// so a new checkpoint still reads better than a raw key.
String friendlyCheckpointLabel(String raw) {
  final token = raw.trim();
  if (token.isEmpty) return 'Starting up';

  final mapped = _checkpointLabels[token.toLowerCase()];
  if (mapped != null) return mapped;

  return token
      .split(RegExp(r'[_\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
