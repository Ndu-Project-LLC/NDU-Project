import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/user_model.dart';
import 'package:ndu_project/services/charter_approval_service.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/utils/charter_lock_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/charter_tech_proc_helper.dart';
import 'package:ndu_project/widgets/expandable_text.dart';
import 'package:ndu_project/widgets/page_regenerate_all_button.dart';
import 'package:ndu_project/providers/project_data_provider.dart';

// ─── Brand Color Tokens ───
class BrandColors {
 static const background = Color(0xFFF7F9FB);
 static const primary = Color(0xFFFFC812);
 static const primaryContainer = Color(0xFF0073DF);
 static const onPrimary = Color(0xFFFFFFFF);
 static const onPrimaryContainer = Color(0xFFFEFCFF);
 static const surface = Color(0xFFF7F9FB);
 static const surfaceContainerLowest = Color(0xFFFFFFFF);
 static const surfaceContainer = Color(0xFFECEEF0);
 static const inverseSurface = Color(0xFF2D3133);
 static const onSurface = Color(0xFF191C1E);
 static const onSurfaceVariant = Color(0xFF414754);
 static const outline = Color(0xFF717786);
 static const outlineVariant = Color(0xFFC0C6D6);
 static const error = Color(0xFFBA1A1A);
 static const tertiaryFixedDim = Color(0xFFFABD00);
 static const tertiary = Color(0xFF755700);
 static const secondaryContainer = Color(0xFFE2DFDE);
 static const secondary = Color(0xFF5F5E5E);
 static const primaryFixed = Color(0xFFD6E3FF);
 static const onPrimaryFixedVariant = Color(0xFF00468C);
 static const tertiaryFixed = Color(0xFFFFDF9E);
 static const onTertiaryFixedVariant = Color(0xFF5B4300);
 static const errorContainer = Color(0xFFFFDAD6);
 static const onErrorContainer = Color(0xFF93000A);
 static const onTertiary = Color(0xFFFFFFFF);
 static const onError = Color(0xFFFFFFFF);
}

// ─── Shared Styles (backward compatibility) ───
const kSectionTitleStyle = TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 letterSpacing: 0.5,
);

const kCardDecoration = BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.all(Radius.circular(12)),
 boxShadow: [
 BoxShadow(
 color: Color.fromRGBO(0, 0, 0, 0.05),
 offset: Offset(0, 2),
 blurRadius: 4,
 )
 ],
);

const kCardBorderDecoration = BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.all(Radius.circular(12)),
 border: Border.fromBorderSide(
 BorderSide(color: BrandColors.outlineVariant, width: 1),
 ),
 boxShadow: [
 BoxShadow(
 color: Color.fromRGBO(0, 0, 0, 0.04),
 offset: Offset(0, 1),
 blurRadius: 3,
 )
 ],
);

Widget sectionTitleWithIcon(IconData icon, String title) {
 return Row(
 children: [
 Icon(icon, size: 20, color: BrandColors.primary),
 const SizedBox(width: 8),
 Text(
 title,
 style: const TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w600,
 color: BrandColors.onSurface,
 ),
 ),
 ],
 );
}

Widget labelStyle(String text) {
 return Text(
 text.toUpperCase(),
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: BrandColors.onSurfaceVariant,
 letterSpacing: 0.8,
 ),
 );
}

// ─── 1. Hero Header ───

class CharterHeroHeader extends StatelessWidget {
 final ProjectDataModel? data;
 final VoidCallback? onRegenerateAll;
 final bool isLoading;

 const CharterHeroHeader({
 super.key,
 required this.data,
 this.onRegenerateAll,
 this.isLoading = false,
 });

 @override
 Widget build(BuildContext context) {
 final projectName = data?.projectName.isNotEmpty == true
 ? data!.projectName
 : 'Untitled Project';

 // When the charter is approved, the FEP is locked — all
 // regeneration / editing affordances disappear from the charter
 // surface so the approved snapshot is preserved.
 final isLocked = CharterLockHelper.isFepLocked(data);

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Top row: Label + Export PDF + AI Assist + Regenerate button
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 const Text(
 'PROJECT CHARTER',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: BrandColors.primary,
 letterSpacing: 1.2,
 ),
 ),
 Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 if (onRegenerateAll != null && !isLocked) ...[
 const SizedBox(width: 8),
 PageRegenerateAllButton(
 onRegenerateAll: onRegenerateAll!,
 isLoading: isLoading,
 tooltip: 'Regenerate all charter content',
 ),
 ],
 ],
 ),
 ],
 ),
 const SizedBox(height: 8),
 // Project name + Active badge
 Row(
 children: [
 Expanded(
 child: Text(
 projectName,
 style: const TextStyle(
 fontSize: 28,
 fontWeight: FontWeight.w700,
 color: BrandColors.onSurface,
 height: 1.2,
 ),
 ),
 ),
 const SizedBox(width: 12),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
 decoration: BoxDecoration(
 color: BrandColors.primaryContainer.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(20),
 ),
 child: const Text(
 'Active',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: BrandColors.primary,
 ),
 ),
 ),
 ],
 ),
 ],
 );
 }
}

// ─── 2. Dashboard Stats Grid ───

class CharterDashboardStats extends StatelessWidget {
 final ProjectDataModel? data;

 const CharterDashboardStats({super.key, required this.data});

 @override
 Widget build(BuildContext context) {
 if (data == null) return const SizedBox();

 final totalCost = _calculateTotalCost(data!);
 final opportunities = _countOpportunities(data!);
 final duration = _calculateDuration(data!);
 final riskLevel = _calculateRiskLevel(data!);
 final projectManager = _determineProjectManager(data!);

 final screenWidth = MediaQuery.sizeOf(context).width;
 final isMobile = screenWidth < 768;
 final mobileItemWidth = (screenWidth - 96) / 2;

 return Container(
 padding: EdgeInsets.symmetric(
 vertical: 24,
 horizontal: isMobile ? 16 : 32,
 ),
 decoration: BoxDecoration(
 color: BrandColors.inverseSurface,
 borderRadius: BorderRadius.circular(12),
 boxShadow: const [
 BoxShadow(
 color: Color.fromRGBO(0, 0, 0, 0.15),
 offset: Offset(0, 4),
 blurRadius: 12,
 )
 ],
 ),
 child: Wrap(
 spacing: isMobile ? 12 : 0,
 runSpacing: isMobile ? 16 : 0,
 alignment: isMobile ? WrapAlignment.start : WrapAlignment.spaceBetween,
 children: [
 _buildStatItem('TOTAL COST', totalCost, Colors.white, isMobile, mobileWidth: mobileItemWidth),
 if (!isMobile) _buildDivider(),
 _buildStatItem('OPPORTUNITIES', opportunities, const Color(0xFF4ADE80),
 isMobile, mobileWidth: mobileItemWidth),
 if (!isMobile) _buildDivider(),
 _buildStatItem('DURATION', duration, const Color(0xFFFFC812), isMobile, mobileWidth: mobileItemWidth),
 if (!isMobile) _buildDivider(),
 _buildStatItem(
 'RISK',
 riskLevel,
 riskLevel.toLowerCase() == 'high'
 ? const Color(0xFFF87171)
 : riskLevel.toLowerCase() == 'medium'
 ? BrandColors.tertiaryFixedDim
 : const Color(0xFF4ADE80),
 isMobile, mobileWidth: mobileItemWidth),
 if (!isMobile) _buildDivider(),
 _buildStatItem('PROJECT MANAGER', projectManager,
 const Color(0xFFFBBF24), isMobile, mobileWidth: mobileItemWidth),
 ],
 ),
 );
 }

 Widget _buildStatItem(
 String label, String value, Color valueColor, bool isMobile, {double? mobileWidth}) {
 return SizedBox(
 width: isMobile && mobileWidth != null ? mobileWidth : null,
 child: Column(
 crossAxisAlignment: isMobile
 ? CrossAxisAlignment.start
 : CrossAxisAlignment.center,
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 label,
 textAlign: isMobile ? TextAlign.left : TextAlign.center,
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.6),
 fontSize: 11,
 fontWeight: FontWeight.w600,
 letterSpacing: 1.0,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 value,
 textAlign: isMobile ? TextAlign.left : TextAlign.center,
 style: TextStyle(
 color: valueColor,
 fontSize: 16,
 fontWeight: FontWeight.bold,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ],
 ),
 );
 }

 Widget _buildDivider() {
 return Container(
 height: 40,
 width: 1,
 color: Colors.white.withValues(alpha: 0.2),
 );
 }

 String _calculateTotalCost(ProjectDataModel data) {
 final total = ProjectDataHelper.getTotalEstimatedCostValue(data);
 return NumberFormat.simpleCurrency(name: data.costBenefitCurrency)
 .format(total);
 }

 String _countOpportunities(ProjectDataModel data) {
 return ProjectDataHelper.getExpectedOpportunitiesCount(data).toString();
 }

 String _calculateDuration(ProjectDataModel data) {
 if (data.keyMilestones.isEmpty) return 'TBD';
 DateTime? start;
 DateTime? end;
 for (var m in data.keyMilestones) {
 final date = DateTime.tryParse(m.dueDate);
 if (date != null) {
 if (start == null || date.isBefore(start)) start = date;
 if (end == null || date.isAfter(end)) end = date;
 }
 }
 if (start != null && end != null) {
 final days = end.difference(start).inDays;
 return '${days < 0 ? 0 : days} Days';
 }
 return 'TBD';
 }

 String _calculateRiskLevel(ProjectDataModel data) {
 final register = data.frontEndPlanning.riskRegisterItems;
 if (register.isNotEmpty) {
 if (register.any((r) => r.impactLevel.toLowerCase() == 'high')) {
 return 'High';
 }
 if (register.any((r) => r.impactLevel.toLowerCase() == 'medium')) {
 return 'Medium';
 }
 return 'Low';
 }
 if (data.solutionRisks.isNotEmpty) return 'Medium';
 return 'Low';
 }

 String _determineProjectManager(ProjectDataModel data) {
 if (data.charterProjectManagerName.isNotEmpty) {
 return data.charterProjectManagerName;
 }
 if (data.charterProjectSponsorName.isNotEmpty) {
 return data.charterProjectSponsorName;
 }
 return 'Not Assigned';
 }
}

// ─── 3. Meta Info Horizontal Scroll ───

class CharterMetaInfoScroll extends StatefulWidget {
 final ProjectDataModel? data;

 const CharterMetaInfoScroll({super.key, required this.data});

 @override
 State<CharterMetaInfoScroll> createState() => _CharterMetaInfoScrollState();
}

