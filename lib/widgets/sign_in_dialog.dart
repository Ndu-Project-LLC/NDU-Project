import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/theme.dart';

/// A popup dialog for signing in — shown on the landing page instead of
/// navigating to the full `/sign-in` route. Keeps the user on the current
/// page and presents credential fields in a modal overlay.
class SignInDialog extends StatefulWidget {
  const SignInDialog({super.key});

  /// Convenience method to show the dialog from any context.
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const SignInDialog(),
    );
  }

  @override
  State<SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<SignInDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Email / password sign-in ──────────────────────────────────────────
  Future<void> _handleEmailSignIn() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _showSnack('Please fill in all fields', Colors.red);
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
      await cred.user?.reload();
      if (!mounted) return;
      _navigateAfterSignIn();
    } on FirebaseAuthException catch (e) {
      _showSnack(_friendlyErrorMessage(e), Colors.red);
    } catch (e) {
      _showSnack('Sign in failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Google sign-in ────────────────────────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuthService.signInWithGoogle();
      if (!mounted) return;
      _navigateAfterSignIn();
    } on FirebaseAuthException catch (e) {
      _showSnack(_friendlyErrorMessage(e), Colors.red);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('popup-closed-by-user') ||
          msg.contains('cancelled') ||
          msg.contains('Sign in aborted')) {
        // User cancelled — no error.
      } else {
        _showSnack('Google sign-in failed: $e', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Navigation after successful auth ──────────────────────────────────
  void _navigateAfterSignIn() {
    if (!mounted) return;
    Navigator.of(context).pop(); // close the dialog
    // Navigate to dashboard (the router will handle subscription checks).
    context.go('/${AppRoutes.dashboard}');
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  String _friendlyErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return 'Incorrect email or password.';
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

  // ── Build ─────────────────────────────────────────────────────────────
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
            TextStyle(color: secondaryText.withValues(alpha: 0.6), fontSize: 14),
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
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: suffix,
      );
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFBBF24), Color(0xFFD97706)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.trending_up,
                        color: Color(0xFF0A0E1A), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Sign in to continue',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    color: secondaryText,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your credentials to access your projects.',
                style: TextStyle(
                  fontSize: 13,
                  color: secondaryText.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 20),

              // ── Google Sign-In ──
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const _GoogleLogo(size: 18),
                  label: const Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryText,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: fieldBorder, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── OR divider ──
              Row(
                children: [
                  const Expanded(child: Divider(color: fieldBorder, height: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR',
                        style: TextStyle(
                          color: secondaryText.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                  const Expanded(child: Divider(color: fieldBorder, height: 1)),
                ],
              ),
              const SizedBox(height: 16),

              // ── Email ──
              const Text('Email',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primaryText)),
              const SizedBox(height: 8),
              SizedBox(
                height: 46,
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 14),
                  decoration: fieldDecoration('you@example.com'),
                  onSubmitted: (_) => _handleEmailSignIn(),
                ),
              ),
              const SizedBox(height: 14),

              // ── Password ──
              const Text('Password',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primaryText)),
              const SizedBox(height: 8),
              SizedBox(
                height: 46,
                child: TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  style: const TextStyle(fontSize: 14),
                  decoration: fieldDecoration(
                    '••••••••',
                    suffix: IconButton(
                      icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: secondaryText,
                          size: 20),
                      onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  onSubmitted: (_) => _handleEmailSignIn(),
                ),
              ),
              const SizedBox(height: 10),

              // ── Remember me + forgot password ──
              Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (v) =>
                          setState(() => _rememberMe = v ?? false),
                      activeColor: headlineAccent,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('Remember me',
                      style: TextStyle(color: secondaryText, fontSize: 12)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      final email = _emailController.text.trim();
                      if (email.isEmpty) {
                        _showSnack(
                            'Enter your email to reset password', Colors.red);
                        return;
                      }
                      try {
                        await FirebaseAuthService.sendPasswordResetEmail(
                            email);
                        _showSnack(
                            'Password reset link sent to $email', Colors.green);
                      } catch (e) {
                        _showSnack('Failed to send reset email: $e',
                            Colors.red);
                      }
                    },
                    child: const Text('Forgot Password?',
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── Sign In button ──
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleEmailSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: headlineAccent,
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Sign In',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),

              // ── Create account link ──
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop(); // close dialog
                    context.push('/create-account');
                  },
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: secondaryText, fontSize: 12),
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
            ],
          ),
        ),
      ),
    );
  }
}

// ── Google Logo (same as sign_in_screen.dart) ───────────────────────────
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter(), size: Size(size, size)),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.46;
    final ringThickness = size.width * 0.14;

    final blue = Paint()..color = const Color(0xFF4285F4);
    final red = Paint()..color = const Color(0xFFEA4335);
    final yellow = Paint()..color = const Color(0xFFFBBC05);
    final green = Paint()..color = const Color(0xFF34A853);

    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(rect, 3.141592653589793 * 1.00,
        3.141592653589793 * 0.50, false,
        yellow..style = PaintingStyle.stroke..strokeWidth = ringThickness);
    canvas.drawArc(rect, 3.141592653589793 * 0.50,
        3.141592653589793 * 0.50, false,
        red..style = PaintingStyle.stroke..strokeWidth = ringThickness);
    canvas.drawArc(rect, 3.141592653589793 * 0.00,
        3.141592653589793 * 0.50, false,
        blue..style = PaintingStyle.stroke..strokeWidth = ringThickness);
    canvas.drawArc(rect, 3.141592653589793 * 1.50,
        3.141592653589793 * 0.35, false,
        green..style = PaintingStyle.stroke..strokeWidth = ringThickness);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringThickness * 0.95
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(center.dx, center.dy),
        Offset(center.dx + radius * 0.55, center.dy),
        barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
