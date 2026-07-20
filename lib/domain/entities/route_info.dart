import 'package:equatable/equatable.dart';

class RoutePoint extends Equatable {
  final double latitude;
  final double longitude;

  const RoutePoint({required this.latitude, required this.longitude});

  @override
  List<Object?> get props => [latitude, longitude];
}

class RouteInfo extends Equatable {
  final List<RoutePoint> points;
  final double distanceKm;
  final double durationMin;

  const RouteInfo({
    required this.points,
    required this.distanceKm,
    required this.durationMin,
  });

  @override
  List<Object?> get props => [points, distanceKm, durationMin];
}