class _CharterMetaInfoScrollState extends State<CharterMetaInfoScroll> {
 @override
 Widget build(BuildContext context) {
 if (widget.data == null) return const SizedBox();

 final data = widget.data!;
 final hasManager = data.charterProjectManagerName.isNotEmpty;
 final hasSponsor = data.charterProjectSponsorName.isNotEmpty;
 // Charter is read-only once approved — the "Assign Manager"
 // affordance disappears so the approved baseline is preserved.
 final isLocked = CharterLockHelper.isFepLocked(data);

 final items = [
 _MetaInfoItem(
 icon: Icons.person_outline,
 label: 'Project Manager',
 value: hasManager
 ? data.charterProjectManagerName
 : 'Assign Manager',
 iconBgColor: BrandColors.secondaryContainer,
 iconFgColor: const Color(0xFF636262),
 onTap: (hasManager || isLocked)
 ? null
 : () => _showAssignManagerDialog(data),
 ),
 // Sponsor card — system suggests the highest role-based authority
 // (admin, then active user, then signed-in user) as the sponsor.
 // The user can also invite an external sponsor via the team
 // invitation flow (sends an email).
 _MetaInfoItem(
 icon: Icons.workspace_premium_outlined,
 label: 'Project Sponsor',
 value: hasSponsor
 ? data.charterProjectSponsorName
 : 'Assign Sponsor',
 iconBgColor: const Color(0xFFFEF3C7),
 iconFgColor: const Color(0xFFB45309),
 onTap: () => _showAssignSponsorDialog(data),
 ),
 _MetaInfoItem(
 icon: Icons.calendar_today_outlined,
 label: 'Start Date',
 value: _formatDate(data.createdAt),
 iconBgColor: BrandColors.tertiaryFixed,
 iconFgColor: BrandColors.onTertiaryFixedVariant,
 ),
 ];

 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: Row(
 children: items.map((item) {
 return Padding(
 padding: const EdgeInsets.only(right: 12),
 child: _MetaInfoCard(item: item),
 );
 }).toList(),
 ),
 );
 }

 String _formatDate(DateTime? date) {
 if (date == null) return 'Not Provided';
 return DateFormat('MMM d, yyyy').format(date);
 }

 Future<void> _showAssignSponsorDialog(ProjectDataModel data) async {
 final nameController = TextEditingController(
 text: data.charterProjectSponsorName,
 );
 final emailController = TextEditingController(
 text: data.charterEmail,
 );
 final formKey = GlobalKey<FormState>();
 ResolvedApprover? suggested;
 List<UserModel> allUsers = const [];
 bool loadingSuggestion = true;
 bool inviting = false;

 // Load users and compute the suggested sponsor in the background.
 Future<void> loadSuggestion = () async {
   try {
     final snap = await FirebaseFirestore.instance
         .collection('users')
         .limit(200)
         .get();
     allUsers =
         snap.docs.map((d) => UserModel.fromJson(d.data())).toList();
     suggested =
         CharterApprovalService.suggestSponsor(allUsers: allUsers);
   } catch (e) {
     debugPrint('Sponsor suggestion load failed: $e');
     suggested = null;
   }
   loadingSuggestion = false;
 }();

 final result = await showDialog<Map<String, String>>(
 context: context,
 builder: (dialogContext) {
   return StatefulBuilder(
     builder: (dialogContext, setDialogState) {
       return AlertDialog(
         shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(20)),
         title: Row(
           children: [
             Container(
               padding: const EdgeInsets.all(8),
               decoration: BoxDecoration(
                 color: const Color(0xFFFEF3C7),
                 borderRadius: BorderRadius.circular(10),
               ),
               child: const Icon(Icons.workspace_premium_outlined,
                   color: Color(0xFFB45309), size: 24),
             ),
             const SizedBox(width: 12),
             const Text('Assign Project Sponsor'),
           ],
         ),
         content: SizedBox(
           width: 440,
           child: Form(
             key: formKey,
             child: Column(
               mainAxisSize: MainAxisSize.min,
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 const Text(
                   'A sponsor must be identified before the charter '
                   'can be approved. The system suggests the highest '
                   'role-based authority on the site. You can accept '
                   'the suggestion, enter a different sponsor, or '
                   'invite an external sponsor via email.',
                   style: TextStyle(color: Colors.grey, fontSize: 12),
                 ),
                 const SizedBox(height: 14),
                 // Suggested sponsor banner
                 if (loadingSuggestion)
                   const Padding(
                     padding: EdgeInsets.symmetric(vertical: 8),
                     child: Row(
                       children: [
                         SizedBox(
                           width: 14,
                           height: 14,
                           child: CircularProgressIndicator(strokeWidth: 2),
                         ),
                         SizedBox(width: 8),
                         Text('Finding suggested sponsor…',
                             style: TextStyle(fontSize: 12)),
                       ],
                     ),
                   )
                 else if (suggested != null &&
                     suggested!.name.isNotEmpty &&
                     suggested!.name != 'Pending Assignment')
                   Container(
                     padding: const EdgeInsets.all(10),
                     decoration: BoxDecoration(
                       color: const Color(0xFFFFF8E1),
                       borderRadius: BorderRadius.circular(8),
                       border: Border.all(
                           color: const Color(0xFFFFC812)
                               .withValues(alpha: 0.2)),
                     ),
                     child: Row(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Icon(Icons.lightbulb_outline,
                             size: 16, color: Color(0xFFFFC812)),
                         const SizedBox(width: 8),
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               const Text(
                                 'Suggested Sponsor (highest role-based authority):',
                                 style: TextStyle(
                                     fontSize: 11,
                                     fontWeight: FontWeight.w700,
                                     color: Color(0xFFFFC812)),
                               ),
                               const SizedBox(height: 2),
                               Text(
                                 '${suggested!.name} — ${suggested!.role}',
                                 style: const TextStyle(fontSize: 12),
                               ),
                               const SizedBox(height: 6),
                               Align(
                                 alignment: Alignment.centerRight,
                                 child: TextButton.icon(
                                   onPressed: () {
                                     setDialogState(() {
                                       nameController.text =
                                           suggested!.name;
                                       emailController.text =
                                           suggested!.email;
                                     });
                                   },
                                   icon: const Icon(Icons.check, size: 14),
                                   label: const Text('Use Suggested',
                                       style: TextStyle(fontSize: 11)),
                                   style: TextButton.styleFrom(
                                     foregroundColor:
                                         const Color(0xFFFFC812),
                                     padding: const EdgeInsets.symmetric(
                                         horizontal: 8, vertical: 2),
                                     minimumSize: Size.zero,
                                     tapTargetSize:
                                         MaterialTapTargetSize.shrinkWrap,
                                   ),
                                 ),
                               ),
                             ],
                           ),
                         ),
                       ],
                     ),
                   ),
                 const SizedBox(height: 14),
                 TextFormField(
                   controller: nameController,
                   autofocus: true,
                   decoration: InputDecoration(
                     labelText: 'Sponsor Name',
                     hintText: 'e.g. Jane Doe',
                     border: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(12)),
                     filled: true,
                     fillColor: Colors.grey[50],
                   ),
                   validator: (value) {
                     if (value == null || value.trim().isEmpty) {
                       return 'Please enter a sponsor name';
                     }
                     if (value.trim().length < 2) {
                       return 'Name must be at least 2 characters';
                     }
                     return null;
                   },
                 ),
                 const SizedBox(height: 12),
                 TextFormField(
                   controller: emailController,
                   decoration: InputDecoration(
                     labelText: 'Email (optional — used to send approval request)',
                     hintText: 'e.g. jane.doe@company.com',
                     border: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(12)),
                     filled: true,
                     fillColor: Colors.grey[50],
                   ),
                 ),
               ],
             ),
           ),
         ),
         actions: [
           TextButton(
             onPressed: inviting
                 ? null
                 : () => Navigator.of(dialogContext).pop(),
             child: const Text('Cancel'),
           ),
           // Invite an external sponsor via email (sends a project
           // manager invitation so they can sign in and approve).
           OutlinedButton.icon(
             onPressed: inviting
                 ? null
                 : () async {
                     final email = emailController.text.trim();
                     if (email.isEmpty || !email.contains('@')) {
                       ScaffoldMessenger.of(dialogContext).showSnackBar(
                         const SnackBar(
                           content: Text(
                               'Enter a valid email to invite an external sponsor.'),
                           backgroundColor: Color(0xFFD97706),
                         ),
                       );
                       return;
                     }
                     setDialogState(() => inviting = true);
                     try {
                       final msg =
                           await CharterApprovalService.inviteExternalSponsor(
                         email: email,
                         sponsorName: nameController.text.trim(),
                         projectName: data.projectName,
                       );
                       if (dialogContext.mounted) {
                         ScaffoldMessenger.of(dialogContext).showSnackBar(
                           SnackBar(
                             content: Text(msg),
                             backgroundColor: Colors.green,
                           ),
                         );
                       }
                     } catch (e) {
                       if (dialogContext.mounted) {
                         ScaffoldMessenger.of(dialogContext).showSnackBar(
                           SnackBar(
                             content: Text(
                                 'Failed to send sponsor invitation: $e'),
                             backgroundColor: Colors.red,
                           ),
                         );
                       }
                     } finally {
                       if (dialogContext.mounted) {
                         setDialogState(() => inviting = false);
                       }
                     }
                   },
             icon: inviting
                 ? const SizedBox(
                     width: 14,
                     height: 14,
                     child: CircularProgressIndicator(strokeWidth: 2),
                   )
                 : const Icon(Icons.person_add_alt_outlined, size: 16),
             label: const Text('Invite Sponsor via Email'),
           ),
           ElevatedButton(
             onPressed: () {
               if (formKey.currentState?.validate() ?? false) {
                 Navigator.of(dialogContext).pop({
                   'name': nameController.text.trim(),
                   'email': emailController.text.trim(),
                 });
               }
             },
             style: ElevatedButton.styleFrom(
               backgroundColor: const Color(0xFFFFC812),
               foregroundColor: Colors.black,
               shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(12)),
             ),
             child: const Text('Assign'),
           ),
         ],
       );
     },
   );
 },
 );

 // Ensure the background load completes (harmless if it already has).
 await loadSuggestion;

 if (result == null) return;

 // Persist the sponsor assignment to Firestore via ProjectDataHelper
 try {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'project_charter',
 dataUpdater: (current) => current.copyWith(
 charterProjectSponsorName: result['name']!,
 charterEmail: result['email']!.isNotEmpty
 ? result['email']
 : current.charterEmail,
 ),
 showSnackbar: false,
 );

 if (mounted) {
 setState(() {});
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 '${result['name']} assigned as Project Sponsor'),
 backgroundColor: Colors.green,
 ),
 );
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Failed to assign sponsor: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 } finally {
 nameController.dispose();
 emailController.dispose();
 }
 }

 Future<void> _showAssignManagerDialog(ProjectDataModel data) async {
   final nameController = TextEditingController();
   final emailController = TextEditingController();
   final formKey = GlobalKey<FormState>();

   // Load registered users BEFORE opening the dialog so the
   // Autocomplete is fully populated by the time the user can interact.
   // Also detect whether this manager was already invited (so we can
   // surface a 'Resend invite' affordance instead of 'Assign').
   List<UserModel> allUsers = const [];
   bool isSendingInvite = false;
   bool wasPreviouslyInvited = false;

   try {
     final snap = await FirebaseFirestore.instance
         .collection('users')
         .limit(200)
         .get();
     allUsers = snap.docs.map((d) => UserModel.fromJson(d.data())).toList();
     final existingEmail = (data.charterEmail ?? '').trim().toLowerCase();
     final existingName = data.charterProjectManagerName.trim();
     if (existingEmail.isNotEmpty && existingName.isNotEmpty) {
       final invSnap = await FirebaseFirestore.instance
           .collection('manager_invitations')
           .where('toEmail', isEqualTo: existingEmail)
           .limit(1)
           .get();
       wasPreviouslyInvited = invSnap.docs.isNotEmpty;
     }
   } catch (e) {
     debugPrint('Manager users load failed: $e');
   }

   final result = await showDialog<Map<String, String>>(
     context: context,
     builder: (dialogContext) {
       return StatefulBuilder(
         builder: (dialogContext, setDialogState) {
         return AlertDialog(
         shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(20)),
         title: Row(
           children: [
             Container(
               padding: const EdgeInsets.all(8),
               decoration: BoxDecoration(
                 color: const Color(0xFFFEF3C7),
                 borderRadius: BorderRadius.circular(10),
               ),
               child: const Icon(Icons.person_add_outlined,
                   color: Color(0xFFB45309), size: 24),
             ),
             const SizedBox(width: 12),
             const Text('Assign Project Manager'),
           ],
         ),
         content: SizedBox(
           width: 400,
           child: Form(
             key: formKey,
             child: Column(
               mainAxisSize: MainAxisSize.min,
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 const Text(
                   'Assign a project manager to this project. '
                   'A manager must be assigned before proceeding to the next step. '
                   'Start typing a name to pick from registered users — '
                   'the email is auto-filled.',
                   style: TextStyle(color: Colors.grey, fontSize: 13),
                 ),
                 const SizedBox(height: 20),
                 // Manager Name — Autocomplete from registered users.
                 Autocomplete<UserModel>(
                     initialValue: TextEditingValue(
                       text: data.charterProjectManagerName,
                     ),
                     displayStringForOption: (u) => u.displayName,
                     optionsBuilder: (textEditingValue) {
                       final q = textEditingValue.text.trim().toLowerCase();
                       if (q.isEmpty) return allUsers;
                       return allUsers.where((u) {
                         final name = u.displayName.toLowerCase();
                         final email = (u.email ?? '').toLowerCase();
                         return name.contains(q) || email.contains(q);
                       });
                     },
                     onSelected: (selection) {
                       nameController.text = selection.displayName;
                       emailController.text = selection.email ?? '';
                       setDialogState(() {});
                     },
                     fieldViewBuilder:
                         (ctx, controller, focusNode, onSubmitted) {
                       controller.addListener(() {
                         if (nameController.text != controller.text) {
                           nameController.text = controller.text;
                         }
                       });
                       return TextFormField(
                         controller: controller,
                         focusNode: focusNode,
                         autofocus: true,
                         decoration: InputDecoration(
                           labelText: 'Manager Name',
                           hintText: 'e.g. John Doe',
                           border: OutlineInputBorder(
                               borderRadius: BorderRadius.circular(12)),
                           filled: true,
                           fillColor: Colors.grey[50],
                         ),
                         validator: (value) {
                           if (value == null || value.trim().isEmpty) {
                             return 'Please enter a manager name';
                           }
                           if (value.trim().length < 2) {
                             return 'Name must be at least 2 characters';
                           }
                           return null;
                         },
                       );
                     },
                     optionsViewBuilder: (ctx, onSelected, options) {
                       return Align(
                         alignment: Alignment.topLeft,
                         child: Material(
                           elevation: 4,
                           borderRadius: BorderRadius.circular(12),
                           child: ConstrainedBox(
                             constraints: const BoxConstraints(maxHeight: 220),
                             child: ListView.builder(
                               padding: EdgeInsets.zero,
                               shrinkWrap: true,
                               itemCount: options.length,
                               itemBuilder: (c, i) {
                                 final u = options.elementAt(i);
                                 return ListTile(
                                   dense: true,
                                   leading: CircleAvatar(
                                     backgroundColor: const Color(0xFFFFC812),
                                     child: Text(
                                       u.displayName.isNotEmpty
                                           ? u.displayName[0].toUpperCase()
                                           : '?',
                                       style: const TextStyle(color: Colors.white),
                                     ),
                                   ),
                                   title: Text(u.displayName),
                                   subtitle: Text(u.email ?? ''),
                                   onTap: () => onSelected(u),
                                 );
                               },
                             ),
                           ),
                         ),
                       );
                     },
                   ),
                 const SizedBox(height: 12),
                 // Email — auto-filled when a registered user is selected,
                 // still editable for the manual external-email path.
                 TextFormField(
                   controller: emailController,
                   decoration: InputDecoration(
                     labelText: 'Email (optional)',
                     hintText: 'e.g. john.doe@company.com',
                     border: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(12)),
                     filled: true,
                     fillColor: Colors.grey[50],
                     suffixIcon: emailController.text.isNotEmpty
                         ? const Icon(Icons.mail_outline,
                             size: 18, color: Color(0xFF10B981))
                         : null,
                   ),
                   onChanged: (_) => setDialogState(() {}),
                 ),
                 if (wasPreviouslyInvited)
                   const Padding(
                     padding: EdgeInsets.only(top: 8),
                     child: Row(
                       children: [
                         Icon(Icons.check_circle_outline,
                             size: 14, color: Color(0xFF10B981)),
                         SizedBox(width: 6),
                         Expanded(
                           child: Text(
                             'This manager has already been invited. '
                             'Saving will resend the invitation email.',
                             style: TextStyle(
                                 fontSize: 11,
                                 color: Color(0xFF10B981)),
                           ),
                         ),
                       ],
                     ),
                   ),
               ],
             ),
           ),
         ),
         actions: [
           TextButton(
             onPressed: () => Navigator.of(dialogContext).pop(),
             child: const Text('Cancel'),
           ),
           ElevatedButton(
             onPressed: isSendingInvite
                 ? null
                 : () async {
                     if (!(formKey.currentState?.validate() ?? false)) {
                       return;
                     }
                     setDialogState(() => isSendingInvite = true);
                     try {
                       // Persist the manager assignment to Firestore first
                       // so the project data model reflects the new PM
                       // before we send the email invitation.
                       await ProjectDataHelper.updateAndSave(
                         context: context,
                         checkpoint: 'project_charter',
                         dataUpdater: (current) => current.copyWith(
                           charterProjectManagerName: nameController.text.trim(),
                           charterEmail: emailController.text.trim().isNotEmpty
                               ? emailController.text.trim()
                               : current.charterEmail,
                         ),
                         showSnackbar: false,
                       );

                       // Send (or resend) the @nduproject.tech invitation
                       // via the sendManagerInvite Cloud Function. Failures
                       // don't roll back the assignment — the user is told
                       // the email failed and offered a resend later.
                       String? sendError;
                       if (emailController.text.trim().isNotEmpty) {
                         try {
                           final callable = FirebaseFunctions.instance
                               .httpsCallable('sendManagerInvite');
                           await callable.call({
                             'toEmail': emailController.text.trim(),
                             'toName': nameController.text.trim(),
                             'managerName': nameController.text.trim(),
                             'projectName': data.projectName ?? '',
                             'projectId': (data.projectId ?? '').trim(),
                             'resend': wasPreviouslyInvited,
                           });
                         } on FirebaseFunctionsException catch (e) {
                           sendError = e.message ?? e.code;
                           debugPrint(
                               'sendManagerInvite failed: ${e.code} ${e.message}');
                         } catch (e) {
                           sendError = e.toString();
                           debugPrint('sendManagerInvite error: $e');
                         }
                       }

                       if (!dialogContext.mounted) return;
                       Navigator.of(dialogContext).pop({
                         'name': nameController.text.trim(),
                         'email': emailController.text.trim(),
                         'inviteError': sendError ?? '',
                       });
                     } catch (e) {
                       if (!dialogContext.mounted) return;
                       Navigator.of(dialogContext).pop();
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(
                           content: Text('Failed to assign manager: $e'),
                           backgroundColor: Colors.red,
                         ),
                       );
                     } finally {
                       if (dialogContext.mounted) {
                         setDialogState(() => isSendingInvite = false);
                       }
                     }
                   },
             style: ElevatedButton.styleFrom(
               backgroundColor: const Color(0xFFFFC812),
               foregroundColor: Colors.black,
               shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(12)),
             ),
             child: isSendingInvite
                 ? const SizedBox(
                     width: 18,
                     height: 18,
                     child: CircularProgressIndicator(
                         strokeWidth: 2, color: Colors.black),
                   )
                 : Text(wasPreviouslyInvited ? 'Resend Invite' : 'Assign'),
           ),
         ],
       );
         },
       );
     },
   );

   if (result == null) {
     nameController.dispose();
     emailController.dispose();
     return;
   }

   // The persist + invite-send already happened inside the dialog (so the
   // dialog could show a spinner on the Assign button). Here we just
   // refresh the parent + surface a status SnackBar.
   if (mounted) {
     setState(() {});
     final inviteError = (result['inviteError'] ?? '').toString();
     if (inviteError.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text(result['email']!.isNotEmpty
               ? '${result['name']} assigned as Project Manager and invite sent to ${result['email']}.'
               : '${result['name']} assigned as Project Manager.'),
           backgroundColor: Colors.green,
         ),
       );
     } else {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text(
               '${result['name']} assigned as Project Manager, but the invite email failed: $inviteError. You can resend later.'),
           backgroundColor: const Color(0xFFD97706),
         ),
       );
     }
   }

   nameController.dispose();
   emailController.dispose();
 }
}

