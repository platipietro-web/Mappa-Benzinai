import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mappa_prezzi_benzina/domain/entities/gas_station.dart';
import 'package:mappa_prezzi_benzina/presentation/pages/station_detail_page.dart';

void main() {
  testWidgets('shows real station data instead of mock data', (tester) async {
    const station = GasStation(
      id: 'station-1',
      name: 'Eni Via Test',
      address: 'Via Test 10 - Bergamo - BG',
      latitude: 45.703246,
      longitude: 9.730959,
      phoneNumber: '+39 035 123456',
      website: 'https://example.com',
      openingHours: '24/7',
      prices: {
        'Benzina': 1.799,
        'Diesel': 1.689,
      },
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: StationDetailPage(station: station),
      ),
    );

    expect(find.text('Eni Via Test'), findsOneWidget);
    expect(find.text('Via Test 10 - Bergamo - BG'), findsWidgets);
    expect(find.text('+39 035 123456'), findsOneWidget);
    expect(find.text('https://example.com'), findsOneWidget);
    expect(find.text('24/7'), findsOneWidget);
    expect(find.text('€1.799'), findsOneWidget);
    expect(find.text('Q8 SELF SERVICE'), findsNothing);
  });
}
