import 'package:flutter_test/flutter_test.dart';
import 'package:mappa_prezzi_benzina/core/services/route_geometry.dart';
import 'package:mappa_prezzi_benzina/domain/entities/route_info.dart';

void main() {
  // Percorso rettilineo nord-sud lungo la stessa longitudine, un punto
  // ogni ~1.1 km circa (0.01° di latitudine), per un totale di ~11 km.
  final straightRoute = List.generate(
    11,
    (i) => RoutePoint(latitude: 45.00 + i * 0.01, longitude: 9.00),
  );

  test('haversineKm returns ~0 for the same point', () {
    final d = RouteGeometry.haversineKm(straightRoute.first, straightRoute.first);
    expect(d, closeTo(0, 0.001));
  });

  test('distanceToRouteKm is ~0 for a point on the route', () {
    final onRoute = straightRoute[5];
    final d = RouteGeometry.distanceToRouteKm(onRoute, straightRoute);
    expect(d, closeTo(0, 0.001));
  });

  test('distanceToRouteKm grows for a point off the route', () {
    // Stesso punto centrale del percorso, spostato di ~0.05° in longitudine
    // (~3.9 km a questa latitudine) verso est.
    final offRoute = RoutePoint(latitude: 45.05, longitude: 9.05);
    final d = RouteGeometry.distanceToRouteKm(offRoute, straightRoute);
    expect(d, greaterThan(3.0));
    expect(d, lessThan(5.0));
  });

  test('sampleCenters always includes first and last point', () {
    final centers =
        RouteGeometry.sampleCenters(straightRoute, intervalKm: 100);
    expect(centers.first, straightRoute.first);
    expect(centers.last, straightRoute.last);
  });

  test('sampleCenters respects the requested interval', () {
    final centers = RouteGeometry.sampleCenters(straightRoute, intervalKm: 5);
    // ~11 km di percorso, campionato ogni 5 km → almeno 2 centri intermedi
    // oltre a origine/destinazione.
    expect(centers.length, greaterThanOrEqualTo(3));
  });

  test('downsample keeps first and last point and reduces density', () {
    // Percorso molto fitto: 100 punti in ~1.1 km.
    final dense = List.generate(
      100,
      (i) => RoutePoint(latitude: 45.00 + i * 0.0001, longitude: 9.00),
    );
    final reduced = RouteGeometry.downsample(dense, minSpacingKm: 0.3);
    expect(reduced.first, dense.first);
    expect(reduced.last, dense.last);
    expect(reduced.length, lessThan(dense.length));
  });

  test('progressAlongRouteKm increases along the route', () {
    final near = RouteGeometry.progressAlongRouteKm(straightRoute[2], straightRoute);
    final far = RouteGeometry.progressAlongRouteKm(straightRoute[8], straightRoute);
    expect(far, greaterThan(near));
  });
}
