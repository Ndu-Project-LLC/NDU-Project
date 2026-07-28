import 'package:flutter/material.dart';
import 'package:ndu_project/screens/sign_in_screen.dart';
import 'package:ndu_project/screens/create_account_screen.dart';

/// Compact "Sign In" + "Start Your Project" buttons for the top-right
/// corner of landing page subpages. Rendered as a small Row — NOT a
/// full-width bottom bar.
///
/// Usage: place inside the top bar Row of each subpage, after the
/// Spacer, alongside the "Back to Landing" button.
class LandingSubpageActions extends StatelessWidget {
  const LandingSubpageActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sign In link
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SignInScreen()),
            );
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Sign In',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        // Start Your Project button (yellow, compact)
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFC812),
            foregroundColor: const Color(0xFF151515),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            elevation: 0,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Start Your Project',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
