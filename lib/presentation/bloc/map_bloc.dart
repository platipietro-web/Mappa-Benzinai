import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:mappa_prezzi_benzina/domain/entities/gas_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';
import 'package:mappa_prezzi_benzina/domain/repositories/repositories.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class MapBlocEvent extends Equatable {
  const MapBlocEvent();
  @override
  List<Object?> get props => [];
}

class LoadNearbyStationsEvent extends MapBlocEvent {
  final UserLocation location;
  final double radiusKm;

  const LoadNearbyStationsEvent({
    required this.location,
    required this.radiusKm,
  });

  @override
  List<Object?> get props => [location, radiusKm];
}

class RefreshStationsEvent extends MapBlocEvent {
  const RefreshStationsEvent();
}

class SelectStationEvent extends MapBlocEvent {
  final GasStation station;
  const SelectStationEvent(this.station);
  @override
  List<Object?> get props => [station];
}

class DeselectStationEvent extends MapBlocEvent {
  const DeselectStationEvent();
}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class MapState extends Equatable {
  const MapState();
  @override
  List<Object?> get props => [];
}

class MapInitial extends MapState {
  const MapInitial();
}

class MapLoading extends MapState {
  // Mantiene le stazioni già caricate visibili mentre carica le nuove
  final List<GasStation> stations;
  final GasStation? selectedStation;
  final UserLocation? userLocation;

  const MapLoading({
    this.stations = const [],
    this.selectedStation,
    this.userLocation,
  });

  @override
  List<Object?> get props => [stations, selectedStation, userLocation];
}

class MapLoaded extends MapState {
  final List<GasStation> stations;
  final GasStation? selectedStation;
  final UserLocation? userLocation;

  const MapLoaded({
    required this.stations,
    this.selectedStation,
    this.userLocation,
  });

  @override
  List<Object?> get props => [stations, selectedStation, userLocation];
}

class MapError extends MapState {
  final String message;
  const MapError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class MapBloc extends Bloc<MapBlocEvent, MapState> {
  final GasStationRepository _gasStationRepository;

  MapBloc(this._gasStationRepository) : super(const MapInitial()) {
    on<LoadNearbyStationsEvent>(_onLoadNearbyStations);
    on<RefreshStationsEvent>(_onRefreshStations);
    on<SelectStationEvent>(_onSelectStation);
    on<DeselectStationEvent>(_onDeselectStation);
  }

  UserLocation? _currentLocation;
  // Mappa id -> stazione: accumula stazioni da aree diverse senza duplicati
  final Map<String, GasStation> _stationsMap = {};
  GasStation? _selectedStation;

  Future<void> _onLoadNearbyStations(
    LoadNearbyStationsEvent event,
    Emitter<MapState> emit,
  ) async {
    _currentLocation = event.location;

    // Emetti loading mantenendo le stazioni già caricate visibili
    emit(MapLoading(
      stations: _stationsMap.values.toList(),
      selectedStation: _selectedStation,
      userLocation: _currentLocation,
    ));

    try {
      final newStations = await _gasStationRepository.getNearbyStations(
        event.location,
        event.radiusKm,
      );

      // Merge: aggiungi le nuove stazioni senza sovrascrivere quelle esistenti
      for (final station in newStations) {
        _stationsMap[station.id] = station;
      }

      // Limita a 500 stazioni totali per non appesantire la mappa
      // Mantieni le più recenti se supera il limite
      if (_stationsMap.length > 500) {
        final keys = _stationsMap.keys.toList();
        for (var i = 0; i < _stationsMap.length - 500; i++) {
          _stationsMap.remove(keys[i]);
        }
      }

      emit(MapLoaded(
        stations: _stationsMap.values.toList(),
        selectedStation: _selectedStation,
        userLocation: _currentLocation,
      ));
    } catch (e) {
      // In caso di errore mostra le stazioni già caricate se esistono
      if (_stationsMap.isNotEmpty) {
        emit(MapLoaded(
          stations: _stationsMap.values.toList(),
          selectedStation: _selectedStation,
          userLocation: _currentLocation,
        ));
      } else {
        emit(MapError('Impossibile caricare le stazioni: ${e.toString()}'));
      }
    }
  }

  Future<void> _onRefreshStations(
    RefreshStationsEvent event,
    Emitter<MapState> emit,
  ) async {
    if (_currentLocation != null) {
      // Refresh: svuota la cache e ricarica
      _stationsMap.clear();
      add(LoadNearbyStationsEvent(
        location: _currentLocation!,
        radiusKm: 50,
      ));
    }
  }

  void _onSelectStation(
    SelectStationEvent event,
    Emitter<MapState> emit,
  ) {
    _selectedStation = event.station;
    emit(MapLoaded(
      stations: _stationsMap.values.toList(),
      selectedStation: event.station,
      userLocation: _currentLocation,
    ));
  }

  void _onDeselectStation(
    DeselectStationEvent event,
    Emitter<MapState> emit,
  ) {
    _selectedStation = null;
    emit(MapLoaded(
      stations: _stationsMap.values.toList(),
      selectedStation: null,
      userLocation: _currentLocation,
    ));
  }
}