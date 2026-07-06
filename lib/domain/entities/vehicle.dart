import 'package:equatable/equatable.dart';

class Vehicle extends Equatable {
  final String id;
  final String userId;
  final String name; // es. "Fiat Panda"
  final String? plate; // targa
  final String fuelType;
  final double? tankSizeLiters;
  final double? declaredConsumptionL100km;
  final int? lastOdometerKm;
  final int? year;
  final String? notes;
  final bool isDefault;
  final DateTime createdAt;

  const Vehicle({
    required this.id,
    required this.userId,
    required this.name,
    this.plate,
    this.fuelType = 'Benzina',
    this.tankSizeLiters,
    this.declaredConsumptionL100km,
    this.lastOdometerKm,
    this.year,
    this.notes,
    this.isDefault = false,
    required this.createdAt,
  });

  Vehicle copyWith({
    String? name,
    String? plate,
    String? fuelType,
    double? tankSizeLiters,
    double? declaredConsumptionL100km,
    int? lastOdometerKm,
    int? year,
    String? notes,
    bool? isDefault,
  }) =>
      Vehicle(
        id: id,
        userId: userId,
        name: name ?? this.name,
        plate: plate ?? this.plate,
        fuelType: fuelType ?? this.fuelType,
        tankSizeLiters: tankSizeLiters ?? this.tankSizeLiters,
        declaredConsumptionL100km:
            declaredConsumptionL100km ?? this.declaredConsumptionL100km,
        lastOdometerKm: lastOdometerKm ?? this.lastOdometerKm,
        year: year ?? this.year,
        notes: notes ?? this.notes,
        isDefault: isDefault ?? this.isDefault,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        plate,
        fuelType,
        tankSizeLiters,
        declaredConsumptionL100km,
        lastOdometerKm,
        year,
        notes,
        isDefault,
        createdAt,
      ];
}
