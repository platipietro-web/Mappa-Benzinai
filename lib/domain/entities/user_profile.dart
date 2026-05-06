import 'package:equatable/equatable.dart';
import 'package:mappa_prezzi_benzina/domain/entities/vehicle_profile.dart';

class UserProfile extends Equatable {
  final String userId;
  final String? email;
  final List<VehicleProfile> vehicles;
  final String? activeVehicleId;

  const UserProfile({
    required this.userId,
    this.email,
    this.vehicles = const [],
    this.activeVehicleId,
  });

  // Veicolo attivo: usa activeVehicleId se presente, altrimenti il primo
  VehicleProfile? get activeVehicle {
    if (vehicles.isEmpty) return null;
    try {
      return vehicles.firstWhere((v) => v.id == activeVehicleId);
    } catch (_) {
      return vehicles.first;
    }
  }

  // Getter di compatibilità: delegano al veicolo attivo
  double get fuelConsumption => activeVehicle?.fuelConsumption ?? 10.0;
  double get tankSize => activeVehicle?.tankSize ?? 50.0;
  String get preferredFuelType => activeVehicle?.preferredFuelType ?? 'Benzina';
  String get vehicleName => activeVehicle?.name ?? '';

  UserProfile copyWith({
    String? email,
    List<VehicleProfile>? vehicles,
    String? activeVehicleId,
  }) =>
      UserProfile(
        userId: userId,
        email: email ?? this.email,
        vehicles: vehicles ?? this.vehicles,
        activeVehicleId: activeVehicleId ?? this.activeVehicleId,
      );

  @override
  List<Object?> get props => [userId, email, vehicles, activeVehicleId];
}
