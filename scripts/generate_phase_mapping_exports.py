from __future__ import annotations

import csv
import json
import re
import textwrap
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Dict, List

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import LongTable, PageBreak, Paragraph, SimpleDocTemplate, Spacer, TableStyle
from reportlab.graphics.shapes import Drawing, Line, Rect, String, Polygon

ROOT = Path('/Users/chunguchama/Ndu_Project')
SIDEBAR_FILE = ROOT / 'lib/services/sidebar_navigation_service.dart'
OUT_DIR = ROOT / 'exports/phase_mapping'
CSV_PATH = OUT_DIR / 'phase_mapping_matrix.csv'
JSON_PATH = OUT_DIR / 'phase_mapping_dataset.json'
PDF_PATH = OUT_DIR / 'phase_mapping_report.pdf'

PHASE_ORDER = [
    'Initiation Phase',
    'Front End Planning',
    'Planning Phase',
    'Design Phase',
    'Execution Phase',
    'Launch Phase',
]

PHASE_COLORS = {
    'Initiation Phase': colors.HexColor('#DCEBFF'),
    'Front End Planning': colors.HexColor('#E9F7E7'),
    'Planning Phase': colors.HexColor('#FFF5D6'),
    'Design Phase': colors.HexColor('#F7E3F3'),
    'Execution Phase': colors.HexColor('#FFE5D6'),
    'Launch Phase': colors.HexColor('#E5F4F8'),
}

WORKSTREAM_ORDER = [
    'Scope & requirements',
    'Solution & business case',
    'Risk & assurance',
    'Technology & integration',
    'Commercial & procurement',
    'Cost & financial control',
    'Governance & delivery planning',
    'Team, org & change',
    'Design & technical realization',
    'Execution monitoring & control',
    'Safety, quality & operations readiness',
    'Launch & closeout',
]

