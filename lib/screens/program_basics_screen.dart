import 'package:flutter/material.dart';
import 'package:ndu_project/screens/front_end_planning_procurement_screen.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/bullet_point_editor.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
const Color _kAccentColor = Color(0xFFFFC812);
const Color _kTextPrimary = Color(0xFF1A1D1F);
const Color _kTextSecondary = Color(0xFF6B7280);
const Color _kSurfaceBorder = Color(0xFFE4E7EC);

/// Program basics workspace mirroring provided design.
class ProgramBasicsScreen extends StatelessWidget {
 const ProgramBasicsScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const ProgramBasicsScreen()),
 );
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 // Use a white page background per spec
 backgroundColor: Colors.white,
 body: Stack(
 children: [
 SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(
 showHeader: true,
 activeItemLabel: 'Initiation Phase',
 ),
 ),
 const Expanded(child: _ProgramBasicsContent()),
 ],
 ),
 ),
 const KazAiChatBubble(),
 const AdminEditToggle(),
 ],
 ),
 );
 }
}

class _ProgramBasicsContent extends StatelessWidget {
 const _ProgramBasicsContent();

 @override
 Widget build(BuildContext context) => const _ProgramBasicsContentStateful();
}

class _ProgramBasicsContentStateful extends StatefulWidget {
 const _ProgramBasicsContentStateful();

 @override
 State<_ProgramBasicsContentStateful> createState() =>
 _ProgramBasicsContentState();
}

class _ProgramBasicsContentState extends State<_ProgramBasicsContentStateful> {
 bool _shownAiHint = false;

 String _displayName() =>
 FirebaseAuthService.displayNameOrEmail(fallback: 'User');

 @override
 void didChangeDependencies() {
 super.didChangeDependencies();
 // Show the hint once when the page is first displayed
 if (!_shownAiHint) {
 _shownAiHint = true;
 WidgetsBinding.instance.addPostFrameCallback((_) {
 _showAiHintDialog(context);
 });
 }
 }

 @override
 Widget build(BuildContext context) {
 return Container(
 // Match requested white background for the content area
 color: Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
 child: LayoutBuilder(
 builder: (context, constraints) {
 return SingleChildScrollView(
 child: ConstrainedBox(
 constraints: BoxConstraints(minHeight: constraints.maxHeight),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 _StepProgressIndicator(),
 SizedBox(height: 12),
 Text(
 'Step 1/5',
 style: TextStyle(
 color: _kTextSecondary,
 fontSize: 13,
 fontWeight: FontWeight.w600,
 ),
 ),
 SizedBox(height: 10),
 Text(
 'Project Basics',
 style: TextStyle(
 color: _kTextPrimary,
 fontSize: 30,
 fontWeight: FontWeight.w700,
 letterSpacing: -0.2,
 ),
 ),
 SizedBox(height: 6),
 Text(
 'Give your project a name and define its purpose.',
 style: TextStyle(
 color: _kTextSecondary,
 fontSize: 15,
 fontWeight: FontWeight.w500,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 20),
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 18, vertical: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(26),
 border: Border.all(color: _kSurfaceBorder),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 18,
 offset: const Offset(0, 12),
 ),
 ],
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CircleAvatar(
 radius: 24,
 backgroundColor: _kSurfaceBorder,
 child: Text(
 _displayName().trim().isNotEmpty
 ? _displayName()
 .trim()
 .substring(0, 1)
 .toUpperCase()
 : 'U',
 style: const TextStyle(
 color: _kTextPrimary,
 fontWeight: FontWeight.w700,
 fontSize: 18,
 ),
 ),
 ),
 const SizedBox(width: 12),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 _displayName(),
 style: TextStyle(
 color: _kTextPrimary,
 fontSize: 15,
 fontWeight: FontWeight.w700,
 ),
 ),
 SizedBox(height: 2),
 Text(
 'Owner',
 style: TextStyle(
 color: _kTextSecondary,
 fontSize: 12,
 fontWeight: FontWeight.w500,
 ),
 ),
 ],
 ),
 // Remove dropdown chevron from header identity chip
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 36),
 const _InputGroup(
 label: 'Project Name',
 hint: 'e.g., Marketing Strategy 2025',
 ),
 const SizedBox(height: 24),
 const _InputGroup(
 label: 'Project Objective',
 hint:
 'Describe your project\'s purpose and goals (e.g Launch an AI-powered chatbot for customer support)',
 maxLines: 6,
 ),
 const SizedBox(height: 42),
 Row(
 mainAxisAlignment: MainAxisAlignment.end,
 children: const [
 _CircularNavButton(
 icon: Icons.arrow_back_ios_new_rounded,
 background: Colors.white,
 borderColor: _kSurfaceBorder,
 iconColor: _kTextSecondary,
 ),
 ],
 ),
 ],
 ),
 ),
 );
 },
 ),
 );
 }
}

