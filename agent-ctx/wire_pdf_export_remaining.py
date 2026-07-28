#!/usr/bin/env python3
"""
Handle remaining screens that are StatelessWidget or have other issues.
For StatelessWidget screens, we add a top-level _exportPdf function.
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
    imports = list(re.finditer(r"^import\s+.*;$", content, re.MULTILINE))
    if imports:
        last = imports[-1]
        return content[:last.end()] + "\n" + imp + content[last.end():]
    return imp + "\n" + content

# StatelessWidget execution screens - need top-level function approach
exec_stateless = {
    "execution_plan_details_screen.dart": {
        "title": "Execution Plan Details",
        "header_line": "ExecutionPlanHeader(\n                onBack: () => Navigator.maybePop(context)),",
        "header_replace": "ExecutionPlanHeader(\n                onBack: () => Navigator.maybePop(context), onExportPdf: () => _exportPdf(context)),",
    },
    "execution_plan_solutions_screen.dart": {
        "title": "Execution Plan Solutions",
        "header_search": "ExecutionPlanHeader(",
    },
    "execution_plan_interface_management_screen.dart": {
        "title": "Interface Management",
        "header_search": "ExecutionPlanHeader(",
    },
    "execution_plan_best_practices_screen.dart": {
        "title": "Best Practices",
        "header_search": "ExecutionPlanHeader(",
    },
    "execution_plan_communication_plan_screen.dart": {
        "title": "Communication Plan",
        "header_search": "ExecutionPlanHeader(",
    },
    "execution_plan_construction_plan_screen.dart": {
        "title": "Construction Plan",
        "header_search": "ExecutionPlanHeader(",
    },
    "execution_plan_lessons_learned_screen.dart": {
        "title": "Lessons Learned",
        "header_search": "ExecutionPlanHeader(",
    },
    "execution_enabling_work_plan_screen.dart": {
        "title": "Enabling Work Plan",
        "header_search": "ExecutionPlanHeader(",
    },
    "execution_issue_management_screen.dart": {
        "title": "Issue Management",
        "header_search": "ExecutionPlanHeader(",
    },
}

# For each StatelessWidget screen:
# 1. Add imports
# 2. Add top-level _exportPdf function before the main class
# 3. Add onExportPdf to the header

for fname, config in exec_stateless.items():
    fp = os.path.join(BASE, fname)
    if not os.path.exists(fp):
        print(f"  SKIP: {fname}")
        continue
    
    content = read_file(fp)
    orig = content
    title = config['title']
    
    # Add imports
    content = add_import_if_missing(content, PDF_IMPORT)
    content = add_import_if_missing(content, PDH_IMPORT)
    
    # Add top-level _exportPdf function if not present
    if 'Future<void> _exportPdf(BuildContext context)' not in content:
        # Insert before the main class
        func = f"""
Future<void> _exportPdf(BuildContext context) async {{
  final projectData = ProjectDataHelper.getData(context);
  await PdfExportHelper.exportScreenPdf(
    context: context,
    screenTitle: '{title}',
    sections: [
      PdfSection.keyValue('Project Info', [
        {{'Project Name': projectData.projectName ?? 'N/A'}},
      ]),
      PdfSection.text('Notes', projectData.planningNotes['{fname.replace('.dart', '')}'] ?? 'No data recorded.'),
    ],
  );
}}