ANNOTATIONS: Dict[str, Dict[str, object]] = {
    'business_case': {
        'workstream': 'Scope & requirements',
        'next_phase': ['Summary', 'Project Requirements', 'Project Charter'],
        'phase_after': ['Project Details', 'Requirements', 'Work Breakdown Structure'],
        'basis': 'workflow alignment + shared model',
    },
    'potential_solutions': {
        'workstream': 'Solution & business case',
        'next_phase': ['Summary', 'Project Charter'],
        'phase_after': ['Project Details', 'Project Goals & Milestones'],
        'basis': 'workflow alignment',
    },
    'risk_identification': {
        'workstream': 'Risk & assurance',
        'next_phase': ['Project Risks'],
        'phase_after': ['Risk Assessment'],
        'basis': 'workflow alignment',
    },
    'it_considerations': {
        'workstream': 'Technology & integration',
        'next_phase': ['Security', 'Procurement'],
        'phase_after': ['Technology', 'Security Management'],
        'basis': 'workflow alignment + shared model',
    },
    'infrastructure_considerations': {
        'workstream': 'Technology & integration',
        'next_phase': ['Procurement', 'Allowance'],
        'phase_after': ['Technology', 'Interface Management'],
        'basis': 'workflow alignment + shared model',
    },
    'core_stakeholders': {
        'workstream': 'Team, org & change',
        'next_phase': ['Project Charter', 'Project Activities Log'],
        'phase_after': ['Roles & Responsibilities', 'Stakeholder Management'],
        'basis': 'workflow alignment + shared model',
    },
    'cost_analysis': {
        'workstream': 'Cost & financial control',
        'next_phase': ['Allowance', 'Procurement', 'Contracting'],
        'phase_after': ['Cost Estimate Overview', 'Project Baseline', 'Contract'],
        'basis': 'workflow alignment + shared model',
    },
    'preferred_solution_analysis': {
        'workstream': 'Solution & business case',
        'next_phase': ['Summary', 'Project Charter'],
        'phase_after': ['Project Details', 'Execution Plan'],
        'basis': 'workflow alignment',
    },
    'fep_summary': {
        'workstream': 'Governance & delivery planning',
        'next_phase': ['Project Details'],
        'phase_after': ['Design Management'],
        'basis': 'workflow alignment',
    },
    'fep_requirements': {
        'workstream': 'Scope & requirements',
        'next_phase': ['Requirements'],
        'phase_after': ['Requirements Implementation'],
        'basis': 'workflow alignment + shared model',
    },
    'fep_risks': {
        'workstream': 'Risk & assurance',
        'next_phase': ['Risk Assessment'],
        'phase_after': ['Technical Alignment', 'Risk Tracking'],
        'basis': 'workflow alignment',
    },
    'fep_opportunities': {
        'workstream': 'Solution & business case',
        'next_phase': ['Project Goals & Milestones', 'Roadmap Overview'],
        'phase_after': ['Design Deliverables'],
        'basis': 'workflow alignment',
    },
    'fep_contract_vendor_quotes': {
        'workstream': 'Commercial & procurement',
        'next_phase': ['Contract'],
        'phase_after': ['Long Lead Equipment Ordering'],
        'basis': 'workflow alignment + shared model',
    },
    'fep_procurement': {
        'workstream': 'Commercial & procurement',
        'next_phase': ['Procurement'],
        'phase_after': ['Long Lead Equipment Ordering'],
        'basis': 'workflow alignment',
    },
    'fep_security': {
        'workstream': 'Risk & assurance',
        'next_phase': ['Security Management'],
        'phase_after': ['Development Set Up', 'Technical Alignment'],
        'basis': 'workflow alignment + shared model',
    },
    'fep_allowance': {
        'workstream': 'Cost & financial control',
        'next_phase': ['Cost Estimate Overview', 'Project Baseline'],
        'phase_after': ['Design Deliverables'],
        'basis': 'workflow alignment',
    },
    'project_charter': {
        'workstream': 'Governance & delivery planning',
        'next_phase': ['Project Details', 'Work Breakdown Structure', 'Execution Plan'],
        'phase_after': ['Requirements Implementation', 'Design Management'],
        'basis': 'direct sync + shared model',
    },
    'project_activities_log': {
        'workstream': 'Governance & delivery planning',
        'next_phase': ['Project Details', 'Contract', 'Stakeholder Management', 'Risk Assessment'],
        'phase_after': ['Design Management', 'Requirements Implementation', 'Progress Tracking'],
        'basis': 'shared model + workflow alignment',
    },
    'project_framework': {
        'workstream': 'Governance & delivery planning',
        'next_phase': ['Design Management'],
        'phase_after': ['Staff Team', 'Project Summary'],
        'basis': 'shared model',
    },
    'work_breakdown_structure': {
        'workstream': 'Scope & requirements',
        'next_phase': ['Design Deliverables'],
        'phase_after': ['Scope Tracking Implementation', 'Scope Completion'],
        'basis': 'shared model + workflow alignment',
    },
    'project_goals_milestones': {
        'workstream': 'Governance & delivery planning',
        'next_phase': ['Design Management', 'Design Deliverables'],
        'phase_after': ['Progress Tracking', 'Start-up or Launch Checklist'],
        'basis': 'shared model + workflow alignment',
    },
    'requirements': {
        'workstream': 'Scope & requirements',
        'next_phase': ['Requirements Implementation'],
        'phase_after': ['Scope Tracking Implementation', 'Scope Completion'],
        'basis': 'shared model + workflow alignment',
    },
    'ssher': {
        'workstream': 'Safety, quality & operations readiness',
        'next_phase': ['Specialized Design'],
        'phase_after': ['Start-up or Launch Checklist', 'Salvage and/or Disposal Plan'],
        'basis': 'workflow alignment',
    },
    'change_management': {
        'workstream': 'Team, org & change',
        'next_phase': ['Design Management', 'Technical Alignment'],
        'phase_after': ['Gap Analysis and Scope Reconciliation', 'Punchlist Overview'],
        'basis': 'workflow alignment',
    },
    'issue_management': {
        'workstream': 'Execution monitoring & control',
        'next_phase': ['Technical Alignment', 'Tools Integration'],
        'phase_after': ['Risk Tracking', 'Punchlist Overview'],
        'basis': 'workflow alignment + shared model',
    },
    'cost_estimate': {
        'workstream': 'Cost & financial control',
        'next_phase': ['Long Lead Equipment Ordering', 'Design Deliverables'],
        'phase_after': ['Vendor Tracking', 'Progress Tracking'],
        'basis': 'shared model + workflow alignment',
    },
    'scope_tracking_plan': {
        'workstream': 'Scope & requirements',
        'next_phase': ['Requirements Implementation', 'Design Deliverables'],
        'phase_after': ['Scope Tracking Implementation', 'Scope Completion'],
        'basis': 'shared model + workflow alignment',
    },
    'contracts': {
        'workstream': 'Commercial & procurement',
        'next_phase': ['Long Lead Equipment Ordering'],
        'phase_after': ['Contracts Tracking'],
        'basis': 'shared model + workflow alignment',
    },
    'project_plan': {
        'workstream': 'Governance & delivery planning',
        'next_phase': ['Design Management'],
        'phase_after': ['Progress Tracking'],
        'basis': 'workflow alignment',
    },
    'execution_plan': {
        'workstream': 'Governance & delivery planning',
        'next_phase': ['Design Management', 'Development Set Up'],
        'phase_after': ['Staff Team', 'Progress Tracking'],
        'basis': 'shared model + workflow alignment',
    },
    'schedule': {
        'workstream': 'Governance & delivery planning',
        'next_phase': ['Design Deliverables', 'Long Lead Equipment Ordering'],
        'phase_after': ['Progress Tracking', 'Start-up or Launch Checklist'],
        'basis': 'shared model + workflow alignment',
    },
    'design': {
        'workstream': 'Design & technical realization',
        'next_phase': ['Design Management'],
        'phase_after': ['Detailed Design'],
        'basis': 'workflow alignment',
    },
    'technology': {
        'workstream': 'Technology & integration',
        'next_phase': ['Technical Alignment', 'Development Set Up', 'Backend Design'],
        'phase_after': ['Tech Debt Management', 'Update Ops and Maintenance Plans'],
        'basis': 'shared model + workflow alignment',
    },
    'interface_management': {
        'workstream': 'Technology & integration',
        'next_phase': ['Technical Alignment', 'Tools Integration'],
        'phase_after': ['Stakeholder Alignment', 'Update Ops and Maintenance Plans'],
        'basis': 'shared model + workflow alignment',
    },
    'startup_planning': {
        'workstream': 'Safety, quality & operations readiness',
        'next_phase': ['Design Deliverables', 'Specialized Design'],
        'phase_after': ['Start-up or Launch Checklist'],
        'basis': 'workflow alignment',
    },
    'deliverable_roadmap': {
        'workstream': 'Governance & delivery planning',
        'next_phase': ['Design Deliverables'],
        'phase_after': ['Progress Tracking'],
        'basis': 'workflow alignment',
    },
    'agile_project_baseline': {
        'workstream': 'Design & technical realization',
        'next_phase': ['Technical Development'],
        'phase_after': ['Agile Development Iterations'],
        'basis': 'workflow alignment',
    },
    'project_baseline': {
        'workstream': 'Cost & financial control',
        'next_phase': ['Design Deliverables', 'Technical Alignment'],
        'phase_after': ['Progress Tracking', 'Gap Analysis and Scope Reconciliation'],
        'basis': 'shared model + workflow alignment',
    },
    'organization_roles_responsibilities': {
        'workstream': 'Team, org & change',
        'next_phase': ['Design Management'],
        'phase_after': ['Staff Team'],
        'basis': 'shared model + workflow alignment',
    },
    'organization_staffing_plan': {
        'workstream': 'Team, org & change',
        'next_phase': ['Development Set Up', 'Design Management'],
        'phase_after': ['Staff Team', 'Identify and Staff Ops Team'],
        'basis': 'shared model + workflow alignment',
    },
    'team_training': {
        'workstream': 'Team, org & change',
        'next_phase': ['Design Management'],
        'phase_after': ['Team Meetings'],
        'basis': 'shared model + workflow alignment',
    },
    'stakeholder_management': {
        'workstream': 'Team, org & change',
        'next_phase': ['Design Management', 'Technical Alignment'],
        'phase_after': ['Stakeholder Alignment'],
        'basis': 'shared model + workflow alignment',
    },
    'lessons_learned': {
        'workstream': 'Governance & delivery planning',
        'next_phase': ['Design Management'],
        'phase_after': ['Gap Analysis and Scope Reconciliation'],
        'basis': 'shared model + workflow alignment',
    },
    'team_management': {
        'workstream': 'Team, org & change',
        'next_phase': ['Development Set Up'],
        'phase_after': ['Staff Team', 'Team Meetings'],
        'basis': 'shared model + workflow alignment',
    },
    'risk_assessment': {
        'workstream': 'Risk & assurance',
        'next_phase': ['Technical Alignment', 'Specialized Design'],
        'phase_after': ['Risk Tracking'],
        'basis': 'shared model + workflow alignment',
    },
    'security_management': {
        'workstream': 'Risk & assurance',
        'next_phase': ['Development Set Up', 'Backend Design'],
        'phase_after': ['Start-up or Launch Checklist', 'Update Ops and Maintenance Plans'],
        'basis': 'shared model + workflow alignment',
    },
    'quality_management': {
        'workstream': 'Safety, quality & operations readiness',
        'next_phase': ['Requirements Implementation', 'Design Deliverables'],
        'phase_after': ['Progress Tracking', 'Scope Completion'],
        'basis': 'shared model + workflow alignment',
    },
    'design_management': {
        'workstream': 'Design & technical realization',
        'next_phase': ['Detailed Design', 'Progress Tracking'],
        'phase_after': ['Deliver Project', 'Project Summary'],
        'basis': 'shared model + workflow alignment',
    },
    'requirements_implementation': {
        'workstream': 'Scope & requirements',
        'next_phase': ['Scope Tracking Implementation', 'Scope Completion'],
        'phase_after': ['Deliver Project', 'Project Close Out'],
        'basis': 'direct sync + shared model',
    },
    'technical_alignment': {
        'workstream': 'Technology & integration',
        'next_phase': ['Detailed Design', 'Tech Debt Management'],
        'phase_after': ['Transition To Production Team'],
        'basis': 'shared model + workflow alignment',
    },
    'development_set_up': {
        'workstream': 'Technology & integration',
        'next_phase': ['Agile Development Iterations', 'Staff Team'],
        'phase_after': ['Transition To Production Team'],
        'basis': 'shared model + workflow alignment',
    },
    'ui_ux_design': {
        'workstream': 'Design & technical realization',
        'next_phase': ['Detailed Design', 'Agile Development Iterations'],
        'phase_after': ['Deliver Project', 'Project Summary'],
        'basis': 'workflow alignment',
    },
    'backend_design': {
        'workstream': 'Design & technical realization',
        'next_phase': ['Agile Development Iterations', 'Tech Debt Management'],
        'phase_after': ['Transition To Production Team', 'Project Close Out'],
        'basis': 'workflow alignment',
    },
    'engineering_design': {
        'workstream': 'Design & technical realization',
        'next_phase': ['Detailed Design', 'Scope Completion'],
        'phase_after': ['Deliver Project', 'Project Summary'],
        'basis': 'workflow alignment',
    },
    'technical_development': {
        'workstream': 'Design & technical realization',
        'next_phase': ['Agile Development Iterations', 'Tech Debt Management'],
        'phase_after': ['Transition To Production Team', 'Project Close Out'],
        'basis': 'workflow alignment',
    },
    'tools_integration': {
        'workstream': 'Technology & integration',
        'next_phase': ['Progress Tracking', 'Tech Debt Management'],
        'phase_after': ['Transition To Production Team', 'Project Close Out'],
        'basis': 'workflow alignment',
    },
    'long_lead_equipment_ordering': {
        'workstream': 'Commercial & procurement',
        'next_phase': ['Vendor Tracking', 'Contracts Tracking'],
        'phase_after': ['Vendor Account Close Out', 'Contract Close Out'],
        'basis': 'workflow alignment + shared model',
    },
    'specialized_design': {
        'workstream': 'Design & technical realization',
        'next_phase': ['Detailed Design', 'Scope Completion'],
        'phase_after': ['Deliver Project', 'Project Summary'],
        'basis': 'workflow alignment',
    },
    'design_deliverables': {
        'workstream': 'Governance & delivery planning',
        'next_phase': ['Progress Tracking', 'Start-up or Launch Checklist'],
        'phase_after': ['Deliver Project', 'Project Summary'],
        'basis': 'shared model + workflow alignment',
    },
    'staff_team': {
        'workstream': 'Team, org & change',
        'next_phase': ['Transition To Production Team'],
        'phase_after': ['Demobilize Team'],
        'basis': 'workflow alignment',
    },
    'team_meetings': {
        'workstream': 'Team, org & change',
        'next_phase': ['Transition To Production Team'],
        'phase_after': ['Project Summary'],
        'basis': 'workflow alignment',
    },
    'progress_tracking': {
        'workstream': 'Execution monitoring & control',
        'next_phase': ['Deliver Project'],
        'phase_after': ['Project Summary', 'Project Close Out'],
        'basis': 'shared model + workflow alignment',
    },
    'contracts_tracking': {
        'workstream': 'Commercial & procurement',
        'next_phase': ['Contract Close Out'],
        'phase_after': ['Project Close Out'],
        'basis': 'shared model + workflow alignment',
    },
    'vendor_tracking': {
        'workstream': 'Commercial & procurement',
        'next_phase': ['Vendor Account Close Out'],
        'phase_after': ['Project Close Out'],
        'basis': 'shared model + workflow alignment',
    },
    'detailed_design': {
        'workstream': 'Design & technical realization',
        'next_phase': ['Deliver Project'],
        'phase_after': ['Project Summary'],
        'basis': 'workflow alignment',
    },
    'agile_development_iterations': {
        'workstream': 'Design & technical realization',
        'next_phase': ['Deliver Project'],
        'phase_after': ['Project Summary', 'Project Close Out'],
        'basis': 'workflow alignment',
    },
    'scope_tracking_implementation': {
        'workstream': 'Scope & requirements',
        'next_phase': ['Deliver Project'],
        'phase_after': ['Project Close Out'],
        'basis': 'shared model + workflow alignment',
    },
    'stakeholder_alignment': {
        'workstream': 'Team, org & change',
        'next_phase': ['Transition To Production Team'],
        'phase_after': ['Project Summary'],
        'basis': 'workflow alignment',
    },
    'update_ops_maintenance_plans': {
        'workstream': 'Technology & integration',
        'next_phase': ['Transition To Production Team'],
        'phase_after': ['Demobilize Team'],
        'basis': 'workflow alignment',
    },
    'launch_checklist': {
        'workstream': 'Safety, quality & operations readiness',
        'next_phase': ['Deliver Project'],
        'phase_after': ['Transition To Production Team'],
        'basis': 'workflow alignment',
    },
    'risk_tracking': {
        'workstream': 'Risk & assurance',
        'next_phase': ['Project Summary'],
        'phase_after': ['Project Close Out'],
        'basis': 'workflow alignment + shared model',
    },
    'scope_completion': {
        'workstream': 'Scope & requirements',
        'next_phase': ['Deliver Project'],
        'phase_after': ['Project Close Out'],
        'basis': 'shared model + workflow alignment',
    },
    'gap_analysis_scope_reconcillation': {
        'workstream': 'Governance & delivery planning',
        'next_phase': ['Project Summary'],
        'phase_after': ['Project Close Out'],
        'basis': 'workflow alignment',
    },
    'punchlist_actions': {
        'workstream': 'Execution monitoring & control',
        'next_phase': ['Deliver Project'],
        'phase_after': ['Project Close Out'],
        'basis': 'workflow alignment',
    },
    'technical_debt_management': {
        'workstream': 'Technology & integration',
        'next_phase': ['Transition To Production Team'],
        'phase_after': ['Project Close Out'],
        'basis': 'workflow alignment',
    },
    'identify_staff_ops_team': {
        'workstream': 'Team, org & change',
        'next_phase': ['Transition To Production Team'],
        'phase_after': ['Demobilize Team'],
        'basis': 'workflow alignment',
    },
    'salvage_disposal_team': {
        'workstream': 'Safety, quality & operations readiness',
        'next_phase': ['Vendor Account Close Out', 'Project Close Out'],
        'phase_after': ['Demobilize Team'],
        'basis': 'workflow alignment',
    },
    'deliver_project_closure': {
        'workstream': 'Launch & closeout',
        'next_phase': ['Project Summary', 'Project Close Out'],
        'phase_after': [],
        'basis': 'terminal launch workflow',
    },
    'transition_to_prod_team': {
        'workstream': 'Launch & closeout',
        'next_phase': ['Demobilize Team'],
        'phase_after': [],
        'basis': 'terminal launch workflow',
    },
    'contract_close_out': {
        'workstream': 'Commercial & procurement',
        'next_phase': ['Project Close Out'],
        'phase_after': [],
        'basis': 'terminal launch workflow',
    },
    'vendor_account_close_out': {
        'workstream': 'Commercial & procurement',
        'next_phase': ['Project Close Out', 'Demobilize Team'],
        'phase_after': [],
        'basis': 'terminal launch workflow',
    },
    'summarize_account_risks': {
        'workstream': 'Governance & delivery planning',
        'next_phase': ['Project Close Out'],
        'phase_after': [],
        'basis': 'terminal launch workflow',
    },
    'project_close_out': {
        'workstream': 'Launch & closeout',
        'next_phase': ['Demobilize Team'],
        'phase_after': [],
        'basis': 'terminal launch workflow',
    },
    'demobilize_team': {
        'workstream': 'Launch & closeout',
        'next_phase': [],
        'phase_after': [],
        'basis': 'terminal end state',
    },
}


