# NDU Project - Application Architecture

## Overview
The NDU Project is a comprehensive project management application built with Flutter that guides users through various phases of project planning and execution.

## State Management Architecture

### Project Data Flow System
The application now uses a centralized state management system to persist and flow data across all screens.

#### Core Components:

1. **ProjectDataModel** (`lib/models/project_data_model.dart`)
   - Comprehensive data model capturing all information across the application
   - Includes: Initiation data, Project Framework, Planning Phase, WBS, Front End Planning, SSHER, Team Management
   - Provides JSON serialization for Firebase persistence

2. **ProjectDataProvider** (`lib/providers/project_data_provider.dart`)
   - ChangeNotifier-based state management
   - Handles all data updates and Firebase synchronization
   - Provides methods for updating specific sections (initiation, framework, planning, etc.)
   - Auto-saves to Firebase when navigating between screens

3. **ProjectDataInherited** (`lib/providers/project_data_provider.dart`)
   - InheritedNotifier widget wrapping the entire app
   - Provides access to ProjectDataProvider from any screen
   - Integrated at app root in `main.dart`

### Usage Pattern in Screens:

```dart
// Access the provider
final provider = ProjectDataInherited.of(context);

// Read current data
final projectData = provider.projectData;

// Update data
provider.updatePlanningData(
  potentialSolution: 'New solution',
  projectObjective: 'New objective',
);

// Save to Firebase (automatic on navigation)
await provider.saveToFirebase(checkpoint: 'planning_phase');
```

### Navigation Flow with Data Persistence:

1. User fills out form on Screen A
2. User clicks "Next"
3. Screen A updates provider with form data
4. Screen A saves to Firebase with current checkpoint
5. Screen A navigates to Screen B
6. Screen B reads data from provider and pre-populates fields
7. Repeat for subsequent screens

### Key Screens Integration:

- **Initiation Phase**: Updates project name, solution, business case
- **Project Framework**: Updates overall framework and project goals
- **Planning Phase**: Updates planning goals and milestones
- **Work Breakdown Structure**: Updates WBS criteria and work items
- **Front End Planning**: Updates all FEP sections (requirements, risks, opportunities, etc.)
- **SSHER**: Updates safety data
- **Team Management**: Updates team member information

### Firebase Schema:

Projects are stored in the `projects` collection with the following structure:
- All ProjectDataModel fields (flattened JSON)
- `ownerId`: User ID from Firebase Auth
- `ownerName`, `ownerEmail`: User metadata
- `checkpointRoute`: Current screen/phase
- `checkpointAt`: Timestamp of last checkpoint
- `createdAt`, `updatedAt`: Timestamps

### Benefits:

1. **Data Persistence**: All user input is preserved when navigating between screens
2. **Resume Capability**: Users can leave and return to their project at any checkpoint
3. **Auto-save**: Data automatically saves when moving between sections
4. **Consistency**: Single source of truth for all project data
5. **Scalability**: Easy to add new fields or sections

## Application Phases

### 1. Initiation Phase
- Project name and solution identification
- Business case development
- Initial stakeholder identification

### 2. Project Framework
- Selection of management framework (Waterfall/Agile/Hybrid)
- Definition of project goals
- Framework assignment to goals

### 3. Planning Phase
- Detailed goal breakdown
- Milestone definition
- Target completion dates

### 4. Work Breakdown Structure
- Decomposition criteria selection
- Work package definition
- Task assignment

### 5. Front End Planning
Multiple sub-sections:
- Project Requirements
- Project Risks
- Project Opportunities
- Contract & Vendor Quotes
- Procurement
- Security
- Allowance
- Summary
- Technology
- Personnel
- Infrastructure
- Contracts

### 6. SSHER (Safety, Health, Environment, Risk)
- Safety item tracking
- Risk assessment
- Compliance management

### 7. Team Management
- Role definition
- Responsibility assignment
- Team structure

## Key Technical Details

- **Framework**: Flutter 3.x
- **Backend**: Firebase (Firestore, Auth)
- **State Management**: InheritedNotifier + ChangeNotifier
- **Authentication**: Firebase Authentication with Google Sign-In
- **Cross-platform**: Web, iOS, Android support
