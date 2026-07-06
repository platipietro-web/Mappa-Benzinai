import 'package:mappa_prezzi_benzina/domain/entities/vehicle.dart';
import 'package:mappa_prezzi_benzina/domain/entities/vehicle_cost_entry.dart';
import 'package:mappa_prezzi_benzina/features/vehicles/vehicle_cost_entry_model.dart';
import 'package:mappa_prezzi_benzina/features/vehicles/vehicle_model.dart';
import 'package:mappa_prezzi_benzina/features/vehicles/vehicle_repository.dart';
import 'package:mappa_prezzi_benzina/features/vehicles/vehicle_service.dart';

class VehicleRepositoryImpl implements VehicleRepository {
  final VehicleService _service;

  VehicleRepositoryImpl(this._service);

  VehicleModel _toModel(Vehicle v) => VehicleModel(
        id: v.id,
        userId: v.userId,
        name: v.name,
        plate: v.plate,
        fuelType: v.fuelType,
        tankSizeLiters: v.tankSizeLiters,
        declaredConsumptionL100km: v.declaredConsumptionL100km,
        lastOdometerKm: v.lastOdometerKm,
        year: v.year,
        notes: v.notes,
        isDefault: v.isDefault,
        createdAt: v.createdAt,
      );

  VehicleCostEntryModel _toEntryModel(VehicleCostEntry e) =>
      VehicleCostEntryModel(
        id: e.id,
        vehicleId: e.vehicleId,
        userId: e.userId,
        category: e.category,
        amount: e.amount,
        date: e.date,
        note: e.note,
        validUntil: e.validUntil,
        createdAt: e.createdAt,
      );

  @override
  Future<List<Vehicle>> getVehicles(String userId) =>
      _service.getVehicles(userId);

  @override
  Future<void> addVehicle(Vehicle vehicle) =>
      _service.addVehicle(_toModel(vehicle));

  @override
  Future<void> updateVehicle(Vehicle vehicle) =>
      _service.updateVehicle(_toModel(vehicle));

  @override
  Future<void> deleteVehicle(String userId, String vehicleId) =>
      _service.deleteVehicle(userId, vehicleId);

  @override
  Future<void> setDefaultVehicle(String userId, String vehicleId) =>
      _service.setDefaultVehicle(userId, vehicleId);

  @override
  Future<void> updateLastOdometer(
          String userId, String vehicleId, int odometerKm) =>
      _service.updateLastOdometer(userId, vehicleId, odometerKm);

  @override
  Future<List<VehicleCostEntry>> getCostEntries(
          String userId, String vehicleId) =>
      _service.getCostEntries(userId, vehicleId);

  @override
  Future<void> addCostEntry(VehicleCostEntry entry) =>
      _service.addCostEntry(_toEntryModel(entry));

  @override
  Future<void> updateCostEntry(VehicleCostEntry entry) =>
      _service.updateCostEntry(_toEntryModel(entry));

  @override
  Future<void> deleteCostEntry(
          String userId, String vehicleId, String entryId) =>
      _service.deleteCostEntry(userId, vehicleId, entryId);
}
