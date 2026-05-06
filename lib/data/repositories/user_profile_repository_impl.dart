import 'package:mappa_prezzi_benzina/core/utils/logger.dart';
import 'package:mappa_prezzi_benzina/data/datasources/firestore_service.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_profile.dart';
import 'package:mappa_prezzi_benzina/domain/repositories/repositories.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  final FirestoreService _firestoreService;

  UserProfileRepositoryImpl(this._firestoreService);

  @override
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      return await _firestoreService.getUserProfile(userId);
    } catch (e) {
      logError('Error in getUserProfile repository', e);
      return null;
    }
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      await _firestoreService.saveUserProfile(profile);
    } catch (e) {
      logError('Error in saveUserProfile repository', e);
      rethrow;
    }
  }
}
