# Project Data Integration Guide

This guide explains how to integrate the new ProjectDataProvider system into screens across the application to enable data persistence and flow between screens.

## Quick Start

### 1. Import Required Files

```dart
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
```

### 2. Read Data on Screen Load

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final projectData = ProjectDataHelper.getData(context);
    
    // Populate your form fields with existing data
    _nameController.text = projectData.projectName;
    _solutionController.text = projectData.solutionTitle;
    // ... etc
    
    setState(() {});
  });
}
```

### 3. Save and Navigate on "Next" Button

```dart
void _handleNextButton() async {
  // Validate form if needed
  if (!_formKey.currentState!.validate()) {
    return;
  }
  
  // Save and navigate
  await ProjectDataHelper.saveAndNavigate(
    context: context,
    checkpoint: 'your_screen_checkpoint',  // e.g., 'planning_phase', 'wbs', etc.
    nextScreenBuilder: () => const NextScreen(),
    dataUpdater: (data) => data.copyWith(
      // Update the fields relevant to your screen
      projectName: _nameController.text.trim(),
      solutionTitle: _solutionController.text.trim(),
      // ... etc
    ),
  );
}
```

## Integration Examples by Screen Type

### Example 1: Simple Form Screen

```dart
class MyFormScreen extends StatefulWidget {
  const MyFormScreen({super.key});
  @override
  State<MyFormScreen> createState() => _MyFormScreenState();
}