class _MetaInfoItem {
 final IconData icon;
 final String label;
 final String value;
 final Color iconBgColor;
 final Color iconFgColor;
 final VoidCallback? onTap;

 const _MetaInfoItem({
 required this.icon,
 required this.label,
 required this.value,
 required this.iconBgColor,
 required this.iconFgColor,
 this.onTap,
 });
}

class _MetaInfoCard extends StatelessWidget {
 final _MetaInfoItem item;

 const _MetaInfoCard({required this.item});

 @override
 Widget build(BuildContext context) {
 final card = Container(
 width: 200,
 padding: const EdgeInsets.all(16),
 decoration: kCardBorderDecoration,
 child: Row(
 children: [
 Container(
 width: 40,
 height: 40,
 decoration: BoxDecoration(
 color: item.iconBgColor,
 shape: BoxShape.circle,
 ),
 child: Icon(item.icon, size: 20, color: item.iconFgColor),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 item.label.toUpperCase(),
 style: const TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w600,
 color: BrandColors.onSurfaceVariant,
 letterSpacing: 0.5,
 ),
 ),
 const SizedBox(height: 2),
 Text(
 item.value,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: BrandColors.onSurface,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ],
 ),
 ),
 ],
 ),
 );

 if (item.onTap != null) {
 return GestureDetector(
 onTap: item.onTap,
 child: MouseRegion(
 cursor: SystemMouseCursors.click,
 child: card,
 ),
 );
 }
 return card;
 }
}

