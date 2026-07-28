import 'package:flutter/material.dart';
import 'package:ndu_project/screens/basic_plan_dashboard_screen.dart';
import 'program_dashboard_screen.dart';
import '../widgets/app_logo.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'portfolio_dashboard_screen.dart';
import 'project_dashboard_screen.dart';

class ManagementLevelScreen extends StatefulWidget {
 const ManagementLevelScreen({super.key});

 @override
 State<ManagementLevelScreen> createState() => _ManagementLevelScreenState();
}

class _ManagementLevelScreenState extends State<ManagementLevelScreen> {
 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: Colors.white,
 body: Stack(
 children: [
 SafeArea(
 child: _buildMainContent(context),
 ),
 const KazAiChatBubble(),
 ],
 ),
 );
 }

 Widget _buildMainContent(BuildContext context) {
 return LayoutBuilder(
 builder: (context, constraints) {
 final isCompact = constraints.maxWidth < 900;
 final horizontalPadding = isCompact ? 24.0 : 40.0;
 final topSpacing = isCompact ? 40.0 : 80.0;
 final cardSpacing = isCompact ? 20.0 : 60.0;
 final availableWidth = constraints.maxWidth - (horizontalPadding * 2);
 final columns = availableWidth >= 1100
 ? 3
 : availableWidth >= 720
 ? 2
 : 1;
 final cardWidth = columns == 1
 ? availableWidth
 : (availableWidth - (cardSpacing * (columns - 1))) / columns;
 final shouldFill = constraints.maxHeight >= 720 && columns >= 2;

 final headerBlock = Column(
 children: [
 SizedBox(height: topSpacing),
 AppLogo(
 height: isCompact ? 180 : 240,
 ),
 const SizedBox(height: 32),
 const Text(
 'Choose Your Management Level',
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: 36,
 fontWeight: FontWeight.w600,
 color: Colors.black,
 ),
 ),
 const SizedBox(height: 16),
 Text(
 'Select the scope of work you want to manage:',
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: 18,
 color: Colors.grey[600],
 ),
 ),
 ],
 );

 final cardsBlock = Wrap(
 alignment: columns == 1 ? WrapAlignment.center : WrapAlignment.spaceBetween,
 spacing: cardSpacing,
 runSpacing: cardSpacing,
 children: [
 _buildManagementCardWithImage(
 width: cardWidth,
 imageUrl: 'assets/images/project-management.png',
 title: 'Basic',
 onTap: () {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (context) => const BasicPlanDashboardScreen(),
 ),
 );
 },
 ),
 _buildManagementCardWithImage(
 width: cardWidth,
 imageUrl: 'assets/images/project-management.png',
 title: 'Project',
 onTap: () {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (context) => const ProjectDashboardScreen(),
 ),
 );
 },
 ),
 _buildManagementCardWithImage(
 width: cardWidth,
 imageUrl: 'assets/images/monitoring.png',
 title: 'Program',
 onTap: () {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (context) => const ProgramDashboardScreen(),
 ),
 );
 },
 ),
 _buildManagementCardWithImage(
 width: cardWidth,
 imageUrl: 'assets/images/professional-portfolio.png',
 title: 'Portfolio',
 onTap: () {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (context) => const PortfolioDashboardScreen(),
 ),
 );
 },
 ),
 ],
 );

 final content = Column(
 children: [
 headerBlock,
 if (!shouldFill) SizedBox(height: topSpacing),
 if (shouldFill) const Spacer(),
 cardsBlock,
 const SizedBox(height: 24),
 ],
 );

 if (shouldFill) {
 return Padding(
 padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 32),
 child: SizedBox(
 height: constraints.maxHeight,
 child: content,
 ),
 );
 }

 return SingleChildScrollView(
 padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 32),
 child: content,
 );
 },
 );
 }

 Widget _buildManagementCardWithImage({
 double? width,
 required String imageUrl,
 required String title,
 VoidCallback? onTap,
 }) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(12),
 child: Container(
 width: width ?? 200,
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: Colors.grey.withOpacity(0.18)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.06),
 blurRadius: 12,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 // Image area with consistent aspect ratio and high-quality scaling
 LayoutBuilder(
 builder: (context, constraints) {
 final dpr = MediaQuery.devicePixelRatioOf(context);
 final targetLogicalWidth = 120.0; // visible logical px we aim for
 final cacheWidth = (targetLogicalWidth * dpr).round();

 Widget imageChild;
 if (imageUrl.toLowerCase().startsWith('http')) {
 imageChild = Image.network(
 imageUrl,
 fit: BoxFit.contain,
 filterQuality: FilterQuality.high,
 errorBuilder: (context, error, stackTrace) {
 return _imageFallback();
 },
 );
 } else {
 imageChild = Image.asset(
 imageUrl,
 fit: BoxFit.contain,
 filterQuality: FilterQuality.high,
 cacheWidth: cacheWidth,
 errorBuilder: (context, error, stackTrace) {
 return _imageFallback();
 },
 );
 }

 return Container(
 width: targetLogicalWidth,
 height: 96,
 alignment: Alignment.center,
 decoration: BoxDecoration(
 color: Colors.grey.withOpacity(0.06),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Padding(
 padding: const EdgeInsets.all(8.0),
 child: RepaintBoundary(
 child: ClipRRect(
 borderRadius: BorderRadius.circular(8),
 child: imageChild,
 ),
 ),
 ),
 );
 },
 ),
 const SizedBox(height: 16),
 Text(
 title,
 textAlign: TextAlign.center,
 style: const TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w600,
 color: Colors.black,
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _imageFallback() {
 return Container(
 decoration: BoxDecoration(
 color: Colors.grey.withOpacity(0.12),
 borderRadius: BorderRadius.circular(8),
 ),
 alignment: Alignment.center,
 child: const Icon(
 Icons.image_outlined,
 size: 40,
 color: Colors.grey,
 ),
 );
 }

}
