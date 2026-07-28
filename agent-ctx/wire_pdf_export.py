#!/usr/bin/env python3
"""
Wire up Export PDF on all screens.
"""

import os, re

BASE = '/home/z/my-project/Ndu_Project/lib/screens'

PDF_IMPORT = "import 'package:ndu_project/utils/pdf_export_helper.dart';"
PDH_IMPORT = "import 'package:ndu_project/utils/project_data_helper.dart';"

def read_file(fp):
    with open(fp, 'r', encoding='utf-8') as f:
        return f.read()

def write_file(fp, content):
    with open(fp, 'w', encoding='utf-8') as f:
        f.write(content)

def add_import_if_missing(content, imp):
    if imp in content:
        return content
    # Find last import
    imports = list(re.finditer(r"^import\s+.*;$", content, re.MULTILINE))
    if imports:
        last = imports[-1]
        return content[:last.end()] + "\n" + imp + content[last.end():]
    return imp + "\n" + content

def find_state_class_name(content):
    """Find state class name from createState()."""
    m = re.search(r'createState\s*\(\)\s*=>\s+(\w+)\s*\(', content)
    return m.group(1) if m else None

def add_method_to_class(content, state_class, method_code):
    """Insert method into state class after initState or after class opening."""
    if f'Future<void> _exportPdf()' in content:
        return content
    
    # Find the state class
    pat = re.compile(rf'class\s+{re.escape(state_class)}\s+extends\s+\S+\s*\{{')
    m = pat.search(content)
    if not m:
        print(f"    WARN: Cannot find class {state_class}")
        return content
    
    # Find initState end
    init_pat = re.compile(r'@override\s*\n\s*void\s+initState\s*\(\s*\)\s*\{')
    init_m = init_pat.search(content, m.end())
    
    if init_m:
        # Find matching closing brace
        brace_count = 0
        start = content.index('{', init_m.start())
        for i in range(start, len(content)):
            if content[i] == '{': brace_count += 1
            elif content[i] == '}':
                brace_count -= 1
                if brace_count == 0:
                    insert_pos = i + 1
                    # Skip whitespace after
                    while insert_pos < len(content) and content[insert_pos] in ' \t\n\r':
                        insert_pos += 1
                    return content[:insert_pos] + method_code + content[insert_pos:]
    
    # Fallback: insert right after class opening brace
    class_open = content.index('{', m.start()) + 1
    return content[:class_open] + method_code + content[class_open:]

def add_onExportPdf_to_header(content, header_type):
    """Add onExportPdf: _exportPdf to the header widget call."""
    if 'onExportPdf: _exportPdf' in content:
        return content
    
    # Find the header widget
    # Look for the header type with possible const prefix
    idx = content.find(f'{header_type}(')
    if idx == -1:
        # Try with const
        idx = content.find(f'const {header_type}(')
    
    if idx == -1:
        print(f"    WARN: Cannot find {header_type} usage")
        return content
    
    # Find the matching closing paren
    # Start from the opening paren after the header type name
    open_idx = content.index('(', idx)
    paren_count = 0
    close_idx = -1
    for i in range(open_idx, len(content)):
        if content[i] == '(':
            paren_count += 1
        elif content[i] == ')':
            paren_count -= 1
            if paren_count == 0:
                close_idx = i
                break
    
    if close_idx == -1:
        print(f"    WARN: Cannot find closing paren for {header_type}")
        return content
    
    # Get the text between parens
    header_content = content[open_idx+1:close_idx]
    
    # Check if already has onExportPdf
    if 'onExportPdf' in header_content:
        return content
    
    # Add onExportPdf parameter
    stripped = header_content.rstrip()
    if stripped == '' or stripped.endswith(','):
        # Empty params or trailing comma
        new_header_content = stripped + ' onExportPdf: _exportPdf'
    else:
        new_header_content = stripped + ', onExportPdf: _exportPdf'
    
    # Also remove 'const ' prefix if present (since we're adding a non-const param)
    prefix = content[idx:open_idx+1]
    if prefix.startswith('const '):
        prefix = prefix[6:]  # Remove 'const '
    
    new_content = prefix + new_header_content + content[close_idx:]
    result = content[:idx] + new_content
    
    return result

def make_method(title, sections_code):
    return f"""
  Future<void> _exportPdf() async {{
{sections_code}
  }}
"""

# ── Process Front End Planning Screens ──────────────────────────────