def parse_sidebar_items() -> List[Dict[str, str]]:
    text = SIDEBAR_FILE.read_text()
    pattern = re.compile(
        r"SidebarItem\(\s*checkpoint: '([^']+)'\s*,\s*label: '([^']+)'\s*\)",
        re.S,
    )
    items = pattern.findall(text)
    return [{'checkpoint': checkpoint, 'label': label} for checkpoint, label in items]


def phase_for_index(index: int) -> str:
    if index <= 8:
        return 'Initiation Phase'
    if index <= 18:
        return 'Front End Planning'
    if index <= 47:
        return 'Planning Phase'
    if index <= 59:
        return 'Design Phase'
    if index <= 77:
        return 'Execution Phase'
    return 'Launch Phase'


def build_rows() -> List[Dict[str, object]]:
    rows = []
    items = parse_sidebar_items()
    missing = []
    for idx, item in enumerate(items, start=1):
        checkpoint = item['checkpoint']
        if checkpoint not in ANNOTATIONS:
            missing.append(checkpoint)
            continue
        annotation = ANNOTATIONS[checkpoint]
        rows.append(
            {
                'order': idx,
                'phase': phase_for_index(idx),
                'checkpoint': checkpoint,
                'label': item['label'],
                'workstream': annotation['workstream'],
                'maps_to_next_phase': annotation['next_phase'],
                'maps_to_phase_after': annotation['phase_after'],
                'mapping_basis': annotation['basis'],
            }
        )
    if missing:
        raise SystemExit(f'Missing annotations for: {missing}')
    if len(rows) != len(items):
        raise SystemExit(f'Expected {len(items)} rows, got {len(rows)}')
    return rows


