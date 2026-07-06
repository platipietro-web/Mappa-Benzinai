import 'package:equatable/equatable.dart';

/// Consumo reale calcolato tra due rifornimenti consecutivi con
/// chilometraggio noto (vedi [ConsumptionCalculator]).
class ConsumptionSegment extends Equatable {
  final DateTime fromDate;
  final DateTime toDate;
  final double distanceKm;
  final double litersUsed;
  final double consumptionL100km;

  const ConsumptionSegment({
    required this.fromDate,
    required this.toDate,
    required this.distanceKm,
    required this.litersUsed,
    required this.consumptionL100km,
  });

  @override
  List<Object?> get props =>
      [fromDate, toDate, distanceKm, litersUsed, consumptionL100km];
}

/// Statistiche derivate di un veicolo: costi totali per categoria e consumo
/// reale. Non persistito — ricalcolato dal [VehicleBloc] a partire da
/// [VehicleCostEntry] e [RefuelingLog].
class VehicleStats extends Equatable {
  final double fuelCost;
  final double insuranceCost;
  final double roadTaxCost;
  final double maintenanceCost;
  final double otherCost;
  final double? averageConsumptionL100km;
  final double? declaredConsumptionL100km;
  final List<ConsumptionSegment> consumptionHistory;
  final int refuelingCount;
  final double totalLitersPurchased;

  const VehicleStats({
    this.fuelCost = 0,
    this.insuranceCost = 0,
    this.roadTaxCost = 0,
    this.maintenanceCost = 0,
    this.otherCost = 0,
    this.averageConsumptionL100km,
    this.declaredConsumptionL100km,
    this.consumptionHistory = const [],
    this.refuelingCount = 0,
    this.totalLitersPurchased = 0,
  });

  double get totalCost =>
      fuelCost + insuranceCost + roadTaxCost + maintenanceCost + otherCost;

  @override
  List<Object?> get props => [
        fuelCost,
        insuranceCost,
        roadTaxCost,
        maintenanceCost,
        otherCost,
        averageConsumptionL100km,
        declaredConsumptionL100km,
        consumptionHistory,
        refuelingCount,
        totalLitersPurchased,
      ];
}