class _StepProgressIndicator extends StatelessWidget {
 const _StepProgressIndicator();

 @override
 Widget build(BuildContext context) {
 return Row(
 children: const [
 Expanded(child: _StepSegment(color: _kAccentColor)),
 SizedBox(width: 10),
 Expanded(child: _StepSegment(color: Color(0xFFE5E7EB))),
 SizedBox(width: 10),
 Expanded(child: _StepSegment(color: Color(0xFFE5E7EB))),
 SizedBox(width: 10),
 Expanded(child: _StepSegment(color: Color(0xFFE5E7EB))),
 SizedBox(width: 10),
 Expanded(child: _StepSegment(color: Color(0xFFE5E7EB))),
 ],
 );
 }
}

class _StepSegment extends StatelessWidget {
 const _StepSegment({required this.color});

 final Color color;

 @override
 Widget build(BuildContext context) {
 return Container(
 height: 8,
 decoration: BoxDecoration(
 color: color,
 borderRadius: BorderRadius.circular(999),
 ),
 );
 }
}

class _InputGroup extends StatelessWidget {
 const _InputGroup({
 required this.label,
 required this.hint,
 this.maxLines = 1,
 });

 final String label;
 final String hint;
 final int maxLines;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: const TextStyle(
 color: _kTextPrimary,
 fontSize: 15,
 fontWeight: FontWeight.w700,
 ),
 ),
 const SizedBox(height: 10),
 VoiceTextField(
 maxLines: maxLines,
 decoration: InputDecoration(
 hintText: hint,
 hintStyle: const TextStyle(
 color: _kTextSecondary,
 fontSize: 14,
 fontWeight: FontWeight.w500,
 ),
 filled: true,
 fillColor: const Color(0xFFF1F4F9),
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(18),
 borderSide: const BorderSide(color: _kSurfaceBorder),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(18),
 borderSide: const BorderSide(color: _kAccentColor, width: 1.6),
 ),
 ),
 ),
 ],
 );
 }
}

class _CircularNavButton extends StatelessWidget {
 const _CircularNavButton({
 required this.icon,
 required this.background,
 required this.borderColor,
 required this.iconColor,
 // ignore: unused_element_parameter
 this.onTap,
 });

 final IconData icon;
 final Color background;
 final Color borderColor;
 final Color iconColor;
 final VoidCallback? onTap;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: 48,
 height: 48,
 decoration: BoxDecoration(
 color: background,
 shape: BoxShape.circle,
 border: Border.all(color: borderColor),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.05),
 blurRadius: 12,
 offset: const Offset(0, 6),
 ),
 ],
 ),
 child: Icon(icon, color: iconColor, size: 18),
 );
 }
}

/// Project details step mirroring provided design.
class ProjectDetailsScreen extends StatelessWidget {
 const ProjectDetailsScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const ProjectDetailsScreen()),
 );
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 // Use white background for the follow-on step as well
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(
 showHeader: true,
 activeItemLabel: 'Initiation Phase',
 ),
 ),
 const Expanded(child: _ProjectDetailsContent()),
 ],
 ),
 ),
 );
 }
}

class _ProjectDetailsContent extends StatefulWidget {
 const _ProjectDetailsContent();

 @override
 State<_ProjectDetailsContent> createState() => _ProjectDetailsContentState();
}

class _ProjectDetailsContentState extends State<_ProjectDetailsContent> {
 bool _shownAiHint = false;

 @override
 void didChangeDependencies() {
 super.didChangeDependencies();
 if (!_shownAiHint) {
 _shownAiHint = true;
 WidgetsBinding.instance.addPostFrameCallback((_) {
 _showAiHintDialog(context);
 });
 }
 }

