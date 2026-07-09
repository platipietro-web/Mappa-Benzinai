import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/core/utils/logger.dart';
import 'package:mappa_prezzi_benzina/features/vehicles/vehicle_cost_entry_model.dart';
import 'package:mappa_prezzi_benzina/features/vehicles/vehicle_model.dart';
import 'package:uuid/uuid.dart';

abstract class VehicleService {
  Future<List<VehicleModel>> getVehicles(String userId);
  Future<void> addVehicle(VehicleModel vehicle);
  Future<void> updateVehicle(VehicleModel vehicle);
  Future<void> deleteVehicle(String userId, String vehicleId);
  Future<void> setDefaultVehicle(String userId, String vehicleId);
  Future<void> updateLastOdometer(
      String userId, String vehicleId, int odometerKm);

  Future<List<VehicleCostEntryModel>> getCostEntries(
      String userId, String vehicleId);
  Future<void> addCostEntry(VehicleCostEntryModel entry);
  Future<void> updateCostEntry(VehicleCostEntryModel entry);
  Future<void> deleteCostEntry(String userId, String vehicleId, String entryId);
}

class VehicleServiceImpl implements VehicleService {
  final FirebaseFirestore _firestore;
  static const _uuid = Uuid();

  VehicleServiceImpl(this._firestore);

  CollectionReference<Map<String, dynamic>> _vehiclesCol(String userId) =>
      _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.vehiclesCollection);

  CollectionReference<Map<String, dynamic>> _costEntriesCol(
          String userId, String vehicleId) =>
      _vehiclesCol(userId)
          .doc(vehicleId)
          .collection(AppConstants.vehicleCostEntriesCollection);

  @override
  Future<List<VehicleModel>> getVehicles(String userId) async {
    try {
      final snapshot = await _vehiclesCol(userId).get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => VehicleModel.fromFirestore(doc.data(), doc.id))
            .toList();
      }
      // Nessun veicolo nel nuovo formato: prova a migrare il vecchio
      // VehicleProfile incorporato nel documento utente, se presente.
      return await _migrateLegacyVehicles(userId);
    } catch (e) {
      logError('VehicleService: error fetching vehicles', e);
      return [];
    }
  }

  /// Migrazione una tantum dal vecchio formato `users/{uid}.vehicles[]`
  /// (VehicleProfile) al nuovo `users/{uid}/vehicles/{id}`, così gli utenti
  /// che avevano già configurato un veicolo non lo perdono.
  Future<List<VehicleModel>> _migrateLegacyVehicles(String userId) async {
    try {
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();
      final data = userDoc.data();
      if (data == null) return [];

      final legacyMaps = <Map<String, dynamic>>[];
      if (data['vehicles'] is List) {
        legacyMaps.addAll((data['vehicles'] as List)
            .whereType<Map<String, dynamic>>());
      } else if (data.containsKey('fuelConsumption')) {
        legacyMaps.add(data);
      }
      if (legacyMaps.isEmpty) return [];

      final migrated = <VehicleModel>[];
      for (var i = 0; i < legacyMaps.length; i++) {
        final m = legacyMaps[i];
        final model = VehicleModel(
          id: _uuid.v4(),
          userId: userId,
          name: m['name'] as String? ?? 'Il mio veicolo',
          fuelType: m['preferredFuelType'] as String? ?? 'Benzina',
          tankSizeLiters: (m['tankSize'] as num?)?.toDouble(),
          declaredConsumptionL100km:
              (m['fuelConsumption'] as num?)?.toDouble(),
          isDefault: i == 0,
          createdAt: DateTime.now(),
        );
        await _vehiclesCol(userId).doc(model.id).set(model.toFirestore());
        migrated.add(model);
      }
      return migrated;
    } catch (e) {
      logError('VehicleService: error migrating legacy vehicles', e);
      return [];
    }
  }

  @override
  Future<void> addVehicle(VehicleModel vehicle) async {
    final id = vehicle.id.isEmpty ? _uuid.v4() : vehicle.id;
    await _vehiclesCol(vehicle.userId).doc(id).set(vehicle.toFirestore());
  }

  @override
  Future<void> updateVehicle(VehicleModel vehicle) async {
    // set (non update): toFirestore() omette i campi opzionali nulli, con
    // update() un campo svuotato (es. targa rimossa) resterebbe nel
    // documento con il vecchio valore invece di sparire.
    await _vehiclesCol(vehicle.userId)
        .doc(vehicle.id)
        .set(vehicle.toFirestore());
  }

  @override
  Future<void> deleteVehicle(String userId, String vehicleId) async {
    final entries = await _costEntriesCol(userId, vehicleId).get();
    for (final doc in entries.docs) {
      await doc.reference.delete();
    }
    await _vehiclesCol(userId).doc(vehicleId).delete();
  }

  @override
  Future<void> setDefaultVehicle(String userId, String vehicleId) async {
    final snapshot = await _vehiclesCol(userId).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isDefault': doc.id == vehicleId});
    }
    await batch.commit();
  }

  @override
  Future<void> updateLastOdometer(
      String userId, String vehicleId, int odometerKm) async {
    await _vehiclesCol(userId)
        .doc(vehicleId)
        .update({'lastOdometerKm': odometerKm});
  }

  @override
  Future<List<VehicleCostEntryModel>> getCostEntries(
      String userId, String vehicleId) async {
    final snapshot = await _costEntriesCol(userId, vehicleId).get();
    return snapshot.docs
        .map((doc) =>
            VehicleCostEntryModel.fromFirestore(doc.data(), doc.id))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> addCostEntry(VehicleCostEntryModel entry) async {
    final id = entry.id.isEmpty ? _uuid.v4() : entry.id;
    await _costEntriesCol(entry.userId, entry.vehicleId)
        .doc(id)
        .set(entry.toFirestore());
  }

  @override
  Future<void> updateCostEntry(VehicleCostEntryModel entry) async {
    // set (non update): stesso motivo di updateVehicle sopra.
    await _costEntriesCol(entry.userId, entry.vehicleId)
        .doc(entry.id)
        .set(entry.toFirestore());
  }

  @override
  Future<void> deleteCostEntry(
      String userId, String vehicleId, String entryId) async {
    await _costEntriesCol(userId, vehicleId).doc(entryId).delete();
  }
}
