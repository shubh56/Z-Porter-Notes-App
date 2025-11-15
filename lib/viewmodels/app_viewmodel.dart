// lib/viewmodels/app_viewmodel.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

/// AppViewModel to expose auth actions to the UI.
/// Use Provider to provide this ViewModel at app root.
class AppViewModel extends ChangeNotifier {
  final AuthService authService;

  AppViewModel({required this.authService}) {
    // listen to auth state and propagate
    authService.authStateChanges().listen((u) {
      user = u;
      initialized = true;
      notifyListeners();
    });
  }

  User? user;
  bool initialized = false;
  bool isBusy = false;
  String? error;

  bool get isLoggedIn => user != null;

  Future<void> signIn(String email, String password) async {
    isBusy = true;
    error = null;
    notifyListeners();
    try {
      await authService.signInWithEmail(email, password);
    } on FirebaseAuthException catch (e) {
      error = e.message ?? 'Sign in failed';
    } catch (e) {
      error = e.toString();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> register(String email, String password) async {
    isBusy = true;
    error = null;
    notifyListeners();
    try {
      await authService.registerWithEmail(email, password);
    } on FirebaseAuthException catch (e) {
      error = e.message ?? 'Registration failed';
    } catch (e) {
      error = e.toString();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    isBusy = true;
    notifyListeners();
    try {
      await authService.signOut();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> signInAnonymously() async {
    isBusy = true;
    notifyListeners();
    try {
      await authService.signInAnonymously();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> sendPasswordReset(String email) async {
    isBusy = true;
    error = null;
    notifyListeners();
    try {
      await authService.sendPasswordReset(email);
    } on FirebaseAuthException catch (e) {
      error = e.message;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