// ─── 4a. Project Definition Card ───

class CharterProjectDefinition extends StatelessWidget {
 final ProjectDataModel? data;
 final VoidCallback? onGenerate;

 const CharterProjectDefinition(
 {super.key, required this.data, this.onGenerate});

 @override
 Widget build(BuildContext context) {
 if (data == null) return const SizedBox();

 final isLocked = CharterLockHelper.isFepLocked(data);

 final projectPurposeText = data!.projectObjective.trim().isNotEmpty
 ? data!.projectObjective
 : data!.solutionDescription.trim().isNotEmpty
 ? data!.solutionDescription
 : data!.businessCase;

 return Container(
 padding: const EdgeInsets.all(20),
 decoration: kCardBorderDecoration,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 sectionTitleWithIcon(Icons.description_outlined, 'Project Purpose'),
 if (onGenerate != null && !isLocked)
 TextButton.icon(
 onPressed: onGenerate,
 icon: const Icon(Icons.auto_awesome, size: 16),
 label:
 const Text('AI Generate', style: TextStyle(fontSize: 12)),
 style: TextButton.styleFrom(
 padding:
 const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 minimumSize: Size.zero,
 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 // Project Purpose text
 ExpandableText(
 text: projectPurposeText.trim().isEmpty
 ? 'Summarize the overall aim of the project and what it will deliver.'
 : projectPurposeText,
 style: TextStyle(
 fontSize: 14,
 height: 1.5,
 color: projectPurposeText.trim().isEmpty
 ? BrandColors.onSurfaceVariant
 : BrandColors.onSurface,
 ),
 maxLines: 4,
 ),
 const SizedBox(height: 20),
 const Divider(color: BrandColors.outlineVariant),
 const SizedBox(height: 16),
 // Business Case subsection
 const Text(
 'BUSINESS CASE',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: BrandColors.primary,
 letterSpacing: 0.8,
 ),
 ),
 const SizedBox(height: 8),
 ExpandableText(
 text: data!.businessCase.trim().isEmpty
 ? 'Provide the financial and strategic rationale for this project.'
 : data!.businessCase,
 style: TextStyle(
 fontSize: 14,
 height: 1.5,
 color: data!.businessCase.trim().isEmpty
 ? BrandColors.onSurfaceVariant
 : BrandColors.onSurface,
 ),
 maxLines: 4,
 ),
 ],
 ),
 );
 }
}

// ─── 4b. Financial Overview Card ───

class CharterFinancialOverview extends StatelessWidget {
 final ProjectDataModel? data;

 const CharterFinancialOverview({super.key, required this.data});

 @override
 Widget build(BuildContext context) {
 if (data == null) return const SizedBox();

 final cost = ProjectDataHelper.getTotalEstimatedCostValue(data!);
 final costStr = NumberFormat.simpleCurrency(name: data!.costBenefitCurrency)
 .format(cost);
 final opportunitiesCount =
 ProjectDataHelper.getExpectedOpportunitiesCount(data!);

 return Container(
 padding: const EdgeInsets.all(20),
 decoration: kCardBorderDecoration,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 sectionTitleWithIcon(
 Icons.payments_outlined, 'Financial Overview'),
 ],
 ),
 const SizedBox(height: 20),

 // Metrics row
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 labelStyle('Total Cost'),
 const SizedBox(height: 4),
 Text(
 costStr,
 style: const TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.bold,
 color: BrandColors.error,
 letterSpacing: -0.5,
 ),
 ),
 ],
 ),
 ),
 Container(
 width: 1, height: 40, color: BrandColors.outlineVariant),
 const SizedBox(width: 20),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 labelStyle('Opportunities'),
 const SizedBox(height: 4),
 Text(
 opportunitiesCount.toString(),
 style: const TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.bold,
 color: BrandColors.primary,
 letterSpacing: -0.5,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),
 const Divider(color: BrandColors.outlineVariant),
 const SizedBox(height: 16),

 // Cost breakdown bar
 labelStyle('Estimated Cost Breakdown'),
 const SizedBox(height: 12),
 _buildCostChart(data!),
 ],
 ),
 );
 }

 Widget _buildCostChart(ProjectDataModel data) {
 final segments = _buildCostBreakdownSegments(data);
 if (segments.isEmpty) {
 return const Padding(
 padding: EdgeInsets.all(16.0),
 child: Text('No cost estimates to display.',
 style: TextStyle(
 color: BrandColors.onSurfaceVariant,
 fontStyle: FontStyle.italic)),
 );
 }

 final total =
 segments.fold<double>(0.0, (sum, segment) => sum + segment.amount);
 final currency =
 NumberFormat.compactSimpleCurrency(name: data.costBenefitCurrency);

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Stacked progress bar
 ClipRRect(
 borderRadius: BorderRadius.circular(6),
 child: Row(
 children: [
 for (final segment in segments)
 Expanded(
 flex: (segment.amount <= 0
 ? 1
 : (segment.amount / total * 100).round())
 .clamp(1, 100),
 child: Tooltip(
 message:
 '${segment.label}: ${currency.format(segment.amount)}',
 child: Container(height: 14, color: segment.color),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 14),
 // Legend
 ...segments.map((segment) {
 final pct = total > 0 ? (segment.amount / total) * 100 : 0.0;
 return Padding(
 padding: const EdgeInsets.only(bottom: 8),
 child: Row(
 children: [
 Container(
 width: 10,
 height: 10,
 decoration: BoxDecoration(
 color: segment.color,
 borderRadius: BorderRadius.circular(2),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 segment.label,
 style: const TextStyle(
 fontSize: 13, fontWeight: FontWeight.w500),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 SizedBox(
 width: 50,
 child: Text(
 '${pct.toStringAsFixed(1)}%',
 textAlign: TextAlign.right,
 style: const TextStyle(
 fontSize: 12, color: BrandColors.onSurfaceVariant),
 ),
 ),
 const SizedBox(width: 8),
 SizedBox(
 width: 100,
 child: Text(
 currency.format(segment.amount),
 textAlign: TextAlign.right,
 style: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w700),
 ),
 ),
 ],
 ),
 );
 }),
 ],
 );
 }

 List<_CostBreakdownSegment> _buildCostBreakdownSegments(
 ProjectDataModel data) {
 final segments = <_CostBreakdownSegment>[];

 final estimateItems = ProjectDataHelper.getActiveCostEstimateItems(
 data,
 costState: 'forecast',
 ).where((item) => item.amount > 0).toList()
 ..sort((a, b) => b.amount.compareTo(a.amount));

 if (estimateItems.isNotEmpty) {
 for (var i = 0; i < estimateItems.length && i < 6; i++) {
 final item = estimateItems[i];
 segments.add(
 _CostBreakdownSegment(
 label: item.title.trim().isNotEmpty
 ? item.title.trim()
 : 'Estimate Item ${i + 1}',
 amount: item.amount,
 color: _getColor(i),
 ),
 );
 }
 return segments;
 }

 final categoryTotals = <String, double>{
 'Allowances': data.frontEndPlanning.allowanceItems
 .fold<double>(0.0, (sum, item) => sum + item.amount),
 'Contracting': data.contractors
 .fold<double>(0.0, (sum, item) => sum + item.estimatedCost),
 'Procurement': data.vendors
 .fold<double>(0.0, (sum, item) => sum + item.estimatedPrice),
 };

 var colorIndex = 0;
 categoryTotals.forEach((label, amount) {
 if (amount <= 0) return;
 segments.add(_CostBreakdownSegment(
 label: label,
 amount: amount,
 color: _getColor(colorIndex++),
 ));
 });

 if (segments.isNotEmpty) return segments;

 final costAnalysisTotal = data.costAnalysisData?.solutionCosts.fold<double>(
 0.0,
 (sum, solution) =>
 sum +
 solution.costRows.fold<double>(0.0,
 (rowSum, row) => rowSum + (double.tryParse(row.cost) ?? 0.0)),
 ) ??
 0.0;
 if (costAnalysisTotal > 0) {
 segments.add(_CostBreakdownSegment(
 label: 'Initial Cost Estimate',
 amount: costAnalysisTotal,
 color: _getColor(0),
 ));
 }

 return segments;
 }

 Color _getColor(int index) {
 const table = [
 BrandColors.primary,
 BrandColors.error,
 Color(0xFF10B981),
 BrandColors.tertiaryFixedDim,
 Color(0xFFB8860B),
 ];
 return table[index % table.length];
 }
}

class _CostBreakdownSegment {
 final String label;
 final double amount;
 final Color color;

 const _CostBreakdownSegment({
 required this.label,
 required this.amount,
 required this.color,
 });
}

// ─── 4c. Success Criteria Card ───

class CharterSuccessCriteria extends StatelessWidget {
 final ProjectDataModel? data;

 const CharterSuccessCriteria({super.key, required this.data});

 @override
 Widget build(BuildContext context) {
 if (data == null) return const SizedBox();

 final items = data!.frontEndPlanning.successCriteriaItems;

 return Container(
 padding: const EdgeInsets.all(20),
 decoration: kCardBorderDecoration,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 sectionTitleWithIcon(Icons.task_alt_outlined, 'Success Criteria'),
 const SizedBox(height: 16),
 if (items.isEmpty)
 const Text(
 'No success criteria defined.',
 style: TextStyle(
 color: BrandColors.onSurfaceVariant,
 fontStyle: FontStyle.italic),
 )
 else
 ...items.map((item) => Padding(
 padding: const EdgeInsets.only(bottom: 14),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Icon(Icons.check_circle,
 size: 20, color: BrandColors.primary),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 item.title.isNotEmpty
 ? item.title
 : item.description,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: BrandColors.onSurface,
 ),
 ),
 if (item.title.isNotEmpty &&
 item.description.isNotEmpty)
 Padding(
 padding: const EdgeInsets.only(top: 2),
 child: Text(
 item.description,
 style: const TextStyle(
 fontSize: 13,
 color: BrandColors.onSurfaceVariant,
 height: 1.4,
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 )),
 ],
 ),
 );
 }
}

// ─── 4d. Project Scope Card ───

class CharterScope extends StatelessWidget {
 final ProjectDataModel? data;
 final VoidCallback? onGenerate;
 /// When provided, the card shows an "Edit" button that navigates the user
 /// back to the Project Details page (where the scope actually lives).
 /// The AI Generate button has been removed — the charter merely reflects
 /// what was entered on the Project Details page.
 final VoidCallback? onEdit;

 const CharterScope({super.key, required this.data, this.onGenerate, this.onEdit});

 @override
 Widget build(BuildContext context) {
 if (data == null) return const SizedBox();

 final isLocked = CharterLockHelper.isFepLocked(data);

 final inScopeItems = data!.withinScope
 .where((s) => s.trim().isNotEmpty)
 .toList();
 final outOfScopeItems = data!.outOfScope
 .where((s) => s.trim().isNotEmpty)
 .toList();

 return Container(
 padding: const EdgeInsets.all(20),
 decoration: kCardBorderDecoration,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 sectionTitleWithIcon(Icons.zoom_in_outlined, 'Project Scope'),
 // AI Generate removed — scope comes from the Project Details
 // page. Show an Edit button that takes the user back there.
 // When the charter is approved, the entire FEP is locked,
 // so the edit affordance disappears.
 if (onEdit != null && !isLocked)
 TextButton.icon(
 onPressed: onEdit,
 icon: const Icon(Icons.edit_outlined, size: 16),
 label: const Text('Edit on Details Page',
 style: TextStyle(fontSize: 12)),
 style: TextButton.styleFrom(
 foregroundColor: BrandColors.primary,
 padding:
 const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 minimumSize: Size.zero,
 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),

 // Within Scope - tag pills
 const Text(
 'WITHIN SCOPE',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: BrandColors.primary,
 letterSpacing: 0.8,
 ),
 ),
 const SizedBox(height: 8),
 if (inScopeItems.isEmpty)
 const Text('Not specified',
 style: TextStyle(
 color: BrandColors.onSurfaceVariant,
 fontStyle: FontStyle.italic,
 fontSize: 13))
 else
 Wrap(
 spacing: 8,
 runSpacing: 8,
 children: inScopeItems.map((item) {
 return Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: BrandColors.primaryFixed,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(
 color: BrandColors.primary.withValues(alpha: 0.3)),
 ),
 child: Text(
 item.trim(),
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: BrandColors.onPrimaryFixedVariant,
 ),
 ),
 );
 }).toList(),
 ),

 const SizedBox(height: 20),

 // Out of Scope - bullet list with error-colored label
 const Text(
 'OUT OF SCOPE',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: BrandColors.error,
 letterSpacing: 0.8,
 ),
 ),
 const SizedBox(height: 8),
 if (outOfScopeItems.isEmpty)
 const Text('Not specified',
 style: TextStyle(
 color: BrandColors.onSurfaceVariant,
 fontStyle: FontStyle.italic,
 fontSize: 13))
 else
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: outOfScopeItems.map((item) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 8),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 6,
 height: 6,
 margin: const EdgeInsets.only(top: 6, right: 10),
 decoration: const BoxDecoration(
 color: BrandColors.error,
 shape: BoxShape.circle,
 ),
 ),
 Expanded(
 child: Text(
 item.trim(),
 style: const TextStyle(
 fontSize: 13,
 color: BrandColors.onSurface,
 height: 1.4,
 ),
 ),
 ),
 ],
 ),
 );
 }).toList(),
 ),
 ],
 ),
 );
 }
}

