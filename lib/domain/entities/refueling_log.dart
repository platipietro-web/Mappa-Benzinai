import 'package:equatable/equatable.dart';

class RefuelingLog extends Equatable {
  final String id;
  final String userId;
  final String stationId;
  final String stationName;
  final String fuelType;
  final double pricePerLiter;
  final double liters;
  final double totalCost;
  final double savedVsArea; // risparmio vs prezzo medio zona (può essere negativo)
  final double areaAvgPrice; // prezzo medio zona al momento del rifornimento
  final DateTime timestamp;
  final String? vehicleId; // null = rifornimento non collegato a un veicolo
  final int? odometerKm;

  const RefuelingLog({
    required this.id,
    required this.userId,
    required this.stationId,
    required this.stationName,
    required this.fuelType,
    required this.pricePerLiter,
    required this.liters,
    required this.totalCost,
    required this.savedVsArea,
    required this.areaAvgPrice,
    required this.timestamp,
    this.vehicleId,
    this.odometerKm,
  });

  @override
  List<Object?> get props => [id];
}