def write_csv(rows: List[Dict[str, object]]) -> None:
    with CSV_PATH.open('w', newline='') as fh:
        writer = csv.writer(fh)
        writer.writerow(
            [
                'order',
                'phase',
                'checkpoint',
                'label',
                'primary_workstream',
                'maps_to_next_phase',
                'maps_to_phase_after',
                'mapping_basis',
            ]
        )
        for row in rows:
            writer.writerow(
                [
                    row['order'],
                    row['phase'],
                    row['checkpoint'],
                    row['label'],
                    row['workstream'],
                    '; '.join(row['maps_to_next_phase']),
                    '; '.join(row['maps_to_phase_after']),
                    row['mapping_basis'],
                ]
            )


def write_json(rows: List[Dict[str, object]]) -> None:
    payload = {
        'generated_at': datetime.utcnow().isoformat() + 'Z',
        'source_files': [
            'lib/services/sidebar_navigation_service.dart',
            'lib/models/project_data_model.dart',
            'lib/services/design_phase_service.dart',
        ],
        'rows': rows,
    }
    JSON_PATH.write_text(json.dumps(payload, indent=2))


def paragraph(text: str, style: ParagraphStyle) -> Paragraph:
    return Paragraph(text.replace('&', '&amp;'), style)


def build_matrix_table(rows: List[Dict[str, object]], styles) -> LongTable:
    header = [
        paragraph('Order', styles['table_header']),
        paragraph('Phase', styles['table_header']),
        paragraph('Sidebar Page', styles['table_header']),
        paragraph('Checkpoint', styles['table_header']),
        paragraph('Workstream', styles['table_header']),
        paragraph('Maps To Next Phase', styles['table_header']),
        paragraph('Maps To Phase After', styles['table_header']),
        paragraph('Basis', styles['table_header']),
    ]
    data = [header]
    for row in rows:
        data.append(
            [
                paragraph(str(row['order']), styles['table_body']),
                paragraph(row['phase'], styles['table_body']),
                paragraph(row['label'], styles['table_body']),
                paragraph(row['checkpoint'], styles['table_body']),
                paragraph(row['workstream'], styles['table_body']),
                paragraph('<br/>'.join(row['maps_to_next_phase']) or '-', styles['table_body']),
                paragraph('<br/>'.join(row['maps_to_phase_after']) or '-', styles['table_body']),
                paragraph(row['mapping_basis'], styles['table_body']),
            ]
        )

    table = LongTable(
        data,
        repeatRows=1,
        colWidths=[0.42 * inch, 1.0 * inch, 1.35 * inch, 1.2 * inch, 1.2 * inch, 1.75 * inch, 1.75 * inch, 1.1 * inch],
        hAlign='LEFT',
    )
    table.setStyle(
        TableStyle(
            [
                ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#0F172A')),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('ALIGN', (0, 0), (0, -1), 'CENTER'),
                ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                ('GRID', (0, 0), (-1, -1), 0.35, colors.HexColor('#CBD5E1')),
                ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F8FAFC')]),
                ('LEFTPADDING', (0, 0), (-1, -1), 4),
                ('RIGHTPADDING', (0, 0), (-1, -1), 4),
                ('TOPPADDING', (0, 0), (-1, -1), 4),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
            ]
        )
    )
    return table