 @override
 Widget build(BuildContext context) {
 return Container(
 // White content background per request
 color: Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
 child: LayoutBuilder(
 builder: (context, constraints) {
 final provider = ProjectDataHelper.getProvider(context);
 final data = provider.projectData;
 return SingleChildScrollView(
 child: ConstrainedBox(
 constraints: BoxConstraints(minHeight: constraints.maxHeight),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const _FrameworkHeader(),
 const SizedBox(height: 28),
 _NotesInput(
 initialValue: data.notes,
 onChanged: (val) {
 provider.updateInitiationData(notes: val);
 provider.saveToFirebase(
 checkpoint: 'project_details_notes');
 },
 ),
 const SizedBox(height: 28),
 BulletPointEditor(
 title: 'Assumptions',
 subtitle: 'Key assumptions for the project charter.',
 items: data.assumptions,
 onChanged: (val) {
 provider.updateField((d) => d.copyWith(assumptions: val));
 provider.saveToFirebase(
 checkpoint: 'project_details_assumptions');
 },
 ),
 const SizedBox(height: 24),
 BulletPointEditor(
 title: 'Constraints',
 subtitle: 'Limitations and constraints.',
 items: data.constraints,
 onChanged: (val) {
 provider.updateField((d) => d.copyWith(constraints: val));
 provider.saveToFirebase(
 checkpoint: 'project_details_constraints');
 },
 ),
 const SizedBox(height: 24),
 BulletPointEditor(
 title: 'Out of Scope',
 subtitle: 'What is explicitly excluded.',
 items: data.outOfScope,
 onChanged: (val) {
 provider.updateField((d) => d.copyWith(outOfScope: val));
 provider.saveToFirebase(
 checkpoint: 'project_details_outofscope');
 },
 ),
 const SizedBox(height: 28),
 const _FrameworkDetailCard(),
 const SizedBox(height: 32),
 const _NextButton(),
 ],
 ),
 ),
 );
 },
 ),
 );
 }
}

void _showAiHintDialog(BuildContext context) {
 showDialog(
 context: context,
 barrierDismissible: true,
 builder: (ctx) {
 return Center(
 child: Dialog(
 backgroundColor: Colors.white,
 insetPadding:
 const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 child: Padding(
 padding: const EdgeInsets.all(24.0),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.center,
 children: const [
 Icon(Icons.lightbulb_outline, color: _kAccentColor, size: 36),
 SizedBox(height: 12),
 Text(
 'Although KAZ AI-generated outputs can provide valuable insights, please review and refine them as needed to ensure they align with your project requirements.',
 textAlign: TextAlign.center,
 style: TextStyle(
 color: _kTextPrimary,
 fontSize: 15,
 fontWeight: FontWeight.w600,
 height: 1.4,
 ),
 ),
 SizedBox(height: 16),
 ],
 ),
 ),
 ),
 );
 },
 );
}

class _FrameworkHeader extends StatelessWidget {
 const _FrameworkHeader();

 @override
 Widget build(BuildContext context) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 Text(
 'Project Details',
 style: TextStyle(
 color: _kTextPrimary,
 fontSize: 30,
 fontWeight: FontWeight.w700,
 letterSpacing: -0.2,
 ),
 ),
 SizedBox(height: 8),
 Text(
 'Select a framework for the overall project and individual goals.',
 style: TextStyle(
 color: _kTextSecondary,
 fontSize: 15,
 fontWeight: FontWeight.w500,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 24),
 const _ProfileSummaryCard(),
 ],
 );
 }
}

class _ProfileSummaryCard extends StatelessWidget {
 const _ProfileSummaryCard();

 @override
 Widget build(BuildContext context) {
 final name = FirebaseAuthService.displayNameOrEmail(fallback: 'User');
 final initial = name.trim().isNotEmpty
 ? name.trim().substring(0, 1).toUpperCase()
 : 'U';
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(26),
 border: Border.all(color: _kSurfaceBorder),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 18,
 offset: const Offset(0, 12),
 ),
 ],
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CircleAvatar(
 radius: 24,
 backgroundColor: _kSurfaceBorder,
 child: Text(
 initial,
 style: const TextStyle(
 color: _kTextPrimary,
 fontWeight: FontWeight.w700,
 fontSize: 18,
 ),
 ),
 ),
 const SizedBox(width: 12),
 const _ProfileSummaryText(),
 // Removed dropdown chevron per request
 ],
 ),
 );
 }
}

class _ProfileSummaryText extends StatelessWidget {
 const _ProfileSummaryText();

 @override
 Widget build(BuildContext context) {
 final name = FirebaseAuthService.displayNameOrEmail(fallback: 'User');
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 name,
 style: const TextStyle(
 color: _kTextPrimary,
 fontSize: 15,
 fontWeight: FontWeight.w700,
 ),
 ),
 const SizedBox(height: 2),
 const Text(
 'Owner',
 style: TextStyle(
 color: _kTextSecondary,
 fontSize: 12,
 fontWeight: FontWeight.w500,
 ),
 ),
 ],
 );
 }
}

class _NotesInput extends StatelessWidget {
 const _NotesInput({this.initialValue = '', this.onChanged});

 final String initialValue;
 final ValueChanged<String>? onChanged;

