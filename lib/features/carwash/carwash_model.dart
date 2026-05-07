import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mappa_prezzi_benzina/domain/entities/car_wash.dart';

class CarWashModel extends CarWash {
  const CarWashModel({
    required super.id,
    required super.name,
    super.address,
    required super.latitude,
    required super.longitude,
    required super.type,
    required super.hasVacuum,
    required super.paymentType,
    super.createdAt,
  });

  factory CarWashModel.fromJson(Map<String, dynamic> json) {
    return CarWashModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Autolavaggio',
      address: json['address'] as String?,
      latitude: ((json['latitude'] as num?) ?? 0.0).toDouble(),
      longitude: ((json['longitude'] as num?) ?? 0.0).toDouble(),
      type: (json['type'] as String?) ?? 'self-service',
      hasVacuum: (json['has_vacuum'] as bool?) ?? false,
      paymentType: (json['payment_type'] as String?) ?? 'coins',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  factory CarWashModel.fromFirestore(Map<String, dynamic> json, String docId) {
    final location = json['location'] as Map<String, dynamic>?;
    return CarWashModel(
      id: docId,
      name: (json['name'] as String?) ?? 'Autolavaggio',
      address: json['address'] as String?,
      latitude: ((location?['latitude'] as num?) ?? 0.0).toDouble(),
      longitude: ((location?['longitude'] as num?) ?? 0.0).toDouble(),
      type: (json['type'] as String?) ?? 'self-service',
      hasVacuum: (json['has_vacuum'] as bool?) ?? false,
      paymentType: (json['payment_type'] as String?) ?? 'coins',
      createdAt: json['created_at'] != null
          ? (json['created_at'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (address != null) 'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'type': type,
        'has_vacuum': hasVacuum,
        'payment_type': paymentType,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  Map<String, dynamic> toFirestore() => {
        'name': name,
        if (address != null && address!.isNotEmpty) 'address': address,
        'location': {'latitude': latitude, 'longitude': longitude},
        'type': type,
        'has_vacuum': hasVacuum,
        'payment_type': paymentType,
        'created_at': FieldValue.serverTimestamp(),
      };
}
