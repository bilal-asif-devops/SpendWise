import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/auth_models.dart';
import 'auth_service.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService() {
    if (!kIsWeb) {
      try {
        GoogleSignIn.instance.initialize();
      } catch (e) {
        debugPrint('GoogleSignIn.instance.initialize note: $e');
      }
    }
  }

  @override
  bool get isConfigured => Firebase.apps.isNotEmpty;

  @override
  Stream<AuthUser?> get authStateChanges {
    if (!isConfigured) {
      return Stream.value(null);
    }
    return fb.FirebaseAuth.instance.authStateChanges().map(_mapFirebaseUser);
  }

  @override
  AuthUser? get currentUser {
    if (!isConfigured) return null;
    return _mapFirebaseUser(fb.FirebaseAuth.instance.currentUser);
  }

  AuthUser? _mapFirebaseUser(fb.User? user) {
    if (user == null) return null;
    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      isAnonymous: user.isAnonymous,
      createdAt: user.metadata.creationTime,
    );
  }

  @override
  Future<AuthUser> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    _ensureConfigured();
    try {
      final credential =
          await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthException(
          message:
              'Sign-in failed. No user was returned by authentication provider.',
          code: 'null-user',
        );
      }
      return _mapFirebaseUser(user)!;
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(
        message: 'Authentication failed: $e',
        originalError: e,
      );
    }
  }

  @override
  Future<AuthUser> createUserWithEmailAndPassword(
    String email,
    String password, {
    String? displayName,
  }) async {
    _ensureConfigured();
    try {
      final credential =
          await fb.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthException(
          message:
              'Registration failed. No user returned by authentication provider.',
          code: 'null-user',
        );
      }

      if (displayName != null && displayName.trim().isNotEmpty) {
        try {
          await user.updateDisplayName(displayName.trim());
          await user.reload();
        } catch (e) {
          debugPrint('Failed to update display name: $e');
        }
      }

      final refreshedUser = fb.FirebaseAuth.instance.currentUser ?? user;
      return _mapFirebaseUser(refreshedUser)!;
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(
        message: 'Registration failed: $e',
        originalError: e,
      );
    }
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    _ensureConfigured();
    try {
      if (kIsWeb) {
        // Web flow: uses popup to avoid DWDS hangs and manual client ID constraints
        final fb.GoogleAuthProvider authProvider = fb.GoogleAuthProvider();
        final fb.UserCredential userCredential =
            await fb.FirebaseAuth.instance.signInWithPopup(authProvider);
        final user = userCredential.user;
        if (user == null) return null;
        return _mapFirebaseUser(user);
      } else {
        // Mobile flow using google_sign_in 7.2.0 API
        final GoogleSignInAccount googleAccount =
            await GoogleSignIn.instance.authenticate();
        final GoogleSignInAuthentication googleAuth =
            googleAccount.authentication;

        final fb.OAuthCredential credential = fb.GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        final userCredential =
            await fb.FirebaseAuth.instance.signInWithCredential(credential);

        final user = userCredential.user;
        if (user == null) {
          throw const AuthException(
            message:
                'Google Sign-In succeeded but no Firebase user was returned.',
            code: 'null-user',
          );
        }

        return _mapFirebaseUser(user);
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        // User deliberately dismissed/canceled Google sign-in
        return null;
      }
      throw AuthException(
        message: 'Google Sign-In failed: ${e.description ?? e.code.name}',
        code: e.code.name,
        originalError: e,
      );
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled') {
        // User closed popup
        return null;
      }
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(
        message: 'Google Sign-In failed: $e',
        originalError: e,
      );
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    _ensureConfigured();
    try {
      await fb.FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.trim(),
      );
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(
        message: 'Password reset request failed: $e',
        originalError: e,
      );
    }
  }

  @override
  Future<void> signOut() async {
    if (!isConfigured) return;
    try {
      if (!kIsWeb) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (e) {
          debugPrint('GoogleSignIn signOut note: $e');
        }
      }
      await fb.FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Error during sign out: $e');
    }
  }

  void _ensureConfigured() {
    if (!isConfigured) {
      throw const AuthException(
        message:
            'Firebase is not configured for this application. Please run "flutterfire configure" to attach your Firebase project.',
        code: 'configuration-required',
      );
    }
  }

  AuthException _mapFirebaseAuthException(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return AuthException(
          message: 'No account found with this email address.',
          code: e.code,
          originalError: e,
        );
      case 'wrong-password':
      case 'invalid-credential':
        return AuthException(
          message:
              'Incorrect email or password. Please verify your credentials.',
          code: e.code,
          originalError: e,
        );
      case 'email-already-in-use':
        return AuthException(
          message:
              'An account with this email address already exists. Please log in.',
          code: e.code,
          originalError: e,
        );
      case 'invalid-email':
        return AuthException(
          message: 'The email address is invalid.',
          code: e.code,
          originalError: e,
        );
      case 'weak-password':
        return AuthException(
          message: 'Password is too weak. Please use at least 6 characters.',
          code: e.code,
          originalError: e,
        );
      case 'user-disabled':
        return AuthException(
          message: 'This account has been disabled. Please contact support.',
          code: e.code,
          originalError: e,
        );
      case 'too-many-requests':
        return AuthException(
          message:
              'Too many unsuccessful attempts. Please try again in a few minutes.',
          code: e.code,
          originalError: e,
        );
      case 'network-request-failed':
        return AuthException(
          message: 'Network error. Please check your internet connection.',
          code: e.code,
          originalError: e,
        );
      default:
        return AuthException(
          message: e.message ?? 'An authentication error occurred (${e.code}).',
          code: e.code,
          originalError: e,
        );
    }
  }
}
