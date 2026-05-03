import 'package:flutter_test/flutter_test.dart';
import 'package:mappa_prezzi_benzina/domain/entities/gas_station.dart';

void main() {
  test('calculates distance between Rome and Milan', () {
    const station = GasStation(
      id: 'roma',
      name: 'Roma Station',
      address: 'Roma',
      latitude: 41.9028,
      longitude: 12.4964,
      prices: {'Benzina': 1.8},
    );

    final distanceKm = station.getDistanceFromCoordinates(45.4642, 9.19);

    expect(distanceKm, greaterThan(470));
    expect(distanceKm, lessThan(490));
  });

  test('returns fuel price by type', () {
    const station = GasStation(
      id: 'station',
      name: 'Station',
      address: 'Address',
      latitude: 0,
      longitude: 0,
      prices: {'Diesel': 1.7},
    );

    expect(station.getPrice('Diesel'), 1.7);
    expect(station.getPrice('GPL'), isNull);
  });
}
