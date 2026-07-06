import 'package:equatable/equatable.dart';

/// Categorie di spesa auto diverse dal carburante (che deriva sempre dai
/// [RefuelingLog] collegati al veicolo, per non duplicare la spesa).
enum VehicleCostCategory { insurance, roadTax, maintenance, other }

extension VehicleCostCategoryLabel on VehicleCostCategory {
  String get label {
    switch (this) {
      case VehicleCostCategory.insurance:
        return 'Assicurazione';
      case VehicleCostCategory.roadTax:
        return 'Bollo';
      case VehicleCostCategory.maintenance:
        return 'Manutenzione';
      case VehicleCostCategory.other:
        return 'Altro';
    }
  }
}

class VehicleCostEntry extends Equatable {
  final String id;
  final String vehicleId;
  final String userId;
  final VehicleCostCategory category;
  final double amount;
  final DateTime date;
  final String? note;
  final DateTime? validUntil; // scadenza bollo/assicurazione
  final DateTime createdAt;

  const VehicleCostEntry({
    required this.id,
    required this.vehicleId,
    required this.userId,
    required this.category,
    required this.amount,
    required this.date,
    this.note,
    this.validUntil,
    required this.createdAt,
  });

  @override
  List<Object?> get props =>
      [id, vehicleId, userId, category, amount, date, note, validUntil, createdAt];
}
