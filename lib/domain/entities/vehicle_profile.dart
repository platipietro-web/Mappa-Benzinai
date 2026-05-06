import 'package:equatable/equatable.dart';

class VehicleProfile extends Equatable {
  final String id;
  final String name; // es. "Fiat Panda", "BMW 320d"
  final double fuelConsumption; // L/100km
  final double tankSize; // litri
  final String preferredFuelType;

  const VehicleProfile({
    required this.id,
    required this.name,
    this.fuelConsumption = 10.0,
    this.tankSize = 50.0,
    this.preferredFuelType = 'Benzina',
  });

  VehicleProfile copyWith({
    String? name,
    double? fuelConsumption,
    double? tankSize,
    String? preferredFuelType,
  }) =>
      VehicleProfile(
        id: id,
        name: name ?? this.name,
        fuelConsumption: fuelConsumption ?? this.fuelConsumption,
        tankSize: tankSize ?? this.tankSize,
        preferredFuelType: preferredFuelType ?? this.preferredFuelType,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'fuelConsumption': fuelConsumption,
        'tankSize': tankSize,
        'preferredFuelType': preferredFuelType,
      };

  factory VehicleProfile.fromMap(Map<String, dynamic> map) => VehicleProfile(
        id: map['id'] as String,
        name: map['name'] as String? ?? 'Veicolo',
        fuelConsumption: (map['fuelConsumption'] as num?)?.toDouble() ?? 10.0,
        tankSize: (map['tankSize'] as num?)?.toDouble() ?? 50.0,
        preferredFuelType: map['preferredFuelType'] as String? ?? 'Benzina',
      );

  @override
  List<Object?> get props =>
      [id, name, fuelConsumption, tankSize, preferredFuelType];
}
