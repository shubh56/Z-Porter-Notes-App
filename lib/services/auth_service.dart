// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

/// Simple AuthService using Firebase Email/Password and Anonymous sign-in support.
/// Keeps the API minimal: signInWithEmail, registerWithEmail, signOut, currentUser, authStateChanges.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Sign in with email & password.
  /// Throws FirebaseAuthException on error.
  Future<User?> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  /// Register (create user) with email & password.
  /// Throws FirebaseAuthException on error.
  Future<User?> registerWithEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  /// Sign out current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Optional: sign in anonymously (if you'd like to keep anonymous behavior)
  Future<User?> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    return cred.user;
  }

  /// Optional: send password reset email
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
