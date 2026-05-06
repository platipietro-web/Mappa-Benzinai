import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/core/errors/exceptions.dart';
import 'package:mappa_prezzi_benzina/core/utils/logger.dart';
import 'package:mappa_prezzi_benzina/data/models/gas_station_model.dart';
import 'package:mappa_prezzi_benzina/data/models/price_snapshot_model.dart';
import 'package:mappa_prezzi_benzina/data/models/price_update_model.dart' hide Timestamp;
import 'package:mappa_prezzi_benzina/data/models/refueling_log_model.dart';
import 'package:mappa_prezzi_benzina/domain/entities/price_snapshot.dart';
import 'package:mappa_prezzi_benzina/domain/entities/refueling_log.dart';
import 'package:mappa_prezzi_benzina/domain/entities/saved_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_profile.dart';
import 'package:mappa_prezzi_benzina/domain/entities/vehicle_profile.dart';
import 'package:uuid/uuid.dart';

abstract class FirestoreService {
  Future<List<GasStationModel>> getNearbyStations(
    double latitude,
    double longitude,
    double radiusKm,
  );
  Future<GasStationModel?> getStationById(String stationId);
  Future<void> addPriceUpdate(PriceUpdateModel update);
  Future<List<PriceUpdateModel>> getPriceUpdatesForStation(String stationId);
  Future<void> createUserProfile(String userId, String email, {String? displayName});
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

  // ── Profilo utente ─────────────────────────────────────────────────────────
  Future<UserProfile?> getUserProfile(String userId);
  Future<void> saveUserProfile(UserProfile profile);

  // ── Storico prezzi ─────────────────────────────────────────────────────────
  Future<void> savePriceSnapshot(
      String stationId, String fuelType, double price);
  Future<List<PriceSnapshot>> getPriceSnapshots(
      String stationId, String fuelType);

  // ── Log rifornimenti ───────────────────────────────────────────────────────
  Future<void> addRefuelingLog(RefuelingLogModel log);
  Future<List<RefuelingLog>> getRefuelingLogs(String userId);
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
  Future<void> createUserProfile(String userId, String email, {String? displayName}) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .set({
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        if (displayName != null && displayName.isNotEmpty) 'displayName': displayName,
      }, SetOptions(merge: true));
    } catch (e) {
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

  // ── Profilo utente ──────────────────────────────────────────────────────────

  @override
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();
      if (!doc.exists || doc.data() == null) return null;
      final d = doc.data()!;

      List<VehicleProfile> vehicles = [];
      String? activeVehicleId;

      if (d.containsKey('vehicles') && d['vehicles'] is List) {
        // Formato nuovo: lista veicoli
        final rawList = d['vehicles'] as List<dynamic>;
        vehicles = rawList
            .whereType<Map<String, dynamic>>()
            .map(VehicleProfile.fromMap)
            .toList();
        activeVehicleId = d['activeVehicleId'] as String?;
      } else if (d.containsKey('fuelConsumption')) {
        // Migrazione formato legacy → crea un veicolo di default
        final legacy = VehicleProfile(
          id: const Uuid().v4(),
          name: 'Il mio veicolo',
          fuelConsumption:
              (d['fuelConsumption'] as num?)?.toDouble() ?? 10.0,
          tankSize: (d['tankSize'] as num?)?.toDouble() ?? 50.0,
          preferredFuelType:
              d['preferredFuelType'] as String? ?? 'Benzina',
        );
        vehicles = [legacy];
        activeVehicleId = legacy.id;
      }

      return UserProfile(
        userId: userId,
        email: d['email'] as String?,
        displayName: d['displayName'] as String?,
        vehicles: vehicles,
        activeVehicleId: activeVehicleId,
      );
    } catch (e) {
      logError('Firestore: error fetching user profile', e);
      return null;
    }
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(profile.userId)
          .set({
        'vehicles': profile.vehicles.map((v) => v.toMap()).toList(),
        'activeVehicleId': profile.activeVehicleId,
        if (profile.displayName != null && profile.displayName!.isNotEmpty)
          'displayName': profile.displayName,
      }, SetOptions(merge: true));
    } catch (e) {
      logError('Firestore: error saving user profile', e);
      throw DatabaseException(message: 'Impossibile salvare il profilo');
    }
  }

  // ── Storico prezzi ──────────────────────────────────────────────────────────

  @override
  Future<void> savePriceSnapshot(
      String stationId, String fuelType, double price) async {
    try {
      // DocID = fuelType_YYYY-MM-DD → deduplicazione naturale, nessun indice
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      // Sanitizza fuelType per usarlo come parte del docId
      final safeType = fuelType.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final docId = '${safeType}_$dateStr';

      final ref = _firestore
          .collection(AppConstants.stationsCollection)
          .doc(stationId)
          .collection(AppConstants.priceHistoryCollection)
          .doc(docId);

      final existing = await ref.get();
      if (existing.exists) return; // già salvato oggi per questo carburante

      final model = PriceSnapshotModel(
        stationId: stationId,
        fuelType: fuelType,
        price: price,
        timestamp: DateTime.now(),
      );
      await ref.set(model.toFirestore());
    } catch (e) {
      logError('Firestore: error saving price snapshot', e);
    }
  }

  @override
  Future<List<PriceSnapshot>> getPriceSnapshots(
      String stationId, String fuelType) async {
    try {
      // Nessun orderBy né filtro lato Firestore: evita indici composti e
      // permission-denied su Firestore Web. Ordinamento e filtraggio client-side.
      final snapshot = await _firestore
          .collection(AppConstants.stationsCollection)
          .doc(stationId)
          .collection(AppConstants.priceHistoryCollection)
          .limit(90)
          .get();

      final results = snapshot.docs
          .map((doc) =>
              PriceSnapshotModel.fromFirestore(doc.data(), stationId))
          .where((s) => s.fuelType == fuelType)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Tieni solo gli ultimi 60 punti dopo l'ordinamento
      return results.length > 60 ? results.sublist(results.length - 60) : results;
    } catch (e) {
      logError('Firestore: error fetching price snapshots', e);
      return [];
    }
  }

  // ── Log rifornimenti ────────────────────────────────────────────────────────

  @override
  Future<void> addRefuelingLog(RefuelingLogModel log) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(log.userId)
          .collection(AppConstants.refuelingLogsCollection)
          .add(log.toFirestore());
    } catch (e) {
      logError('Firestore: error adding refueling log', e);
      throw DatabaseException(message: 'Impossibile salvare il rifornimento');
    }
  }

  @override
  Future<List<RefuelingLog>> getRefuelingLogs(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.refuelingLogsCollection)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) =>
              RefuelingLogModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      logError('Firestore: error fetching refueling logs', e);
      throw DatabaseException(
          message: 'Impossibile caricare i rifornimenti');
    }
  }
}
