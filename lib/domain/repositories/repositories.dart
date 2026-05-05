import 'package:mappa_prezzi_benzina/domain/entities/gas_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/price_update.dart';
import 'package:mappa_prezzi_benzina/domain/entities/saved_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';

abstract class GasStationRepository {
  Future<List<GasStation>> getNearbyStations(
    UserLocation location,
    double radiusKm,
  );
  Future<GasStation?> getStationDetails(String stationId);
  Future<void> submitPriceUpdate(PriceUpdate update);
  Future<List<PriceUpdate>> getPriceHistory(String stationId);
  Future<void> addToFavorites(String userId, GasStation station);
  Future<void> removeFromFavorites(String userId, String stationId);
  Future<List<SavedStation>> getFavorites(String userId);
}

abstract class LocationRepository {
  Future<UserLocation> getCurrentLocation();
  Future<bool> requestLocationPermission();
  Future<bool> isLocationServiceEnabled();
  Stream<UserLocation> getLocationUpdates();
}

abstract class AuthRepository {
  Future<void> signUpWithEmail(String email, String password);
  Future<void> signInWithEmail(String email, String password);
  Future<void> signInAnonymously();
  Future<void> signOut();
  String? getCurrentUserId();
  bool isCurrentUserAnonymous();
  Stream<String?> authStateChanges();
  Future<void> resetPassword(String email);
}