def wrap_lines(lines: List[str], width: int = 28) -> List[str]:
    wrapped: List[str] = []
    for line in lines:
        chunks = textwrap.wrap(line, width=width) or ['']
        wrapped.extend(chunks)
    return wrapped


def arrowhead(x: float, y: float, direction: str) -> Polygon:
    if direction == 'right':
        points = [x, y, x - 6, y + 3, x - 6, y - 3]
    elif direction == 'down':
        points = [x, y, x - 3, y + 6, x + 3, y + 6]
    else:
        points = [x, y, x + 6, y + 3, x + 6, y - 3]
    return Polygon(points, fillColor=colors.HexColor('#475569'), strokeColor=colors.HexColor('#475569'))


def build_workstream_drawing(workstream: str, rows: List[Dict[str, object]]) -> Drawing:
    lane_rows = [row for row in rows if row['workstream'] == workstream]
    by_phase: Dict[str, List[str]] = defaultdict(list)
    for row in lane_rows:
        by_phase[row['phase']].append(row['label'])

    drawing = Drawing(760, 480)
    box_w = 220
    box_gap_x = 20
    box_gap_y = 28
    left = 18
    top_y = 420
    row_height = 180
    positions = {
        'Initiation Phase': (left, top_y),
        'Front End Planning': (left + box_w + box_gap_x, top_y),
        'Planning Phase': (left + 2 * (box_w + box_gap_x), top_y),
        'Design Phase': (left, top_y - row_height - box_gap_y),
        'Execution Phase': (left + box_w + box_gap_x, top_y - row_height - box_gap_y),
        'Launch Phase': (left + 2 * (box_w + box_gap_x), top_y - row_height - box_gap_y),
    }

    drawing.add(String(380, 456, workstream, fontName='Helvetica-Bold', fontSize=16, textAnchor='middle', fillColor=colors.HexColor('#111827')))
    drawing.add(String(380, 438, 'Grouped dependency diagram by phase', fontName='Helvetica', fontSize=9, textAnchor='middle', fillColor=colors.HexColor('#64748B')))

    box_centers = {}
    populated_phases = []

    for phase in PHASE_ORDER:
        x, y = positions[phase]
        labels = by_phase.get(phase, [])
        if labels:
            populated_phases.append(phase)
        wrapped_lines = wrap_lines([f'- {label}' for label in labels], width=30)
        max_lines = max(len(wrapped_lines), 1)
        content_height = 20 + (max_lines * 9)
        box_h = max(92, min(150, content_height + 28))
        y0 = y - box_h
        drawing.add(
            Rect(
                x,
                y0,
                box_w,
                box_h,
                rx=12,
                ry=12,
                fillColor=PHASE_COLORS[phase],
                strokeColor=colors.HexColor('#94A3B8'),
                strokeWidth=1,
            )
        )
        drawing.add(String(x + 10, y - 16, phase, fontName='Helvetica-Bold', fontSize=11, fillColor=colors.HexColor('#0F172A')))
        if labels:
            current_y = y - 32
            for line in wrapped_lines[:12]:
                drawing.add(String(x + 12, current_y, line, fontName='Helvetica', fontSize=7.2, fillColor=colors.HexColor('#1F2937')))
                current_y -= 9
        else:
            drawing.add(String(x + 12, y - 36, '(No primary pages in this workstream)', fontName='Helvetica-Oblique', fontSize=7.2, fillColor=colors.HexColor('#64748B')))
        box_centers[phase] = (x + box_w / 2, y0 + box_h / 2, x, y0, box_w, box_h)

    phase_index = {phase: i for i, phase in enumerate(PHASE_ORDER)}
    for prev, curr in zip(populated_phases, populated_phases[1:]):
        prev_i = phase_index[prev]
        curr_i = phase_index[curr]
        px, py, px0, py0, pw, ph = box_centers[prev]
        cx, cy, cx0, cy0, cw, ch = box_centers[curr]
        if curr_i == prev_i + 1 and prev in ('Initiation Phase', 'Front End Planning'):
            start_x = px0 + pw
            start_y = py
            end_x = cx0
            end_y = cy
            drawing.add(Line(start_x, start_y, end_x, end_y, strokeColor=colors.HexColor('#475569'), strokeWidth=1.2))
            drawing.add(arrowhead(end_x, end_y, 'right'))
        elif prev == 'Planning Phase' and curr == 'Design Phase':
            start_x = px
            start_y = py0
            end_x = cx
            end_y = cy0 + ch
            drawing.add(Line(start_x, start_y, end_x, end_y, strokeColor=colors.HexColor('#475569'), strokeWidth=1.2))
            drawing.add(arrowhead(end_x, end_y - 1, 'down'))
        elif prev in ('Design Phase', 'Execution Phase'):
            start_x = px0 + pw
            start_y = py
            end_x = cx0
            end_y = cy
            drawing.add(Line(start_x, start_y, end_x, end_y, strokeColor=colors.HexColor('#475569'), strokeWidth=1.2))
            drawing.add(arrowhead(end_x, end_y, 'right'))
        else:
            # Fallback connector for non-adjacent populated phases.
            start_x = px
            start_y = py0
            end_x = cx
            end_y = cy0 + ch
            drawing.add(Line(start_x, start_y, end_x, end_y, strokeColor=colors.HexColor('#475569'), strokeWidth=1.0))
            drawing.add(arrowhead(end_x, end_y - 1, 'down'))

    return drawing


