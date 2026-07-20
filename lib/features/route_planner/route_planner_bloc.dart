import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/core/services/real_cost_calculator.dart';
import 'package:mappa_prezzi_benzina/core/services/route_geometry.dart';
import 'package:mappa_prezzi_benzina/core/services/route_service.dart';
import 'package:mappa_prezzi_benzina/domain/entities/gas_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/route_info.dart';
import 'package:mappa_prezzi_benzina/domain/entities/route_station_suggestion.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';
import 'package:mappa_prezzi_benzina/domain/repositories/repositories.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class RoutePlannerEvent extends Equatable {
  const RoutePlannerEvent();
  @override
  List<Object?> get props => [];
}

class CalculateRouteEvent extends RoutePlannerEvent {
  final double originLat;
  final double originLon;
  final String originLabel;
  final double destLat;
  final double destLon;
  final String destLabel;
  final String fuelType;
  // Consumo/serbatoio del veicolo di default dell'utente (già risolti con
  // fallback lato UI, stessi valori usati in station_detail_page.dart).
  final double consumption;
  final double tankSize;

  const CalculateRouteEvent({
    required this.originLat,
    required this.originLon,
    required this.originLabel,
    required this.destLat,
    required this.destLon,
    required this.destLabel,
    required this.fuelType,
    required this.consumption,
    required this.tankSize,
  });

  @override
  List<Object?> get props => [
        originLat,
        originLon,
        originLabel,
        destLat,
        destLon,
        destLabel,
        fuelType,
        consumption,
        tankSize,
      ];
}

/// L'utente sceglie un'alternativa stradale tra quelle proposte per lo
/// stesso viaggio Partenza → Destinazione.
class SelectRouteAlternativeEvent extends RoutePlannerEvent {
  final int index;
  const SelectRouteAlternativeEvent(this.index);
  @override
  List<Object?> get props => [index];
}

/// Imposta (o sostituisce, se già presente) una tappa intermedia: il
/// percorso viene ricalcolato come Partenza → [station] → Destinazione.
class AddWaypointEvent extends RoutePlannerEvent {
  final GasStation station;
  const AddWaypointEvent(this.station);
  @override
  List<Object?> get props => [station.id];
}

/// Rimuove la tappa e torna al percorso diretto (con le sue alternative).
class RemoveWaypointEvent extends RoutePlannerEvent {
  const RemoveWaypointEvent();
}

class ClearRouteEvent extends RoutePlannerEvent {
  const ClearRouteEvent();
}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class RoutePlannerState extends Equatable {
  const RoutePlannerState();
  @override
  List<Object?> get props => [];
}

class RoutePlannerInitial extends RoutePlannerState {
  const RoutePlannerInitial();
}

class RoutePlannerLoading extends RoutePlannerState {
  const RoutePlannerLoading();
}

class RoutePlannerLoaded extends RoutePlannerState {
  // Alternative per il viaggio Partenza → Destinazione (>= 1 elemento).
  // Contiene una sola route quando è impostata una tappa (waypointStation
  // != null): OSRM non gestisce alternative affidabili con più di 2 punti.
  final List<RouteInfo> routes;
  final int selectedRouteIndex;
  // Elenco completo dei benzinai nel corridoio della route attiva,
  // ordinato per prezzo effettivo. NON filtrato per brand: quel filtro
  // resta lato UI (vedi RoutePlannerScreen._applyBrandFilter).
  final List<RouteStationSuggestion> suggestions;
  final String originLabel;
  final String destLabel;
  final GasStation? waypointStation;
  // true mentre si ricalcolano i suggerimenti per una nuova alternativa o
  // per una tappa: il tracciato (già disponibile) può aggiornarsi subito,
  // la lista resta con i dati precedenti finché non arrivano quelli nuovi.
  final bool isRecalculating;

  const RoutePlannerLoaded({
    required this.routes,
    required this.selectedRouteIndex,
    required this.suggestions,
    required this.originLabel,
    required this.destLabel,
    this.waypointStation,
    this.isRecalculating = false,
  });

  RouteInfo get activeRoute => routes[selectedRouteIndex];

  RouteStationSuggestion? get recommended =>
      suggestions.isEmpty ? null : suggestions.first;

  RoutePlannerLoaded copyWith({
    List<RouteInfo>? routes,
    int? selectedRouteIndex,
    List<RouteStationSuggestion>? suggestions,
    String? originLabel,
    String? destLabel,
    bool? isRecalculating,
  }) {
    return RoutePlannerLoaded(
      routes: routes ?? this.routes,
      selectedRouteIndex: selectedRouteIndex ?? this.selectedRouteIndex,
      suggestions: suggestions ?? this.suggestions,
      originLabel: originLabel ?? this.originLabel,
      destLabel: destLabel ?? this.destLabel,
      waypointStation: waypointStation,
      isRecalculating: isRecalculating ?? this.isRecalculating,
    );
  }