// ─── 5. Key Risks Section ───

class CharterRisks extends StatelessWidget {
 final ProjectDataModel? data;
 final VoidCallback? onGenerate;

 const CharterRisks({super.key, required this.data, this.onGenerate});

 @override
 Widget build(BuildContext context) {
 if (data == null) return const SizedBox();

 final riskRegister = data!.frontEndPlanning.riskRegisterItems;
 List<Map<String, dynamic>> allRisks = [];

 if (riskRegister.isNotEmpty) {
 for (var risk in riskRegister) {
 allRisks.add({
 'type': 'Risk',
 'description': risk.riskName,
 'impact': risk.impactLevel,
 'likelihood': 'Medium',
 'mitigation': risk.mitigationStrategy,
 });
 }
 } else {
 for (var solutionRisk in data!.solutionRisks) {
 for (var riskStr in solutionRisk.risks) {
 allRisks.add({
 'type': 'Risk',
 'description': riskStr,
 'impact': 'Medium',
 'likelihood': 'Medium',
 'mitigation': 'TBD',
 });
 }
 }
 }

 allRisks.sort((a, b) {
 final scoreA = _impactScore(a['impact']);
 final scoreB = _impactScore(b['impact']);
 return scoreB.compareTo(scoreA);
 });

 final displayRisks = allRisks.take(5).toList();
 final totalRisksCount = allRisks.length;

 return Container(
 padding: const EdgeInsets.all(20),
 decoration: kCardBorderDecoration,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Icon(Icons.warning_amber_rounded,
 size: 20, color: BrandColors.error),
 const SizedBox(width: 8),
 const Text(
 'Key Risks',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w600,
 color: BrandColors.onSurface,
 ),
 ),
 const SizedBox(width: 8),
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: BrandColors.errorContainer,
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(
 '$totalRisksCount Total',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: BrandColors.onErrorContainer,
 letterSpacing: 0.5,
 ),
 ),
 ),
 // AI Generate button removed per user request — Key Risks
 // reflect the risk register maintained on the dedicated Risks
 // page; the charter is a reflection, not a generator.
 ],
 ),
 const SizedBox(height: 20),

 // Risk items with border-left severity
 if (allRisks.isEmpty)
 const Text('No risks identified.',
 style: TextStyle(
 color: BrandColors.onSurfaceVariant,
 fontStyle: FontStyle.italic))
 else
 Column(
 children: displayRisks.map((item) {
 final impact = item['impact'].toString();
 final Color borderColor;
 final Color badgeBg;
 final Color badgeText;
 if (impact.toLowerCase() == 'high') {
 borderColor = BrandColors.error;
 badgeBg = BrandColors.errorContainer;
 badgeText = BrandColors.onErrorContainer;
 } else if (impact.toLowerCase() == 'medium') {
 borderColor = BrandColors.tertiaryFixedDim;
 badgeBg = BrandColors.tertiaryFixed;
 badgeText = BrandColors.onTertiaryFixedVariant;
 } else {
 borderColor = const Color(0xFF4ADE80);
 badgeBg = const Color(0xFFDCFCE7);
 badgeText = const Color(0xFF166534);
 }

 return Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding:
 const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(8),
 border: Border(
 left: BorderSide(color: borderColor, width: 4),
 ),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.03),
 offset: const Offset(0, 1),
 blurRadius: 2,
 )
 ],
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Strip a leading orphan period (data-entry typo like
 // ". Failure to..." → "Failure to...").
 Text(
 _cleanRiskDescription(item['description']),
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w500,
 color: BrandColors.onSurface,
 height: 1.45,
 ),
 ),
 if (item['mitigation'] != null &&
 item['mitigation'].toString().isNotEmpty &&
 item['mitigation'].toString() != 'TBD')
 Padding(
 padding: const EdgeInsets.only(top: 4),
 child: Text(
 'Mitigation: ${item['mitigation']}',
 style: const TextStyle(
 fontSize: 12,
 color: BrandColors.onSurfaceVariant,
 height: 1.4,
 ),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: badgeBg,
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(
 impact,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: badgeText,
 ),
 ),
 ),
 ],
 ),
 );
 }).toList(),
 ),

 // Constraints
 if (data!.constraints.isNotEmpty) ...[
 const SizedBox(height: 20),
 const Divider(color: BrandColors.outlineVariant),
 const SizedBox(height: 16),
 labelStyle('Project Constraints'),
 const SizedBox(height: 8),
 ...data!.constraints.take(5).map((c) => Padding(
 padding: const EdgeInsets.only(bottom: 6),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('• ',
 style: TextStyle(
 color: BrandColors.onSurfaceVariant,
 fontSize: 13)),
 Expanded(
 child: Text(c,
 style: const TextStyle(
 fontSize: 13,
 color: BrandColors.onSurface))),
 ],
 ),
 )),
 ],
 ],
 ),
 );
 }

 int _impactScore(String impact) {
 switch (impact.toLowerCase()) {
 case 'high':
 return 3;
 case 'medium':
 return 2;
 case 'low':
 return 1;
 default:
 return 0;
 }
 }

 /// Strip a leading orphan period and surrounding whitespace from a
 /// risk description (data-entry typo like ". Failure to..." →
 /// "Failure to...").
 String _cleanRiskDescription(dynamic desc) {
 final s = desc?.toString() ?? '';
 var t = s.trim();
 while (t.startsWith('.') || t.startsWith(',') || t.startsWith(';')) {
 t = t.substring(1).trim();
 }
 return t;
 }
}

// ─── 6. Technical & Procurement Bento ───

class CharterTechnicalProcurementBento extends StatefulWidget {
  final ProjectDataModel? data;
  final VoidCallback? onGenerate;
  /// When provided, shows a "View Preferred Solution" button that
  /// takes the user to the Preferred Solution Analysis screen (the
  /// source of truth for the preferred solution). The Business Case
  /// section is read-only after the preferred solution is locked.
  final VoidCallback? onEdit;

  /// When a preferred solution is locked, IT considerations and
  /// Infrastructure text shown in the charter are sourced from the
  /// preferred solution's SolutionAnalysisItem. The Business Case
  /// itself is locked, but the user can still update the charter's
  /// wording directly — [onSaveITOverride] / [onSaveInfraOverride]
  /// are called with the new text when the user edits a section
  /// inline. When the override is empty, the charter falls back to
  /// the preferred-solution text.
  final void Function(String text)? onSaveITOverride;
  final void Function(String text)? onSaveInfraOverride;

  /// Clear the charter-side override so the section reverts to the
  /// preferred-solution text.
  final VoidCallback? onClearITOverride;
  final VoidCallback? onClearInfraOverride;

  const CharterTechnicalProcurementBento({
    super.key,
    required this.data,
    this.onGenerate,
    this.onEdit,
    this.onSaveITOverride,
    this.onSaveInfraOverride,
    this.onClearITOverride,
    this.onClearInfraOverride,
  });

  @override
  State<CharterTechnicalProcurementBento> createState() =>
      _CharterTechnicalProcurementBentoState();
}

