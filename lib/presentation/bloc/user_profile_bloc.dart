import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_profile.dart';
import 'package:mappa_prezzi_benzina/domain/entities/vehicle_profile.dart';
import 'package:mappa_prezzi_benzina/domain/repositories/repositories.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class UserProfileEvent extends Equatable {
  const UserProfileEvent();
  @override
  List<Object?> get props => [];
}

class LoadUserProfileEvent extends UserProfileEvent {
  final String userId;
  const LoadUserProfileEvent(this.userId);
  @override
  List<Object?> get props => [userId];
}

class AddVehicleEvent extends UserProfileEvent {
  final VehicleProfile vehicle;
  const AddVehicleEvent(this.vehicle);
  @override
  List<Object?> get props => [vehicle.id];
}

class UpdateVehicleEvent extends UserProfileEvent {
  final VehicleProfile vehicle;
  const UpdateVehicleEvent(this.vehicle);
  @override
  List<Object?> get props => [vehicle.id];
}

class RemoveVehicleEvent extends UserProfileEvent {
  final String vehicleId;
  const RemoveVehicleEvent(this.vehicleId);
  @override
  List<Object?> get props => [vehicleId];
}

class SetActiveVehicleEvent extends UserProfileEvent {
  final String vehicleId;
  const SetActiveVehicleEvent(this.vehicleId);
  @override
  List<Object?> get props => [vehicleId];
}

class ClearUserProfileEvent extends UserProfileEvent {
  const ClearUserProfileEvent();
}

// ─── State ────────────────────────────────────────────────────────────────────

class UserProfileState extends Equatable {
  final UserProfile? profile;
  final bool isLoading;
  final bool isSaving;

  const UserProfileState({
    this.profile,
    this.isLoading = false,
    this.isSaving = false,
  });

  UserProfileState copyWith({
    UserProfile? profile,
    bool? isLoading,
    bool? isSaving,
  }) =>
      UserProfileState(
        profile: profile ?? this.profile,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
      );

  UserProfile profileOrDefault(String userId) =>
      profile ?? UserProfile(userId: userId);

  @override
  List<Object?> get props => [profile, isLoading, isSaving];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class UserProfileBloc extends Bloc<UserProfileEvent, UserProfileState> {
  final UserProfileRepository _repo;

  UserProfileBloc(this._repo) : super(const UserProfileState()) {
    on<LoadUserProfileEvent>(_onLoad);
    on<AddVehicleEvent>(_onAddVehicle);
    on<UpdateVehicleEvent>(_onUpdateVehicle);
    on<RemoveVehicleEvent>(_onRemoveVehicle);
    on<SetActiveVehicleEvent>(_onSetActive);
    on<ClearUserProfileEvent>(_onClear);
  }

  Future<void> _onLoad(
    LoadUserProfileEvent event,
    Emitter<UserProfileState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    final profile = await _repo.getUserProfile(event.userId);
    emit(state.copyWith(
      profile: profile ?? UserProfile(userId: event.userId),
      isLoading: false,
    ));
  }

  Future<void> _onAddVehicle(
    AddVehicleEvent event,
    Emitter<UserProfileState> emit,
  ) async {
    final current = state.profile;
    if (current == null) return;
    final updated = current.copyWith(
      vehicles: [...current.vehicles, event.vehicle],
      activeVehicleId: current.activeVehicleId ?? event.vehicle.id,
    );
    emit(state.copyWith(profile: updated, isSaving: true));
    await _save(updated);
    emit(state.copyWith(isSaving: false));
  }

  Future<void> _onUpdateVehicle(
    UpdateVehicleEvent event,
    Emitter<UserProfileState> emit,
  ) async {
    final current = state.profile;
    if (current == null) return;
    final updated = current.copyWith(
      vehicles: current.vehicles
          .map((v) => v.id == event.vehicle.id ? event.vehicle : v)
          .toList(),
    );
    emit(state.copyWith(profile: updated, isSaving: true));
    await _save(updated);
    emit(state.copyWith(isSaving: false));
  }

  Future<void> _onRemoveVehicle(
    RemoveVehicleEvent event,
    Emitter<UserProfileState> emit,
  ) async {
    final current = state.profile;
    if (current == null) return;
    final newVehicles =
        current.vehicles.where((v) => v.id != event.vehicleId).toList();
    // Se si rimuove il veicolo attivo, seleziona il primo disponibile
    final newActiveId =
        current.activeVehicleId == event.vehicleId
            ? (newVehicles.isNotEmpty ? newVehicles.first.id : null)
            : current.activeVehicleId;
    final updated = current.copyWith(
      vehicles: newVehicles,
      activeVehicleId: newActiveId,
    );
    emit(state.copyWith(profile: updated, isSaving: true));
    await _save(updated);
    emit(state.copyWith(isSaving: false));
  }

  Future<void> _onSetActive(
    SetActiveVehicleEvent event,
    Emitter<UserProfileState> emit,
  ) async {
    final current = state.profile;
    if (current == null) return;
    final updated = current.copyWith(activeVehicleId: event.vehicleId);
    emit(state.copyWith(profile: updated, isSaving: true));
    await _save(updated);
    emit(state.copyWith(isSaving: false));
  }

  void _onClear(ClearUserProfileEvent event, Emitter<UserProfileState> emit) {
    emit(const UserProfileState());
  }

  Future<void> _save(UserProfile profile) async {
    try {
      await _repo.saveUserProfile(profile);
    } catch (_) {
      // Ottimistico: mantiene lo stato locale anche se il salvataggio fallisce
    }
  }
}
