import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ndu_project/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/access_policy.dart';
import 'package:ndu_project/screens/create_account_screen.dart';
import 'package:ndu_project/screens/two_factor_verification_screen.dart';
import 'package:ndu_project/widgets/app_logo.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/elevated_auth_container.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/services/subscription_service.dart';

import 'package:ndu_project/services/security_services.dart';
import 'package:ndu_project/screens/project_dashboard_screen.dart';
import 'package:ndu_project/screens/pricing_screen.dart';
import 'package:ndu_project/screens/admin/admin_home_screen.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberMePreference();
  }

  Future<void> _loadRememberMePreference() async {
    final rememberMe = await FirebaseAuthService.getRememberMe();
    if (mounted) {
      setState(() => _rememberMe = rememberMe);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailSignIn() async {
    if (_isUnsupportedDevice(context)) {
      await _showDeviceRestrictionDialog();
      return;
    }
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _showSnack('Please fill in all fields', Colors.red);
      return;
    }
    // Clear any stale account lockout from previous failed attempts
    // (caused by earlier auth bugs that have since been fixed)
    await AccountLockoutService.resetAttempts();
    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuthService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        rememberMe: _rememberMe,
      );
      if (!mounted) return;
      // #8: Reset failed attempts on successful login
      await AccountLockoutService.resetAttempts();
      // #9: Log successful sign-in (non-blocking)
      unawaited(SecurityAuditLogger.logSignIn(
              email: _emailController.text.trim())
          .catchError((e) => debugPrint('Audit log failed: $e')));
      // #6: Start session manager
      SessionManager.instance.start();
      // #20: Check for login anomalies (non-blocking)
      unawaited(AnomalyDetector.checkLoginAnomaly(
        userId: cred.user?.uid ?? '',
        email: _emailController.text.trim(),
      ).catchError((e) {
        debugPrint('Anomaly check failed (non-blocking): $e');
      }));

      // ── Navigate after sign in ────────────────────────────────────
      // All post-auth checks are wrapped to ensure the user can always
      // reach the dashboard. Failures in any check don't block sign-in.
      _navigateAfterSignIn();
    } catch (e) {
      // Log failed sign-in (non-blocking) but DON'T lock the account —
      // previous auth bugs caused false lockouts from Firestore errors
      unawaited(SecurityAuditLogger.logFailedSignIn(
        email: _emailController.text.trim(),
        reason: e.toString(),
      ).catchError((_) {}));
      _showSnack(
        'Sign in failed: ${e.toString().replaceAll("Exception: ", "").replaceAll("[firebase_auth/", "").replaceAll("]", "")}',
        Colors.red,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isGoogleProvider(User user) {
    return user.providerData.any((p) => p.providerId == 'google.com');
  }

  void _navigateAfterSignIn() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Navigate directly to dashboard — don't let subscription checks
      // or any other Firestore-dependent logic block navigation
      final isAdminHost = AccessPolicy.isRestrictedAdminHost();
      final target = isAdminHost ? '/${AppRoutes.adminHome}' : '/${AppRoutes.dashboard}';

      if (!mounted) return;
      try {
        context.go(target);
      } catch (e) {
        debugPrint('GoRouter navigation failed, using Navigator fallback: $e');
        if (!mounted) return;
        try {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => _buildFallbackScreen(target)),
            (route) => false,
          );
        } catch (e2) {
          debugPrint('Navigator fallback also failed: $e2');
        }
      }
    });
  }

  Widget _buildFallbackScreen(String target) {
    // Map route paths to screens for fallback navigation
    switch (target) {
      case '/dashboard':
        return const ProjectDashboardScreen();
      case '/pricing':
        return const PricingScreen();
      case '/admin-home':
        return const AdminHomeScreen();
      default:
        return const ProjectDashboardScreen();
    }
  }

  bool _shouldDeferToAuthWrapper() {
    try {
      final path = GoRouterState.of(context).uri.path;
      return path.startsWith('/${AppRoutes.adminPortal}') ||
          path.startsWith('/admin-');
    } catch (e) {
      debugPrint('Router state check failed: $e');
      return false;
    }
  }

  Future<void> _showVerifyEmailDialog(String email) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify your email'),
        content: Text(
            'We\'ve sent a verification link to\n$email. Please verify your email, then come back and sign in.'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await FirebaseAuth.instance.currentUser
                    ?.sendEmailVerification();
                if (mounted) {
                  _showSnack('Verification email sent', Colors.green);
                }
              } catch (e) {
                if (mounted) _showSnack('Failed to resend: $e', Colors.red);
              }
            },
            child: const Text('Resend'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  bool _isUnsupportedDevice(BuildContext context) {
    return false;
  }

  Future<void> _showDeviceRestrictionDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Device Not Supported'),
        content: const Text(
            'Use either a Tablet/Desktop for the best experience possible'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryText = Color(0xFF1F2933);
    const secondaryText = Color(0xFF616E7C);
    const fieldBorder = Color(0xFFD2D6DC);
    const headlineAccent = LightModeColors.accent;

    InputDecoration fieldDecoration(String hint, {Widget? suffix}) {
      final borderShape = BorderRadius.circular(12);
      return InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: secondaryText.withOpacity(0.6), fontSize: 15),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: borderShape,
          borderSide: const BorderSide(color: fieldBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderShape,
          borderSide: const BorderSide(color: fieldBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderShape,
          borderSide: const BorderSide(color: headlineAccent, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        suffixIcon: suffix,
      );
    }

    // Responsive sizes
    final bool isTablet = AppBreakpoints.isTablet(context);
    final bool isDesktop = AppBreakpoints.isDesktop(context);
    final double maxContentWidth = isDesktop ? 480 : (isTablet ? 440 : 400);
    final EdgeInsets pagePadding = EdgeInsets.symmetric(
      horizontal: AppBreakpoints.pagePadding(context),
      vertical: 32,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: true,
        child: SingleChildScrollView(
          padding: pagePadding,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Center(child: AppLogo(height: 320)),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Welcome back',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedAuthContainer(
                    maxWidth: maxContentWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sign in with your work email and password.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: secondaryText.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text('Email',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: primaryText)),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 54,
                          child: VoiceTextField(
                            enableKazAi: false,
                            enableTextFormatting: false,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(fontSize: 15),
                            decoration: fieldDecoration('jane.joe@gmail.com'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('Password',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: primaryText)),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 54,
                          child: VoiceTextField(
                            enableKazAi: false,
                            enableTextFormatting: false,
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            style: const TextStyle(fontSize: 15),
                            decoration: fieldDecoration(
                              '**********',
                              suffix: IconButton(
                                icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: secondaryText),
                                onPressed: () => setState(() =>
                                    _isPasswordVisible = !_isPasswordVisible),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: (value) => setState(
                                        () => _rememberMe = value ?? false),
                                    activeColor: headlineAccent,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Remember Me',
                                  style: TextStyle(
                                      color: secondaryText, fontSize: 13),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () async {
                                final email = _emailController.text.trim();
                                if (email.isEmpty) {
                                  _showSnack(
                                      'Enter your email to reset password',
                                      Colors.red);
                                  return;
                                }
                                setState(() => _isLoading = true);
                                try {
                                  await FirebaseAuthService
                                      .sendPasswordResetEmail(email);
                                  _showSnack(
                                      'Password reset link sent to $email',
                                      Colors.green);
                                } catch (e) {
                                  _showSnack('Failed to send reset email: $e',
                                      Colors.red);
                                } finally {
                                  if (mounted)
                                    setState(() => _isLoading = false);
                                }
                              },
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: primaryText,
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleEmailSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: LightModeColors.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Text('Sign In',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── Admin Panel button ──────────────────────────────────
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.go('/admin-home');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1A1D1F),
                        backgroundColor: Colors.white,
                        side: const BorderSide(
                            color: Color(0xFFE4E7EC), width: 1.5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.shield_outlined,
                          size: 18, color: Color(0xFF6B7280)),
                      label: const Text(
                        'Admin Panel',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CreateAccountScreen()),
                        );
                      },
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              color: secondaryText, fontSize: 13),
                          children: [
                            const TextSpan(text: "Don't have an account? "),
                            const TextSpan(
                              text: 'Create Account',
                              style: TextStyle(
                                  color: headlineAccent,
                                  decoration: TextDecoration.underline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