  @override
  List<Object?> get props => [
        routes,
        selectedRouteIndex,
        suggestions,
        originLabel,
        destLabel,
        waypointStation,
        isRecalculating,
      ];
}

class RoutePlannerError extends RoutePlannerState {
  final String message;
  const RoutePlannerError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────────

class RoutePlannerBloc extends Bloc<RoutePlannerEvent, RoutePlannerState> {
  final GasStationRepository _gasStationRepository;

  RoutePlannerBloc(this._gasStationRepository)
      : super(const RoutePlannerInitial()) {
    on<CalculateRouteEvent>(_onCalculateRoute);
    on<SelectRouteAlternativeEvent>(_onSelectRouteAlternative);
    on<AddWaypointEvent>(_onAddWaypoint);
    on<RemoveWaypointEvent>(_onRemoveWaypoint);
    on<ClearRouteEvent>((event, emit) {
      _lastRequest = null;
      _altSuggestionsCache.clear();
      emit(const RoutePlannerInitial());
    });
  }

  // Ultima richiesta calcolata dall'utente (Da/A/carburante/veicolo): serve
  // per ricalcolare le alternative o rimuovere la tappa senza dover far
  // ripetere la ricerca.
  CalculateRouteEvent? _lastRequest;
  // Suggerimenti già calcolati per indice di alternativa, per non rifare le
  // query quando si torna su una route già vista. Azzerata a ogni nuovo
  // CalculateRouteEvent.
  final Map<int, List<RouteStationSuggestion>> _altSuggestionsCache = {};

  Future<void> _onCalculateRoute(
    CalculateRouteEvent event,
    Emitter<RoutePlannerState> emit,
  ) async {
    _lastRequest = event;
    await _runCalculate(event, emit);
  }

  Future<void> _runCalculate(
    CalculateRouteEvent event,
    Emitter<RoutePlannerState> emit,
  ) async {
    emit(const RoutePlannerLoading());
    _altSuggestionsCache.clear();

    final origin =
        RoutePoint(latitude: event.originLat, longitude: event.originLon);
    final dest = RoutePoint(latitude: event.destLat, longitude: event.destLon);

    final routes = await RouteService.getRoutes(
      waypoints: [origin, dest],
      alternatives: true,
    );
    if (routes.isEmpty) {
      emit(const RoutePlannerError(
          'Impossibile calcolare il percorso. Riprova.'));
      return;
    }
    final limitedRoutes =
        routes.take(AppConstants.routeMaxAlternatives).toList();

    // Solo la prima alternativa viene analizzata subito: le altre, se
    // scelte dall'utente, vengono calcolate on demand (vedi
    // _onSelectRouteAlternative) per non moltiplicare le query.
    final suggestions = await _findSuggestionsForRoute(
      limitedRoutes.first,
      fuelType: event.fuelType,
      consumption: event.consumption,
      tankSize: event.tankSize,
    );
    if (suggestions == null) {
      emit(const RoutePlannerError(
          'Errore nel recupero dei distributori lungo il percorso.'));
      return;
    }
    _altSuggestionsCache[0] = suggestions;

    emit(RoutePlannerLoaded(
      routes: limitedRoutes,
      selectedRouteIndex: 0,
      suggestions: suggestions,
      originLabel: event.originLabel,
      destLabel: event.destLabel,
    ));
  }

  Future<void> _onSelectRouteAlternative(
    SelectRouteAlternativeEvent event,
    Emitter<RoutePlannerState> emit,
  ) async {
    final current = state;
    final request = _lastRequest;
    if (current is! RoutePlannerLoaded || request == null) return;
    if (event.index == current.selectedRouteIndex) return;
    if (event.index < 0 || event.index >= current.routes.length) return;

    final cached = _altSuggestionsCache[event.index];
    if (cached != null) {
      emit(current.copyWith(
        selectedRouteIndex: event.index,
        suggestions: cached,
      ));
      return;
    }

    // Il tracciato della nuova alternativa è già disponibile: si aggiorna
    // subito la mappa, la lista resta quella precedente finché non
    // arrivano i nuovi suggerimenti.
    emit(current.copyWith(
      selectedRouteIndex: event.index,
      isRecalculating: true,
    ));

    final suggestions = await _findSuggestionsForRoute(
      current.routes[event.index],
      fuelType: request.fuelType,
      consumption: request.consumption,
      tankSize: request.tankSize,
    );

    final latest = state;
    if (latest is! RoutePlannerLoaded ||
        latest.selectedRouteIndex != event.index) {
      return; // l'utente ha già cambiato di nuovo selezione nel frattempo
    }
    if (suggestions == null) {
      emit(latest.copyWith(isRecalculating: false));
      return;
    }
    _altSuggestionsCache[event.index] = suggestions;
    emit(latest.copyWith(suggestions: suggestions, isRecalculating: false));
  }

