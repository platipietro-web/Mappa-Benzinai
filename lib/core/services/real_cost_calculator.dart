import 'package:mappa_prezzi_benzina/domain/entities/real_cost_result.dart';

class RealCostCalculator {
  /// Calcola il costo reale di rifornimento tenendo conto del tragitto.
  ///
  /// Formula:
  ///   tripLiters = distanceKm * 2 * consumption / 100   (A/R)
  ///   effectivePrice = (stationPrice * tankSize + tripLiters * stationPrice) / tankSize
  ///   netSaving = (areaAvgPrice * tankSize) - (effectivePrice * tankSize)
  static RealCostResult calculate({
    required double distanceKm,
    required double fuelPrice,
    required double areaAvgPrice,
    required double consumption,
    required double tankSize,
  }) {
    final tripLiters = (distanceKm * 2.0 * consumption) / 100.0;
    final tripFuelCost = tripLiters * fuelPrice;

    final totalCost = (fuelPrice * tankSize) + tripFuelCost;
    final effectivePrice = totalCost / tankSize;

    final standardCost = areaAvgPrice * tankSize;
    final netSaving = standardCost - totalCost;

    return RealCostResult(
      listedPrice: fuelPrice,
      effectivePrice: effectivePrice,
      tripFuelCost: tripFuelCost,
      netSaving: netSaving,
      isWorthIt: netSaving > 0,
      distanceKm: distanceKm,
    );
  }

  /// Calcola il prezzo medio per una lista di prezzi della stessa zona.
  static double areaAverage(Iterable<double> prices) {
    if (prices.isEmpty) return 0;
    return prices.reduce((a, b) => a + b) / prices.length;
  }
}
