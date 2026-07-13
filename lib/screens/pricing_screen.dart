import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/screens/basic_plan_dashboard_screen.dart';
import 'package:ndu_project/screens/program_dashboard_screen.dart';
import 'package:ndu_project/screens/portfolio_dashboard_screen.dart';
import 'package:ndu_project/screens/project_dashboard_screen.dart';
import 'package:ndu_project/services/subscription_service.dart';
import 'package:ndu_project/services/subscription_pricing_service.dart';
import 'package:ndu_project/services/user_preferences_service.dart';
import 'package:ndu_project/widgets/payment_dialog.dart';

const Color _pageBackground = Color(0xFFFFFFFF);
const Color _primaryText = Color(0xFF0F0F0F);
const Color _secondaryText = Color(0xFF5A5C60);
const Color _themeColor = Color(0xFFF4B400); // Unified golden theme
const Color _themeSurface = Color(0xFFFFF7E6); // Soft warm backdrop

class PricingScreen extends StatefulWidget {
 const PricingScreen({super.key});

 @override
 State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
 static final NumberFormat _currencyFormatter = NumberFormat.currency(
 symbol: UserPreferencesService.currencySymbolSync,
 decimalDigits: 0,
 );
 _PlanTier _selectedTier = _PlanTier.program;
 // ignore: unused_field
 bool _isCheckingSubscription = false;
 bool _isAnnual = false;

 /// Admin-configured pricing (loaded from Firestore). Falls back to defaults.
 SubscriptionPricingConfig _pricingConfig = SubscriptionPricingConfig.defaults;
 Stream<SubscriptionPricingConfig>? _pricingStream;

 @override
 void initState() {
 super.initState();
 _pricingStream = SubscriptionPricingService.watch();
 _pricingStream!.listen((config) {
 if (mounted) setState(() => _pricingConfig = config);
 });
 }

 /// Builds the plans list from the admin-configured pricing, falling back to
 /// the hardcoded defaults if the config hasn't loaded yet.
 List<_PricingPlan> get _dynamicPlans {
 final tiers = _pricingConfig.tiers;
 return [
 _tierToPlan(tiers[PricingTierId.basicProject] ?? TierPricingConfig.defaultBasicProject),
 _tierToPlan(tiers[PricingTierId.project] ?? TierPricingConfig.defaultProject),
 _tierToPlan(tiers[PricingTierId.program] ?? TierPricingConfig.defaultProgram),
 _tierToPlan(tiers[PricingTierId.portfolio] ?? TierPricingConfig.defaultPortfolio),
 ];
 }

 _PricingPlan _tierToPlan(TierPricingConfig tier) {
 return _PricingPlan(
 tier: _convertTier(tier.id),
 label: tier.label,
 badgeColor: _themeColor,
 subtitle: tier.subtitle,
 monthlyPrice: tier.monthlyPrice.toDouble(),
 monthlyOriginalPrice: tier.monthlyOriginalPrice.toDouble(),
 features: tier.features,
 );
 }

 _PlanTier _convertTier(PricingTierId id) {
 switch (id) {
 case PricingTierId.basicProject:
 return _PlanTier.basicProject;
 case PricingTierId.project:
 return _PlanTier.project;
 case PricingTierId.program:
 return _PlanTier.program;
 case PricingTierId.portfolio:
 return _PlanTier.portfolio;
 }
 }

 Future<void> _handlePlanSelection(BuildContext context, _PricingPlan plan) async {
 setState(() => _isCheckingSubscription = true);
 final navigator = Navigator.of(context);
 final messenger = ScaffoldMessenger.of(context);
 
 try {
 final isBasicPlan = plan.tier == _PlanTier.basicProject;
 final subscriptionTier = _convertToSubscriptionTier(plan.tier);
 final hasSubscription = await SubscriptionService.hasActiveSubscription(tier: subscriptionTier);
 
 if (!context.mounted) return;
 
 if (hasSubscription) {
 _navigateToManagementLevel(navigator, isBasicPlan: isBasicPlan, tier: plan.tier);
 } else {
 final price = _priceForPlan(plan);
 final paymentResult = await PaymentDialog.show(
 context: context,
 tier: subscriptionTier,
 isAnnual: _isAnnual,
 displayTierName: plan.label,
 displayPrice: price.price,
 displayPeriod: _isAnnual ? 'Billed annually' : 'Billed monthly',
 pricingTierId: _pricingTierIdFor(plan.tier),
 onPaymentComplete: () {
 if (!mounted) return;
 messenger.showSnackBar(
 const SnackBar(
 content: Text('Subscription activated successfully!'),
 backgroundColor: Color(0xFF22C55E),
 ),
 );
 },
 );
 
 if (!context.mounted) return;
 if (paymentResult) {
 _navigateToManagementLevel(navigator, isBasicPlan: isBasicPlan, tier: plan.tier);
 }
 }
 } catch (e) {
 if (!mounted) return;
 messenger.showSnackBar(
 SnackBar(content: Text('Error checking subscription: $e'), backgroundColor: Colors.red),
 );
 } finally {
 if (mounted) setState(() => _isCheckingSubscription = false);
 }
 }
 
