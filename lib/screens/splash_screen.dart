import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/services/project_navigation_service.dart';
import 'package:ndu_project/services/user_preferences_service.dart';

/// Splash screen shown only on native mobile apps (iOS/Android)
/// NEVER shown on web platform
class SplashScreen extends StatefulWidget {
 const SplashScreen({super.key});

 @override
 State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
 with SingleTickerProviderStateMixin {
 static const Duration _minimumSplashDuration = Duration(milliseconds: 900);
 static const Duration _maxPrewarmWait = Duration(milliseconds: 250);

 late AnimationController _controller;
 late Animation<double> _fadeAnimation;

 @override
 void initState() {
 super.initState();

 // Setup fade animation
 _controller = AnimationController(
 duration: const Duration(milliseconds: 800),
 vsync: this,
 );

 _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
 CurvedAnimation(parent: _controller, curve: Curves.easeIn),
 );

 _controller.forward();

 // Navigate after splash
 _navigateAfterSplash();
 }

 @override
 void dispose() {
 _controller.dispose();
 super.dispose();
 }

 Future<void> _navigateAfterSplash() async {
 final minimumDelay = Future<void>.delayed(_minimumSplashDuration);
 final decisionFuture = _prepareStartupDecision();
 final prewarmFuture = _prewarmCriticalResources();

 await minimumDelay;
 await prewarmFuture.timeout(_maxPrewarmWait, onTimeout: () {});

 if (!mounted) return;

 final decision = await decisionFuture;
 if (!mounted) return;

 if (decision.isFirstTime) {
 // First time user → Onboarding
 context.go('/onboarding');
 } else {
 // Returning user → Check auth status
 if (decision.user != null) {
 // Authenticated → Dashboard
 context.go('/${AppRoutes.dashboard}');
 } else {
 // Not authenticated → Login
 context.go('/${AppRoutes.signIn}');
 }
 }
 }

 Future<_SplashDecision> _prepareStartupDecision() async {
 final isFirstTimeFuture = UserPreferencesService.isFirstTimeUser();
 final user = FirebaseAuth.instance.currentUser;
 final isFirstTime = await isFirstTimeFuture;
 return _SplashDecision(isFirstTime: isFirstTime, user: user);
 }

 Future<void> _prewarmCriticalResources() async {
 // Fire-and-forget warmups while splash is visible.
 final futures = <Future<void>>[
 UserPreferencesService.warmUp(),
 ProjectNavigationService.instance.warmUp(),
 _prewarmRouteLocations(),
 // Pre-cache common assets used immediately after splash.
 _safePrecacheAsset('assets/images/Logo.png'),
 _safePrecacheAsset('assets/images/search.png'),
 ];
 await Future.wait(futures);
 }

 Future<void> _prewarmRouteLocations() {
 try {
 final router = GoRouter.of(context);
 router.namedLocation(AppRoutes.onboarding);
 router.namedLocation(AppRoutes.signIn);
 router.namedLocation(AppRoutes.dashboard);
 } catch (e) {
 // Router prewarm is best-effort.
 }
 return Future.value();
 }

 Future<void> _safePrecacheAsset(String assetPath) async {
 try {
 await precacheImage(AssetImage(assetPath), context);
 } catch (e) {
 // Prewarming is best-effort; never block startup on missing assets.
 }
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: const Color(0xFFFFD700), // Brand yellow
 body: SafeArea(
 top: true,
 child: Center(
 child: FadeTransition(
 opacity: _fadeAnimation,
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 // NDU Project Logo
 Container(
 width: 120,
 height: 120,
 decoration: BoxDecoration(
 color: Colors.black,
 borderRadius: BorderRadius.circular(24),
 ),
 child: const Center(
 child: Text(
 'NDU',
 style: TextStyle(
 color: Color(0xFFFFD700),
 fontSize: 36,
 fontWeight: FontWeight.w900,
 letterSpacing: 2,
 ),
 ),
 ),
 ),
 const SizedBox(height: 24),
 const Text(
 'NDUPROJECT',
 style: TextStyle(
 color: Colors.black,
 fontSize: 20,
 fontWeight: FontWeight.w700,
 letterSpacing: 4,
 ),
 ),
 const SizedBox(height: 8),
 const Text(
 'INITIATE. DELIVER. ITERATE.',
 style: TextStyle(
 color: Colors.black87,
 fontSize: 11,
 fontWeight: FontWeight.w500,
 letterSpacing: 2,
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 );
 }
}

class _SplashDecision {
 const _SplashDecision({required this.isFirstTime, required this.user});

 final bool isFirstTime;
 final User? user;
}
