import 'dart:math' as math;
import 'package:equatable/equatable.dart';

class CarWash extends Equatable {
  final String id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  // 'both' = self-service + automatic (default)
  // 'automatic' = solo rulli (no self-service)
  // 'self-only' = solo self-service (no rulli) — impostato esplicitamente
  // 'self-service' = legacy pre-migration, trattato come 'both' in lettura
  final String type;
  final bool? hasVacuum;
  final String paymentType; // 'coins' | 'card' | 'both'
  final DateTime? createdAt;

  // Future extensions: double? averageRating, int? numberOfRatings, List<String>? photos

  const CarWash({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.hasVacuum,
    required this.paymentType,
    this.createdAt,
  });

  double getDistanceFromCoordinates(double userLat, double userLon) {
    const earthRadiusKm = 6371;
    final dLat = _toRad(latitude - userLat);
    final dLon = _toRad(longitude - userLon);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRad(userLat)) *
            math.cos(_toRad(latitude)) *
            math.pow(math.sin(dLon / 2), 2);
    final c = 2 * math.asin(math.sqrt(a));
    return earthRadiusKm * c;
  }

  double _toRad(double degree) => degree * math.pi / 180;

  @override
  List<Object?> get props =>
      [id, name, address, latitude, longitude, type, hasVacuum, paymentType, createdAt];
}
