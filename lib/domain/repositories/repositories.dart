import 'package:mappa_prezzi_benzina/domain/entities/dashboard_stats.dart';
import 'package:mappa_prezzi_benzina/domain/entities/gas_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/price_snapshot.dart';
import 'package:mappa_prezzi_benzina/domain/entities/price_update.dart';
import 'package:mappa_prezzi_benzina/domain/entities/refueling_log.dart';
import 'package:mappa_prezzi_benzina/domain/entities/saved_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_profile.dart';

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
  Future<void> signUpWithEmail(String email, String password, {String? displayName});
  Future<void> signInWithEmail(String email, String password);
  Future<void> signInAnonymously();
  Future<void> signOut();
  String? getCurrentUserId();
  bool isCurrentUserAnonymous();
  Stream<String?> authStateChanges();
  Future<void> resetPassword(String email);
}

abstract class UserProfileRepository {
  Future<UserProfile?> getUserProfile(String userId);
  Future<void> saveUserProfile(UserProfile profile);
}

abstract class AnalyticsRepository {
  // Rifornimenti
  Future<void> logRefueling(RefuelingLog log);
  Future<List<RefuelingLog>> getRefuelingLogs(String userId);

  // Storico prezzi per previsione
  Future<void> savePriceSnapshot(
      String stationId, String fuelType, double price);
  Future<List<PriceSnapshot>> getPriceSnapshots(
      String stationId, String fuelType);

  // Stats dashboard (calcolate lato client dai log)
  Future<DashboardStats> getDashboardStats(String userId);
}
