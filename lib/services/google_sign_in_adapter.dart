import 'package:firebase_auth/firebase_auth.dart';

// Conditional import: Web uses popup; others use google_sign_in plugin
import 'google_sign_in_adapter_web.dart' if (dart.library.io) 'google_sign_in_adapter_io.dart' as impl;

Future<UserCredential> signIn() => impl.signIn();
