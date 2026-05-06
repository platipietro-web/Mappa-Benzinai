import 'package:equatable/equatable.dart';

class RealCostResult extends Equatable {
  final double listedPrice; // prezzo al litro listato dal distributore
  final double effectivePrice; // prezzo effettivo considerando il tragitto
  final double tripFuelCost; // costo carburante per il tragitto A/R (€)
  final double netSaving; // risparmio netto vs prezzo medio zona (€ su pieno)
  final bool isWorthIt; // true se conviene raggiungere la stazione
  final double distanceKm;

  const RealCostResult({
    required this.listedPrice,
    required this.effectivePrice,
    required this.tripFuelCost,
    required this.netSaving,
    required this.isWorthIt,
    required this.distanceKm,
  });

  @override
  List<Object?> get props =>
      [listedPrice, effectivePrice, tripFuelCost, netSaving, isWorthIt, distanceKm];
}
