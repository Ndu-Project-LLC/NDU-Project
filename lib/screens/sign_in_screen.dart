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
    // #8: Check account lockout before attempting sign-in
    if (await AccountLockoutService.isLocked()) {
      final remaining = await AccountLockoutService.getRemainingLockout();
      final mins = remaining?.inMinutes ?? 0;
      _showSnack(
          'Account locked. Try again in $mins minute${mins == 1 ? '' : 's'}.',
          Colors.red);
      return;
    }
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
      // #9: Log successful sign-in
      await SecurityAuditLogger.logSignIn(email: _emailController.text.trim());
      // #6: Start session manager
      SessionManager.instance.start();
      // #20: Check for login anomalies
      await AnomalyDetector.checkLoginAnomaly(
        userId: cred.user?.uid ?? '',
        email: _emailController.text.trim(),
      );
      final user = cred.user;
      await user?.reload();
      if (!mounted) return;
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed == null) {
        _showSnack('Sign in failed. Please try again.', Colors.red);
        return;
      }

      // ── Email verification check (soft warning, not a hard blocker) ──
      // Previously, an unverified email caused a forced sign-out which left
      // users unable to enter the app at all (especially when verification
      // emails were delayed or filtered as spam). We now allow the user to
      // proceed but show a non-blocking reminder so they can verify at their
      // own pace. The router's subscription guard still applies.
      if (!refreshed.emailVerified && !_isGoogleProvider(refreshed)) {
        _showSnack(
          'Please verify your email. Tap "Resend verification" in Settings if you did not receive the link.',
          Colors.orange,
        );
      }

      // ── 2FA check ─────────────────────────────────────────────
      // Sign out first so the user can't access protected routes
      // without completing 2FA. They'll re-authenticate after verification.
      final policy = await TwoFactorAuthService.loadPolicy();
      final trustedDevice = await TwoFactorAuthService.isTrustedDevice(
        refreshed.uid,
        rememberDays: policy.rememberDeviceDays,
      );
      if (!mounted) return;
      final requiresMfa = policy.mfaEnabled &&
          !_isGoogleProvider(refreshed) &&
          (!policy.requireMfaNewDeviceOnly || !trustedDevice);
      if (requiresMfa) {
        final userEmail = refreshed.email ?? _emailController.text.trim();
        // Sign out so session is not active during 2FA
        await FirebaseAuthService.signOut();
        if (!mounted) return;
        // Navigate to 2FA verification screen with credentials stored
        // so the app can re-authenticate after successful verification
        context.push('/two-factor-verification', extra: TwoFactorVerificationScreen(
              email: userEmail,
              password: _passwordController.text,
            ));
        return;
      }
      _navigateAfterSignIn();
    } on FirebaseAuthException catch (e) {
      // #8: Record failed attempt
      final locked = await AccountLockoutService.recordFailedAttempt();
      // #9: Log failed sign-in
      await SecurityAuditLogger.logFailedSignIn(
        email: _emailController.text.trim(),
        reason: e.toString(),
      );
      final friendly = _friendlyAuthErrorMessage(e);
      if (locked) {
        _showSnack('Too many failed attempts. Account locked for 15 minutes.',
            Colors.red);
      } else {
        final attempts = await AccountLockoutService.getAttemptCount();
        final remaining = AccountLockoutService.maxAttempts - attempts;
        _showSnack(
          remaining > 0
              ? '$friendly $remaining attempt${remaining == 1 ? '' : 's'} remaining.'
              : friendly,
          Colors.red,
        );
      }
    } catch (e) {
      // #8: Record failed attempt
      final locked = await AccountLockoutService.recordFailedAttempt();
      // #9: Log failed sign-in
      await SecurityAuditLogger.logFailedSignIn(
        email: _emailController.text.trim(),
        reason: e.toString(),
      );
      if (locked) {
        _showSnack('Too many failed attempts. Account locked for 15 minutes.',
            Colors.red);
      } else {
        final attempts = await AccountLockoutService.getAttemptCount();
        final remaining = AccountLockoutService.maxAttempts - attempts;
        _showSnack(
          remaining > 0
              ? 'Sign in failed. $remaining attempt${remaining == 1 ? '' : 's'} remaining.'
              : 'Sign in failed: $e',
          Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Maps Firebase Auth error codes to user-friendly messages so users
  /// understand WHY authentication failed instead of seeing a raw exception.
  String _friendlyAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return 'Incorrect email or password.';
      case 'invalid-verification-code':
        return 'The verification code is invalid.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled for this project.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'popup-closed-by-user':
        return 'Sign-in cancelled.';
      case 'popup-blocked':
        return 'Sign-in popup was blocked by the browser.';
      case 'unauthorized-domain':
        return 'This domain is not authorized for sign-in.';
      default:
        return e.message ?? 'Sign in failed. Please try again.';
    }
  }

  /// Cross-platform Google Sign-In entry point.
  ///
  /// Uses [FirebaseAuthService.signInWithGoogle] which dispatches to the
  /// platform-appropriate adapter (popup on web, provider flow on mobile).
  Future<void> _handleGoogleSignIn() async {
    if (_isUnsupportedDevice(context)) {
      await _showDeviceRestrictionDialog();
      return;
    }
    // #8: Check account lockout before attempting sign-in
    if (await AccountLockoutService.isLocked()) {
      final remaining = await AccountLockoutService.getRemainingLockout();
      final mins = remaining?.inMinutes ?? 0;
      _showSnack(
          'Account locked. Try again in $mins minute${mins == 1 ? '' : 's'}.',
          Colors.red);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuthService.signInWithGoogle();
      if (!mounted) return;
      await AccountLockoutService.resetAttempts();
      await SecurityAuditLogger.logSignIn(
          email: cred.user?.email ?? 'google-user');
      SessionManager.instance.start();
      await AnomalyDetector.checkLoginAnomaly(
        userId: cred.user?.uid ?? '',
        email: cred.user?.email ?? '',
      );
      final user = cred.user;
      await user?.reload();
      if (!mounted) return;
      _navigateAfterSignIn();
    } on FirebaseAuthException catch (e) {
      final friendly = _friendlyAuthErrorMessage(e);
      _showSnack(friendly, Colors.red);
    } catch (e) {
      // User-cancellation (popup closed) is expected and should NOT show
      // an error snack — the user intentionally backed out.
      final msg = e.toString();
      if (msg.contains('popup-closed-by-user') ||
          msg.contains('cancelled') ||
          msg.contains('Sign in aborted')) {
        debugPrint('Google sign-in cancelled: $e');
      } else {
        _showSnack('Google sign-in failed: $e', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isGoogleProvider(User user) {
    return user.providerData.any((p) => p.providerId == 'google.com');
  }

  void _navigateAfterSignIn() {
    if (!mounted) return;
    if (_shouldDeferToAuthWrapper()) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      String target;
      final isAdminHost = AccessPolicy.isRestrictedAdminHost();

      if (isAdminHost) {
        target = '/${AppRoutes.adminHome}';
      } else {
        // Check for active subscription (including trials)
        try {
          final hasSubscription =
              await SubscriptionService.hasActiveSubscription();
          if (hasSubscription) {
            target = '/${AppRoutes.dashboard}';
          } else {
            target = '/${AppRoutes.pricing}';
          }
        } catch (e) {
          debugPrint('Error checking subscription on sign in: $e');
          target = '/${AppRoutes.pricing}';
        }
      }

      if (!mounted) return;
      context.go(target);
    });
  }

  Widget _buildFallbackScreen(String target) {
    // Map route paths to screens for fallback navigation.
    // Kept for future use; currently navigation goes through GoRouter.
    switch (target) {
      case '/dashboard':
        return const ProjectDashboardScreen();
      case '/pricing':
        return const PricingScreen();
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
            TextStyle(color: secondaryText.withValues(alpha: 0.6), fontSize: 15),
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
                  const Center(child: AppLogo(height: 320)),
                  const SizedBox(height: 8),
                  const Center(
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
                          'Continue with Google or your work email below.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: secondaryText.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // ── Google Sign-In ──────────────────────────────────
                        // Cross-platform Google sign-in. Uses the popup flow on
                        // web and the provider flow on mobile via the adapter.
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed:
                                _isLoading ? null : _handleGoogleSignIn,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : _GoogleLogo(size: 20),
                            label: const Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: primaryText,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: fieldBorder, width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // OR divider
                        Row(
                          children: [
                            Expanded(
                                child:
                                    Divider(color: fieldBorder, height: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              child: Text('OR',
                                  style: TextStyle(
                                    color: secondaryText
                                        .withValues(alpha: 0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ),
                            Expanded(
                                child:
                                    Divider(color: fieldBorder, height: 1)),
                          ],
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
                            enableVoice: false,
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
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
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
                                  if (mounted) {
                                    setState(() => _isLoading = false);
                                  }
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
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        context.pushReplacement('/create-account');
                      },
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                              color: secondaryText, fontSize: 13),
                          children: [
                            TextSpan(text: "Don't have an account? "),
                            TextSpan(
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

/// Renders the official multi-color Google "G" logo as a vector asset so we
/// don't depend on a network fetch (which fails when the browser blocks
/// third-party requests or the user is offline).
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
        size: Size(size, size),
      ),
    );
  }
}

/// Hand-drawn Google "G" logo using the official brand colors. Drawn with
/// [CustomPaint] so it scales crisply at any size without bundling an SVG
/// asset or fetching the favicon over the network.
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.46;
    final ringThickness = size.width * 0.14;

    // The Google "G" is a ring with a wedge missing on the right side and a
    // short bar extending from the center toward the gap. We approximate it
    // with four colored arcs (blue, red, yellow, green) and a horizontal bar.

    final blue = Paint()..color = const Color(0xFF4285F4);
    final red = Paint()..color = const Color(0xFFEA4335);
    final yellow = Paint()..color = const Color(0xFFFBBC05);
    final green = Paint()..color = const Color(0xFF34A853);

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Arcs span 90 degrees each, offset so the missing wedge sits on the
    // right side (around 0 radians). Start angle measured clockwise from the
    // positive x-axis (3 o'clock).
    // Yellow (top-left quadrant)
    canvas.drawArc(
      rect,
      3.141592653589793 * 1.00,
      3.141592653589793 * 0.50,
      false,
      yellow..style = PaintingStyle.stroke..strokeWidth = ringThickness,
    );
    // Red (bottom-left quadrant)
    canvas.drawArc(
      rect,
      3.141592653589793 * 0.50,
      3.141592653589793 * 0.50,
      false,
      red..style = PaintingStyle.stroke..strokeWidth = ringThickness,
    );
    // Blue (bottom-right quadrant)
    canvas.drawArc(
      rect,
      3.141592653589793 * 0.00,
      3.141592653589793 * 0.50,
      false,
      blue..style = PaintingStyle.stroke..strokeWidth = ringThickness,
    );
    // Green (top-right quadrant) — but leave the gap for the bar
    canvas.drawArc(
      rect,
      3.141592653589793 * 1.50,
      3.141592653589793 * 0.35,
      false,
      green..style = PaintingStyle.stroke..strokeWidth = ringThickness,
    );

    // Horizontal bar (the crossbar of the G) — drawn in blue to match the
    // official logo's bar color.
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringThickness * 0.95
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx + radius * 0.55, center.dy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