 @override
 Widget build(BuildContext context) {
 return VoiceTextFormField(
 initialValue: initialValue,
 onChanged: onChanged,
 // Allow the Notes field to grow with content with no character/line cap
 minLines: 5,
 maxLines: null,
 decoration: InputDecoration(
 hintText: 'Input your notes here...',
 hintStyle: const TextStyle(
 color: _kTextSecondary,
 fontSize: 14,
 fontWeight: FontWeight.w500,
 ),
 filled: true,
 fillColor: Colors.white,
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(22),
 borderSide: const BorderSide(color: _kSurfaceBorder),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(22),
 borderSide: const BorderSide(color: _kAccentColor, width: 1.6),
 ),
 ),
 );
 }
}

class _FrameworkDetailCard extends StatelessWidget {
 const _FrameworkDetailCard();

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(28),
 border: Border.all(color: _kSurfaceBorder),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.03),
 blurRadius: 26,
 offset: const Offset(0, 14),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 Expanded(child: _FrameworkCardHeaderText()),
 SizedBox(width: 24),
 _AddGoalButton(),
 ],
 ),
 const SizedBox(height: 28),
 const Text(
 'Overall Project Framework',
 style: TextStyle(
 color: _kTextPrimary,
 fontSize: 16,
 fontWeight: FontWeight.w700,
 ),
 ),
 const SizedBox(height: 16),
 const _FrameworkDropdown(text: 'Select a Framework'),
 const SizedBox(height: 12),
 const Text(
 "If 'Waterfall' or 'Agile' is chosen, all goals below will inherit this framework. If 'Hybrid' is chosen, you can set a framework for each goal individually .",
 style: TextStyle(
 color: _kTextSecondary,
 fontSize: 13,
 fontWeight: FontWeight.w500,
 ),
 ),
 const SizedBox(height: 30),
 const Text(
 'Project Goals',
 style: TextStyle(
 color: _kTextPrimary,
 fontSize: 16,
 fontWeight: FontWeight.w700,
 ),
 ),
 const SizedBox(height: 18),
 const _GoalRow(),
 ],
 ),
 );
 }
}

class _FrameworkCardHeaderText extends StatelessWidget {
 const _FrameworkCardHeaderText();

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 Text(
 'Project Details',
 style: TextStyle(
 color: _kTextPrimary,
 fontSize: 22,
 fontWeight: FontWeight.w700,
 ),
 ),
 SizedBox(height: 6),
 Text(
 'Select a framework for the overall project and individual goals .',
 style: TextStyle(
 color: _kTextSecondary,
 fontSize: 14,
 fontWeight: FontWeight.w500,
 ),
 ),
 ],
 );
 }
}

class _AddGoalButton extends StatelessWidget {
 const _AddGoalButton();

 @override
 Widget build(BuildContext context) {
 return ElevatedButton(
 onPressed: () {},
 style: ElevatedButton.styleFrom(
 elevation: 0,
 backgroundColor: const Color(0xFFFFA552),
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
 padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
 textStyle: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 ),
 ),
 child: const Text('Add Goal'),
 );
 }
}

class _FrameworkDropdown extends StatelessWidget {
 const _FrameworkDropdown({required this.text});

 final String text;

 @override
 Widget build(BuildContext context) {
 return Container(
 height: 54,
 padding: const EdgeInsets.symmetric(horizontal: 20),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: _kSurfaceBorder),
 ),
 child: Row(
 children: [
 Expanded(
 child: Text(
 text,
 style: const TextStyle(
 color: _kTextSecondary,
 fontSize: 14,
 fontWeight: FontWeight.w500,
 ),
 ),
 ),
 const Icon(Icons.keyboard_arrow_down_rounded, color: _kTextSecondary),
 ],
 ),
 );
 }
}

class _GoalRow extends StatelessWidget {
 const _GoalRow();

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(22),
 border: Border.all(color: _kSurfaceBorder),
 ),
 child: Row(
 children: [
 Expanded(
 child: Text(
 'Goal 1',
 style: TextStyle(
 color: _kTextSecondary,
 fontSize: 14,
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 SizedBox(width: 20),
 SizedBox(
 width: 190,
 child: _FrameworkDropdown(text: 'Select Framework'),
 ),
 ],
 ),
 );
 }
}

class _NextButton extends StatelessWidget {
 const _NextButton();

 @override
 Widget build(BuildContext context) {
 return Align(
 alignment: Alignment.centerRight,
 child: ElevatedButton(
 onPressed: () => FrontEndPlanningProcurementScreen.open(context),
 style: ElevatedButton.styleFrom(
 elevation: 8,
 backgroundColor: _kAccentColor,
 foregroundColor: _kTextPrimary,
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
 padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 18),
 textStyle: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 ),
 ),
 child: const Text('Next'),
 ),
 );
 }
}
