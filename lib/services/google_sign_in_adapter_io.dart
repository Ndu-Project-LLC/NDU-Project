import 'package:firebase_auth/firebase_auth.dart';

Future<UserCredential> signIn() async {
  // Fallback IO implementation that uses provider-based sign-in.
  // On some platforms this may require additional configuration.
  final provider = GoogleAuthProvider();
  return await FirebaseAuth.instance.signInWithProvider(provider);
}
