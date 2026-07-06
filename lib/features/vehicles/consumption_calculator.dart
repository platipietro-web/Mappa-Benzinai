import 'package:mappa_prezzi_benzina/domain/entities/refueling_log.dart';
import 'package:mappa_prezzi_benzina/domain/entities/vehicle_stats.dart';

/// Calcola il consumo reale di un veicolo tra rifornimenti consecutivi con
/// chilometraggio noto: litri di un rifornimento diviso i km percorsi da
/// quello precedente. Il primo rifornimento di un veicolo non produce un
/// segmento (non c'è un chilometraggio precedente con cui confrontarlo).
class ConsumptionCalculator {
  static List<ConsumptionSegment> computeSegments(List<RefuelingLog> logs) {
    final withOdometer = logs.where((l) => l.odometerKm != null).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final segments = <ConsumptionSegment>[];
    for (var i = 1; i < withOdometer.length; i++) {
      final prev = withOdometer[i - 1];
      final curr = withOdometer[i];
      final distanceKm = (curr.odometerKm! - prev.odometerKm!).toDouble();
      if (distanceKm <= 0) continue;

      segments.add(ConsumptionSegment(
        fromDate: prev.timestamp,
        toDate: curr.timestamp,
        distanceKm: distanceKm,
        litersUsed: curr.liters,
        consumptionL100km: curr.liters / distanceKm * 100,
      ));
    }
    return segments;
  }

  /// Media pesata (litri totali / km totali), non media semplice dei
  /// segmenti, per non sovra-pesare gli intervalli brevi.
  static double? averageConsumption(List<ConsumptionSegment> segments) {
    if (segments.isEmpty) return null;
    final totalLiters = segments.fold(0.0, (sum, s) => sum + s.litersUsed);
    final totalKm = segments.fold(0.0, (sum, s) => sum + s.distanceKm);
    if (totalKm <= 0) return null;
    return totalLiters / totalKm * 100;
  }
}
