import 'package:flutter/material.dart';
import 'package:ndu_project/screens/landing_screen.dart';
import 'package:ndu_project/screens/home_screen.dart';
import 'package:ndu_project/screens/admin/admin_home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/services/access_policy.dart';
import 'package:ndu_project/services/subscription_service.dart'; // Added
import 'package:ndu_project/widgets/restricted_access.dart';

class AuthWrapper extends StatefulWidget {
 const AuthWrapper({super.key});

 @override
 State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
 @override
 Widget build(BuildContext context) {
 return StreamBuilder<User?>(
 stream: FirebaseAuth.instance.authStateChanges(),
 builder: (context, snapshot) {
 if (snapshot.hasError) {
 return Scaffold(
 body: SafeArea(
 top: true,
 child: Center(
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 520),
 child: Card(
 margin: const EdgeInsets.all(24),
 child: Padding(
 padding: const EdgeInsets.all(24.0),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.error_outline,
 color: Theme.of(context).colorScheme.error,
 size: 40),
 const SizedBox(height: 12),
 Text('Authentication error',
 style: Theme.of(context).textTheme.titleLarge),
 const SizedBox(height: 8),
 Text(
 snapshot.error?.toString() ??
 'An unexpected error occurred while checking your session.',
 style: Theme.of(context).textTheme.bodyMedium,
 textAlign: TextAlign.center,
 ),
 const SizedBox(height: 16),
 FilledButton.icon(
 onPressed: () {
 // Force rebuild to retry stream subscription
 setState(() {});
 },
 icon: const Icon(Icons.refresh),
 label: const Text('Retry'),
 ),
 ],
 ),
 ),
 ),
 ),
 ),
 ),
 );
 }
 if (snapshot.connectionState == ConnectionState.waiting) {
 return const Scaffold(
 body: SafeArea(
 top: true,
 child:
 Center(child: CircularProgressIndicator(strokeWidth: 2))),
 );
 }
 final user = snapshot.data;
 if (user != null) {
 // Create or update user record in Firestore
 UserService.createOrUpdateUser(user);

 // Host-aware access guard: if running on admin.nduproject.com, allow only
 // nduproject.com emails or the designated Gmail
 final hostRestricted = AccessPolicy.isRestrictedAdminHost();
 final emailAllowed = AccessPolicy.isEmailAllowedForAdmin(user.email);
 if (hostRestricted && !emailAllowed) {
 debugPrint('Access blocked on admin host for email: ${user.email}');
 return RestrictedAccessScreen(email: user.email);
 }

 // Route based on admin and subscription status
 return FutureBuilder<List<bool>>(
 future: Future.wait([
 UserService.isCurrentUserAdmin(),
 SubscriptionService.hasActiveSubscription(),
 ]),
 builder: (context, snapshot) {
 if (snapshot.connectionState == ConnectionState.waiting) {
 return const Scaffold(
 body: SafeArea(
 top: true,
 child: Center(
 child: CircularProgressIndicator(strokeWidth: 2))),
 );
 }

 final result = snapshot.data ?? [false, false];
 final isAdmin = result[0];
 final hasSubscription = result[1];

 if (isAdmin) {
 // Admin users go to Admin Dashboard
 return const _KeyLoader(child: AdminHomeScreen());
 } else if (hasSubscription) {
 // Client users with active subscription go to Dashboard
 return const _KeyLoader(child: HomeScreen());
 } else {
 // Client users without subscription go to the public landing page.
 return const LandingScreen();
 }
 },
 );
 }
 return const LandingScreen();
 },
 );
 }
}

class _KeyLoader extends StatefulWidget {
 const _KeyLoader({required this.child});
 final Widget child;

 @override
 State<_KeyLoader> createState() => _KeyLoaderState();
}

class _KeyLoaderState extends State<_KeyLoader> {
 @override
 void initState() {
 super.initState();
 // Load persisted API key for the signed-in user, if not set from env.
 WidgetsBinding.instance.addPostFrameCallback((_) {
 ApiKeyManager.ensureLoadedForSignedInUser();
 });
 }

 @override
 Widget build(BuildContext context) => widget.child;
}
