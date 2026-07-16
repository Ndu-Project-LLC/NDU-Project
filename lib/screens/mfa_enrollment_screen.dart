import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/services/security_services.dart';

class MfaEnrollmentScreen extends StatefulWidget {
  const MfaEnrollmentScreen({super.key});

  @override
  State<MfaEnrollmentScreen> createState() => _MfaEnrollmentScreenState();
}

class _MfaEnrollmentScreenState extends State<MfaEnrollmentScreen> {
  MfaMethod _method = MfaMethod.authenticator;
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String _secret = '';
  String _emailCode = '';
  String _smsVerificationId = '';
  int? _smsResendToken;
  bool _busy = false;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _secret = _generateSecret();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String _generateSecret() {
    final rng = Random.secure();
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    return List.generate(16, (_) => alphabet[rng.nextInt(alphabet.length)])
        .join();
  }

  String _otpauthUri(String email) {
    final issuer = Uri.encodeComponent('NDU Project');
    final label = Uri.encodeComponent('NDU Project:$email');
    return 'otpauth://totp/$label?secret=$_secret&issuer=$issuer&period=30&digits=6';
  }

  Future<void> _saveSelection() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_method == MfaMethod.authenticator) {
      await SecureStorage.setTwoFactorSecret(_secret);
    } else {
      await SecureStorage.clearTwoFactorSecret();
    }
    await TwoFactorAuthService.saveUserSecurity(
      uid: user.uid,
      email: user.email ?? '',
      method: _method,
      encryptedSecret: _method == MfaMethod.authenticator ? _secret : null,
      phoneNumber:
          _method == MfaMethod.sms ? _phoneController.text.trim() : null,
    );
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'security': {
        'mfaMethod': _method.name,
        'mfaEnabled': true,
        'phoneNumber':
            _method == MfaMethod.sms ? _phoneController.text.trim() : null,
        'encryptedSecret': _method == MfaMethod.authenticator ? _secret : null,
        'updatedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  Future<void> _sendEmailCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;
    setState(() => _busy = true);
    try {
      _emailCode = (100000 + Random().nextInt(900000)).toString();
      await TwoFactorAuthService.sendCode(email: user!.email!);
      await TwoFactorAuthService.saveUserSecurity(
        uid: user.uid,
        email: user.email!,
        method: MfaMethod.emailCode,
      );
      await SecurityAuditLogger.log(
        action: 'mfa_email_code_generated',
        userId: user.uid,
        metadata: {'email': user.email},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verification code prepared.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendSmsCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS enrollment is available on mobile/native only.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.currentUser
              ?.linkWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('SMS verification failed: ${e.message ?? e.code}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        codeSent: (verificationId, resendToken) {
          _smsVerificationId = verificationId;
          _smsResendToken = resendToken;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('SMS code sent.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _smsVerificationId = verificationId;
        },
        forceResendingToken: _smsResendToken,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifySmsCode() async {
    final code = _codeController.text.trim();
    if (_smsVerificationId.isEmpty || code.length < 4) return;
    setState(() => _busy = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _smsVerificationId,
        smsCode: code,
      );
      await FirebaseAuth.instance.currentUser?.linkWithCredential(credential);
      await _saveSelection();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final recoveryCodes = TwoFactorAuthService.generateRecoveryCodes();
        await TwoFactorAuthService.saveRecoveryCodes(user.uid, recoveryCodes);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS MFA verified.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not verify SMS code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeEnrollment() async {
    setState(() => _busy = true);
    try {
      await _saveSelection();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final recoveryCodes = TwoFactorAuthService.generateRecoveryCodes();
      await TwoFactorAuthService.saveRecoveryCodes(user.uid, recoveryCodes);
      await TwoFactorAuthService.rememberDevice(user.uid, days: 30);
      setState(() => _verified = true);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Enrollment complete'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recovery codes:'),
                const SizedBox(height: 8),
                ...recoveryCodes.map((c) =>
                    Text(c, style: const TextStyle(fontFamily: 'monospace'))),
                const SizedBox(height: 12),
                const Text(
                  'Store these codes securely. Each code can be used once for account recovery.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email =
        FirebaseAuth.instance.currentUser?.email ?? 'user@example.com';
    final uri = _otpauthUri(email);

    return Scaffold(
      appBar: AppBar(title: const Text('MFA Enrollment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Security Enrollment',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose one primary MFA method and optionally keep backup methods enabled.',
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  children: [
                    ChoiceChip(
                      label: const Text('Authenticator App'),
                      selected: _method == MfaMethod.authenticator,
                      onSelected: (_) =>
                          setState(() => _method = MfaMethod.authenticator),
                    ),
                    ChoiceChip(
                      label: const Text('SMS'),
                      selected: _method == MfaMethod.sms,
                      onSelected: (_) =>
                          setState(() => _method = MfaMethod.sms),
                    ),
                    ChoiceChip(
                      label: const Text('Email Code'),
                      selected: _method == MfaMethod.emailCode,
                      onSelected: (_) =>
                          setState(() => _method = MfaMethod.emailCode),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_method == MfaMethod.authenticator)
                  _buildAuthenticator(uri),
                if (_method == MfaMethod.sms) _buildSms(),
                if (_method == MfaMethod.emailCode) _buildEmailCode(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _busy ? null : _completeEnrollment,
                      child: Text(_verified ? 'Saved' : 'Save & Complete'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthenticator(String uri) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Authenticator App',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Secret: $_secret',
                  style: const TextStyle(fontFamily: 'monospace')),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(
                  painter: _PseudoQrPainter(uri),
                  child: const Center(child: Text('Scan in Authenticator App')),
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(uri,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSms() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SMS Verification',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Mobile number'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton(
              onPressed: _busy ? null : _sendSmsCode,
              child: const Text('Send SMS Code'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '6-digit code'),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _busy ? null : _verifySmsCode,
              child: const Text('Verify'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Uses Firebase phone verification for the second factor on mobile/native.',
        ),
      ],
    );
  }

  Widget _buildEmailCode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Email Verification Code',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
            'This uses the existing Resend email-code flow already present in the app.'),
        const SizedBox(height: 12),
        TextField(
          controller: _codeController,
          decoration: const InputDecoration(labelText: 'Enter code to verify'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _sendEmailCode,
          child: const Text('Generate Code'),
        ),
        if (_emailCode.isNotEmpty) ...[
          const SizedBox(height: 8),
          SelectableText('Temp code: $_emailCode',
              style: const TextStyle(fontFamily: 'monospace')),
        ],
      ],
    );
  }
}

class _PseudoQrPainter extends CustomPainter {
  _PseudoQrPainter(this.data);
  final String data;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final bytes = utf8.encode(data);
    const cells = 25;
    final cellSize = size.width / cells;
    for (var y = 0; y < cells; y++) {
      for (var x = 0; x < cells; x++) {
        final idx = (x + y * cells) % bytes.length;
        final value = (bytes[idx] + x * 13 + y * 7) % 2 == 0;
        paint.color = value ? Colors.black : Colors.white;
        canvas.drawRect(
          Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PseudoQrPainter oldDelegate) =>
      oldDelegate.data != data;
}
