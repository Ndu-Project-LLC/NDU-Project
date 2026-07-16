import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/widgets/app_logo.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/elevated_auth_container.dart';
import 'package:ndu_project/screens/sign_in_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/services/security_services.dart';
import 'package:ndu_project/screens/home_screen.dart';
import 'package:ndu_project/routing/app_router.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _companyController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToPrivacyPolicy = false;
  bool _isLoading = false;
  // ignore: unused_field
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _companyController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _handleEmailSignUp() async {
    // Validate form
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showErrorSnackBar('Please fill in all fields');
      return;
    }

    if (!_isValidEmail(_emailController.text.trim())) {
      _showErrorSnackBar('Please enter a valid email address');
      return;
    }

    // #7: Strong password validation
    final passwordError = PasswordValidator.validate(_passwordController.text);
    if (passwordError != null) {
      _showErrorSnackBar(passwordError);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar('Passwords do not match');
      return;
    }

    if (!_agreeToPrivacyPolicy) {
      _showErrorSnackBar(
          'Please agree to the Privacy Policy and Terms & Conditions');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Attempt real Firebase Auth sign up
      final String email = _emailController.text.trim();
      final String password = _passwordController.text;
      final String fullName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
              .trim();

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Set display name
      if (cred.user != null && fullName.isNotEmpty) {
        await cred.user!.updateDisplayName(fullName);
      }

      // Send verification email
      await cred.user?.sendEmailVerification();
      if (cred.user != null) {
        await SecurityAuditLogger.logAccountCreation(email: email);
      }

      if (!mounted) return;

      // Inform user and route to Sign In
      await showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Verify your email'),
            content: Text(
              'We\'ve sent a verification link to\n$email. Please verify your email before signing in.',
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  // Provide a quick way to resend once
                  try {
                    await FirebaseAuth.instance.currentUser
                        ?.sendEmailVerification();
                    if (mounted) {
                      _showSuccessSnackBar('Verification email resent');
                    }
                  } catch (e) {
                    debugPrint('Error: $e');
                  }
                },
                child: const Text('Resend'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LightModeColors.accent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      _showSuccessSnackBar('Verification email sent');

      // Initialize user security profile so MFA setup can continue after login
      if (cred.user != null) {
        await TwoFactorAuthService.saveUserSecurity(
          uid: cred.user!.uid,
          email: email,
          method: MfaMethod.none,
        );
      }

      // Navigate to Sign In so the user can log in after verifying
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const SignInScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage;
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage = 'An account already exists with this email address.';
            break;
          case 'invalid-email':
            errorMessage = 'Please enter a valid email address.';
            break;
          case 'weak-password':
            errorMessage =
                'Password is too weak. Please use a stronger password.';
            break;
          case 'operation-not-allowed':
            errorMessage = 'Email/password sign up is not enabled.';
            break;
          default:
            errorMessage = e.message ?? 'Sign up failed. Please try again.';
        }
        _showErrorSnackBar(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Sign up failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // ignore: unused_element
  void _showSignInDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isPasswordVisible = false;
    bool isLoading = false;
    final parentNav = Navigator.of(context);
    final parentMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Sign In'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VoiceTextField(
                  enableKazAi: false,
                  enableTextFormatting: false,
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
                VoiceTextField(
                  enableKazAi: false,
                  enableTextFormatting: false,
                  controller: passwordController,
                  obscureText: !isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          isPasswordVisible = !isPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (emailController.text.trim().isEmpty ||
                          passwordController.text.isEmpty) {
                        parentMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Please fill in all fields'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setState(() {
                        isLoading = true;
                      });

                      try {
                        await FirebaseAuth.instance.signInWithEmailAndPassword(
                          email: emailController.text.trim(),
                          password: passwordController.text,
                        );

                        if (!context.mounted) return;
                        Navigator.pop(context);
                        parentNav.pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(),
                          ),
                        );
                      } on FirebaseAuthException catch (e) {
                        if (context.mounted) {
                          String errorMessage;
                          switch (e.code) {
                            case 'user-not-found':
                              errorMessage =
                                  'No account found with this email.';
                              break;
                            case 'wrong-password':
                              errorMessage = 'Incorrect password.';
                              break;
                            case 'invalid-email':
                              errorMessage = 'Invalid email address.';
                              break;
                            case 'user-disabled':
                              errorMessage = 'This account has been disabled.';
                              break;
                            default:
                              errorMessage = e.message ?? 'Sign in failed.';
                          }
                          parentMessenger.showSnackBar(
                            SnackBar(
                              content: Text(errorMessage),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          parentMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Sign in failed: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() {
                            isLoading = false;
                          });
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: LightModeColors.accent,
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);
    final bool isTablet = AppBreakpoints.isTablet(context);
    final bool isDesktop = AppBreakpoints.isDesktop(context);

    // Responsive content max width
    final double maxContentWidth = isDesktop ? 480 : (isTablet ? 440 : 400);

    // Control common paddings/spacings
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  Center(child: AppLogo(height: 120)),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedAuthContainer(
                    maxWidth: maxContentWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create your account using business profile details.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (isMobile)
                          Column(
                            children: [
                              _NameField(
                                  label: 'First Name',
                                  controller: _firstNameController),
                              const SizedBox(height: 16),
                              _NameField(
                                  label: 'Last Name',
                                  controller: _lastNameController),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                  child: _NameField(
                                      label: 'First Name',
                                      controller: _firstNameController)),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: _NameField(
                                      label: 'Last Name',
                                      controller: _lastNameController)),
                            ],
                          ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Company Name',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800])),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 52,
                              child: VoiceTextField(
                                enableKazAi: false,
                                enableTextFormatting: false,
                                controller: _companyController,
                                style: const TextStyle(fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: 'Company',
                                  hintStyle: TextStyle(
                                      color: Colors.grey[500], fontSize: 15),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: LightModeColors.accent,
                                        width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Email',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800])),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 52,
                              child: VoiceTextField(
                                enableKazAi: false,
                                enableTextFormatting: false,
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: 'Email@gmail.com',
                                  hintStyle: TextStyle(
                                      color: Colors.grey[500], fontSize: 15),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: LightModeColors.accent,
                                        width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Password',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800])),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 52,
                              child: VoiceTextField(
                                enableKazAi: false,
                                enableTextFormatting: false,
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                style: const TextStyle(fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: '••••••••••',
                                  hintStyle: TextStyle(
                                      color: Colors.grey[500], fontSize: 15),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: LightModeColors.accent,
                                        width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                        _isPasswordVisible
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.grey[600]),
                                    onPressed: () => setState(() =>
                                        _isPasswordVisible =
                                            !_isPasswordVisible),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Confirm Password',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800])),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 52,
                              child: VoiceTextField(
                                enableKazAi: false,
                                enableTextFormatting: false,
                                controller: _confirmPasswordController,
                                obscureText: !_isConfirmPasswordVisible,
                                style: const TextStyle(fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: '••••••••••',
                                  hintStyle: TextStyle(
                                      color: Colors.grey[500], fontSize: 15),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: LightModeColors.accent,
                                        width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                        _isConfirmPasswordVisible
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.grey[600]),
                                    onPressed: () => setState(() =>
                                        _isConfirmPasswordVisible =
                                            !_isConfirmPasswordVisible),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: _agreeToPrivacyPolicy,
                              onChanged: (value) => setState(
                                  () => _agreeToPrivacyPolicy = value ?? false),
                              activeColor: LightModeColors.accent,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 13),
                                  children: [
                                    const TextSpan(text: 'You agree to our '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: TextStyle(
                                          color: Colors.grey[800],
                                          decoration: TextDecoration.underline),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () => context.push(
                                            '/${AppRoutes.privacyPolicy}'),
                                    ),
                                    const TextSpan(text: ' and '),
                                    TextSpan(
                                      text: 'Terms & Conditions',
                                      style: TextStyle(
                                          color: Colors.grey[800],
                                          decoration: TextDecoration.underline),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () => context.push(
                                            '/${AppRoutes.termsConditions}'),
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleEmailSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: LightModeColors.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
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
                                : const Text('Get Started',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SignInScreen()),
                      );
                    },
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        children: [
                          const TextSpan(text: 'Already have an account ? '),
                          TextSpan(
                            text: 'Click here',
                            style: TextStyle(
                                color: Colors.grey[800],
                                decoration: TextDecoration.underline),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: VoiceTextField(
            enableKazAi: false,
            enableTextFormatting: false,
            controller: controller,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: LightModeColors.accent, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}