"""
        # Find the main class and insert before it
        # Look for the class that extends StatelessWidget
        class_pat = re.compile(rf'class\s+{re.escape(fname.replace(".dart", "").split("_")[-1].capitalize())}|class\s+\w+Screen\s+extends\s+StatelessWidget')
        # More generic: find first class extending StatelessWidget
        class_pat = re.compile(r'class\s+\w+Screen\s+extends\s+StatelessWidget')
        m = class_pat.search(content)
        if m:
            content = content[:m.start()] + func + content[m.start():]
        else:
            print(f"  WARN: Could not find StatelessWidget class in {fname}")
            continue
    
    # Add onExportPdf to ExecutionPlanHeader
    if 'onExportPdf' not in content:
        # Find ExecutionPlanHeader and add onExportPdf parameter
        idx = content.find('ExecutionPlanHeader(')
        if idx == -1:
            print(f"  WARN: ExecutionPlanHeader not found in {fname}")
            continue
        
        # Find matching closing paren
        open_idx = content.index('(', idx)
        paren_count = 0
        for i in range(open_idx, len(content)):
            if content[i] == '(':
                paren_count += 1
            elif content[i] == ')':
                paren_count -= 1
                if paren_count == 0:
                    header_text = content[idx:i+1]
                    # Add onExportPdf before closing paren
                    before_close = content[idx:i].rstrip()
                    if before_close.endswith(','):
                        new_text = before_close + ' onExportPdf: () => _exportPdf(context))'
                    else:
                        new_text = before_close + ', onExportPdf: () => _exportPdf(context))'
                    content = content[:idx] + new_text + content[i+1:]
                    break
    
    if content != orig:
        write_file(fp, content)
        print(f"  DONE: {fname}")
    else:
        print(f"  NO CHANGE: {fname}")

# Fix execution_plan_stakeholder_identification_screen.dart
# The _exportPdf was incorrectly placed in the child widget, need to move it to top-level
fp = os.path.join(BASE, 'execution_plan_stakeholder_identification_screen.dart')
if os.path.exists(fp):
    content = read_file(fp)
    orig = content
    
    # Add imports (pdf_export_helper already present from first run)
    content = add_import_if_missing(content, PDH_IMPORT)
    
    # Add top-level _exportPdf function before the main class
    if 'Future<void> _exportPdf(BuildContext context)' not in content:
        func = """
Future<void> _exportPdf(BuildContext context) async {
  final projectData = ProjectDataHelper.getData(context);
  await PdfExportHelper.exportScreenPdf(
    context: context,
    screenTitle: 'Stakeholder Identification',
    sections: [
      PdfSection.keyValue('Project Info', [
        {'Project Name': projectData.projectName ?? 'N/A'},
      ]),
      PdfSection.text('Notes', projectData.planningNotes['execution_stakeholder_identification'] ?? 'No data recorded.'),
    ],
  );
}

"""
        # Insert before the main class
        class_pat = re.compile(r'class\s+ExecutionPlanStakeholderIdentificationScreen\s+extends\s+StatelessWidget')
        m = class_pat.search(content)
        if m:
            content = content[:m.start()] + func + content[m.start():]
    
    # Fix the header - the onExportPdf: _exportPdf won't work since _exportPdf is 
    # in a different class. Need to change it to () => _exportPdf(context)
    content = content.replace('onExportPdf: _exportPdf)', 'onExportPdf: () => _exportPdf(context))')
    
    if content != orig:
        write_file(fp, content)
        print(f"  DONE: execution_plan_stakeholder_identification_screen.dart")
    else:
        print(f"  NO CHANGE: execution_plan_stakeholder_identification_screen.dart")

# Handle front_end_planning_technology_screen.dart (deprecated wrapper)
# The actual screen is planning_technology_screen.dart which uses PlanningPhaseHeader
fp = os.path.join(BASE, 'planning_technology_screen.dart')
if os.path.exists(fp):
    content = read_file(fp)
    orig = content
    
    # Add imports
    content = add_import_if_missing(content, PDF_IMPORT)
    content = add_import_if_missing(content, PDH_IMPORT)
    
    # Find state class
    m = re.search(r'createState\s*\(\)\s*=>\s+(\w+)\s*\(', content)
    if m and '_exportPdf' not in content:
        scn = m.group(1)
        # Add _exportPdf method
        method = f"""
  Future<void> _exportPdf() async {{
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Technology',
      sections: [
        PdfSection.keyValue('Project Info', [
          {{'Project Name': projectData.projectName ?? 'N/A'}},
        ]),
        PdfSection.text('Technology Notes', projectData.frontEndPlanning.technology ?? 'No data recorded.'),
      ],
    );
  }}
