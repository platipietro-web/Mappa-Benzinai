import 'package:mappa_prezzi_benzina/core/utils/logger.dart';
import 'package:mappa_prezzi_benzina/data/datasources/auth_service.dart';
import 'package:mappa_prezzi_benzina/data/datasources/firestore_service.dart';
import 'package:mappa_prezzi_benzina/domain/repositories/repositories.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  AuthRepositoryImpl(this._authService, this._firestoreService);

  @override
  Future<void> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _authService.signUpWithEmail(email, password);
      // Crea profilo utente su Firestore dopo la registrazione
      final uid = credential?.user?.uid;
      if (uid != null) {
        await _firestoreService.createUserProfile(uid, email);
      }
    } catch (e) {
      logError('Error in signUpWithEmail repository', e);
      rethrow;
    }
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _authService.signInWithEmail(email, password);
    } catch (e) {
      logError('Error in signInWithEmail repository', e);
      rethrow;
    }
  }

  @override
  Future<void> signInAnonymously() async {
    try {
      await _authService.signInAnonymously();
    } catch (e) {
      logError('Error in signInAnonymously repository', e);
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      logError('Error in signOut repository', e);
      rethrow;
    }
  }

  @override
  String? getCurrentUserId() {
    try {
      return _authService.getCurrentUser()?.uid;
    } catch (e) {
      logError('Error in getCurrentUserId repository', e);
      return null;
    }
  }

  @override
  bool isCurrentUserAnonymous() {
    return _authService.getCurrentUser()?.isAnonymous ?? false;
  }

  @override
  Stream<String?> authStateChanges() {
    return _authService.authStateChanges().map((user) => user?.uid);
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
    } catch (e) {
      logError('Error in resetPassword repository', e);
      rethrow;
    }
  }
}
