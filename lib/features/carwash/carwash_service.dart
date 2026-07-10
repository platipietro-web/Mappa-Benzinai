import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/features/carwash/carwash_model.dart';
import 'package:mappa_prezzi_benzina/features/carwash/osm_carwash_importer.dart';
import 'package:uuid/uuid.dart';

abstract class CarWashService {
  Future<List<CarWashModel>> getCarWashes(
      double lat, double lon, double radiusKm);
  Future<void> addCarWash(CarWashModel carWash);
  Future<void> updateCarWash(CarWashModel carWash);

  /// Fetches car washes from OSM Overpass API, writes them to Firestore
  /// and returns the imported list so callers can populate the map immediately.
  Future<List<CarWashModel>> importFromOsm(double lat, double lon, double radiusKm);
}

class CarWashServiceImpl implements CarWashService {
  final FirebaseFirestore _firestore;
  final OsmCarWashImporter _importer;
  static const _uuid = Uuid();

  CarWashServiceImpl(this._firestore, this._importer);

  @override
  Future<List<CarWashModel>> getCarWashes(
      double lat, double lon, double radiusKm) async {
    final snapshot = await _firestore
        .collection(AppConstants.carWashesCollection)
        .limit(500)
        .get();

    return snapshot.docs
        .map((doc) => CarWashModel.fromFirestore(doc.data(), doc.id))
        .where((w) => w.getDistanceFromCoordinates(lat, lon) <= radiusKm)
        .toList();
  }

  @override
  Future<void> addCarWash(CarWashModel carWash) async {
    final id = carWash.id.isEmpty ? _uuid.v4() : carWash.id;
    await _firestore
        .collection(AppConstants.carWashesCollection)
        .doc(id)
        .set(carWash.toFirestore());
  }

  @override
  Future<void> updateCarWash(CarWashModel carWash) async {
    await _firestore
        .collection(AppConstants.carWashesCollection)
        .doc(carWash.id)
        .update({
      'type': carWash.type,
      'has_vacuum': carWash.hasVacuum,
      'payment_type': carWash.paymentType,
      if (carWash.address != null && carWash.address!.isNotEmpty)
        'address': carWash.address,
    });
  }

  @override
  Future<List<CarWashModel>> importFromOsm(double lat, double lon, double radiusKm) async {
    // Cella di ~0.25° (≈ 20-28km in Italia): raggruppa le richieste di import
    // per zona così che utenti diversi che aprono la stessa area non
    // richiamino Overpass ripetutamente — condiviso su Firestore, non solo
    // per-dispositivo, perché il problema è il traffico aggregato su un
    // servizio pubblico gratuito con fair-use policy.
    final cellId = _importCellId(lat, lon);
    final cellRef =
        _firestore.collection(AppConstants.importCellsCollection).doc(cellId);

    final cellDoc = await cellRef.get();
    final lastImported = cellDoc.data()?['lastImportedAt'] as Timestamp?;
    if (lastImported != null &&
        DateTime.now().difference(lastImported.toDate()) <
            AppConstants.carWashImportCooldown) {
      return [];
    }

    final washes = await _importer.fetchCarWashes(lat, lon, radiusKm);

    await cellRef.set({'lastImportedAt': FieldValue.serverTimestamp()});

    if (washes.isEmpty) return [];

    // Firestore batch limit is 500 — split if needed.
    const batchSize = 400;
    for (var i = 0; i < washes.length; i += batchSize) {
      final chunk = washes.sublist(i, (i + batchSize).clamp(0, washes.length));
      final batch = _firestore.batch();
      for (final w in chunk) {
        final ref = _firestore
            .collection(AppConstants.carWashesCollection)
            .doc(w.id);
        batch.set(ref, w.toFirestore());
      }
      await batch.commit();
    }

    return washes;
  }

  String _importCellId(double lat, double lon) {
    final latCell = (lat * 4).round();
    final lonCell = (lon * 4).round();
    return '${latCell}_$lonCell';
  }
}
