import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mappa_prezzi_benzina/domain/entities/price_snapshot.dart';

class PriceSnapshotModel extends PriceSnapshot {
  const PriceSnapshotModel({
    required super.stationId,
    required super.fuelType,
    required super.price,
    required super.timestamp,
  });

  factory PriceSnapshotModel.fromFirestore(
      Map<String, dynamic> data, String stationId) {
    return PriceSnapshotModel(
      stationId: stationId,
      fuelType: data['fuelType'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'fuelType': fuelType,
        'price': price,
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'auto',
      };
}
