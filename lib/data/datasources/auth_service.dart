import 'package:firebase_auth/firebase_auth.dart';
import 'package:mappa_prezzi_benzina/core/errors/exceptions.dart';
import 'package:mappa_prezzi_benzina/core/utils/logger.dart';

abstract class AuthService {
  Future<UserCredential?> signUpWithEmail(String email, String password);
  Future<UserCredential?> signInWithEmail(String email, String password);
  Future<UserCredential?> signInAnonymously();
  Future<void> signOut();
  Future<void> deleteAccount();
  User? getCurrentUser();
  Stream<User?> authStateChanges();
  Future<void> resetPassword(String email);
}

class AuthServiceImpl implements AuthService {
  final FirebaseAuth _firebaseAuth;

  AuthServiceImpl(this._firebaseAuth);

  @override
  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      logInfo('Signing up with email: $email');
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      logError('Sign up error', e);
      throw AuthException(message: _getAuthErrorMessage(e.code));
    } catch (e) {
      logError('Unexpected error during sign up', e);
      throw AuthException(message: 'Sign up failed');
    }
  }

  @override
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      logInfo('Signing in with email: $email');
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      logError('Sign in error', e);
      throw AuthException(message: _getAuthErrorMessage(e.code));
    } catch (e) {
      logError('Unexpected error during sign in', e);
      throw AuthException(message: 'Sign in failed');
    }
  }

  @override
  Future<UserCredential?> signInAnonymously() async {
    try {
      logInfo('Signing in anonymously');
      final credential = await _firebaseAuth.signInAnonymously();
      return credential;
    } on FirebaseAuthException catch (e) {
      logError('Anonymous sign in error', e);
      throw AuthException(message: _getAuthErrorMessage(e.code));
    } catch (e) {
      logError('Unexpected error during anonymous sign in', e);
      throw AuthException(message: 'Anonymous sign in failed');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      logInfo('Signing out');
      await _firebaseAuth.signOut();
    } catch (e) {
      logError('Sign out error', e);
      throw AuthException(message: 'Sign out failed');
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw AuthException(message: 'No user logged in');
      logInfo('Deleting account: ${user.uid}');
      await user.delete();
    } on FirebaseAuthException catch (e) {
      logError('Delete account error', e);
      throw AuthException(message: _getAuthErrorMessage(e.code));
    } catch (e) {
      logError('Unexpected error during account deletion', e);
      throw AuthException(message: 'Account deletion failed');
    }
  }

  @override
  User? getCurrentUser() {
    return _firebaseAuth.currentUser;
  }

  @override
  Stream<User?> authStateChanges() {
    return _firebaseAuth.authStateChanges();
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      logInfo('Resetting password for: $email');
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      logError('Password reset error', e);
      throw AuthException(message: _getAuthErrorMessage(e.code));
    } catch (e) {
      logError('Unexpected error during password reset', e);
      throw AuthException(message: 'Password reset failed');
    }
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'User not found';
      case 'wrong-password':
        return 'Wrong password';
      case 'email-already-in-use':
        return 'Email already in use';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email address';
      default:
        return 'Authentication failed: $code';
    }
  }
}
