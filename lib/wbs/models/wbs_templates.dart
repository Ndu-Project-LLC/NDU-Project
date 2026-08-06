/// WBS Framework templates — extracted verbatim from the two guidance docs.
///
/// Each framework has Level 1 seed suggestions (with Level 2 example children)
/// so the user can start from a proven structure instead of a blank canvas.


library;

import 'package:ndu_project/wbs/models/wbs_models.dart';

class TemplateNode {
  final String name;
  final String? description;
  final List<({String name, String? description})> children;

  const TemplateNode({
    required this.name,
    this.description,
    required this.children,
  });
}

class WBSTemplates {
  static Map<WBSFramework, List<TemplateNode>> get templates => {
        // ============================================================
        // AGILE — from "Agile Project WBS Guidance.docx"
        // ============================================================
        WBSFramework.agile: [
          const TemplateNode(
            name: 'User Management',
            description: 'User lifecycle and identity management epic',
            children: [
              (name: 'User Registration', description: 'Sign-up flow and validation'),
              (name: 'Login and Authentication', description: 'Credential-based and SSO login'),
              (name: 'Password Reset', description: 'Self-service password recovery'),
              (name: 'User Roles and Permissions', description: 'Role-based access control'),
            ],
          ),
          const TemplateNode(
            name: 'Customer Management',
            description: 'Customer data and relationship management epic',
            children: [
              (name: 'Customer Profile Creation', description: 'Create and edit customer profiles'),
              (name: 'Customer Search', description: 'Search and filter customer records'),
              (name: 'Customer History', description: 'Activity history and audit trail'),
            ],
          ),
          const TemplateNode(
            name: 'Sales Pipeline',
            description: 'Opportunity tracking and sales forecasting epic',
            children: [
              (name: 'Opportunity Creation', description: 'Create sales opportunities'),
              (name: 'Opportunity Tracking', description: 'Track stage progression'),
              (name: 'Forecasting', description: 'Revenue forecasting and pipeline analytics'),
            ],
          ),
          const TemplateNode(
            name: 'Reporting and Analytics',
            description: 'Dashboards and reporting epic',
            children: [
              (name: 'Dashboard', description: 'Configurable KPI dashboard'),
              (name: 'Reports', description: 'Standard and custom reports'),
              (name: 'Export Functionality', description: 'CSV / PDF / Excel export'),
            ],
          ),
          const TemplateNode(
            name: 'Notifications',
            description: 'System and user notifications epic',
            children: [
              (name: 'In-App Notifications', description: 'Real-time in-app alerts'),
              (name: 'Email Notifications', description: 'Transactional and digest emails'),
              (name: 'Push Notifications', description: 'Mobile push notifications'),
            ],
          ),
        ],

        // ============================================================
        // WATERFALL_DELIVERABLE — Section 1: Deliverable-Based WBS
        // ============================================================
        WBSFramework.waterfallDeliverable: [
          const TemplateNode(
            name: 'Site Preparation',
            description: 'Site readiness and ground works',
            children: [
              (name: 'Clearing and Grading', description: 'Vegetation removal and ground leveling'),
              (name: 'Earthworks', description: 'Excavation, fill, and compaction'),
              (name: 'Utilities Relocation', description: 'Relocate existing utilities'),
            ],
          ),
          const TemplateNode(
            name: 'Building Structure',
            description: 'Structural envelope and shell',
            children: [
              (name: 'Foundations', description: 'Footings, piers, and slabs'),
              (name: 'Steel Structure', description: 'Structural steel erection'),
              (name: 'Roof System', description: 'Roofing and waterproofing'),
            ],
          ),
          const TemplateNode(
            name: 'Process Systems',
            description: 'Mechanical and electrical process systems',
            children: [
              (name: 'Piping System', description: 'Process piping fabrication and installation'),
              (name: 'Electrical System', description: 'Power distribution and wiring'),
              (name: 'Instrumentation System', description: 'Instrumentation and controls'),
            ],
          ),
          const TemplateNode(
            name: 'Commissioning Package',
            description: 'Testing and commissioning deliverables',
            children: [
              (name: 'Mechanical Completion', description: 'Mechanical completion verification'),
              (name: 'Startup Testing', description: 'System startup and functional testing'),
              (name: 'Performance Validation', description: 'Performance and acceptance testing'),
            ],
          ),
          const TemplateNode(
            name: 'Handover Package',
            description: 'Closeout and handover deliverables',
            children: [
              (name: 'As-Built Drawings', description: 'Record drawings and documentation'),
              (name: 'Training', description: 'Operator and maintenance training'),
              (name: 'Operations Manual', description: 'Operations and maintenance manuals'),
            ],
          ),
        ],

        // ============================================================
        // WATERFALL_DISCIPLINE — Section 2: Discipline-Based WBS
        // ============================================================
        WBSFramework.waterfallDiscipline: [
          const TemplateNode(
            name: 'Civil',
            description: 'Civil engineering works',
            children: [
              (name: 'Excavation', description: 'Site excavation and earthworks'),
              (name: 'Concrete Foundations', description: 'Foundation concrete works'),
              (name: 'Underground Utilities', description: 'Underground drainage and utilities'),
            ],
          ),
          const TemplateNode(
            name: 'Structural',
            description: 'Structural engineering works',
            children: [
              (name: 'Structural Steel', description: 'Structural steel fabrication and erection'),
              (name: 'Platforms and Supports', description: 'Platforms, walkways, and supports'),
            ],
          ),
          const TemplateNode(
            name: 'Mechanical',
            description: 'Mechanical engineering works',
            children: [
              (name: 'Equipment Installation', description: 'Static and rotating equipment installation'),
              (name: 'Rotating Equipment', description: 'Pumps, compressors, and rotating machinery'),
            ],
          ),
          const TemplateNode(
            name: 'Piping',
            description: 'Piping engineering works',
            children: [
              (name: 'Fabrication', description: 'Pipe spool fabrication'),
              (name: 'Installation', description: 'Piping installation and supports'),
              (name: 'Pressure Testing', description: 'Hydrostatic and pneumatic testing'),
            ],
          ),
          const TemplateNode(
            name: 'Electrical',
            description: 'Electrical engineering works',
            children: [
              (name: 'Cable Tray', description: 'Cable tray and conduit installation'),
              (name: 'Power Distribution', description: 'Power distribution and switchgear'),
              (name: 'Lighting', description: 'Lighting and small power'),
            ],
          ),
          const TemplateNode(
            name: 'Instrumentation & Controls',
            description: 'I&C engineering works',
            children: [
              (name: 'Field Instruments', description: 'Field instrument installation'),
              (name: 'Control Systems', description: 'PLC/DCS configuration and installation'),
              (name: 'SCADA', description: 'SCADA and HMI implementation'),
            ],
          ),
          const TemplateNode(
            name: 'Commissioning',
            description: 'Commissioning discipline',
            children: [
              (name: 'Pre-Commissioning', description: 'Pre-commissioning checks'),
              (name: 'Commissioning', description: 'System commissioning'),
              (name: 'Performance Testing', description: 'Performance guarantee testing'),
            ],
          ),
        ],

        // ============================================================
        // WATERFALL_FUNCTIONAL — Section 3: Functional Area WBS
        // ============================================================
        WBSFramework.waterfallFunctional: [
          const TemplateNode(
            name: 'Engineering',
            description: 'Engineering function',
            children: [
              (name: 'Design Package', description: 'Detailed design packages'),
              (name: 'Specifications', description: 'Technical specifications'),
              (name: 'Calculations', description: 'Engineering calculations'),
            ],
          ),
          const TemplateNode(
            name: 'Procurement',
            description: 'Procurement function',
            children: [
              (name: 'Long Lead Equipment', description: 'Long-lead equipment procurement'),
              (name: 'Vendor Management', description: 'Vendor selection and management'),
              (name: 'Purchase Orders', description: 'Purchase order management'),
            ],
          ),
          const TemplateNode(
            name: 'Construction',
            description: 'Construction function',
            children: [
              (name: 'Site Works', description: 'Site preparation and works'),
              (name: 'Building Construction', description: 'Building construction activities'),
              (name: 'Equipment Installation', description: 'Equipment installation'),
            ],
          ),
          const TemplateNode(
            name: 'Quality',
            description: 'Quality function',
            children: [
              (name: 'Inspection Plans', description: 'Inspection and test plans'),
              (name: 'Testing', description: 'Quality testing and verification'),
              (name: 'Quality Documentation', description: 'Quality records and documentation'),
            ],
          ),
          const TemplateNode(
            name: 'Project Controls',
            description: 'Project controls function',
            children: [
              (name: 'Schedule Management', description: 'Schedule development and control'),
              (name: 'Cost Management', description: 'Cost control and management'),
              (name: 'Reporting', description: 'Progress reporting and analytics'),
            ],
          ),
        ],

        // ============================================================
        // WATERFALL_GEOGRAPHIC — Section 4: Geographic Location WBS
        // ============================================================
        WBSFramework.waterfallGeographic: [
          const TemplateNode(
            name: 'East Region',
            description: 'Eastern region deployment',
            children: [
              (name: 'New York Site', description: 'New York site deployment'),
              (name: 'Boston Site', description: 'Boston site deployment'),
              (name: 'Philadelphia Site', description: 'Philadelphia site deployment'),
            ],
          ),
          const TemplateNode(
            name: 'Central Region',
            description: 'Central region deployment',
            children: [
              (name: 'Houston Site', description: 'Houston site deployment'),
              (name: 'Dallas Site', description: 'Dallas site deployment'),
              (name: 'Chicago Site', description: 'Chicago site deployment'),
            ],
          ),
          const TemplateNode(
            name: 'West Region',
            description: 'Western region deployment',
            children: [
              (name: 'Los Angeles Site', description: 'Los Angeles site deployment'),
              (name: 'Seattle Site', description: 'Seattle site deployment'),
              (name: 'Phoenix Site', description: 'Phoenix site deployment'),
            ],
          ),
        ],

        // ============================================================
        // WATERFALL_PHASE — Section 5: Phase-Based WBS (Least Preferred)
        // ============================================================
        WBSFramework.waterfallPhase: [
          const TemplateNode(
            name: 'Initiation',
            description: 'Project initiation phase',
            children: [
              (name: 'Business Case', description: 'Business case development'),
              (name: 'Project Charter', description: 'Project charter development'),
            ],
          ),
          const TemplateNode(
            name: 'Planning',
            description: 'Project planning phase',
            children: [
              (name: 'Scope Definition', description: 'Scope definition and WBS'),
              (name: 'Schedule Development', description: 'Schedule development'),
              (name: 'Risk Planning', description: 'Risk management planning'),
            ],
          ),
          const TemplateNode(
            name: 'Design',
            description: 'Design phase',
            children: [
              (name: 'System Design', description: 'System architecture and design'),
              (name: 'Interfaces', description: 'Interface design'),
              (name: 'Data Architecture', description: 'Data architecture and modeling'),
            ],
          ),
          const TemplateNode(
            name: 'Execution',
            description: 'Execution phase',
            children: [
              (name: 'Configuration', description: 'System configuration'),
              (name: 'Data Migration', description: 'Data migration and cutover'),
              (name: 'Integration', description: 'System integration'),
            ],
          ),
          const TemplateNode(
            name: 'Testing',
            description: 'Testing phase',
            children: [
              (name: 'System Testing', description: 'System testing'),
              (name: 'User Acceptance Testing', description: 'UAT'),
              (name: 'Defect Resolution', description: 'Defect resolution'),
            ],
          ),
          const TemplateNode(
            name: 'Closeout',
            description: 'Closeout phase',
            children: [
              (name: 'Training', description: 'End-user training'),
              (name: 'Documentation', description: 'Documentation handover'),
              (name: 'Project Handover', description: 'Project handover and sign-off'),
            ],
          ),
        ],
      };
}