fep_configs = {
    "front_end_planning_screen.dart": "Project Summary",
    "front_end_planning_opportunities_screen.dart": "Project Opportunities",
    "front_end_planning_contracts_screen.dart": "Contracting",
    "front_end_planning_contract_vendor_quotes_screen.dart": "Contract & Vendor Quotes",
    "front_end_planning_milestone.dart": "Milestone Planning",
    "front_end_planning_summary.dart": "Front End Planning Summary",
    "front_end_planning_summary_end.dart": "Front End Planning Summary End",
    "front_end_planning_requirements_screen.dart": "Requirements",
    "front_end_planning_personnel_screen.dart": "Personnel",
    "front_end_planning_technology_personnel_screen.dart": "Technology Personnel",
    "front_end_planning_infrastructure_screen.dart": "Infrastructure",
    "front_end_planning_risks_screen.dart": "Risks",
    "front_end_planning_procurement_screen.dart": "Procurement",
    "front_end_planning_security.dart": "Security",
    "front_end_planning_allowance.dart": "Allowance",
    "front_end_planning_workspace_screen.dart": "Front End Planning Workspace",
    "front_end_planning_technology_screen.dart": "Technology",
    "project_charter_screen.dart": "Project Charter",
    "project_activities_log_screen.dart": "Project Activities Log",
    "work_breakdown_structure_screen.dart": "Work Breakdown Structure",
}

print("=== Front End Planning Screens ===")
for fname, title in fep_configs.items():
    fp = os.path.join(BASE, fname)
    if not os.path.exists(fp):
        print(f"  SKIP: {fname}")
        continue
    
    content = read_file(fp)
    orig = content
    
    # Add imports
    content = add_import_if_missing(content, PDF_IMPORT)
    content = add_import_if_missing(content, PDH_IMPORT)
    
    # Find state class
    scn = find_state_class_name(content)
    if not scn:
        print(f"  WARN: No state class in {fname}")
        continue
    
    # Add method if not present
    if 'Future<void> _exportPdf()' not in content:
        sections = f"""      final projectData = ProjectDataHelper.getData(context);
      final fep = projectData.frontEndPlanning;
      await PdfExportHelper.exportScreenPdf(
        context: context,
        screenTitle: '{title}',
        sections: [
          PdfSection.keyValue('Project Info', [
            {{'Project Name': projectData.projectName ?? 'N/A'}},
          ]),
          PdfSection.text('Notes', fep.requirementsNotes ?? 'No data recorded.'),
        ],
      );"""
        content = add_method_to_class(content, scn, make_method(title, sections))
    
    # Wire to header
    content = add_onExportPdf_to_header(content, 'FrontEndPlanningHeader')
    
    if content != orig:
        write_file(fp, content)
        print(f"  DONE: {fname}")
    else:
        print(f"  NO CHANGE: {fname}")

# ── Process Execution Plan Screens ──────────────────────────────────

exec_configs = {
    "execution_plan_screen.dart": "Execution Plan",
    "execution_plan_details_screen.dart": "Execution Plan Details",
    "execution_plan_solutions_screen.dart": "Execution Plan Solutions",
    "execution_plan_interface_management_screen.dart": "Interface Management",
    "execution_plan_interface_management_plan_screen.dart": "Interface Management Plan",
    "execution_plan_infrastructure_plan_screen.dart": "Infrastructure Plan",
    "execution_plan_best_practices_screen.dart": "Best Practices",
    "execution_plan_communication_plan_screen.dart": "Communication Plan",
    "execution_plan_construction_plan_screen.dart": "Construction Plan",
    "execution_plan_lessons_learned_screen.dart": "Lessons Learned",
    "execution_plan_stakeholder_identification_screen.dart": "Stakeholder Identification",
    "execution_plan_agile_delivery_plan_screen.dart": "Agile Delivery Plan",
    "execution_enabling_work_plan_screen.dart": "Enabling Work Plan",
    "execution_issue_management_screen.dart": "Issue Management",
}

print("\n=== Execution Plan Screens ===")
for fname, title in exec_configs.items():
    fp = os.path.join(BASE, fname)
    if not os.path.exists(fp):
        print(f"  SKIP: {fname}")
        continue
    
    content = read_file(fp)
    orig = content
    
    # Add imports
    content = add_import_if_missing(content, PDF_IMPORT)
    content = add_import_if_missing(content, PDH_IMPORT)
    
    # Find state class
    scn = find_state_class_name(content)
    if not scn:
        print(f"  WARN: No state class in {fname}")
        continue
    
    # Add method if not present
    if 'Future<void> _exportPdf()' not in content:
        sections = f"""      final projectData = ProjectDataHelper.getData(context);
      await PdfExportHelper.exportScreenPdf(
        context: context,
        screenTitle: '{title}',
        sections: [
          PdfSection.keyValue('Project Info', [
            {{'Project Name': projectData.projectName ?? 'N/A'}},
          ]),
          PdfSection.text('Notes', projectData.planningNotes['{fname.replace('.dart', '')}'] ?? 'No data recorded.'),
        ],
      );"""
        content = add_method_to_class(content, scn, make_method(title, sections))
    
    # Wire to header
    content = add_onExportPdf_to_header(content, 'ExecutionPlanHeader')
    
    if content != orig:
        write_file(fp, content)
        print(f"  DONE: {fname}")
    else:
        print(f"  NO CHANGE: {fname}")

# ── Process Launch Screens with existing _exportPdf ─────────────────

