import 'package:mappa_prezzi_benzina/domain/entities/vehicle.dart';
import 'package:mappa_prezzi_benzina/domain/entities/vehicle_cost_entry.dart';

abstract class VehicleRepository {
  Future<List<Vehicle>> getVehicles(String userId);
  Future<void> addVehicle(Vehicle vehicle);
  Future<void> updateVehicle(Vehicle vehicle);
  Future<void> deleteVehicle(String userId, String vehicleId);
  Future<void> setDefaultVehicle(String userId, String vehicleId);
  Future<void> updateLastOdometer(
      String userId, String vehicleId, int odometerKm);

  Future<List<VehicleCostEntry>> getCostEntries(
      String userId, String vehicleId);
  Future<void> addCostEntry(VehicleCostEntry entry);
  Future<void> updateCostEntry(VehicleCostEntry entry);
  Future<void> deleteCostEntry(String userId, String vehicleId, String entryId);
}
