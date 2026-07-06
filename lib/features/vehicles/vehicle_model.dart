import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mappa_prezzi_benzina/domain/entities/vehicle.dart';

class VehicleModel extends Vehicle {
  const VehicleModel({
    required super.id,
    required super.userId,
    required super.name,
    super.plate,
    required super.fuelType,
    super.tankSizeLiters,
    super.declaredConsumptionL100km,
    super.lastOdometerKm,
    super.year,
    super.notes,
    super.isDefault,
    required super.createdAt,
  });

  factory VehicleModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return VehicleModel(
      id: docId,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? 'Veicolo',
      plate: data['plate'] as String?,
      fuelType: data['fuelType'] as String? ?? 'Benzina',
      tankSizeLiters: (data['tankSizeLiters'] as num?)?.toDouble(),
      declaredConsumptionL100km:
          (data['declaredConsumptionL100km'] as num?)?.toDouble(),
      lastOdometerKm: (data['lastOdometerKm'] as num?)?.toInt(),
      year: (data['year'] as num?)?.toInt(),
      notes: data['notes'] as String?,
      isDefault: data['isDefault'] as bool? ?? false,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'name': name,
        if (plate != null && plate!.isNotEmpty) 'plate': plate,
        'fuelType': fuelType,
        if (tankSizeLiters != null) 'tankSizeLiters': tankSizeLiters,
        if (declaredConsumptionL100km != null)
          'declaredConsumptionL100km': declaredConsumptionL100km,
        if (lastOdometerKm != null) 'lastOdometerKm': lastOdometerKm,
        if (year != null) 'year': year,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'isDefault': isDefault,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
