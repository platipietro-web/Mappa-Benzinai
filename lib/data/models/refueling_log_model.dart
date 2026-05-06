import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mappa_prezzi_benzina/domain/entities/refueling_log.dart';

class RefuelingLogModel extends RefuelingLog {
  const RefuelingLogModel({
    required super.id,
    required super.userId,
    required super.stationId,
    required super.stationName,
    required super.fuelType,
    required super.pricePerLiter,
    required super.liters,
    required super.totalCost,
    required super.savedVsArea,
    required super.areaAvgPrice,
    required super.timestamp,
  });

  factory RefuelingLogModel.fromFirestore(
      Map<String, dynamic> data, String docId) {
    return RefuelingLogModel(
      id: docId,
      userId: data['userId'] as String? ?? '',
      stationId: data['stationId'] as String? ?? '',
      stationName: data['stationName'] as String? ?? '',
      fuelType: data['fuelType'] as String? ?? '',
      pricePerLiter: (data['pricePerLiter'] as num?)?.toDouble() ?? 0.0,
      liters: (data['liters'] as num?)?.toDouble() ?? 0.0,
      totalCost: (data['totalCost'] as num?)?.toDouble() ?? 0.0,
      savedVsArea: (data['savedVsArea'] as num?)?.toDouble() ?? 0.0,
      areaAvgPrice: (data['areaAvgPrice'] as num?)?.toDouble() ?? 0.0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'stationId': stationId,
        'stationName': stationName,
        'fuelType': fuelType,
        'pricePerLiter': pricePerLiter,
        'liters': liters,
        'totalCost': totalCost,
        'savedVsArea': savedVsArea,
        'areaAvgPrice': areaAvgPrice,
        'timestamp': FieldValue.serverTimestamp(),
      };
}
