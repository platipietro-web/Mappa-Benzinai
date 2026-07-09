import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mappa_prezzi_benzina/domain/entities/refueling_log.dart';
import 'package:mappa_prezzi_benzina/domain/entities/vehicle.dart';
import 'package:mappa_prezzi_benzina/domain/entities/vehicle_cost_entry.dart';
import 'package:mappa_prezzi_benzina/domain/entities/vehicle_stats.dart';
import 'package:mappa_prezzi_benzina/domain/repositories/repositories.dart';
import 'package:mappa_prezzi_benzina/features/vehicles/consumption_calculator.dart';
import 'package:mappa_prezzi_benzina/features/vehicles/vehicle_repository.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class VehicleEvent extends Equatable {
  const VehicleEvent();
  @override
  List<Object?> get props => [];
}

class LoadVehiclesEvent extends VehicleEvent {
  final String userId;
  const LoadVehiclesEvent(this.userId);
  @override
  List<Object?> get props => [userId];
}

class AddVehicleEvent extends VehicleEvent {
  final Vehicle vehicle;
  const AddVehicleEvent(this.vehicle);
  @override
  List<Object?> get props => [vehicle.id];
}

class UpdateVehicleEvent extends VehicleEvent {
  final Vehicle vehicle;
  const UpdateVehicleEvent(this.vehicle);
  @override
  List<Object?> get props => [vehicle.id];
}

class DeleteVehicleEvent extends VehicleEvent {
  final Vehicle vehicle;
  const DeleteVehicleEvent(this.vehicle);
  @override
  List<Object?> get props => [vehicle.id];
}

class SetDefaultVehicleEvent extends VehicleEvent {
  final String vehicleId;
  const SetDefaultVehicleEvent(this.vehicleId);
  @override
  List<Object?> get props => [vehicleId];
}

class LoadVehicleDetailEvent extends VehicleEvent {
  final String vehicleId;
  const LoadVehicleDetailEvent(this.vehicleId);
  @override
  List<Object?> get props => [vehicleId];
}

class AddCostEntryEvent extends VehicleEvent {
  final VehicleCostEntry entry;
  const AddCostEntryEvent(this.entry);
  @override
  List<Object?> get props => [entry.id];
}

class UpdateCostEntryEvent extends VehicleEvent {
  final VehicleCostEntry entry;
  const UpdateCostEntryEvent(this.entry);
  @override
  List<Object?> get props => [entry.id];
}

class DeleteCostEntryEvent extends VehicleEvent {
  final VehicleCostEntry entry;
  const DeleteCostEntryEvent(this.entry);
  @override
  List<Object?> get props => [entry.id];
}

/// Notifica il bloc che un rifornimento collegato a un veicolo è stato
/// registrato altrove (dal bottom sheet condiviso, sia dalla scheda
/// distributore sia dalla sezione Auto) — aggiorna storico, statistiche e
/// l'ultimo chilometraggio noto del veicolo.
class RefuelingLoggedEvent extends VehicleEvent {
  final RefuelingLog log;
  const RefuelingLoggedEvent(this.log);
  @override
  List<Object?> get props => [log.id];
}

class ClearVehiclesEvent extends VehicleEvent {
  const ClearVehiclesEvent();
}

// ─── State ────────────────────────────────────────────────────────────────────

class VehicleState extends Equatable {
  final List<Vehicle> vehicles;
  final bool isLoading;
  final bool isSaving;
  final bool isDetailLoading;
  final Map<String, List<RefuelingLog>> fuelLogsByVehicle;
  final Map<String, List<VehicleCostEntry>> costEntriesByVehicle;
  final Map<String, VehicleStats> statsByVehicle;

  const VehicleState({
    this.vehicles = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.isDetailLoading = false,
    this.fuelLogsByVehicle = const {},
    this.costEntriesByVehicle = const {},
    this.statsByVehicle = const {},
  });

  Vehicle? get defaultVehicle {
    if (vehicles.isEmpty) return null;
    // Niente firstWhere(orElse:): vehicles è dichiarata List<Vehicle> ma a
    // runtime contiene sempre VehicleModel, quindi la closure passata a
    // orElse verrebbe tipizzata "Vehicle Function()" invece di "VehicleModel
    // Function()" e Dart la rifiuterebbe con un TypeError a runtime.
    for (final v in vehicles) {
      if (v.isDefault) return v;
    }
    return vehicles.first;
  }