launch_existing = [
    "launch_checklist_screen.dart",
    "project_close_out_screen.dart",
    "commerce_viability_screen.dart",
    "demobilize_team_screen.dart",
    "transition_to_prod_team_screen.dart",
    "deliver_project_closure_screen.dart",
    "vendor_account_close_out_screen.dart",
    "contract_close_out_screen.dart",
    "summarize_account_risks_screen.dart",
    "actual_vs_planned_gap_analysis_screen.dart",
]

print("\n=== Launch Screens (existing _exportPdf) ===")
for fname in launch_existing:
    fp = os.path.join(BASE, fname)
    if not os.path.exists(fp):
        print(f"  SKIP: {fname}")
        continue
    
    content = read_file(fp)
    orig = content
    
    # Just wire to header - method already exists
    content = add_onExportPdf_to_header(content, 'PlanningPhaseHeader')
    
    if content != orig:
        write_file(fp, content)
        print(f"  DONE: {fname}")
    else:
        print(f"  NO CHANGE: {fname}")

# ── Process Launch Screens needing new _exportPdf ───────────────────

launch_new = {
    "finalize_project_screen.dart": "Finalize Project",
    "identify_staff_ops_team_screen.dart": "Identify Staff & Ops Team",
    "salvage_disposal_team_screen.dart": "Salvage & Disposal Team",
    "staff_team_screen.dart": "Staff Team",
    "update_ops_maintenance_plans_screen.dart": "Update Ops & Maintenance Plans",
}

print("\n=== Launch Screens (new _exportPdf) ===")
for fname, title in launch_new.items():
    fp = os.path.join(BASE, fname)
    if not os.path.exists(fp):
        print(f"  SKIP: {fname}")
        continue
    
    content = read_file(fp)
    orig = content
    
    # Add imports
    content = add_import_if_missing(content, PDF_IMPORT)
    content = add_import_if_missing(content, PDH_IMPORT)
    
    # Find state class
    scn = find_state_class_name(content)
    if not scn:
        print(f"  WARN: No state class in {fname}")
        continue
    
    # Add method if not present
    if 'Future<void> _exportPdf()' not in content:
        sections = f"""      final projectData = ProjectDataHelper.getData(context);
      await PdfExportHelper.exportScreenPdf(
        context: context,
        screenTitle: '{title}',
        sections: [
          PdfSection.keyValue('Project Info', [
            {{'Project Name': projectData.projectName ?? 'N/A'}},
          ]),
          PdfSection.text('Notes', projectData.planningNotes['{fname.replace('.dart', '')}'] ?? 'No data recorded.'),
        ],
      );"""
        content = add_method_to_class(content, scn, make_method(title, sections))
    
    # Wire to header
    content = add_onExportPdf_to_header(content, 'PlanningPhaseHeader')
    
    if content != orig:
        write_file(fp, content)
        print(f"  DONE: {fname}")
    else:
        print(f"  NO CHANGE: {fname}")

# ── Process Design Screens ──────────────────────────────────────────

design_configs = {
    "design_phase_screen.dart": "Design Phase",
    "design_planning_screen.dart": "Design Planning",
    "design_deliverables_screen.dart": "Design Deliverables",
    "engineering_design_screen.dart": "Engineering Design",
    "backend_design_screen.dart": "Backend Design",
    "specialized_design_screen.dart": "Specialized Design",
    "detailed_design_screen.dart": "Detailed Design",
    "ui_ux_design_screen.dart": "UI/UX Design",
    "technical_development_screen.dart": "Technical Development",
}

print("\n=== Design Screens ===")
for fname, title in design_configs.items():
    fp = os.path.join(BASE, fname)
    if not os.path.exists(fp):
        print(f"  SKIP: {fname}")
        continue
    
    content = read_file(fp)
    orig = content
    
    # Add imports
    content = add_import_if_missing(content, PDF_IMPORT)
    content = add_import_if_missing(content, PDH_IMPORT)
    
    # Find state class
    scn = find_state_class_name(content)
    if not scn:
        print(f"  WARN: No state class in {fname}")
        continue
    
    # Add method if not present
    if 'Future<void> _exportPdf()' not in content:
        sections = f"""      final projectData = ProjectDataHelper.getData(context);
      await PdfExportHelper.exportScreenPdf(
        context: context,
        screenTitle: '{title}',
        sections: [
          PdfSection.keyValue('Project Info', [
            {{'Project Name': projectData.projectName ?? 'N/A'}},
          ]),
          PdfSection.text('Notes', projectData.planningNotes['{fname.replace('.dart', '')}'] ?? 'No data recorded.'),
        ],
      );"""
        content = add_method_to_class(content, scn, make_method(title, sections))
    
    # Wire to header
    content = add_onExportPdf_to_header(content, 'PlanningPhaseHeader')
    
    if content != orig:
        write_file(fp, content)
        print(f"  DONE: {fname}")
    else:
        print(f"  NO CHANGE: {fname}")

print("\nAll done!")
