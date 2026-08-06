import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/services/security_services.dart';

class RecoveryCodesScreen extends StatefulWidget {
  const RecoveryCodesScreen({super.key});

  @override
  State<RecoveryCodesScreen> createState() => _RecoveryCodesScreenState();
}

class _RecoveryCodesScreenState extends State<RecoveryCodesScreen> {
  List<String> _codes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final codes = await TwoFactorAuthService.getRecoveryCodes(user.uid);
    if (mounted) {
      setState(() {
        _codes = codes;
        _loading = false;
      });
    }
  }

  Future<void> _regenerate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final codes = TwoFactorAuthService.generateRecoveryCodes();
    await TwoFactorAuthService.saveRecoveryCodes(user.uid, codes);
    if (!mounted) return;
    setState(() => _codes = codes);
  }

  Future<void> _consume(String code) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ok = await TwoFactorAuthService.consumeRecoveryCode(user.uid, code);
    if (ok && mounted) {
      setState(() => _codes.remove(code));
    }
  }

  Future<void> _clearAll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await TwoFactorAuthService.saveRecoveryCodes(user.uid, <String>[]);
    if (!mounted) return;
    setState(() => _codes = <String>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recovery Codes')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _regenerate,
                        child: const Text('Generate New Set'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _clearAll,
                        child: const Text('Revoke All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _codes
                        .map(
                          (code) => InputChip(
                            label: Text(code),
                            onDeleted: () => _consume(code),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
      ),
    );
  }
}