  Vehicle? vehicleById(String id) {
    try {
      return vehicles.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  VehicleState copyWith({
    List<Vehicle>? vehicles,
    bool? isLoading,
    bool? isSaving,
    bool? isDetailLoading,
    Map<String, List<RefuelingLog>>? fuelLogsByVehicle,
    Map<String, List<VehicleCostEntry>>? costEntriesByVehicle,
    Map<String, VehicleStats>? statsByVehicle,
  }) =>
      VehicleState(
        vehicles: vehicles ?? this.vehicles,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        isDetailLoading: isDetailLoading ?? this.isDetailLoading,
        fuelLogsByVehicle: fuelLogsByVehicle ?? this.fuelLogsByVehicle,
        costEntriesByVehicle: costEntriesByVehicle ?? this.costEntriesByVehicle,
        statsByVehicle: statsByVehicle ?? this.statsByVehicle,
      );

  @override
  List<Object?> get props => [
        vehicles,
        isLoading,
        isSaving,
        isDetailLoading,
        fuelLogsByVehicle,
        costEntriesByVehicle,
        statsByVehicle,
      ];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class VehicleBloc extends Bloc<VehicleEvent, VehicleState> {
  final VehicleRepository _vehicleRepo;
  final AnalyticsRepository _analyticsRepo;
  String? _currentUserId;

  VehicleBloc(this._vehicleRepo, this._analyticsRepo)
      : super(const VehicleState()) {
    on<LoadVehiclesEvent>(_onLoadVehicles);
    on<AddVehicleEvent>(_onAddVehicle);
    on<UpdateVehicleEvent>(_onUpdateVehicle);
    on<DeleteVehicleEvent>(_onDeleteVehicle);
    on<SetDefaultVehicleEvent>(_onSetDefaultVehicle);
    on<LoadVehicleDetailEvent>(_onLoadVehicleDetail);
    on<AddCostEntryEvent>(_onAddCostEntry);
    on<UpdateCostEntryEvent>(_onUpdateCostEntry);
    on<DeleteCostEntryEvent>(_onDeleteCostEntry);
    on<RefuelingLoggedEvent>(_onRefuelingLogged);
    on<ClearVehiclesEvent>(_onClear);
  }

  Future<void> _onLoadVehicles(
    LoadVehiclesEvent event,
    Emitter<VehicleState> emit,
  ) async {
    _currentUserId = event.userId;
    emit(state.copyWith(isLoading: true));
    final vehicles = await _vehicleRepo.getVehicles(event.userId);
    emit(state.copyWith(vehicles: vehicles, isLoading: false));
  }

  Future<void> _onAddVehicle(
    AddVehicleEvent event,
    Emitter<VehicleState> emit,
  ) async {
    emit(state.copyWith(isSaving: true));
    try {
      await _vehicleRepo.addVehicle(event.vehicle);
      emit(state.copyWith(
        vehicles: [...state.vehicles, event.vehicle],
        isSaving: false,
      ));
    } catch (_) {
      emit(state.copyWith(isSaving: false));
    }
  }

  Future<void> _onUpdateVehicle(
    UpdateVehicleEvent event,
    Emitter<VehicleState> emit,
  ) async {
    emit(state.copyWith(isSaving: true));
    try {
      await _vehicleRepo.updateVehicle(event.vehicle);
      emit(state.copyWith(
        vehicles: state.vehicles
            .map((v) => v.id == event.vehicle.id ? event.vehicle : v)
            .toList(),
        isSaving: false,
      ));
    } catch (_) {
      emit(state.copyWith(isSaving: false));
    }
  }

  Future<void> _onDeleteVehicle(
    DeleteVehicleEvent event,
    Emitter<VehicleState> emit,
  ) async {
    final userId = _currentUserId;
    if (userId == null) return;
    emit(state.copyWith(isSaving: true));
    try {
      await _vehicleRepo.deleteVehicle(userId, event.vehicle.id);
      var vehicles =
          state.vehicles.where((v) => v.id != event.vehicle.id).toList();
      if (event.vehicle.isDefault &&
          vehicles.isNotEmpty &&
          !vehicles.any((v) => v.isDefault)) {
        await _vehicleRepo.setDefaultVehicle(userId, vehicles.first.id);
        vehicles = [
          vehicles.first.copyWith(isDefault: true),
          ...vehicles.skip(1),
        ];
      }
      final fuelLogsByVehicle = Map<String, List<RefuelingLog>>.of(
          state.fuelLogsByVehicle)
        ..remove(event.vehicle.id);
      final costEntriesByVehicle = Map<String, List<VehicleCostEntry>>.of(
          state.costEntriesByVehicle)
        ..remove(event.vehicle.id);
      final statsByVehicle =
          Map<String, VehicleStats>.of(state.statsByVehicle)
            ..remove(event.vehicle.id);
      emit(state.copyWith(
        vehicles: vehicles,
        fuelLogsByVehicle: fuelLogsByVehicle,
        costEntriesByVehicle: costEntriesByVehicle,
        statsByVehicle: statsByVehicle,
        isSaving: false,
      ));
    } catch (_) {
      emit(state.copyWith(isSaving: false));
    }
  }

  Future<void> _onSetDefaultVehicle(
    SetDefaultVehicleEvent event,
    Emitter<VehicleState> emit,
  ) async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      await _vehicleRepo.setDefaultVehicle(userId, event.vehicleId);
      emit(state.copyWith(
        vehicles: state.vehicles
            .map((v) => v.copyWith(isDefault: v.id == event.vehicleId))
            .toList(),
      ));
    } catch (_) {
      // Ottimistico: nessun rollback, il refresh successivo correggerà lo stato
    }
  }

  Future<void> _onLoadVehicleDetail(
    LoadVehicleDetailEvent event,
    Emitter<VehicleState> emit,
  ) async {
    final userId = _currentUserId;
    if (userId == null) return;
    emit(state.copyWith(isDetailLoading: true));
    try {
      final costEntries =
          await _vehicleRepo.getCostEntries(userId, event.vehicleId);
      final allLogs = await _analyticsRepo.getRefuelingLogs(userId);
      final fuelLogs =
          allLogs.where((l) => l.vehicleId == event.vehicleId).toList();

      emit(state.copyWith(
        fuelLogsByVehicle: <String, List<RefuelingLog>>{
          ...state.fuelLogsByVehicle,
          event.vehicleId: fuelLogs,
        },
        costEntriesByVehicle: <String, List<VehicleCostEntry>>{
          ...state.costEntriesByVehicle,
          event.vehicleId: costEntries,
        },
        statsByVehicle: <String, VehicleStats>{
          ...state.statsByVehicle,
          event.vehicleId: _computeStats(event.vehicleId, fuelLogs, costEntries),
        },
        isDetailLoading: false,
      ));
    } catch (_) {
      emit(state.copyWith(isDetailLoading: false));
    }
  }

  Future<void> _onAddCostEntry(
    AddCostEntryEvent event,
    Emitter<VehicleState> emit,
  ) async {
    emit(state.copyWith(isSaving: true));
    try {
      await _vehicleRepo.addCostEntry(event.entry);
      final vehicleId = event.entry.vehicleId;
      final List<VehicleCostEntry> entries = [
        ...(state.costEntriesByVehicle[vehicleId] ?? const []),
        event.entry,
      ];
      emit(state.copyWith(
        costEntriesByVehicle: <String, List<VehicleCostEntry>>{
          ...state.costEntriesByVehicle,
          vehicleId: entries,
        },
        statsByVehicle: <String, VehicleStats>{
          ...state.statsByVehicle,
          vehicleId: _computeStats(
              vehicleId, state.fuelLogsByVehicle[vehicleId] ?? const [], entries),
        },
        isSaving: false,
      ));
    } catch (_) {
      emit(state.copyWith(isSaving: false));
    }
  }

  Future<void> _onUpdateCostEntry(
    UpdateCostEntryEvent event,
    Emitter<VehicleState> emit,
  ) async {
    emit(state.copyWith(isSaving: true));
    try {
      await _vehicleRepo.updateCostEntry(event.entry);
      final vehicleId = event.entry.vehicleId;
      final List<VehicleCostEntry> entries =
          (state.costEntriesByVehicle[vehicleId] ?? const [])
              .map((e) => e.id == event.entry.id ? event.entry : e)
              .toList();
      emit(state.copyWith(
        costEntriesByVehicle: <String, List<VehicleCostEntry>>{
          ...state.costEntriesByVehicle,
          vehicleId: entries,
        },
        statsByVehicle: <String, VehicleStats>{
          ...state.statsByVehicle,
          vehicleId: _computeStats(
              vehicleId, state.fuelLogsByVehicle[vehicleId] ?? const [], entries),
        },
        isSaving: false,
      ));
    } catch (_) {
      emit(state.copyWith(isSaving: false));
    }
  }

  Future<void> _onDeleteCostEntry(
    DeleteCostEntryEvent event,
    Emitter<VehicleState> emit,
  ) async {
    final userId = _currentUserId;
    if (userId == null) return;
    emit(state.copyWith(isSaving: true));
    try {
      await _vehicleRepo.deleteCostEntry(
          userId, event.entry.vehicleId, event.entry.id);
      final vehicleId = event.entry.vehicleId;
      final List<VehicleCostEntry> entries =
          (state.costEntriesByVehicle[vehicleId] ?? const [])
              .where((e) => e.id != event.entry.id)
              .toList();
      emit(state.copyWith(
        costEntriesByVehicle: <String, List<VehicleCostEntry>>{
          ...state.costEntriesByVehicle,
          vehicleId: entries,
        },
        statsByVehicle: <String, VehicleStats>{
          ...state.statsByVehicle,
          vehicleId: _computeStats(
              vehicleId, state.fuelLogsByVehicle[vehicleId] ?? const [], entries),
        },
        isSaving: false,
      ));
    } catch (_) {
      emit(state.copyWith(isSaving: false));
    }
  }

  Future<void> _onRefuelingLogged(
    RefuelingLoggedEvent event,
    Emitter<VehicleState> emit,
  ) async {
    final userId = _currentUserId;
    final vehicleId = event.log.vehicleId;
    if (userId == null || vehicleId == null) return;

    final List<RefuelingLog> logs = [
      event.log,
      ...(state.fuelLogsByVehicle[vehicleId] ?? const []),
    ];
    final List<VehicleCostEntry> costEntries =
        state.costEntriesByVehicle[vehicleId] ?? const [];

    var vehicles = state.vehicles;
    final odometerKm = event.log.odometerKm;
    if (odometerKm != null) {
      vehicles = state.vehicles
          .map((v) =>
              v.id == vehicleId ? v.copyWith(lastOdometerKm: odometerKm) : v)
          .toList();
      try {
        await _vehicleRepo.updateLastOdometer(userId, vehicleId, odometerKm);
      } catch (_) {
        // Il chilometraggio locale resta aggiornato anche se la scrittura fallisce
      }
    }

    emit(state.copyWith(
      vehicles: vehicles,
      fuelLogsByVehicle: <String, List<RefuelingLog>>{
        ...state.fuelLogsByVehicle,
        vehicleId: logs,
      },
      statsByVehicle: <String, VehicleStats>{
        ...state.statsByVehicle,
        vehicleId: _computeStats(vehicleId, logs, costEntries),
      },
    ));
  }

  void _onClear(ClearVehiclesEvent event, Emitter<VehicleState> emit) {
    _currentUserId = null;
    emit(const VehicleState());
  }

  VehicleStats _computeStats(
    String vehicleId,
    List<RefuelingLog> fuelLogs,
    List<VehicleCostEntry> costEntries,
  ) {
    double costOf(VehicleCostCategory c) => costEntries
        .where((e) => e.category == c)
        .fold(0.0, (sum, e) => sum + e.amount);

    final segments = ConsumptionCalculator.computeSegments(fuelLogs);

    return VehicleStats(
      fuelCost: fuelLogs.fold(0.0, (sum, l) => sum + l.totalCost),
      insuranceCost: costOf(VehicleCostCategory.insurance),
      roadTaxCost: costOf(VehicleCostCategory.roadTax),
      maintenanceCost: costOf(VehicleCostCategory.maintenance),
      otherCost: costOf(VehicleCostCategory.other),
      averageConsumptionL100km: ConsumptionCalculator.averageConsumption(segments),
      declaredConsumptionL100km:
          state.vehicleById(vehicleId)?.declaredConsumptionL100km,
      consumptionHistory: segments,
      refuelingCount: fuelLogs.length,
      totalLitersPurchased: fuelLogs.fold(0.0, (sum, l) => sum + l.liters),
    );
  }
}
