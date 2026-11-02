import '../models/auth_models.dart';

abstract class AuthService {
  Stream<AuthUser?> get authStateChanges;
  AuthUser? get currentUser;
  bool get isConfigured;

  Future<AuthUser> signInWithEmailAndPassword(String email, String password);
  Future<AuthUser> createUserWithEmailAndPassword(
    String email,
    String password, {
    String? displayName,
  });
  Future<AuthUser?> signInWithGoogle();
  Future<void> sendPasswordResetEmail(String email);
  Future<void> updateDisplayName(String displayName);
  Future<void> signOut();
}