 SubscriptionTier _convertToSubscriptionTier(_PlanTier tier) {
 switch (tier) {
 case _PlanTier.basicProject:
 return SubscriptionTier.project;
 case _PlanTier.project:
 return SubscriptionTier.project;
 case _PlanTier.program:
 return SubscriptionTier.program;
 case _PlanTier.portfolio:
 return SubscriptionTier.portfolio;
 }
 }

 /// Map the internal [_PlanTier] enum to the editable pricing config's
 /// [PricingTierId] so the payment dialog can load admin-set add-on prices.
 PricingTierId _pricingTierIdFor(_PlanTier tier) {
 switch (tier) {
 case _PlanTier.basicProject:
 return PricingTierId.basicProject;
 case _PlanTier.project:
 return PricingTierId.project;
 case _PlanTier.program:
 return PricingTierId.program;
 case _PlanTier.portfolio:
 return PricingTierId.portfolio;
 }
 }
 
 void _navigateToManagementLevel(NavigatorState navigator, {bool isBasicPlan = false, _PlanTier? tier}) {
 // Navigate directly to the appropriate dashboard based on the plan tier,
 // skipping the Management Level selection screen.
 Widget screen;
 if (isBasicPlan || tier == _PlanTier.basicProject) {
 screen = const BasicPlanDashboardScreen();
 } else if (tier == _PlanTier.program) {
 screen = const ProgramDashboardScreen();
 } else if (tier == _PlanTier.portfolio) {
 screen = const PortfolioDashboardScreen();
 } else {
 // Default: Project dashboard
 screen = const ProjectDashboardScreen();
 }
 navigator.push(MaterialPageRoute(builder: (_) => screen));
 }

 _PlanPrice _priceForPlan(_PricingPlan plan) {
 final String? note = plan.tier == _PlanTier.basicProject ? 'First month free' : null;
 if (_isAnnual) {
 final double annualPrice = plan.monthlyPrice * 11;
 final double annualOriginal = plan.monthlyPrice * 12;
 return _PlanPrice(
 price: _currencyFormatter.format(annualPrice),
 originalPrice: _currencyFormatter.format(annualOriginal),
 period: 'per year',
 note: note,
 );
 }
 return _PlanPrice(
 price: _currencyFormatter.format(plan.monthlyPrice),
 originalPrice: _currencyFormatter.format(plan.monthlyOriginalPrice),
 period: 'per month',
 note: note,
 );
 }

