import 'package:mappa_prezzi_benzina/core/utils/logger.dart';
import 'package:mappa_prezzi_benzina/data/datasources/firestore_service.dart';
import 'package:mappa_prezzi_benzina/data/datasources/fuel_price_api.dart';
import 'package:mappa_prezzi_benzina/data/models/price_update_model.dart';
import 'package:mappa_prezzi_benzina/domain/entities/gas_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/price_update.dart';
import 'package:mappa_prezzi_benzina/domain/entities/saved_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';
import 'package:mappa_prezzi_benzina/domain/repositories/repositories.dart';

class GasStationRepositoryImpl implements GasStationRepository {
  final FirestoreService _firestoreService;
  final FuelPriceApi _fuelPriceApi;

  GasStationRepositoryImpl(this._firestoreService, this._fuelPriceApi);

  @override
  Future<List<GasStation>> getNearbyStations(
    UserLocation location,
    double radiusKm,
  ) async {
    try {
      final stations = await _fuelPriceApi.getNearbyStations(
        location,
        radiusKm,
      );
      if (stations.isNotEmpty) {
        return stations;
      }

      return await _firestoreService.getNearbyStations(
        location.latitude,
        location.longitude,
        radiusKm,
      );
    } catch (e) {
      logError('Error in getNearbyStations repository', e);
      return await _firestoreService.getNearbyStations(
        location.latitude,
        location.longitude,
        radiusKm,
      );
    }
  }

  @override
  Future<GasStation?> getStationDetails(String stationId) async {
    try {
      return await _firestoreService.getStationById(stationId);
    } catch (e) {
      logError('Error in getStationDetails repository', e);
      rethrow;
    }
  }

  @override
  Future<void> submitPriceUpdate(PriceUpdate update) async {
    try {
      final model = PriceUpdateModel(
        id: update.id,
        stationId: update.stationId,
        userId: update.userId,
        fuelType: update.fuelType,
        price: update.price,
        timestamp: update.timestamp,
        likes: update.likes,
        isFlagged: update.isFlagged,
      );
      await _firestoreService.addPriceUpdate(model);
    } catch (e) {
      logError('Error in submitPriceUpdate repository', e);
      rethrow;
    }
  }

  @override
  Future<List<PriceUpdate>> getPriceHistory(String stationId) async {
    try {
      return await _firestoreService.getPriceUpdatesForStation(stationId);
    } catch (e) {
      logError('Error in getPriceHistory repository', e);
      rethrow;
    }
  }

  @override
  Future<void> addToFavorites(String userId, GasStation station) async {
    try {
      await _firestoreService.addFavorite(
        userId,
        station.id,
        station.name,
        station.address,
        station.brand,
        station.latitude,
        station.longitude,
        station.prices,
      );
    } catch (e) {
      logError('Error in addToFavorites repository', e);
      rethrow;
    }
  }

  @override
  Future<void> removeFromFavorites(String userId, String stationId) async {
    try {
      await _firestoreService.removeFavorite(userId, stationId);
    } catch (e) {
      logError('Error in removeFromFavorites repository', e);
      rethrow;
    }
  }

  @override
  Future<List<SavedStation>> getFavorites(String userId) async {
    try {
      final saved = await _firestoreService.getFavorites(userId);
      if (saved.isEmpty) return saved;

      // For any station missing prices, fetch current data from MIMIT API
      final missingIds =
          saved.where((s) => s.prices.isEmpty).map((s) => s.id).toList();
      if (missingIds.isEmpty) return saved;

      final apiMap = await _fuelPriceApi.getStationsByIds(missingIds);

      return saved.map((s) {
        if (s.prices.isEmpty && apiMap.containsKey(s.id)) {
          return SavedStation(
            id: s.id,
            name: s.name,
            address: s.address,
            brand: s.brand,
            latitude: s.latitude,
            longitude: s.longitude,
            addedAt: s.addedAt,
            prices: apiMap[s.id]!.prices,
          );
        }
        return s;
      }).toList();
    } catch (e) {
      logError('Error in getFavorites repository', e);
      rethrow;
    }
  }
}
