import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mappa_prezzi_benzina/domain/entities/car_wash.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';
import 'package:mappa_prezzi_benzina/features/carwash/carwash_repository.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class CarWashEvent extends Equatable {
  const CarWashEvent();
  @override
  List<Object?> get props => [];
}

class LoadNearbyCarWashesEvent extends CarWashEvent {
  final UserLocation location;
  final double radiusKm;
  final bool isGpsLocation;

  const LoadNearbyCarWashesEvent({
    required this.location,
    required this.radiusKm,
    this.isGpsLocation = false,
  });

  @override
  List<Object?> get props => [location, radiusKm, isGpsLocation];
}

class RefreshCarWashesEvent extends CarWashEvent {
  const RefreshCarWashesEvent();
}

class SelectCarWashEvent extends CarWashEvent {
  final CarWash carWash;
  const SelectCarWashEvent(this.carWash);
  @override
  List<Object?> get props => [carWash];
}

class DeselectCarWashEvent extends CarWashEvent {
  const DeselectCarWashEvent();
}

class AddCarWashEvent extends CarWashEvent {
  final CarWash carWash;
  const AddCarWashEvent(this.carWash);
  @override
  List<Object?> get props => [carWash];
}

class AddMultipleCarWashesEvent extends CarWashEvent {
  final List<CarWash> washes;
  const AddMultipleCarWashesEvent(this.washes);
  @override
  List<Object?> get props => [washes];
}

class UpdateCarWashEvent extends CarWashEvent {
  final CarWash carWash;
  const UpdateCarWashEvent(this.carWash);
  @override
  List<Object?> get props => [carWash];
}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class CarWashState extends Equatable {
  const CarWashState();
  @override
  List<Object?> get props => [];
}

class CarWashInitial extends CarWashState {
  const CarWashInitial();
}

class CarWashLoading extends CarWashState {
  final List<CarWash> washes;
  final CarWash? selectedWash;
  final UserLocation? userLocation;

  const CarWashLoading({
    this.washes = const [],
    this.selectedWash,
    this.userLocation,
  });

  @override
  List<Object?> get props => [washes, selectedWash, userLocation];
}

class CarWashLoaded extends CarWashState {
  final List<CarWash> washes;
  final CarWash? selectedWash;
  final UserLocation? userLocation;

  const CarWashLoaded({
    required this.washes,
    this.selectedWash,
    this.userLocation,
  });

  @override
  List<Object?> get props => [washes, selectedWash, userLocation];
}

class CarWashError extends CarWashState {
  final String message;
  const CarWashError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class CarWashBloc extends Bloc<CarWashEvent, CarWashState> {
  final CarWashRepository _repository;

  UserLocation? _gpsLocation;
  UserLocation? _queryCenter;
  final Map<String, CarWash> _washesMap = {};
  CarWash? _selectedWash;

  CarWashBloc(this._repository) : super(const CarWashInitial()) {
    on<LoadNearbyCarWashesEvent>(_onLoad);
    on<RefreshCarWashesEvent>(_onRefresh);
    on<SelectCarWashEvent>(_onSelect);
    on<DeselectCarWashEvent>(_onDeselect);
    on<AddCarWashEvent>(_onAdd);
    on<AddMultipleCarWashesEvent>(_onAddMultiple);
    on<UpdateCarWashEvent>(_onUpdate);
  }

  Future<void> _onLoad(
    LoadNearbyCarWashesEvent event,
    Emitter<CarWashState> emit,
  ) async {
    _queryCenter = event.location;
    if (event.isGpsLocation) _gpsLocation = event.location;

    emit(CarWashLoading(
      washes: _washesMap.values.toList(),
      selectedWash: _selectedWash,
      userLocation: _gpsLocation,
    ));

    try {
      final newWashes = await _repository.getNearbyCarWashes(
        event.location.latitude,
        event.location.longitude,
        event.radiusKm,
      );
      for (final w in newWashes) {
        _washesMap[w.id] = w;
      }
      emit(CarWashLoaded(
        washes: _washesMap.values.toList(),
        selectedWash: _selectedWash,
        userLocation: _gpsLocation,
      ));
    } catch (e) {
      if (_washesMap.isNotEmpty) {
        emit(CarWashLoaded(
          washes: _washesMap.values.toList(),
          selectedWash: _selectedWash,
          userLocation: _gpsLocation,
        ));
      } else {
        emit(CarWashError('Impossibile caricare gli autolavaggi: $e'));
      }
    }
  }

  Future<void> _onRefresh(
    RefreshCarWashesEvent event,
    Emitter<CarWashState> emit,
  ) async {
    final center = _queryCenter ?? _gpsLocation;
    if (center != null) {
      _washesMap.clear();
      add(LoadNearbyCarWashesEvent(location: center, radiusKm: 50));
    }
  }

  void _onSelect(SelectCarWashEvent event, Emitter<CarWashState> emit) {
    _selectedWash = event.carWash;
    emit(CarWashLoaded(
      washes: _washesMap.values.toList(),
      selectedWash: event.carWash,
      userLocation: _gpsLocation,
    ));
  }

  void _onDeselect(DeselectCarWashEvent event, Emitter<CarWashState> emit) {
    _selectedWash = null;
    emit(CarWashLoaded(
      washes: _washesMap.values.toList(),
      selectedWash: null,
      userLocation: _gpsLocation,
    ));
  }

  Future<void> _onAdd(
    AddCarWashEvent event,
    Emitter<CarWashState> emit,
  ) async {
    try {
      await _repository.addCarWash(event.carWash);
      _washesMap[event.carWash.id] = event.carWash;
      emit(CarWashLoaded(
        washes: _washesMap.values.toList(),
        selectedWash: _selectedWash,
        userLocation: _gpsLocation,
      ));
    } catch (e) {
      emit(CarWashError('Errore durante il salvataggio: $e'));
    }
  }

  void _onAddMultiple(
    AddMultipleCarWashesEvent event,
    Emitter<CarWashState> emit,
  ) {
    for (final w in event.washes) {
      _washesMap[w.id] = w;
    }
    emit(CarWashLoaded(
      washes: _washesMap.values.toList(),
      selectedWash: _selectedWash,
      userLocation: _gpsLocation,
    ));
  }

  Future<void> _onUpdate(
    UpdateCarWashEvent event,
    Emitter<CarWashState> emit,
  ) async {
    try {
      await _repository.updateCarWash(event.carWash);
      _washesMap[event.carWash.id] = event.carWash;
      if (_selectedWash?.id == event.carWash.id) {
        _selectedWash = event.carWash;
      }
      emit(CarWashLoaded(
        washes: _washesMap.values.toList(),
        selectedWash: _selectedWash,
        userLocation: _gpsLocation,
      ));
    } catch (e) {
      emit(CarWashError('Errore durante l\'aggiornamento: $e'));
    }
  }
}