 @override
 Widget build(BuildContext context) {
 final size = MediaQuery.of(context).size;
 final isDesktop = size.width >= 1200;
 final isTablet = size.width >= 800 && size.width < 1200;

 return Scaffold(
 backgroundColor: _pageBackground,
 body: SafeArea(
 child: SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: isDesktop ? 48 : (isTablet ? 32 : 16),
 vertical: 24,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildHeaderRow(context),
 const SizedBox(height: 32),
 _buildSectionHeader(isDesktop || isTablet),
 const SizedBox(height: 24),
 // Plans grid
 _buildPlansGrid(isDesktop, isTablet),
 const SizedBox(height: 48),
 // All additional pricing sections
 const _PricingExtras(),
 const SizedBox(height: 48),
 ],
 ),
 ),
 ),
 );
 }

 Widget _buildSectionHeader(bool showInlineToggle) {
 final title = Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Simple, Scalable Pricing for Every Level of Project Delivery',
 style: TextStyle(
 fontSize: 36,
 fontWeight: FontWeight.w700,
 color: _primaryText,
 letterSpacing: -0.5,
 height: 1.15,
 ),
 ),
 const SizedBox(height: 10),
 const Text(
 'Whether you\'re managing a single project or an enterprise portfolio, Ndu Project grows with your organization.',
 style: TextStyle(
 fontSize: 15,
 color: _secondaryText,
 height: 1.5,
 ),
 ),
 const SizedBox(height: 8),
 Container(
 height: 6,
 width: 220,
 decoration: BoxDecoration(
 color: _themeColor,
 borderRadius: BorderRadius.circular(999),
 ),
 ),
 ],
 );

 if (showInlineToggle) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 title,
 const Spacer(),
 Column(
 crossAxisAlignment: CrossAxisAlignment.end,
 children: [
 _BillingToggle(
 isAnnual: _isAnnual,
 onChanged: (value) => setState(() => _isAnnual = value),
 ),
 const SizedBox(height: 8),
 const Text(
 'Annual will save 1 month\'s payment',
 style: TextStyle(
 color: _secondaryText,
 fontSize: 12,
 fontWeight: FontWeight.w600,
 ),
 ),
 ],
 ),
 ],
 );
 }

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 title,
 const SizedBox(height: 12),
 _BillingToggle(
 isAnnual: _isAnnual,
 onChanged: (value) => setState(() => _isAnnual = value),
 ),
 const SizedBox(height: 8),
 const Text(
 'Annual will save 1 month\'s payment',
 style: TextStyle(
 color: _secondaryText,
 fontSize: 12,
 fontWeight: FontWeight.w600,
 ),
 ),
 ],
 );
 }

 Widget _buildHeaderRow(BuildContext context) {
 return Row(
 children: [
 _BackButton(onPressed: () {
 final navigator = Navigator.of(context);
 if (navigator.canPop()) {
 navigator.maybePop();
 } else {
 // Go to the project dashboard instead of the management level screen
 Navigator.pushReplacement(
 context,
 MaterialPageRoute(builder: (_) => const ProjectDashboardScreen()),
 );
 }
 }),
 const SizedBox(width: 12),
 const Expanded(
 child: Text(
 'Select a plan that fits your needs',
 style: TextStyle(color: _secondaryText, fontWeight: FontWeight.w500),
 ),
 ),
 ],
 );
 }

 Widget _buildPlansGrid(bool isDesktop, bool isTablet) {
 if (isDesktop) {
 // 4 columns on desktop
 return IntrinsicHeight(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: _dynamicPlans.map((plan) => Expanded(
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 8),
 child: _PlanColumn(
 plan: plan,
 isSelected: _selectedTier == plan.tier,
 price: _priceForPlan(plan),
 onSelect: () {
 setState(() => _selectedTier = plan.tier);
 _handlePlanSelection(context, plan);
 },
 ),
 ),
 )).toList(),
 ),
 );
 } else if (isTablet) {
 // 2x2 grid on tablet
 return Column(
 children: [
 IntrinsicHeight(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 Expanded(child: Padding(
 padding: const EdgeInsets.all(8),
 child: _PlanColumn(
 plan: _dynamicPlans[0],
 isSelected: _selectedTier == _dynamicPlans[0].tier,
 price: _priceForPlan(_dynamicPlans[0]),
 onSelect: () {
 setState(() => _selectedTier = _dynamicPlans[0].tier);
 _handlePlanSelection(context, _dynamicPlans[0]);
 },
 ),
 )),
 Expanded(child: Padding(
 padding: const EdgeInsets.all(8),
 child: _PlanColumn(
 plan: _dynamicPlans[1],
 isSelected: _selectedTier == _dynamicPlans[1].tier,
 price: _priceForPlan(_dynamicPlans[1]),
 onSelect: () {
 setState(() => _selectedTier = _dynamicPlans[1].tier);
 _handlePlanSelection(context, _dynamicPlans[1]);
 },
 ),
 )),
 ],
 ),
 ),
 const SizedBox(height: 16),
 IntrinsicHeight(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 Expanded(child: Padding(
 padding: const EdgeInsets.all(8),
 child: _PlanColumn(
 plan: _dynamicPlans[2],
 isSelected: _selectedTier == _dynamicPlans[2].tier,
 price: _priceForPlan(_dynamicPlans[2]),
 onSelect: () {
 setState(() => _selectedTier = _dynamicPlans[2].tier);
 _handlePlanSelection(context, _dynamicPlans[2]);
 },
 ),
 )),
 Expanded(child: Padding(
 padding: const EdgeInsets.all(8),
 child: _PlanColumn(
 plan: _dynamicPlans[3],
 isSelected: _selectedTier == _dynamicPlans[3].tier,
 price: _priceForPlan(_dynamicPlans[3]),
 onSelect: () {
 setState(() => _selectedTier = _dynamicPlans[3].tier);
 _handlePlanSelection(context, _dynamicPlans[3]);
 },
 ),
 )),
 ],
 ),
 ),
 ],
 );
 } else {
 // Single column on mobile
 return Column(
 children: _dynamicPlans.map((plan) => Padding(
 padding: const EdgeInsets.only(bottom: 24),
 child: _PlanColumn(
 plan: plan,
 isSelected: _selectedTier == plan.tier,
 price: _priceForPlan(plan),
 onSelect: () {
 setState(() => _selectedTier = plan.tier);
 _handlePlanSelection(context, plan);
 },
 ),
 )).toList(),
 );
 }
 }
}

