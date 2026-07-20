import 'dart:math' as math;

import 'package:mappa_prezzi_benzina/domain/entities/route_info.dart';

/// Calcoli geometrici puri sulla polyline di un percorso: nessun I/O, per
/// questo facilmente testabile (come [RealCostCalculator]).
class RouteGeometry {
  static const double _earthRadiusKm = 6371;

  static double _toRad(double degree) => degree * math.pi / 180;

  static double haversineKm(RoutePoint a, RoutePoint b) {
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final sa = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRad(a.latitude)) *
            math.cos(_toRad(b.latitude)) *
            math.pow(math.sin(dLon / 2), 2);
    final c = 2 * math.asin(math.sqrt(sa));
    return _earthRadiusKm * c;
  }

  /// Riduce la geometria (che per OSRM `overview=full` può avere migliaia
  /// di punti) a un passo minimo gestibile, mantenendo sempre primo e
  /// ultimo punto.
  static List<RoutePoint> downsample(
    List<RoutePoint> points, {
    double minSpacingKm = 0.3,
  }) {
    if (points.length <= 2) return points;
    final result = <RoutePoint>[points.first];
    var last = points.first;
    for (var i = 1; i < points.length - 1; i++) {
      if (haversineKm(last, points[i]) >= minSpacingKm) {
        result.add(points[i]);
        last = points[i];
      }
    }
    result.add(points.last);
    return result;
  }

  /// Centri da usare per le query `getNearbyStations` lungo il percorso,
  /// spaziati per distanza cumulata reale (non in linea d'aria). Include
  /// sempre origine e destinazione.
  static List<RoutePoint> sampleCenters(
    List<RoutePoint> points, {
    required double intervalKm,
  }) {
    if (points.isEmpty) return const [];
    if (points.length == 1) return [points.first];

    final result = <RoutePoint>[points.first];
    var accumulated = 0.0;
    for (var i = 1; i < points.length; i++) {
      accumulated += haversineKm(points[i - 1], points[i]);
      if (accumulated >= intervalKm) {
        result.add(points[i]);
        accumulated = 0.0;
      }
    }
    if (result.last != points.last) result.add(points.last);
    return result;
  }

  /// Distanza minima dal punto [p] alla polyline [routePoints]: distanza
  /// (haversine) dal vertice più vicino. Semplificazione deliberata rispetto
  /// alla proiezione punto-segmento esatta — con `routePoints` già
  /// downsampled a ~300-500m l'errore è trascurabile per un corridoio di
  /// pochi km, ed evita la complessità di una proiezione planare su lat/lon.
  static double distanceToRouteKm(RoutePoint p, List<RoutePoint> routePoints) {
    if (routePoints.isEmpty) return double.infinity;
    var minDist = double.infinity;
    for (final rp in routePoints) {
      final d = haversineKm(p, rp);
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  /// Distanza cumulata dall'origine del percorso al vertice più vicino a
  /// [p], per ordinare/mostrare "a X km dalla partenza".
  static double progressAlongRouteKm(RoutePoint p, List<RoutePoint> routePoints) {
    if (routePoints.isEmpty) return 0;
    var minDist = double.infinity;
    var minIndex = 0;
    for (var i = 0; i < routePoints.length; i++) {
      final d = haversineKm(p, routePoints[i]);
      if (d < minDist) {
        minDist = d;
        minIndex = i;
      }
    }
    var cumulative = 0.0;
    for (var i = 1; i <= minIndex; i++) {
      cumulative += haversineKm(routePoints[i - 1], routePoints[i]);
    }
    return cumulative;
  }
}