class _MyFormScreenState extends State<MyFormScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final data = ProjectDataHelper.getData(context);
      _nameController.text = data.projectName;
      _descriptionController.text = data.solutionDescription;
      setState(() {});
    });
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _handleNext() async {
    await ProjectDataHelper.saveAndNavigate(
      context: context,
      checkpoint: 'my_screen',
      nextScreenBuilder: () => const NextScreen(),
      dataUpdater: (data) => data.copyWith(
        projectName: _nameController.text.trim(),
        solutionDescription: _descriptionController.text.trim(),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextField(controller: _nameController),
          TextField(controller: _descriptionController),
          ElevatedButton(
            onPressed: _handleNext,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}
```

### Example 2: Screen with Complex Data (Lists)

```dart
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<TextEditingController> _goalControllers = [];
  
  @override
  void initState() {
    super.initState();
    _goalControllers = List.generate(3, (_) => TextEditingController());
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final data = ProjectDataHelper.getData(context);
      
      // Populate from existing data
      for (int i = 0; i < data.planningGoals.length && i < 3; i++) {
        _goalControllers[i].text = data.planningGoals[i].title;
      }
      
      setState(() {});
    });
  }
  
  @override
  void dispose() {
    for (var c in _goalControllers) {
      c.dispose();
    }
    super.dispose();
  }
  
  Future<void> _handleNext() async {
    // Convert controllers to data model
    final goals = List.generate(3, (i) => PlanningGoal(
      goalNumber: i + 1,
      title: _goalControllers[i].text.trim(),
      description: '',
      targetYear: '',
    ));
    
    await ProjectDataHelper.saveAndNavigate(
      context: context,
      checkpoint: 'goals_screen',
      nextScreenBuilder: () => const NextScreen(),
      dataUpdater: (data) => data.copyWith(planningGoals: goals),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Build UI...
    return Container();
  }
}
```

### Example 3: Screen with Front End Planning Data

```dart
class FrontEndPlanningRequirementsScreen extends StatefulWidget {
  const FrontEndPlanningRequirementsScreen({super.key});
  @override
  State<FrontEndPlanningRequirementsScreen> createState() => _FrontEndPlanningRequirementsScreenState();
}

class _FrontEndPlanningRequirementsScreenState extends State<FrontEndPlanningRequirementsScreen> {
  final _requirementsController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final data = ProjectDataHelper.getData(context);
      _requirementsController.text = data.frontEndPlanning.requirements;
      setState(() {});
    });
  }
  
  @override
  void dispose() {
    _requirementsController.dispose();
    super.dispose();
  }
  
  Future<void> _handleNext() async {
    final provider = ProjectDataHelper.getProvider(context);
    final currentFEP = provider.projectData.frontEndPlanning;
    
    await ProjectDataHelper.saveAndNavigate(
      context: context,
      checkpoint: 'fep_requirements',
      nextScreenBuilder: () => const FrontEndPlanningRisksScreen(),
      dataUpdater: (data) => data.copyWith(
        frontEndPlanning: FrontEndPlanningData(
          requirements: _requirementsController.text.trim(),
          risks: currentFEP.risks,
          opportunities: currentFEP.opportunities,
          // ... preserve other fields
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Build UI...
    return Container();
  }
}
```

## Checkpoint Names Convention

Use these checkpoint names for consistency:
- `initiation` - Initiation Phase
- `project_framework` - Project Framework Screen
- `planning_phase` - Planning Phase (goals and milestones)
- `wbs` - Work Breakdown Structure
- `fep_requirements` - Front End Planning - Requirements
- `fep_risks` - Front End Planning - Risks
- `fep_opportunities` - Front End Planning - Opportunities
- `fep_contracts` - Front End Planning - Contract & Vendor Quotes
- `fep_procurement` - Front End Planning - Procurement
- `fep_security` - Front End Planning - Security
- `fep_allowance` - Front End Planning - Allowance
- `fep_summary` - Front End Planning - Summary
- `fep_technology` - Front End Planning - Technology
- `fep_personnel` - Front End Planning - Personnel
- `fep_infrastructure` - Front End Planning - Infrastructure
- `ssher` - SSHER Screen
- `team_management` - Team Management

## Available Data Fields

### ProjectDataModel Main Fields
- `projectName` (String)
- `solutionTitle` (String)
- `solutionDescription` (String)
- `businessCase` (String)
- `notes` (String)
- `tags` (List<String>)
- `overallFramework` (String?)
- `projectGoals` (List<ProjectGoal>)
- `potentialSolution` (String)
- `projectObjective` (String)
- `planningGoals` (List<PlanningGoal>)
- `keyMilestones` (List<Milestone>)
- `wbsCriteriaA` (String?)
- `wbsCriteriaB` (String?)
- `goalWorkItems` (List<List<WorkItem>>)
- `frontEndPlanning` (FrontEndPlanningData)
- `ssherData` (SSHERData)
- `teamMembers` (List<TeamMember>)

### FrontEndPlanningData Fields
- `requirements`
- `risks`
- `opportunities`
- `contractVendorQuotes`
- `procurement`
- `security`
- `allowance`
- `summary`
- `technology`
- `personnel`
- `infrastructure`
- `contracts`

## Helper Methods

### ProjectDataHelper Methods

```dart
// Get current project data
final data = ProjectDataHelper.getData(context);

// Get provider instance
final provider = ProjectDataHelper.getProvider(context);

// Save and navigate
await ProjectDataHelper.saveAndNavigate(
  context: context,
  checkpoint: 'screen_name',
  nextScreenBuilder: () => NextScreen(),
  dataUpdater: (data) => data.copyWith(...),
);

// Update and save without navigation
await ProjectDataHelper.updateAndSave(
  context: context,
  checkpoint: 'screen_name',
  dataUpdater: (data) => data.copyWith(...),
  showSnackbar: true,
);

// Show saving indicator
ProjectDataHelper.showSavingIndicator(context);
```

## Migration Tips

1. **Remove constructor parameters**: Screens no longer need to accept data via constructor. Remove parameters like `final List<Map<String, String>>? goals`.

2. **Update static open methods**: Change from passing data in navigator to reading from provider:
   ```dart
   // Before
   static void open(BuildContext context, {required String data}) {
     Navigator.push(context, MaterialPageRoute(
       builder: (_) => MyScreen(data: data),
     ));
   }
   
   // After
   static void open(BuildContext context) {
     Navigator.push(context, MaterialPageRoute(
       builder: (_) => const MyScreen(),
     ));
   }
   ```

3. **Load data in initState**: Always use `WidgetsBinding.instance.addPostFrameCallback` to ensure context is available.

4. **Preserve existing data**: When updating nested objects like `FrontEndPlanningData`, make sure to preserve fields you're not modifying.

5. **Validate before saving**: Check form validation before calling `saveAndNavigate`.

## Testing Checklist

After integrating a screen:
- [ ] Data from previous screen appears correctly
- [ ] Filling out the form and clicking Next saves data
- [ ] Navigating back shows the same data
- [ ] Data persists after hot reload
- [ ] Firebase shows updated data (check Firestore console)
- [ ] Error handling works (disconnect internet and try saving)

## Common Pitfalls

1. **Not using addPostFrameCallback**: Accessing context in initState without the callback will fail.
2. **Forgetting to preserve data**: When updating one field, other fields might get reset if not explicitly preserved.
3. **Not disposing controllers**: Always dispose TextEditingControllers in the dispose method.
4. **Missing await**: Always await the `saveAndNavigate` or `updateAndSave` calls.
5. **Wrong checkpoint name**: Use consistent checkpoint names across the app.

## Support

For questions or issues with integration, refer to:
- `lib/models/project_data_model.dart` - Data structure definitions
- `lib/providers/project_data_provider.dart` - Provider implementation
- `lib/utils/project_data_helper.dart` - Helper methods
- `architecture.md` - Overall architecture documentation