"""
        # Find initState end or class opening
        init_pat = re.compile(r'@override\s*\n\s*void\s+initState\s*\(\s*\)\s*\{')
        init_m = init_pat.search(content)
        if init_m:
            brace_count = 0
            start = content.index('{', init_m.start())
            for i in range(start, len(content)):
                if content[i] == '{': brace_count += 1
                elif content[i] == '}':
                    brace_count -= 1
                    if brace_count == 0:
                        insert_pos = i + 1
                        while insert_pos < len(content) and content[insert_pos] in ' \t\n\r':
                            insert_pos += 1
                        content = content[:insert_pos] + method + content[insert_pos:]
                        break
        else:
            # Insert after class opening brace
            class_pat = re.compile(rf'class\s+{re.escape(scn)}\s+extends\s+\S+')
            cm = class_pat.search(content)
            if cm:
                brace_pos = content.index('{', cm.start()) + 1
                content = content[:brace_pos] + method + content[brace_pos:]
    
    # Add onExportPdf to PlanningPhaseHeader
    if 'onExportPdf' not in content:
        idx = content.find('PlanningPhaseHeader(')
        if idx >= 0:
            open_idx = content.index('(', idx)
            paren_count = 0
            for i in range(open_idx, len(content)):
                if content[i] == '(':
                    paren_count += 1
                elif content[i] == ')':
                    paren_count -= 1
                    if paren_count == 0:
                        before_close = content[idx:i].rstrip()
                        if before_close.endswith(','):
                            new_text = before_close + ' onExportPdf: _exportPdf)'
                        else:
                            new_text = before_close + ', onExportPdf: _exportPdf)'
                        content = content[:idx] + new_text + content[i+1:]
                        break
    
    if content != orig:
        write_file(fp, content)
        print(f"  DONE: planning_technology_screen.dart")
    else:
        print(f"  NO CHANGE: planning_technology_screen.dart")

# Handle execution_plan_agile_delivery_plan_screen.dart
# This redirects to AgileDeliveryModelScreen
fp = os.path.join(BASE, 'agile_delivery_model_screen.dart')
if os.path.exists(fp):
    content = read_file(fp)
    orig = content
    
    # Add imports
    content = add_import_if_missing(content, PDF_IMPORT)
    content = add_import_if_missing(content, PDH_IMPORT)
    
    # Find state class
    m = re.search(r'createState\s*\(\)\s*=>\s+(\w+)\s*\(', content)
    if m and '_exportPdf' not in content:
        scn = m.group(1)
        method = f"""
  Future<void> _exportPdf() async {{
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Agile Delivery Plan',
      sections: [
        PdfSection.keyValue('Project Info', [
          {{'Project Name': projectData.projectName ?? 'N/A'}},
        ]),
        PdfSection.text('Agile Delivery Plan Notes', projectData.planningNotes['execution_agile_delivery_plan_decision'] ?? 'No data recorded.'),
      ],
    );
  }}
"""
        # Find initState end
        init_pat = re.compile(r'@override\s*\n\s*void\s+initState\s*\(\s*\)\s*\{')
        init_m = init_pat.search(content)
        if init_m:
            brace_count = 0
            start = content.index('{', init_m.start())
            for i in range(start, len(content)):
                if content[i] == '{': brace_count += 1
                elif content[i] == '}':
                    brace_count -= 1
                    if brace_count == 0:
                        insert_pos = i + 1
                        while insert_pos < len(content) and content[insert_pos] in ' \t\n\r':
                            insert_pos += 1
                        content = content[:insert_pos] + method + content[insert_pos:]
                        break
        else:
            class_pat = re.compile(rf'class\s+{re.escape(scn)}\s+extends\s+\S+')
            cm = class_pat.search(content)
            if cm:
                brace_pos = content.index('{', cm.start()) + 1
                content = content[:brace_pos] + method + content[brace_pos:]
    
    # Add onExportPdf to PlanningPhaseHeader
    if 'onExportPdf' not in content:
        idx = content.find('PlanningPhaseHeader(')
        if idx >= 0:
            open_idx = content.index('(', idx)
            paren_count = 0
            for i in range(open_idx, len(content)):
                if content[i] == '(':
                    paren_count += 1
                elif content[i] == ')':
                    paren_count -= 1
                    if paren_count == 0:
                        before_close = content[idx:i].rstrip()
                        if before_close.endswith(','):
                            new_text = before_close + ' onExportPdf: _exportPdf)'
                        else:
                            new_text = before_close + ', onExportPdf: _exportPdf)'
                        content = content[:idx] + new_text + content[i+1:]
                        break
    
    if content != orig:
        write_file(fp, content)
        print(f"  DONE: agile_delivery_model_screen.dart")
    else:
        print(f"  NO CHANGE: agile_delivery_model_screen.dart")

print("\nAll remaining files processed!")
