import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';
import 'package:mappa_prezzi_benzina/domain/repositories/repositories.dart';

// Events
abstract class LocationEvent extends Equatable {
  const LocationEvent();

  @override
  List<Object?> get props => [];
}

class RequestLocationPermissionEvent extends LocationEvent {
  const RequestLocationPermissionEvent();
}

class CheckLocationServiceEvent extends LocationEvent {
  const CheckLocationServiceEvent();
}

class GetCurrentLocationEvent extends LocationEvent {
  const GetCurrentLocationEvent();
}

class StartLocationUpdatesEvent extends LocationEvent {
  const StartLocationUpdatesEvent();
}

class StopLocationUpdatesEvent extends LocationEvent {
  const StopLocationUpdatesEvent();
}

// States
abstract class LocationState extends Equatable {
  const LocationState();

  @override
  List<Object?> get props => [];
}

class LocationInitial extends LocationState {
  const LocationInitial();
}

class LocationLoading extends LocationState {
  const LocationLoading();
}

class LocationPermissionGranted extends LocationState {
  const LocationPermissionGranted();
}

class LocationLoaded extends LocationState {
  final UserLocation location;

  const LocationLoaded(this.location);

  @override
  List<Object?> get props => [location];
}

class LocationPermissionDenied extends LocationState {
  const LocationPermissionDenied();
}

class LocationServiceDisabled extends LocationState {
  const LocationServiceDisabled();
}

class LocationUpdating extends LocationState {
  const LocationUpdating();
}

class LocationError extends LocationState {
  final String message;

  const LocationError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final LocationRepository _locationRepository;

  LocationBloc(this._locationRepository) : super(const LocationInitial()) {
    on<RequestLocationPermissionEvent>(_onRequestPermission);
    on<CheckLocationServiceEvent>(_onCheckService);
    on<GetCurrentLocationEvent>(_onGetCurrentLocation);
    on<StartLocationUpdatesEvent>(_onStartUpdates);
    on<StopLocationUpdatesEvent>(_onStopUpdates);
  }

  Future<void> _onRequestPermission(
    RequestLocationPermissionEvent event,
    Emitter<LocationState> emit,
  ) async {
    emit(const LocationLoading());
    try {
      final enabled = await _locationRepository.isLocationServiceEnabled();
      if (!enabled) {
        emit(const LocationServiceDisabled());
        return;
      }

      final granted = await _locationRepository.requestLocationPermission();
      if (granted) {
        final location = await _locationRepository.getCurrentLocation();
        emit(LocationLoaded(location));
      } else {
        emit(const LocationPermissionDenied());
      }
    } catch (e) {
      emit(LocationError(e.toString()));
    }
  }

  Future<void> _onCheckService(
    CheckLocationServiceEvent event,
    Emitter<LocationState> emit,
  ) async {
    try {
      final enabled = await _locationRepository.isLocationServiceEnabled();
      if (!enabled) {
        emit(const LocationServiceDisabled());
      }
    } catch (e) {
      emit(LocationError(e.toString()));
    }
  }

  Future<void> _onGetCurrentLocation(
    GetCurrentLocationEvent event,
    Emitter<LocationState> emit,
  ) async {
    emit(const LocationLoading());
    try {
      final location = await _locationRepository.getCurrentLocation();
      emit(LocationLoaded(location));
    } catch (e) {
      emit(LocationError(e.toString()));
    }
  }

  Future<void> _onStartUpdates(
    StartLocationUpdatesEvent event,
    Emitter<LocationState> emit,
  ) async {
    emit(const LocationUpdating());
    try {
      await emit.forEach(
        _locationRepository.getLocationUpdates(),
        onData: (location) => const LocationUpdating(),
        onError: (error, stackTrace) => LocationError(error.toString()),
      );
    } catch (e) {
      emit(LocationError(e.toString()));
    }
  }

  Future<void> _onStopUpdates(
    StopLocationUpdatesEvent event,
    Emitter<LocationState> emit,
  ) async {
    emit(const LocationInitial());
  }
}
