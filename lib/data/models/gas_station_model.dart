import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mappa_prezzi_benzina/domain/entities/gas_station.dart';

class GasStationModel extends GasStation {
  const GasStationModel({
    required super.id,
    required super.name,
    required super.address,
    required super.latitude,
    required super.longitude,
    super.phoneNumber,
    super.website,
    super.openingHours,
    required super.prices,
    super.lastUpdated,
    super.numberOfRatings,
    super.averageRating,
    super.brand,
  });

  // ─── From JSON (generico / REST) ──────────────────────────────────────────

  factory GasStationModel.fromJson(Map<String, dynamic> json) {
    return GasStationModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Sconosciuto',
      address: (json['address'] as String?) ?? '',
      latitude: ((json['latitude'] as num?) ?? 0.0).toDouble(),
      longitude: ((json['longitude'] as num?) ?? 0.0).toDouble(),
      phoneNumber: json['phoneNumber'] as String?,
      website: json['website'] as String?,
      openingHours: json['openingHours'] as String?,
      prices: _parsePrices(json['prices']),
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'] as String)
          : null,
      numberOfRatings: json['numberOfRatings'] as int?,
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      brand: json['brand'] as String?,
    );
  }

  // ─── From Firestore ───────────────────────────────────────────────────────

  factory GasStationModel.fromFirestore(
    Map<String, dynamic> json,
    String docId,
  ) {
    final location = json['location'] as Map<String, dynamic>?;
    return GasStationModel(
      id: docId,
      name: (json['name'] as String?) ?? 'Sconosciuto',
      address: (json['address'] as String?) ?? '',
      latitude: ((location?['latitude'] as num?) ?? 0.0).toDouble(),
      longitude: ((location?['longitude'] as num?) ?? 0.0).toDouble(),
      phoneNumber: json['phoneNumber'] as String?,
      website: json['website'] as String?,
      openingHours: json['openingHours'] as String?,
      prices: _parsePrices(json['prices']),
      lastUpdated: json['lastUpdated'] != null
          ? (json['lastUpdated'] as Timestamp).toDate()
          : null,
      numberOfRatings: json['numberOfRatings'] as int?,
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      brand: json['brand'] as String?,
    );
  }

  // ─── To JSON ──────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (website != null) 'website': website,
      if (openingHours != null) 'openingHours': openingHours,
      'prices': prices,
      if (lastUpdated != null) 'lastUpdated': lastUpdated!.toIso8601String(),
      if (numberOfRatings != null) 'numberOfRatings': numberOfRatings,
      if (averageRating != null) 'averageRating': averageRating,
      if (brand != null) 'brand': brand,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (website != null) 'website': website,
      if (openingHours != null) 'openingHours': openingHours,
      'prices': prices,
      'lastUpdated': lastUpdated != null
          ? Timestamp.fromDate(lastUpdated!)
          : FieldValue.serverTimestamp(),
      if (numberOfRatings != null) 'numberOfRatings': numberOfRatings,
      if (averageRating != null) 'averageRating': averageRating,
      if (brand != null) 'brand': brand,
    };
  }

  // ─── Helper ───────────────────────────────────────────────────────────────

  static Map<String, double> _parsePrices(dynamic raw) {
    if (raw is! Map) return const {};
    return Map<String, double>.from(
      (raw as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
    );
  }
}