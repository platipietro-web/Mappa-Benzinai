import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/core/errors/exceptions.dart';
import 'package:mappa_prezzi_benzina/core/utils/logger.dart';
import 'package:mappa_prezzi_benzina/data/models/gas_station_model.dart';
import 'package:mappa_prezzi_benzina/data/models/price_update_model.dart';

abstract class FirestoreService {
  Future<List<GasStationModel>> getNearbyStations(
    double latitude,
    double longitude,
    double radiusKm,
  );
  Future<GasStationModel?> getStationById(String stationId);
  Future<void> addPriceUpdate(PriceUpdateModel update);
  Future<List<PriceUpdateModel>> getPriceUpdatesForStation(String stationId);
  Future<void> addFavorite(String userId, String stationId);
  Future<void> removeFavorite(String userId, String stationId);
  Future<List<String>> getFavorites(String userId);
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

      // Firestore non supporta query geospaziali native → filtro lato client
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
      logInfo('Firestore: fetching station $stationId');
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
      logInfo('Firestore: adding price update for ${update.stationId}');

      final batch = _firestore.batch();

      // Aggiungi sub-collection price_updates
      final updateRef = _firestore
          .collection(AppConstants.stationsCollection)
          .doc(update.stationId)
          .collection(AppConstants.priceUpdatesCollection)
          .doc();
      batch.set(updateRef, update.toFirestore());

      // Aggiorna il prezzo corrente nella stazione
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
      logInfo('Firestore: fetching price updates for $stationId');

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
  Future<void> addFavorite(String userId, String stationId) async {
    try {
      logInfo('Firestore: adding favorite $stationId for user $userId');
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.favoritesCollection)
          .doc(stationId)
          .set({
        'stationId': stationId,
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
      logInfo('Firestore: removing favorite $stationId for user $userId');
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
  Future<List<String>> getFavorites(String userId) async {
    try {
      logInfo('Firestore: fetching favorites for user $userId');
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.favoritesCollection)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['stationId'] as String)
          .toList();
    } catch (e) {
      logError('Firestore: error fetching favorites', e);
      throw DatabaseException(message: 'Impossibile caricare i preferiti');
    }
  }
}