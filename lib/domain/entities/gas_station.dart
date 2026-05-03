import 'dart:math' as math;

import 'package:equatable/equatable.dart';

class GasStation extends Equatable {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? phoneNumber;
  final String? website;
  final String? openingHours;
  final Map<String, double> prices; // fuel type -> price
  final DateTime? lastUpdated;
  final int? numberOfRatings;
  final double? averageRating;
  final String? brand; // brand/marchio del benzinaio

  const GasStation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phoneNumber,
    this.website,
    this.openingHours,
    required this.prices,
    this.lastUpdated,
    this.numberOfRatings,
    this.averageRating,
    this.brand,
  });

  // Distance calculation using Haversine formula (simplified)
  double getDistanceFromCoordinates(double userLat, double userLon) {
    const earthRadiusKm = 6371; // Earth's radius in kilometers
    final dLat = _toRad(latitude - userLat);
    final dLon = _toRad(longitude - userLon);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(userLat.toRadians()) *
            math.cos(latitude.toRadians()) *
            math.pow(math.sin(dLon / 2), 2);
    final c = 2 * math.asin(math.sqrt(a));
    return earthRadiusKm * c;
  }

  double _toRad(double degree) {
    return degree * 3.141592653589793 / 180;
  }

  double? getPrice(String fuelType) {
    return prices[fuelType];
  }

  @override
  List<Object?> get props => [
    id,
    name,
    address,
    latitude,
    longitude,
    phoneNumber,
    website,
    openingHours,
    prices,
    lastUpdated,
    numberOfRatings,
    averageRating,
    brand,
  ];
}

extension on double {
  double toRadians() => this * 3.141592653589793 / 180;
}
