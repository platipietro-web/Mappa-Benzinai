import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mappa_prezzi_benzina/domain/entities/vehicle_cost_entry.dart';

class VehicleCostEntryModel extends VehicleCostEntry {
  const VehicleCostEntryModel({
    required super.id,
    required super.vehicleId,
    required super.userId,
    required super.category,
    required super.amount,
    required super.date,
    super.note,
    super.validUntil,
    required super.createdAt,
  });

  factory VehicleCostEntryModel.fromFirestore(
      Map<String, dynamic> data, String docId) {
    return VehicleCostEntryModel(
      id: docId,
      vehicleId: data['vehicleId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      category: VehicleCostCategory.values.firstWhere(
        (c) => c.name == data['category'],
        orElse: () => VehicleCostCategory.other,
      ),
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'] as String?,
      validUntil: (data['validUntil'] as Timestamp?)?.toDate(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'vehicleId': vehicleId,
        'userId': userId,
        'category': category.name,
        'amount': amount,
        'date': Timestamp.fromDate(date),
        if (note != null && note!.isNotEmpty) 'note': note,
        if (validUntil != null) 'validUntil': Timestamp.fromDate(validUntil!),
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
