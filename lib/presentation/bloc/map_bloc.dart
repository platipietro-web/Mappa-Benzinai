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
  // true solo quando la location arriva dal GPS del dispositivo:
  // il pin dell'utente si sposta solo in quel caso
  final bool isGpsLocation;

  const LoadNearbyStationsEvent({
    required this.location,
    required this.radiusKm,
    this.isGpsLocation = false,
  });

  @override
  List<Object?> get props => [location, radiusKm, isGpsLocation];
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

class SetPendingHighlightStationEvent extends MapBlocEvent {
  final GasStation station;
  const SetPendingHighlightStationEvent(this.station);
  @override
  List<Object?> get props => [station];
}

class ClearPendingHighlightStationEvent extends MapBlocEvent {
  const ClearPendingHighlightStationEvent();
}

class UpdateStationPricesEvent extends MapBlocEvent {
  final String stationId;
  final String fuelType;
  final double price;
  const UpdateStationPricesEvent({
    required this.stationId,
    required this.fuelType,
    required this.price,
  });
  @override
  List<Object?> get props => [stationId, fuelType, price];
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
  final GasStation? pendingHighlightStation;

  const MapLoaded({
    required this.stations,
    this.selectedStation,
    this.userLocation,
    this.pendingHighlightStation,
  });

  @override
  List<Object?> get props => [stations, selectedStation, userLocation, pendingHighlightStation];
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
    on<UpdateStationPricesEvent>(_onUpdatePrice);
    on<SetPendingHighlightStationEvent>(_onSetPendingHighlight);
    on<ClearPendingHighlightStationEvent>(_onClearPendingHighlight);
  }

  // Posizione GPS reale del dispositivo — aggiornata solo da isGpsLocation=true
  UserLocation? _gpsLocation;
  // Centro usato per le query — può essere qualsiasi luogo cercato/navigato
  UserLocation? _queryCenter;

  final Map<String, GasStation> _stationsMap = {};
  GasStation? _selectedStation;
  GasStation? _pendingHighlightStation;

  Future<void> _onLoadNearbyStations(
    LoadNearbyStationsEvent event,
    Emitter<MapState> emit,
  ) async {
    _queryCenter = event.location;
    if (event.isGpsLocation) {
      _gpsLocation = event.location;
    }

    emit(MapLoading(
      stations: _stationsMap.values.toList(),
      selectedStation: _selectedStation,
      userLocation: _gpsLocation,
    ));

    try {
      final newStations = await _gasStationRepository.getNearbyStations(
        event.location,
        event.radiusKm,
      );

      for (final station in newStations) {
        _stationsMap[station.id] = station;
      }

      if (_stationsMap.length > 2000) {
        final center = event.location;
        final sorted = _stationsMap.values.toList()
          ..sort((a, b) => a
              .getDistanceFromCoordinates(center.latitude, center.longitude)
              .compareTo(b.getDistanceFromCoordinates(
                  center.latitude, center.longitude)));
        _stationsMap.clear();
        for (final s in sorted.take(2000)) {
          _stationsMap[s.id] = s;
        }
      }

      emit(MapLoaded(
        stations: _stationsMap.values.toList(),
        selectedStation: _selectedStation,
        userLocation: _gpsLocation,
        pendingHighlightStation: _pendingHighlightStation,
      ));
    } catch (e) {
      if (_stationsMap.isNotEmpty) {
        emit(MapLoaded(
          stations: _stationsMap.values.toList(),
          selectedStation: _selectedStation,
          userLocation: _gpsLocation,
          pendingHighlightStation: _pendingHighlightStation,
        ));
      } else {
        emit(MapError('Impossibile caricare le stazioni: ${e.toString()}'));
      }
    }
  }

  void _onSetPendingHighlight(
    SetPendingHighlightStationEvent event,
    Emitter<MapState> emit,
  ) {
    _pendingHighlightStation = event.station;
  }

  void _onClearPendingHighlight(
    ClearPendingHighlightStationEvent event,
    Emitter<MapState> emit,
  ) {
    _pendingHighlightStation = null;
    if (state is MapLoaded) {
      final s = state as MapLoaded;
      emit(MapLoaded(
        stations: s.stations,
        selectedStation: s.selectedStation,
        userLocation: s.userLocation,
        pendingHighlightStation: null,
      ));
    }
  }

  Future<void> _onRefreshStations(
    RefreshStationsEvent event,
    Emitter<MapState> emit,
  ) async {
    final center = _queryCenter ?? _gpsLocation;
    if (center != null) {
      _stationsMap.clear();
      add(LoadNearbyStationsEvent(
        location: center,
        radiusKm: 50,
        isGpsLocation: false,
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
      userLocation: _gpsLocation,
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
      userLocation: _gpsLocation,
    ));
  }

  void _onUpdatePrice(
    UpdateStationPricesEvent event,
    Emitter<MapState> emit,
  ) {
    final station = _stationsMap[event.stationId];
    if (station == null) return;
    final updated = GasStation(
      id: station.id,
      name: station.name,
      address: station.address,
      latitude: station.latitude,
      longitude: station.longitude,
      phoneNumber: station.phoneNumber,
      website: station.website,
      openingHours: station.openingHours,
      prices: Map<String, double>.from(station.prices)..[event.fuelType] = event.price,
      lastUpdated: DateTime.now(),
      numberOfRatings: station.numberOfRatings,
      averageRating: station.averageRating,
      brand: station.brand,
    );
    _stationsMap[event.stationId] = updated;
    if (_selectedStation?.id == event.stationId) _selectedStation = updated;
    emit(MapLoaded(
      stations: _stationsMap.values.toList(),
      selectedStation: _selectedStation,
      userLocation: _gpsLocation,
    ));
  }
}
