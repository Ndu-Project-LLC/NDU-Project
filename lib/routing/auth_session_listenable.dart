import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Tells go_router to re-run its auth guard when a signed-in session ends.
///
/// go_router only evaluates `redirect` on navigation. Session timeout (and any
/// other sign-out) calls `FirebaseAuth.signOut()` while the user is still on a
/// protected page. Nothing navigates, so the page stays open with no session:
/// every Firestore read and write is then denied, and the screens render empty.
///
/// This notifies only on a transition from signed-in to signed-out. The initial
/// signed-out state and sign-in itself are left to the normal flow, so the
/// router does not redirect during sign-in.
class AuthSessionListenable extends ChangeNotifier {
  AuthSessionListenable(Stream<User?> authChanges) {
    _subscription = authChanges.listen(_onAuthChanged, onError: (_) {});
  }

  /// Wired to the live FirebaseAuth stream. Falls back to no listening when
  /// Firebase has not been initialised (for example in unit tests).
  static final AuthSessionListenable instance = _create();

  static AuthSessionListenable _create() {
    try {
      return AuthSessionListenable(FirebaseAuth.instance.authStateChanges());
    } catch (_) {
      return AuthSessionListenable(const Stream<User?>.empty());
    }
  }

  StreamSubscription<User?>? _subscription;
  bool _signedIn = false;

  void _onAuthChanged(User? user) {
    final endedSession = _signedIn && user == null;
    _signedIn = user != null;
    if (endedSession) notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