class _BackButton extends StatelessWidget {
 const _BackButton({required this.onPressed});
 final VoidCallback onPressed;

 @override
 Widget build(BuildContext context) {
 return Material(
 color: Colors.white,
 borderRadius: BorderRadius.circular(999),
 child: InkWell(
 onTap: onPressed,
 borderRadius: BorderRadius.circular(999),
 child: const Padding(
 padding: EdgeInsets.all(10),
 child: Icon(Icons.arrow_back, color: _secondaryText, size: 20),
 ),
 ),
 );
 }
}

class _BillingToggle extends StatelessWidget {
 const _BillingToggle({required this.isAnnual, required this.onChanged});

 final bool isAnnual;
 final ValueChanged<bool> onChanged;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(4),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: Colors.black12),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.05),
 blurRadius: 10,
 offset: const Offset(0, 6),
 spreadRadius: -6,
 ),
 ],
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 _BillingToggleButton(
 label: 'Monthly',
 isActive: !isAnnual,
 onTap: () => onChanged(false),
 ),
 _BillingToggleButton(
 label: 'Annual',
 isActive: isAnnual,
 onTap: () => onChanged(true),
 ),
 ],
 ),
 );
 }
}

class _BillingToggleButton extends StatelessWidget {
 const _BillingToggleButton({
 required this.label,
 required this.isActive,
 required this.onTap,
 });

 final String label;
 final bool isActive;
 final VoidCallback onTap;

 @override
 Widget build(BuildContext context) {
 return AnimatedContainer(
 duration: const Duration(milliseconds: 180),
 curve: Curves.easeOut,
 margin: const EdgeInsets.symmetric(horizontal: 2),
 decoration: BoxDecoration(
 color: isActive ? _themeColor : Colors.transparent,
 borderRadius: BorderRadius.circular(999),
 ),
 child: InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(999),
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
 child: Text(
 label,
 style: TextStyle(
 color: isActive ? Colors.white : _secondaryText,
 fontWeight: FontWeight.w700,
 fontSize: 12,
 ),
 ),
 ),
 ),
 );
 }
}

class _PlanColumn extends StatelessWidget {
 const _PlanColumn({
 required this.plan,
 required this.isSelected,
 required this.price,
 required this.onSelect,
 });

 final _PricingPlan plan;
 final bool isSelected;
 final _PlanPrice price;
 final VoidCallback onSelect;