def build_pdf(rows: List[Dict[str, object]]) -> None:
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(name='TitlePage', parent=styles['Title'], fontName='Helvetica-Bold', fontSize=22, leading=26, alignment=TA_LEFT, textColor=colors.HexColor('#0F172A')))
    styles.add(ParagraphStyle(name='Subtitle', parent=styles['BodyText'], fontName='Helvetica', fontSize=10, leading=13, textColor=colors.HexColor('#475569')))
    styles.add(ParagraphStyle(name='HeadingSmall', parent=styles['Heading2'], fontName='Helvetica-Bold', fontSize=14, leading=18, textColor=colors.HexColor('#111827')))
    styles.add(ParagraphStyle(name='table_header', parent=styles['BodyText'], fontName='Helvetica-Bold', fontSize=6.5, leading=8, alignment=TA_CENTER, textColor=colors.white))
    styles.add(ParagraphStyle(name='table_body', parent=styles['BodyText'], fontName='Helvetica', fontSize=6.2, leading=7.4, alignment=TA_LEFT, textColor=colors.HexColor('#1F2937')))

    doc = SimpleDocTemplate(
        str(PDF_PATH),
        pagesize=landscape(A4),
        leftMargin=24,
        rightMargin=24,
        topMargin=24,
        bottomMargin=24,
        title='Phase Mapping Report',
        author='OpenAI Codex',
    )

    story = []
    generated = datetime.now().strftime('%Y-%m-%d %H:%M')
    story.append(paragraph('Phase-to-Phase Sidebar Mapping', styles['TitlePage']))
    story.append(Spacer(1, 8))
    story.append(paragraph('Exports generated from the sidebar order defined in <b>lib/services/sidebar_navigation_service.dart</b> and mapped across the next phase and the phase after that. The report includes both a CSV-style matrix and grouped workstream diagrams.', styles['Subtitle']))
    story.append(Spacer(1, 8))
    story.append(paragraph(f'Generated: {generated}', styles['Subtitle']))
    story.append(paragraph('Explicit direct carry-forward verified in code: Project Charter / scope -> Requirements Implementation via lib/services/design_phase_service.dart.', styles['Subtitle']))
    story.append(Spacer(1, 14))
    story.append(paragraph('CSV-Style Matrix', styles['HeadingSmall']))
    story.append(Spacer(1, 8))
    story.append(build_matrix_table(rows, styles))
    story.append(PageBreak())
    story.append(paragraph('Visual Dependency Diagrams Grouped By Workstream', styles['HeadingSmall']))
    story.append(Spacer(1, 6))
    story.append(paragraph('Each page groups the primary sidebar pages for one workstream into phase lanes. Arrows indicate how the workstream advances from one phase to the next populated phase.', styles['Subtitle']))
    story.append(PageBreak())

    for idx, workstream in enumerate(WORKSTREAM_ORDER):
        story.append(build_workstream_drawing(workstream, rows))
        if idx < len(WORKSTREAM_ORDER) - 1:
            story.append(PageBreak())

    doc.build(story)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    rows = build_rows()
    write_csv(rows)
    write_json(rows)
    build_pdf(rows)
    print(f'Wrote {CSV_PATH}')
    print(f'Wrote {JSON_PATH}')
    print(f'Wrote {PDF_PATH}')


if __name__ == '__main__':
    main()
