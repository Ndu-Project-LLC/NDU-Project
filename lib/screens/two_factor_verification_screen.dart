import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/widgets/app_logo.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/elevated_auth_container.dart';
import 'package:ndu_project/services/security_services.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/services/subscription_service.dart';

class TwoFactorVerificationScreen extends StatefulWidget {
  final String email;
  final String? password;

  const TwoFactorVerificationScreen(
      {super.key, required this.email, this.password});

  @override
  State<TwoFactorVerificationScreen> createState() =>
      _TwoFactorVerificationScreenState();
}

class _TwoFactorVerificationScreenState
    extends State<TwoFactorVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isSending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _sendCode();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _cooldownTimer?.cancel();
    super.dispose();
  }

  String get _enteredCode => _controllers.map((c) => c.text).join();

  // ── Send OTP ──────────────────────────────────────────────────────
  Future<void> _sendCode() async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    try {
      await TwoFactorAuthService.sendCode(email: widget.email);
      if (mounted) {
        setState(() => _resendCooldown = 60);
        _startCooldown();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification code sent to ${widget.email}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => _errorMessage = 'Failed to send code. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 0) {
        timer.cancel();
      } else if (mounted) {
        setState(() => _resendCooldown--);
      }
    });
  }

  // ── Verify OTP ────────────────────────────────────────────────────
  Future<void> _verifyCode() async {
    final code = _enteredCode;
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the full 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await TwoFactorAuthService.verifyCode(
          code: code, email: widget.email);
      if (!mounted) return;

      if (success) {
        final policy = await TwoFactorAuthService.loadPolicy();
// Re-authenticate with email/password after 2FA verification
        if (widget.password != null && widget.password!.isNotEmpty) {
          try {
            await FirebaseAuthService.signInWithEmailAndPassword(
              email: widget.email,
              password: widget.password!,
              rememberMe: true,
            );
          } catch (e) {
            debugPrint('[TwoFactorVerification] Re-auth failed: $e');
          }
        }
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await TwoFactorAuthService.rememberDevice(
            currentUser.uid,
            days: policy.rememberDeviceDays,
          );
        }
// Navigate to dashboard
        try {
          final hasSubscription =
              await SubscriptionService.hasActiveSubscription();
          if (!mounted) return;
          context.go(hasSubscription
              ? '/${AppRoutes.dashboard}'
              : '/${AppRoutes.pricing}');
        } catch (e) {
          if (mounted) context.go('/${AppRoutes.pricing}');
        }
      } else {
        setState(() => _errorMessage = 'Invalid code. Please try again.');
        _clearCode();
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => _errorMessage = 'Verification failed. Please try again.');
        _clearCode();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearCode() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    const primaryText = Color(0xFF1F2933);
    const secondaryText = Color(0xFF616E7C);
    final headlineAccent = LightModeColors.accent;

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
                  Center(child: AppLogo(height: 240)),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Two-Factor Verification',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Enter the 6-digit code sent to',
                      style: TextStyle(fontSize: 14, color: secondaryText),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      widget.email,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: headlineAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedAuthContainer(
                    maxWidth: maxContentWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── OTP Input Fields ───────────────────────────
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(6, (index) {
                              return Container(
                                width: 48,
                                height: 56,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: KeyboardListener(
                                  focusNode: FocusNode(),
                                  onKeyEvent: (event) {
                                    if (event is KeyDownEvent &&
                                        event.logicalKey ==
                                            LogicalKeyboardKey.backspace &&
                                        _controllers[index].text.isEmpty &&
                                        index > 0) {
                                      _controllers[index - 1].clear();
                                      _focusNodes[index - 1].requestFocus();
                                    }
                                  },
                                  child: TextFormField(
                                    controller: _controllers[index],
                                    focusNode: _focusNodes[index],
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    maxLength: 1,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: primaryText,
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      counterText: '',
                                      filled: true,
                                      fillColor: const Color(0xFFF9FAFB),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFD2D6DC),
                                          width: 1.5,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFD2D6DC),
                                          width: 1.5,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: headlineAccent,
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (value) {
                                      if (value.isNotEmpty && index < 5) {
                                        _focusNodes[index + 1].requestFocus();
                                      }
                                      if (value.isNotEmpty && index == 5) {
                                        // Auto-submit when all 6 digits entered
                                        _focusNodes[index].unfocus();
                                        _verifyCode();
                                      }
                                    },
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ── Error Message ──────────────────────────────
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // ── Verify Button ──────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _verifyCode,
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
                                : const Text('Verify Code',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Resend Code ────────────────────────────────
                        Center(
                          child: _resendCooldown > 0
                              ? Text(
                                  'Resend code in ${_resendCooldown}s',
                                  style: const TextStyle(
                                    color: secondaryText,
                                    fontSize: 13,
                                  ),
                                )
                              : GestureDetector(
                                  onTap: _isSending ? null : _sendCode,
                                  child: Text(
                                    _isSending ? 'Sending...' : 'Resend Code',
                                    style: TextStyle(
                                      color: headlineAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                        ),

                        const SizedBox(height: 16),

                        // ── Back to Sign In ────────────────────────────
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text(
                              'Back to Sign In',
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 13,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
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