 @override
 Widget build(BuildContext context) {
 final Color accent = _themeColor;
 return Container(
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(18),
 gradient: LinearGradient(
 colors: [
 _themeSurface,
 Colors.white,
 Colors.white.withOpacity(0.9),
 ],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 border: Border.all(
 color: isSelected ? accent : Colors.black12,
 width: isSelected ? 1.4 : 1,
 ),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.06),
 blurRadius: 18,
 offset: const Offset(0, 12),
 spreadRadius: -6,
 ),
 if (isSelected)
 BoxShadow(
 color: accent.withOpacity(0.14),
 blurRadius: 26,
 offset: const Offset(0, 10),
 spreadRadius: -4,
 ),
 ],
 ),
 padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
 child: Column(
 mainAxisSize: MainAxisSize.max,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
 decoration: BoxDecoration(
 gradient: LinearGradient(
 colors: [accent, accent.withOpacity(0.85)],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 borderRadius: BorderRadius.circular(10),
 boxShadow: [
 BoxShadow(
 color: accent.withOpacity(0.25),
 blurRadius: 14,
 offset: const Offset(0, 8),
 spreadRadius: -6,
 ),
 ],
 ),
 child: Text(
 plan.label,
 style: const TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.w700,
 fontSize: 14,
 letterSpacing: 0.1,
 ),
 ),
 ),
 const Spacer(),
 if (isSelected)
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: accent.withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: accent.withOpacity(0.3)),
 ),
 child: Row(
 children: const [
 Icon(Icons.check_circle, color: _themeColor, size: 16),
 SizedBox(width: 6),
 Text(
 'Selected',
 style: TextStyle(
 color: _themeColor,
 fontWeight: FontWeight.w700,
 fontSize: 12,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 Text(
 plan.subtitle,
 style: const TextStyle(
 color: _primaryText,
 fontSize: 15,
 fontWeight: FontWeight.w600,
 height: 1.5,
 letterSpacing: -0.1,
 ),
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.end,
 children: [
 Text(
 price.price,
 style: const TextStyle(
 color: _primaryText,
 fontSize: 28,
 fontWeight: FontWeight.w800,
 letterSpacing: -0.6,
 ),
 ),
 const SizedBox(width: 6),
 Padding(
 padding: const EdgeInsets.only(bottom: 4),
 child: Text(
 price.period,
 style: const TextStyle(
 color: _secondaryText,
 fontSize: 12,
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 ],
 ),
 if (price.note != null) ...[
 const SizedBox(height: 6),
 Text(
 price.note!,
 style: const TextStyle(
 color: _secondaryText,
 fontSize: 12,
 fontWeight: FontWeight.w600,
 ),
 ),
 ],
 const SizedBox(height: 16),
 Expanded(
 child: SingleChildScrollView(
 padding: EdgeInsets.zero,
 child: Column(
 children: plan.features.map((feature) => Padding(
 padding: const EdgeInsets.only(bottom: 10),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 margin: const EdgeInsets.only(top: 4),
 height: 10,
 width: 10,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 gradient: LinearGradient(
 colors: [accent, accent.withOpacity(0.7)],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 feature,
 style: const TextStyle(
 color: _primaryText,
 fontSize: 13,
 height: 1.45,
 ),
 ),
 ),
 ],
 ),
 )).toList(),
 ),
 ),
 ),
 const SizedBox(height: 18),
 SizedBox(
 width: double.infinity,
 child: ElevatedButton(
 onPressed: onSelect,
 style: ElevatedButton.styleFrom(
 backgroundColor: isSelected ? accent : Colors.white,
 foregroundColor: isSelected ? Colors.white : accent,
 elevation: isSelected ? 8 : 2,
 padding: const EdgeInsets.symmetric(vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12),
 side: BorderSide(color: accent, width: 1.4),
 ),
 textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
 shadowColor: accent.withOpacity(isSelected ? 0.3 : 0.15),
 ),
 child: Text(isSelected ? 'Selected' : 'Select Plan'),
 ),
 ),
 ],
 ),
 );
 }
}