class _CharterTechnicalProcurementBentoState
    extends State<CharterTechnicalProcurementBento> {
  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data == null) return const SizedBox();

    final vendorCount = data.vendors.length;
    final contractCount = data.contractors.length;
    // Charter is read-only once approved — the "View Preferred Solution"
    // affordance disappears so the approved baseline is preserved.
    final isLocked = CharterLockHelper.isFepLocked(data);

    // IT considerations + Infrastructure source from the preferred
    // solution when one is locked. The user can still update the
    // charter's wording via the inline Edit affordance, which writes
    // a charter-side override (ProjectDataModel.charterITOverride /
    // charterInfraOverride). When no preferred solution is selected,
    // fall back to the dedicated FEP IT/Infra Considerations pages.
    final preferred = data.preferredSolution;
    final hasPreferred = preferred != null;

    final sourceLabel = hasPreferred
        ? 'Source: Preferred Solution — ${preferred.title}'
        : 'Source: IT & Infrastructure Considerations pages';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: sectionTitleWithIcon(
                  Icons.precision_manufacturing_outlined, 'Technical & Procurement'),
            ),
            // AI Generate removed per user request — IT considerations and
            // Infrastructure come from the preferred solution (Business Case
            // section, which is locked once a preferred solution is selected).
            // When the charter is approved, the edit affordance disappears.
            if (widget.onEdit != null && !isLocked)
              TextButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('View Preferred Solution',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          sourceLabel,
          style: const TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: BrandColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 768;
            return isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // IT + Infrastructure card
                      Expanded(
                        child: _buildTechCard(data, hasPreferred),
                      ),
                      const SizedBox(width: 12),
                      // Contracts + Procurement side by side
                      Expanded(
                        child: Column(
                          children: [
                            _buildStatCard(
                              'Contracts',
                              contractCount,
                              'Contracts Pending',
                              Icons.description_outlined,
                              BrandColors.primary,
                              BrandColors.primaryFixed,
                            ),
                            const SizedBox(height: 12),
                            _buildStatCard(
                              'Procurement',
                              vendorCount,
                              'Items Identified',
                              Icons.inventory_2_outlined,
                              BrandColors.tertiary,
                              BrandColors.tertiaryFixed,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildTechCard(data, hasPreferred),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Contracts',
                              contractCount,
                              'Contracts Pending',
                              Icons.description_outlined,
                              BrandColors.primary,
                              BrandColors.primaryFixed,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Procurement',
                              vendorCount,
                              'Items Identified',
                              Icons.inventory_2_outlined,
                              BrandColors.tertiary,
                              BrandColors.tertiaryFixed,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
          },
        ),
      ],
    );
  }

  /// Build the IT considerations + Infrastructure card.
  ///
  /// When [hasPreferred] is true (a preferred solution is locked):
  ///   - IT considerations text = charterITOverride ?? preferred solution IT text
  ///   - Infrastructure text    = charterInfraOverride ?? preferred solution infra text
  ///   - Edit buttons open an inline dialog that writes the charter-side
  ///     override (does NOT unlock or modify the Business Case).
  ///
  /// When [hasPreferred] is false (no preferred solution yet):
  ///   - Falls back to the FEP IT/Infrastructure Considerations pages'
  ///     structured data (hardware/software/network, space/power/connectivity).
  ///   - Edit buttons are hidden (the FEP pages remain the source of truth
  ///     in this state and are still editable from the sidebar).
  Widget _buildTechCard(ProjectDataModel data, bool hasPreferred) {
    final itText = hasPreferred
        ? CharterTechProcHelper.charterITText(data)
        : _fepITText(data.itConsiderationsData);
    final infraText = hasPreferred
        ? CharterTechProcHelper.charterInfraText(data)
        : _fepInfraText(data.infrastructureConsiderationsData);

    // Track whether the displayed text is an override (vs. the raw
    // preferred-solution text). Used to show a "Charter override"
    // badge and a "Reset to preferred solution" affordance.
    final itIsOverride = hasPreferred &&
        (data.charterITOverride?.trim().isNotEmpty ?? false);
    final infraIsOverride = hasPreferred &&
        (data.charterInfraOverride?.trim().isNotEmpty ?? false);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: kCardBorderDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── IT Considerations ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              labelStyle('IT Considerations'),
              if (hasPreferred && widget.onSaveITOverride != null)
                TextButton.icon(
                  onPressed: () => _editSection(
                    title: 'IT Considerations',
                    fieldLabel: 'IT considerations for the charter',
                    currentText: itText ?? '',
                    preferredText:
                        CharterTechProcHelper.preferredSolutionITText(data) ??
                            '',
                    isOverride: itIsOverride,
                    onSave: widget.onSaveITOverride,
                    onClear: widget.onClearITOverride,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit',
                      style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: BrandColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (itText == null || itText.trim().isEmpty)
            const Text('No specific requirements defined.',
                style: TextStyle(
                    color: BrandColors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                    fontSize: 13))
          else if (hasPreferred)
            _buildTextBlock(itText, itIsOverride)
          else ...[
            // Structured FEP rows (pre-preferred-solution display).
            if (data.itConsiderationsData != null) ...[
              if (data.itConsiderationsData!.hardwareRequirements.isNotEmpty)
                _buildReqRow(
                    'Hardware', data.itConsiderationsData!.hardwareRequirements),
              if (data.itConsiderationsData!.softwareRequirements.isNotEmpty)
                _buildReqRow(
                    'Software', data.itConsiderationsData!.softwareRequirements),
              if (data.itConsiderationsData!.networkRequirements.isNotEmpty)
                _buildReqRow(
                    'Network', data.itConsiderationsData!.networkRequirements),
            ],
          ],
          const SizedBox(height: 16),
          const Divider(color: BrandColors.outlineVariant),
          const SizedBox(height: 12),
          // ─── Infrastructure ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              labelStyle('Infrastructure'),
              if (hasPreferred && widget.onSaveInfraOverride != null)
                TextButton.icon(
                  onPressed: () => _editSection(
                    title: 'Infrastructure',
                    fieldLabel: 'Infrastructure considerations for the charter',
                    currentText: infraText ?? '',
                    preferredText:
                        CharterTechProcHelper.preferredSolutionInfraText(data) ??
                            '',
                    isOverride: infraIsOverride,
                    onSave: widget.onSaveInfraOverride,
                    onClear: widget.onClearInfraOverride,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit',
                      style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: BrandColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (infraText == null || infraText.trim().isEmpty)
            const Text('No specific requirements defined.',
                style: TextStyle(
                    color: BrandColors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                    fontSize: 13))
          else if (hasPreferred)
            _buildTextBlock(infraText, infraIsOverride)
          else ...[
            // Structured FEP rows (pre-preferred-solution display).
            if (data.infrastructureConsiderationsData != null) ...[
              if (data
                  .infrastructureConsiderationsData!.physicalSpaceRequirements
                  .isNotEmpty)
                _buildReqRow('Space',
                    data.infrastructureConsiderationsData!.physicalSpaceRequirements),
              if (data
                  .infrastructureConsiderationsData!.powerCoolingRequirements
                  .isNotEmpty)
                _buildReqRow('Power/Cooling',
                    data.infrastructureConsiderationsData!.powerCoolingRequirements),
              if (data
                  .infrastructureConsiderationsData!.connectivityRequirements
                  .isNotEmpty)
                _buildReqRow('Connectivity',
                    data.infrastructureConsiderationsData!.connectivityRequirements),
            ],
          ],
        ],
      ),
    );
  }

  /// Render a multi-line text block with proper wrapping. When
  /// [isOverride] is true, show a small "Charter override" badge so
  /// the user can see the section has been tailored away from the
  /// preferred-solution source.
  Widget _buildTextBlock(String text, bool isOverride) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isOverride)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: BrandColors.tertiaryFixed,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Charter override',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: BrandColors.tertiary,
                ),
              ),
            ),
          ),
        Text(
          text,
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
      ],
    );
  }

  /// Open a dialog that lets the user edit the charter-side override
  /// for one of the two sections (IT considerations or Infrastructure).
  ///
  /// The dialog shows:
  ///   - The preferred-solution source text (read-only, for reference)
  ///   - A multiline text field pre-filled with the current display
  ///     text (which is the override if set, else the preferred text)
  ///   - A "Reset to preferred solution" button (only when an
  ///     override is active)
  ///   - Save / Cancel buttons
  Future<void> _editSection({
    required String title,
    required String fieldLabel,
    required String currentText,
    required String preferredText,
    required bool isOverride,
    required void Function(String)? onSave,
    required VoidCallback? onClear,
  }) async {
    final controller = TextEditingController(text: currentText);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final canReset = isOverride && onClear != null;
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Edit $title')),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This section is sourced from the preferred solution. '
                  'The Business Case is locked, but you can tailor the '
                  'wording shown in the charter below.',
                  style: TextStyle(
                    fontSize: 12,
                    color: BrandColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                if (preferredText.isNotEmpty) ...[
                  const Text(
                    'Preferred solution source text (read-only):',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: BrandColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: BrandColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: BrandColors.outlineVariant),
                    ),
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: SingleChildScrollView(
                      child: Text(
                        preferredText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: BrandColors.onSurfaceVariant,
                          height: 1.4,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  fieldLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  maxLines: 8,
                  minLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter the text to display in the charter…',
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (canReset)
              TextButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop('__reset__');
                },
                icon: const Icon(Icons.restart_alt, size: 16),
                label: const Text('Reset to preferred solution'),
                style: TextButton.styleFrom(
                  foregroundColor: BrandColors.error,
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop(controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    if (result == '__reset__') {
      if (onClear != null) onClear();
      return;
    }
    if (onSave != null) onSave(result);
  }

  /// Build the IT considerations text from the FEP IT Considerations
  /// page data (used when no preferred solution is locked yet).
  String? _fepITText(ITConsiderationsData? it) {
    if (it == null) return null;
    final parts = <String>[];
    if (it.hardwareRequirements.isNotEmpty) {
      parts.add('Hardware: ${it.hardwareRequirements}');
    }
    if (it.softwareRequirements.isNotEmpty) {
      parts.add('Software: ${it.softwareRequirements}');
    }
    if (it.networkRequirements.isNotEmpty) {
      parts.add('Network: ${it.networkRequirements}');
    }
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  /// Build the Infrastructure text from the FEP Infrastructure
  /// Considerations page data (used when no preferred solution is
  /// locked yet).
  String? _fepInfraText(InfrastructureConsiderationsData? infra) {
    if (infra == null) return null;
    final parts = <String>[];
    if (infra.physicalSpaceRequirements.isNotEmpty) {
      parts.add('Space: ${infra.physicalSpaceRequirements}');
    }
    if (infra.powerCoolingRequirements.isNotEmpty) {
      parts.add('Power/Cooling: ${infra.powerCoolingRequirements}');
    }
    if (infra.connectivityRequirements.isNotEmpty) {
      parts.add('Connectivity: ${infra.connectivityRequirements}');
    }
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  Widget _buildReqRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, String subtitle,
      IconData icon, Color accentColor, Color bgColor) {
    // Helper text to disambiguate "0" counts — tells the user whether
    // the count is genuinely zero or just not yet captured.
    final helper = count == 0
        ? 'No records added yet. Use "View Preferred Solution" to add.'
        : null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: kCardBorderDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: accentColor)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor.withValues(alpha: 0.8))),
                if (helper != null) ...[
                  const SizedBox(height: 6),
                  Text(helper,
                      style: TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: accentColor.withValues(alpha: 0.65),
                          height: 1.3)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 7. Tentative Schedule Timeline ───

class CharterScheduleTimeline extends StatelessWidget {
 final ProjectDataModel? data;

 const CharterScheduleTimeline({super.key, required this.data});

 @override
 Widget build(BuildContext context) {
 if (data == null) return const SizedBox();

 final milestones =
 data!.keyMilestones.where((m) => m.dueDate.isNotEmpty).toList();
 if (milestones.isEmpty) return const SizedBox();

 // Sort by date
 milestones.sort((a, b) {
 final da = DateTime.tryParse(a.dueDate) ?? DateTime.now();
 final db = DateTime.tryParse(b.dueDate) ?? DateTime.now();
 return da.compareTo(db);
 });

 return Container(
 padding: const EdgeInsets.all(20),
 decoration: kCardBorderDecoration,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 sectionTitleWithIcon(
 Icons.schedule_outlined, 'Tentative Schedule'),
 const SizedBox(height: 24),
 // Timeline
 ...milestones.asMap().entries.map((entry) {
 final index = entry.key;
 final m = entry.value;
 final mDate = DateTime.tryParse(m.dueDate);
 final isCompleted =
 mDate != null && mDate.isBefore(DateTime.now());
 final isLast = index == milestones.length - 1;

 return _TimelineItem(
 name: m.name,
 description: m.discipline.isNotEmpty ? m.discipline : '',
 date: mDate != null ? DateFormat('MMM d, yyyy').format(mDate) : 'TBD',
 isCompleted: isCompleted,
 isLast: isLast,
 );
 }),
 ],
 ),
 );
 }
}

class _TimelineItem extends StatelessWidget {
 final String name;
 final String description;
 final String date;
 final bool isCompleted;
 final bool isLast;

 const _TimelineItem({
 required this.name,
 required this.description,
 required this.date,
 required this.isCompleted,
 required this.isLast,
 });

 @override
 Widget build(BuildContext context) {
 return IntrinsicHeight(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Timeline line + dot
 SizedBox(
 width: 32,
 child: Column(
 children: [
 // Dot
 Container(
 width: 16,
 height: 16,
 decoration: BoxDecoration(
 color: isCompleted ? BrandColors.primary : Colors.white,
 shape: BoxShape.circle,
 border: Border.all(
 color: isCompleted
 ? BrandColors.primary
 : BrandColors.outline,
 width: 2,
 ),
 ),
 child: isCompleted
 ? const Icon(Icons.check, size: 10, color: Colors.white)
 : null,
 ),
 // Line
 if (!isLast)
 Expanded(
 child: Container(
 width: 2,
 color: BrandColors.outlineVariant,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 16),
 // Content
 Expanded(
 child: Padding(
 padding: const EdgeInsets.only(bottom: 20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 name,
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: isCompleted
 ? BrandColors.onSurface
 : BrandColors.onSurfaceVariant,
 ),
 ),
 if (description.isNotEmpty) ...[
 const SizedBox(height: 2),
 Text(
 description,
 style: const TextStyle(
 fontSize: 13,
 color: BrandColors.onSurfaceVariant,
 height: 1.4,
 ),
 ),
 ],
 const SizedBox(height: 4),
 Text(
 date,
 style: const TextStyle(
 fontSize: 12,
 color: BrandColors.outline,
 fontWeight: FontWeight.w500,
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }
}

// ─── 8. Floating Approval Action Bar ───

class CharterFloatingApprovalBar extends StatefulWidget {
  final ProjectDataModel? data;

  const CharterFloatingApprovalBar({super.key, required this.data});

  @override
  State<CharterFloatingApprovalBar> createState() =>
      _CharterFloatingApprovalBarState();
}

class _CharterFloatingApprovalBarState
    extends State<CharterFloatingApprovalBar> {
  List<UserModel> _allUsers = const [];
  ResolvedApprover _resolved = ResolvedApprover.empty;
  bool _resolving = false;
  bool _sendingEmail = false;

  @override
  void initState() {
    super.initState();
    _loadUsersAndResolve();
  }

  @override
  void didUpdateWidget(covariant CharterFloatingApprovalBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-resolve when the underlying data changes (e.g. user just named
    // a sponsor on the meta-info card).
    if (oldWidget.data?.charterProjectSponsorName !=
            widget.data?.charterProjectSponsorName ||
        oldWidget.data?.charterProjectManagerName !=
            widget.data?.charterProjectManagerName ||
        oldWidget.data?.charterEmail != widget.data?.charterEmail) {
      _resolveFromCachedUsers();
    }
  }

  Future<void> _loadUsersAndResolve() async {
    if (_resolving) return;
    setState(() => _resolving = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .limit(200)
          .get();
      final users =
          snap.docs.map((d) => UserModel.fromJson(d.data())).toList();
      if (!mounted) return;
      setState(() {
        _allUsers = users;
        _resolved = widget.data == null
            ? ResolvedApprover.empty
            : CharterApprovalService.resolveApprover(
                data: widget.data!, allUsers: users);
        _resolving = false;
      });
    } catch (e) {
      debugPrint('CharterFloatingApprovalBar: user load failed: $e');
      if (mounted) {
        setState(() {
          _resolved = widget.data == null
              ? ResolvedApprover.empty
              : CharterApprovalService.resolveApprover(
                  data: widget.data!, allUsers: const []);
          _resolving = false;
        });
      }
    }
  }

  void _resolveFromCachedUsers() {
    if (widget.data == null) return;
    setState(() {
      _resolved = CharterApprovalService.resolveApprover(
          data: widget.data!, allUsers: _allUsers);
    });
  }

  Future<void> _sendApprovalRequestEmail() async {
    final data = widget.data;
    if (data == null) return;
    if (!_resolved.hasEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No email address on file for the resolved approver. Assign a sponsor or project manager with an email first.'),
          backgroundColor: Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _sendingEmail = true);
    try {
      // Construct a deep link to the Project Charter screen so the email's
      // "Review & Approve Charter →" button lands the sponsor on the actual
      // charter page (where they can review and tap "Click to Approve") —
      // not on the bare homepage where nothing happens. The GoRouter route
      // `/project-charter` resolves to ProjectCharterScreen, and Flutter web
      // uses hash-based routing by default so the URL is `/#/project-charter`.
      // projectId is appended as a query param so the charter screen can
      // pre-select the right project when the sponsor has multiple.
      final projectId = (data.projectId ?? '').trim();
      final deepLinkUrl = projectId.isEmpty
          ? 'https://nduproject.tech/#/project-charter'
          : 'https://nduproject.tech/#/project-charter?projectId=$projectId';
      final result = await CharterApprovalService.sendApprovalRequestEmail(
        data: data,
        approver: _resolved,
        deepLinkUrl: deepLinkUrl,
      );
      if (!mounted) return;
      final msg = switch (result.result) {
        CharterEmailSendResult.queued =>
          'Approval request email queued for ${_resolved.name} (${_resolved.email}). They will receive an email shortly.',
        CharterEmailSendResult.mailtoGenerated =>
          'Opening your email client to send the approval request to ${_resolved.name} (${_resolved.email}).',
        CharterEmailSendResult.noApproverEmail =>
          'No email address on file for the resolved approver.',
        CharterEmailSendResult.failed =>
          'Could not queue the email: ${result.error ?? "unknown error"}',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: result.result == CharterEmailSendResult.queued ||
                  result.result == CharterEmailSendResult.mailtoGenerated
              ? Colors.green
              : const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: result.mailtoUri != null
              ? SnackBarAction(
                  label: 'Copy email link',
                  textColor: Colors.white,
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: result.mailtoUri!));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Email link copied to clipboard. Paste it into your browser address bar to open your email client.'),
                        duration: Duration(seconds: 6),
                      ),
                    );
                  },
                )
              : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send approval email: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isApproved = data?.charterApprovalDate != null ||
        (data?.frontEndPlanning.charterApproved ?? false);

    // Prefer the resolved approver (which knows about registered
    // users and the admin fallback), fall back to the raw charter
    // fields for display.
    //
    // After approval, we show the actual approver — the resolved
    // name if available, otherwise the named sponsor/PM, otherwise
    // the currently signed-in user (who must have approved since
    // they clicked the Approve button).
    String signerName;
    String signerRole;
    if (_resolved.name.isNotEmpty &&
        _resolved.name != 'Pending Assignment') {
      signerName = _resolved.name;
      signerRole = _resolved.role;
    } else if ((data?.charterProjectSponsorName ?? '').isNotEmpty) {
      signerName = data!.charterProjectSponsorName;
      signerRole = 'Project Sponsor';
    } else if ((data?.charterProjectManagerName ?? '').isNotEmpty) {
      signerName = data!.charterProjectManagerName;
      signerRole = 'Project Owner';
    } else if (isApproved) {
      // Charter was approved but no sponsor/PM was named — use the
      // currently signed-in user as the approver of record. This
      // fixes the bug where the bottom bar shows "Pending
      // Assignment (Project Owner)" even after the user approved.
      final currentUser = FirebaseAuth.instance.currentUser;
      final dn = (currentUser?.displayName ?? '').trim();
      final em = (currentUser?.email ?? '').trim();
      signerName = dn.isNotEmpty ? dn : (em.isNotEmpty ? em : 'Approver');
      signerRole = 'Project Owner (signed-in user)';
    } else {
      signerName = 'Pending Assignment';
      signerRole = 'Pending Assignment';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: BrandColors.inverseSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            offset: const Offset(0, -4),
            blurRadius: 12,
          )
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: LayoutBuilder(builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final info = _buildApprovalInfo(signerName, signerRole, isApproved);
            final emailBtn = _buildEmailButton();
            final approveBtn = _buildApproveButton(context, signerName, isApproved);
            final actions = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (emailBtn != null) ...[emailBtn, const SizedBox(width: 8)],
                approveBtn,
              ],
            );
            if (isMobile) {
              return Column(
                children: [
                  info,
                  const SizedBox(height: 12),
                  actions,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: 12),
                actions,
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildApprovalInfo(
      String signerName, String signerRole, bool isApproved) {
    // After approval, the message changes to "Charter approved by …".
    // Before approval, it tells the user who the approver is and that
    // the charter needs their sign-off.
    final message = isApproved
        ? 'Charter approved by $signerName ($signerRole) — Front End Planning is now locked'
        : 'Approval Authority: $signerName ($signerRole) — Charter to be approved by sponsor, owner or applicable lead';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isApproved ? Icons.lock_outline : Icons.gavel_outlined,
          size: 18,
          color: Colors.white70,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isApproved) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text('APPROVED',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget? _buildEmailButton() {
    final data = widget.data;
    if (data == null) return null;
    final isApproved = data.charterApprovalDate != null ||
        (data.frontEndPlanning.charterApproved ?? false);
    if (isApproved) return null;

    final hasApproverEmail = _resolved.hasEmail;
    final label = _resolved.isFallback
        ? 'Email Site Admin'
        : (_resolved.isRegisteredUser
            ? 'Email Approver'
            : 'Email Sponsor');

    return InkWell(
      onTap: _sendingEmail ? null : () => _sendApprovalRequestEmail(),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_sendingEmail)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(
                hasApproverEmail
                    ? Icons.mail_outline_rounded
                    : Icons.person_add_alt_outlined,
                size: 16,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            const SizedBox(width: 6),
            Text(
              _sendingEmail ? 'Sending…' : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApproveButton(
      BuildContext context, String signerName, bool isApproved) {
    if (isApproved) return const SizedBox();

    return InkWell(
      onTap: () => _showApprovalConfirmationDialog(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [BrandColors.primary, BrandColors.primaryContainer],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: BrandColors.primary.withValues(alpha: 0.3),
              offset: const Offset(0, 2),
              blurRadius: 8,
            )
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Click to Approve',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showApprovalConfirmationDialog() async {
    final data = widget.data;
    if (data == null) return;
    // Per Task 24: charter approval must NOT proceed if a sponsor is not
    // explicitly assigned. Previously the check only blocked when BOTH
    // sponsor AND PM were empty, which let users approve with just a PM
    // set — leaving the Sponsor card showing "Assign Sponsor" after
    // approval. Now: sponsor is strictly required.
    if (data.charterProjectSponsorName.isEmpty) {
      // Try to suggest a sponsor on the fly (highest role authority).
      ResolvedApprover? suggestion;
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .limit(200)
            .get();
        final users =
            snap.docs.map((d) => UserModel.fromJson(d.data())).toList();
        suggestion = CharterApprovalService.suggestSponsor(allUsers: users);
      } catch (e) {
        debugPrint('On-the-fly sponsor suggestion failed: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            suggestion != null && suggestion.name != 'Pending Assignment'
                ? 'A sponsor must be identified before approving. Suggested: '
                    '${suggestion.name} (${suggestion.role}). Tap the '
                    '"Assign Sponsor" card to assign them.'
                : 'A sponsor must be identified before approving. Tap the '
                    '"Assign Sponsor" card to assign one (or invite an '
                    'external sponsor via email).'),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
      return;
    }

    bool smeReviewed = false;
    bool sponsorConfirmed = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.gavel_outlined,
                  color: BrandColors.primary, size: 22),
              SizedBox(width: 10),
              Text('Confirm Charter Approval'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Charter to be approved by sponsor, owner or applicable lead. '
                  'Confirm the following before approving:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 14),
                CheckboxListTile(
                  value: smeReviewed,
                  onChanged: (v) =>
                      setDialogState(() => smeReviewed = v ?? false),
                  title: const Text(
                    'I confirm the applicable subject matter experts have reviewed all relevant sections of the Front End Execution Plan.',
                    style: TextStyle(fontSize: 12),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                CheckboxListTile(
                  value: sponsorConfirmed,
                  onChanged: (v) =>
                      setDialogState(() => sponsorConfirmed = v ?? false),
                  title: const Text(
                    'I am the project sponsor, owner, or applicable lead and I am authorized to approve this charter.',
                    style: TextStyle(fontSize: 12),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Once approved, the Front End Planning sections will be locked and the Planning phase will be unlocked.',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFD97706),
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (smeReviewed && sponsorConfirmed)
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm & Approve'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _approveCharter();
    }
  }

  Future<void> _approveCharter() async {
    final provider = ProjectDataInherited.maybeOf(context);
    if (provider == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to find project context.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    provider.updateField((data) => data.copyWith(
          charterApprovalDate: DateTime.now(),
          frontEndPlanning: data.frontEndPlanning.copyWith(
            charterApproved: true,
            charterApprovedAt: DateTime.now(),
          ),
        ));

    // Retry cloud sync up to 3 times to avoid the "Approval saved
    // locally, but cloud sync failed" message.
    bool success = false;
    String? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        success = await provider.saveToFirebase(
          checkpoint: 'project_charter',
        );
        if (success) break;
      } catch (e) {
        lastError = e.toString();
      }
      await Future.delayed(const Duration(milliseconds: 800));
    }

    if (!mounted) return;
    if (success) {
      // Re-resolve the approver now that the charter is approved, so
      // the bottom bar updates immediately to show the approver's
      // name instead of "Pending Assignment".
      _resolveFromCachedUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Project charter approved. Front End Planning is now locked and the Planning phase is unlocked.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Approval saved locally but cloud sync failed after 3 retries. Please check your network connection and tap Approve again to retry. Error: $lastError'),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
    }
  }
}

// ─── Legacy// ─── Legacy/Kept widgets for compatibility ───

class CharterExecutiveSnapshot extends StatelessWidget {
 final ProjectDataModel? data;
 const CharterExecutiveSnapshot({super.key, required this.data});

 @override
 Widget build(BuildContext context) {
 return CharterDashboardStats(data: data);
 }
}

class CharterExecutiveSummary extends StatelessWidget {
 final ProjectDataModel? data;
 const CharterExecutiveSummary({super.key, required this.data});

 @override
 Widget build(BuildContext context) {
 return Column(
 children: [
 CharterHeroHeader(data: data),
 const SizedBox(height: 16),
 CharterMetaInfoScroll(data: data),
 ],
 );
 }
}

class CharterFinancialSnapshot extends StatelessWidget {
 final ProjectDataModel? data;
 const CharterFinancialSnapshot({super.key, required this.data});

 @override
 Widget build(BuildContext context) {
 return CharterFinancialOverview(data: data);
 }
}

class CharterMilestoneVisualizer extends StatelessWidget {
 final ProjectDataModel? data;
 const CharterMilestoneVisualizer({super.key, required this.data});

 @override
 Widget build(BuildContext context) {
 return CharterScheduleTimeline(data: data);
 }
}

class CharterScheduleTable extends StatelessWidget {
 final ProjectDataModel? data;
 const CharterScheduleTable({super.key, required this.data});

 @override
 Widget build(BuildContext context) {
 return CharterScheduleTimeline(data: data);
 }
}

class CharterCostChart extends StatelessWidget {
 final ProjectDataModel? data;
 const CharterCostChart({super.key, required this.data});

 @override
 Widget build(BuildContext context) {
 return const SizedBox();
 }
}

class CharterResources extends StatelessWidget {
 final ProjectDataModel? data;
 const CharterResources({super.key, required this.data});

 @override
 Widget build(BuildContext context) {
 return const SizedBox();
 }
}

class CharterTechnicalEnvironment extends StatelessWidget {
 final ProjectDataModel? data;
 final VoidCallback? onGenerate;

 const CharterTechnicalEnvironment(
 {super.key, required this.data, this.onGenerate});

 @override
 Widget build(BuildContext context) {
 return CharterTechnicalProcurementBento(
 data: data, onGenerate: onGenerate);
 }
}

class CharterStakeholders extends StatelessWidget {
 final ProjectDataModel? data;
 const CharterStakeholders({super.key, required this.data});

 @override
 Widget build(BuildContext context) {
 return const SizedBox();
 }
}

// ─── Assumptions (Collapsible) ───

class CharterAssumptions extends StatefulWidget {
 final ProjectDataModel? data;
 const CharterAssumptions({super.key, required this.data});

 @override
 State<CharterAssumptions> createState() => _CharterAssumptionsState();
}

class _CharterAssumptionsState extends State<CharterAssumptions> {
 bool _expanded = false;

 @override
 Widget build(BuildContext context) {
 if (widget.data == null) return const SizedBox();

 final assumptions = widget.data!.assumptions
 .where((a) => a.trim().isNotEmpty)
 .toList();
 final constraints = widget.data!.constraints
 .where((c) => c.trim().isNotEmpty)
 .toList();

 if (assumptions.isEmpty && constraints.isEmpty) return const SizedBox();

 return Container(
 padding: const EdgeInsets.all(20),
 decoration: kCardBorderDecoration,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 InkWell(
 onTap: () => setState(() => _expanded = !_expanded),
 child: Row(
 children: [
 const Icon(Icons.lightbulb_outline,
 size: 20, color: BrandColors.tertiaryFixedDim),
 const SizedBox(width: 8),
 const Text(
 'Assumptions & Constraints',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w600,
 color: BrandColors.onSurface,
 ),
 ),
 const Spacer(),
 Icon(
 _expanded
 ? Icons.expand_less
 : Icons.expand_more,
 color: BrandColors.onSurfaceVariant,
 ),
 ],
 ),
 ),
 if (_expanded) ...[
 const SizedBox(height: 16),
 if (assumptions.isNotEmpty) ...[
 labelStyle('Assumptions'),
 const SizedBox(height: 8),
 ...assumptions.take(5).map((a) => Padding(
 padding: const EdgeInsets.only(bottom: 6),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('• ',
 style: TextStyle(
 fontSize: 12,
 color: BrandColors.onSurfaceVariant)),
 Expanded(
 child: Text(a,
 style: const TextStyle(
 fontSize: 13,
 color: BrandColors.onSurface))),
 ],
 ),
 )),
 ],
 if (constraints.isNotEmpty) ...[
 const SizedBox(height: 16),
 labelStyle('Constraints'),
 const SizedBox(height: 8),
 ...constraints.take(5).map((c) => Padding(
 padding: const EdgeInsets.only(bottom: 6),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('• ',
 style: TextStyle(
 fontSize: 12,
 color: BrandColors.onSurfaceVariant)),
 Expanded(
 child: Text(c,
 style: const TextStyle(
 fontSize: 13,
 color: BrandColors.onSurface))),
 ],
 ),
 )),
 ],
 ],
 ],
 ),
 );
 }
}

/// Beautiful visual walkthrough shown when no Project Manager is assigned.
class AssignManagerWalkthrough extends StatefulWidget {
 final VoidCallback onAssignTapped;
 const AssignManagerWalkthrough({super.key, required this.onAssignTapped});

 @override
 State<AssignManagerWalkthrough> createState() => _AssignManagerWalkthroughState();
}

class _AssignManagerWalkthroughState extends State<AssignManagerWalkthrough>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bobController;

  @override
  void initState() {
    super.initState();
    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8E1), Color(0xFFFFE8A3)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5C518), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFFFC812),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_add_alt_1, color: Colors.black, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Assign your Project Manager',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Required',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Before you can move forward in the Project Charter, you need to assign a Project Manager. Here\'s how:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF5B4300)),
                ),
                const SizedBox(height: 12),
                _walkthroughStep(1, 'Tap the "PROJECT MANAGER" card below', Icons.touch_app_outlined),
                _walkthroughStep(2, 'Enter the manager\'s name in the dialog', Icons.edit_outlined),
                _walkthroughStep(3, 'Click "Assign" — you\'re all set!', Icons.check_circle_outline),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: widget.onAssignTapped,
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('Assign Manager Now'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC812),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _bobController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _bobController.value * 6 - 3),
                child: child,
              );
            },
            child: const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(Icons.south, color: Color(0xFFB45309), size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _walkthroughStep(int n, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(color: Color(0xFFFFC812), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 16, color: const Color(0xFF5B4300)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)))),
        ],
      ),
    );
  }
}
