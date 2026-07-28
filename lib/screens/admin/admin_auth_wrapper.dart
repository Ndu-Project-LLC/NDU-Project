import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/screens/sign_in_screen.dart';
import 'package:ndu_project/screens/admin/admin_home_screen.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/services/access_policy.dart';
import 'package:ndu_project/widgets/restricted_access.dart';

class AdminAuthWrapper extends StatelessWidget {
  const AdminAuthWrapper({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: SafeArea(
                top: true,
                child:
                    Center(child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const SignInScreen();
        }

        // Host-aware access guard for admin domain
        final hostRestricted = AccessPolicy.isRestrictedAdminHost();
        final emailAllowed = AccessPolicy.isEmailAllowedForAdmin(user.email);
        if (hostRestricted && !emailAllowed) {
          debugPrint('Access blocked on admin host for email: ${user.email}');
          return RestrictedAccessScreen(email: user.email);
        }

        // Check if user is admin
        return FutureBuilder<bool>(
          future: UserService.isCurrentUserAdmin(),
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: SafeArea(
                    top: true,
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }

            final isAdmin = adminSnapshot.data ?? false;

            if (!isAdmin) {
              return Scaffold(
                body: SafeArea(
                  top: true,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text(
                          'Access Denied',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You do not have admin privileges.',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => FirebaseAuth.instance.signOut(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC107),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return child ?? const AdminHomeScreen();
          },
        );
      },
    );
  }
}