// Pricing extras widget containing all the additional sections
class _PricingExtras extends StatelessWidget {
 const _PricingExtras();

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildAllPlansInclude(),
 const SizedBox(height: 48),
 _buildRoleBasedAccess(),
 const SizedBox(height: 48),
 _buildAdditionalUserPricing(),
 const SizedBox(height: 48),
 _buildWhyViewersCostLess(),
 const SizedBox(height: 48),
 _buildFAQSection(),
 ],
 );
 }

 Widget _buildAllPlansInclude() {
 final features = ['AI Project Assistant', 'Standard Templates', 'Dashboards & Reports', 'Mobile Access', 'Secure Cloud Hosting', 'Email Support'];
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(28),
 decoration: BoxDecoration(
 color: _themeSurface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('All Plans Include', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _primaryText)),
 const SizedBox(height: 16),
 Wrap(
 spacing: 12, runSpacing: 8,
 children: features.map((f) => Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
 const SizedBox(width: 8),
 Text(f, style: const TextStyle(fontSize: 14, color: _primaryText, fontWeight: FontWeight.w500)),
 ],
 )).toList(),
 ),
 ],
 ),
 );
 }

 Widget _buildRoleBasedAccess() {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(28),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Role-Based Access', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _primaryText)),
 const SizedBox(height: 12),
 const Text('Every plan includes granular permissions to ensure users have access appropriate to their responsibilities.', style: TextStyle(fontSize: 14, color: _secondaryText, height: 1.5)),
 const SizedBox(height: 16),
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(color: _themeSurface, borderRadius: BorderRadius.circular(12)),
 child: const Text('The core users included with each plan may be assigned any combination of Owner, Admin, Editor, Contributor, or Viewer roles. Additional user charges apply only after the included user limit is exceeded.', style: TextStyle(fontSize: 13, color: _secondaryText, height: 1.6)),
 ),
 ],
 ),
 );
 }

 Widget _buildAdditionalUserPricing() {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(28),
 decoration: BoxDecoration(
 color: _themeSurface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Icon(Icons.group_add, color: _themeColor, size: 24),
 const SizedBox(width: 10),
 const Text('Additional User Pricing', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _primaryText)),
 ],
 ),
 const SizedBox(height: 8),
 const Text('As your team grows, you can add users without changing plans.', style: TextStyle(fontSize: 14, color: _secondaryText, height: 1.5)),
 ],
 ),
 );
 }

 Widget _buildWhyViewersCostLess() {
 final viewerAccess = ['Executive Dashboards', 'Portfolio Dashboards', 'Reports', 'Approved Documents', 'Milestones', 'Risks', 'Meeting Summaries', 'PDF Export'];
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(28),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Why Viewers Cost Less', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _primaryText)),
 const SizedBox(height: 12),
 const Text('Many organizations have significantly more stakeholders than delivery team members. Executives, sponsors, clients, auditors, and department leaders often need visibility into project status without making changes.', style: TextStyle(fontSize: 14, color: _secondaryText, height: 1.6)),
 const SizedBox(height: 12),
 const Text('Viewer licenses provide access to:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _primaryText)),
 const SizedBox(height: 10),
 Wrap(
 spacing: 8, runSpacing: 6,
 children: viewerAccess.map((v) => Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(color: _themeSurface, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
 child: Text(v, style: const TextStyle(fontSize: 12, color: _primaryText, fontWeight: FontWeight.w500)),
 )).toList(),
 ),
 const SizedBox(height: 12),
 const Text('Because Viewers cannot create or modify project data, they are offered at a lower price, making it affordable to extend visibility across the organization.', style: TextStyle(fontSize: 13, color: _secondaryText, height: 1.6, fontStyle: FontStyle.italic)),
 ],
 ),
 );
 }

 Widget _buildFAQSection() {
 final faqs = [
 {'q': 'Can I upgrade between plans?', 'a': 'Yes. Upgrade at any time as your organization grows.'},
 {'q': 'Can I purchase additional projects instead of upgrading?', 'a': 'Yes. Additional Pro Projects can be purchased individually or you can upgrade to the Program or Portfolio tier for greater value.'},
 {'q': 'What happens if I exceed my included users?', 'a': 'You can add Contributors or Viewers anytime.'},
 {'q': 'Can I mix user roles?', 'a': 'Yes. Assign Owner, Admin, Editor, Contributor, and Viewer roles based on each user\'s responsibilities.'},
 {'q': 'Do Viewers consume a full license?', 'a': 'No. Viewer licenses are priced separately because they provide read-only access and do not contribute to project execution.'},
 ];
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Frequently Asked Questions', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _primaryText)),
 const SizedBox(height: 20),
 ...faqs.map((faq) => Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Icon(Icons.help_outline, color: _themeColor, size: 20),
 const SizedBox(width: 8),
 Expanded(child: Text(faq['q']!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _primaryText))),
 ],
 ),
 const SizedBox(height: 8),
 Padding(
 padding: const EdgeInsets.only(left: 28),
 child: Text(faq['q'] != faq['a'] ? faq['a']! : '', style: const TextStyle(fontSize: 13, color: _secondaryText, height: 1.5)),
 ),
 ],
 ),
 )).toList(),
 ],
 );
 }
}

class _PricingPlan {
 const _PricingPlan({
 required this.tier,
 required this.label,
 required this.badgeColor,
 required this.subtitle,
 required this.features,
 required this.monthlyPrice,
 required this.monthlyOriginalPrice,
 });

 final _PlanTier tier;
 final String label;
 final Color badgeColor;
 final String subtitle;
 final List<String> features;
 final double monthlyPrice;
 final double monthlyOriginalPrice;
}

class _PlanPrice {
 const _PlanPrice({required this.price, required this.period, this.note, this.originalPrice});

 final String price;
 final String period;
 final String? note;
 final String? originalPrice;
}

enum _PlanTier { basicProject, project, program, portfolio }
