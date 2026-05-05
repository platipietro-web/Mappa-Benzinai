import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/core/errors/exceptions.dart';
import 'package:mappa_prezzi_benzina/core/utils/logger.dart';
import 'package:mappa_prezzi_benzina/data/models/gas_station_model.dart';
import 'package:mappa_prezzi_benzina/data/models/price_update_model.dart' hide Timestamp;
import 'package:mappa_prezzi_benzina/domain/entities/saved_station.dart';

abstract class FirestoreService {
  Future<List<GasStationModel>> getNearbyStations(
    double latitude,
    double longitude,
    double radiusKm,
  );
  Future<GasStationModel?> getStationById(String stationId);
  Future<void> addPriceUpdate(PriceUpdateModel update);
  Future<List<PriceUpdateModel>> getPriceUpdatesForStation(String stationId);
  Future<void> createUserProfile(String userId, String email);
  Future<void> addFavorite(
    String userId,
    String stationId,
    String name,
    String address,
    String? brand,
    double lat,
    double lon,
    Map<String, double> prices,
  );
  Future<void> removeFavorite(String userId, String stationId);
  Future<List<SavedStation>> getFavorites(String userId);
}

class FirestoreServiceImpl implements FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreServiceImpl(this._firestore);

  @override
  Future<List<GasStationModel>> getNearbyStations(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    try {
      logInfo(
          'Firestore: fetching stations near $latitude,$longitude r=${radiusKm}km');

      final snapshot = await _firestore
          .collection(AppConstants.stationsCollection)
          .limit(500)
          .get();

      final stations = snapshot.docs
          .map((doc) => GasStationModel.fromFirestore(doc.data(), doc.id))
          .toList();

      final nearby = stations
          .where((s) =>
              s.getDistanceFromCoordinates(latitude, longitude) <= radiusKm)
          .toList()
        ..sort((a, b) => a
            .getDistanceFromCoordinates(latitude, longitude)
            .compareTo(b.getDistanceFromCoordinates(latitude, longitude)));

      logInfo('Firestore: found ${nearby.length} nearby stations');
      return nearby;
    } catch (e) {
      logError('Firestore: error fetching nearby stations', e);
      throw DatabaseException(message: 'Impossibile caricare le stazioni');
    }
  }

  @override
  Future<GasStationModel?> getStationById(String stationId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.stationsCollection)
          .doc(stationId)
          .get();

      if (!doc.exists || doc.data() == null) return null;
      return GasStationModel.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      logError('Firestore: error fetching station $stationId', e);
      throw DatabaseException(message: 'Impossibile caricare la stazione');
    }
  }

  @override
  Future<void> addPriceUpdate(PriceUpdateModel update) async {
    try {
      final batch = _firestore.batch();

      final updateRef = _firestore
          .collection(AppConstants.stationsCollection)
          .doc(update.stationId)
          .collection(AppConstants.priceUpdatesCollection)
          .doc();
      batch.set(updateRef, update.toFirestore());

      final stationRef = _firestore
          .collection(AppConstants.stationsCollection)
          .doc(update.stationId);
      batch.update(stationRef, {
        'prices.${update.fuelType}': update.price,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      logError('Firestore: error adding price update', e);
      throw DatabaseException(message: 'Impossibile inviare il prezzo');
    }
  }

  @override
  Future<List<PriceUpdateModel>> getPriceUpdatesForStation(
    String stationId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.stationsCollection)
          .doc(stationId)
          .collection(AppConstants.priceUpdatesCollection)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => PriceUpdateModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      logError('Firestore: error fetching price updates', e);
      throw DatabaseException(
          message: 'Impossibile caricare lo storico prezzi');
    }
  }

  @override
  Future<void> createUserProfile(String userId, String email) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .set({
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Non blocca il signup se fallisce
      logError('Firestore: error creating user profile', e);
    }
  }

  @override
  Future<void> addFavorite(
    String userId,
    String stationId,
    String name,
    String address,
    String? brand,
    double lat,
    double lon,
    Map<String, double> prices,
  ) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.favoritesCollection)
          .doc(stationId)
          .set({
        'stationId': stationId,
        'name': name,
        'address': address,
        'brand': brand,
        'latitude': lat,
        'longitude': lon,
        'prices': prices,
        'addedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logError('Firestore: error adding favorite', e);
      throw DatabaseException(message: 'Impossibile aggiungere ai preferiti');
    }
  }

  @override
  Future<void> removeFavorite(String userId, String stationId) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.favoritesCollection)
          .doc(stationId)
          .delete();
    } catch (e) {
      logError('Firestore: error removing favorite', e);
      throw DatabaseException(message: 'Impossibile rimuovere dai preferiti');
    }
  }

  @override
  Future<List<SavedStation>> getFavorites(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.favoritesCollection)
          .get();

      return snapshot.docs.map((doc) {
        final d = doc.data();
        final rawPrices = d['prices'] as Map<String, dynamic>? ?? {};
        final prices = rawPrices.map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        );
        return SavedStation(
          id: d['stationId'] as String? ?? doc.id,
          name: d['name'] as String? ?? '',
          address: d['address'] as String? ?? '',
          brand: d['brand'] as String?,
          latitude: (d['latitude'] as num?)?.toDouble() ?? 0.0,
          longitude: (d['longitude'] as num?)?.toDouble() ?? 0.0,
          addedAt: (d['addedAt'] as Timestamp?)?.toDate(),
          prices: prices,
        );
      }).toList();
    } catch (e) {
      logError('Firestore: error fetching favorites', e);
      throw DatabaseException(message: 'Impossibile caricare i preferiti');
    }
  }
}