  Future<void> _onAddWaypoint(
    AddWaypointEvent event,
    Emitter<RoutePlannerState> emit,
  ) async {
    final current = state;
    final request = _lastRequest;
    if (current is! RoutePlannerLoaded || request == null) return;

    emit(current.copyWith(isRecalculating: true));

    final origin =
        RoutePoint(latitude: request.originLat, longitude: request.originLon);
    final stop = RoutePoint(
        latitude: event.station.latitude, longitude: event.station.longitude);
    final dest =
        RoutePoint(latitude: request.destLat, longitude: request.destLon);

    final routes = await RouteService.getRoutes(
      waypoints: [origin, stop, dest],
      alternatives: false,
    );
    if (routes.isEmpty) {
      final latest = state;
      if (latest is RoutePlannerLoaded) {
        emit(latest.copyWith(isRecalculating: false));
      }
      return;
    }

    final suggestions = await _findSuggestionsForRoute(
      routes.first,
      fuelType: request.fuelType,
      consumption: request.consumption,
      tankSize: request.tankSize,
    );

    emit(RoutePlannerLoaded(
      routes: [routes.first],
      selectedRouteIndex: 0,
      suggestions: suggestions ?? const [],
      originLabel: current.originLabel,
      destLabel: current.destLabel,
      waypointStation: event.station,
    ));
  }

  Future<void> _onRemoveWaypoint(
    RemoveWaypointEvent event,
    Emitter<RoutePlannerState> emit,
  ) async {
    final request = _lastRequest;
    if (request == null) return;
    await _runCalculate(request, emit);
  }

  /// Corridoio + carburante + ranking per una singola route (alternativa o
  /// route con tappa). Ritorna `null` solo per un errore I/O — da
  /// distinguere da "nessun candidato", che ritorna una lista vuota.
  Future<List<RouteStationSuggestion>?> _findSuggestionsForRoute(
    RouteInfo route, {
    required String fuelType,
    required double consumption,
    required double tankSize,
  }) async {
    final simplified =
        RouteGeometry.downsample(route.points, minSpacingKm: 0.3);

    final interval = math.max(
      AppConstants.routeSampleIntervalKm,
      route.distanceKm / 25,
    );
    final centers =
        RouteGeometry.sampleCenters(route.points, intervalKm: interval);

    final Map<String, GasStation> merged = {};
    try {
      final results = await Future.wait(centers.map((c) =>
          _gasStationRepository.getNearbyStations(
            UserLocation(
              latitude: c.latitude,
              longitude: c.longitude,
              timestamp: DateTime.now(),
            ),
            AppConstants.routeSearchFetchRadiusKm,
          )));
      for (final list in results) {
        for (final s in list) {
          merged[s.id] = s;
        }
      }
    } catch (_) {
      return null;
    }

    final candidates = <GasStation>[];
    final detourById = <String, double>{};
    for (final s in merged.values) {
      if (!s.prices.containsKey(fuelType)) continue;
      final point = RoutePoint(latitude: s.latitude, longitude: s.longitude);
      final detour = RouteGeometry.distanceToRouteKm(point, simplified);
      if (detour <= AppConstants.routeCorridorKm) {
        candidates.add(s);
        detourById[s.id] = detour;
      }
    }

    if (candidates.isEmpty) return const [];

    final areaAvg = RealCostCalculator.areaAverage(
        candidates.map((s) => s.prices[fuelType]!));

    final suggestions = candidates.map((s) {
      final price = s.prices[fuelType]!;
      final detour = detourById[s.id]!;
      final result = RealCostCalculator.calculate(
        distanceKm: detour,
        fuelPrice: price,
        areaAvgPrice: areaAvg,
        consumption: consumption,
        tankSize: tankSize,
      );
      final point = RoutePoint(latitude: s.latitude, longitude: s.longitude);
      return RouteStationSuggestion(
        station: s,
        detourKm: detour,
        distanceAlongRouteKm:
            RouteGeometry.progressAlongRouteKm(point, simplified),
        fuelPrice: price,
        effectivePrice: result.effectivePrice,
        netSaving: result.netSaving,
        isWorthIt: result.isWorthIt,
      );
    }).toList()
      ..sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));

    return suggestions.take(AppConstants.routeMaxSuggestions).toList();
  }
}
