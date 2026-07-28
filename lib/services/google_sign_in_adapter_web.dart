import 'package:firebase_auth/firebase_auth.dart';

Future<UserCredential> signIn() async {
  final provider = GoogleAuthProvider();
  return await FirebaseAuth.instance.signInWithPopup(provider);
}
