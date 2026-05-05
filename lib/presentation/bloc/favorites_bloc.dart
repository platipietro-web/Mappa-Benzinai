import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:mappa_prezzi_benzina/domain/entities/gas_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/saved_station.dart';
import 'package:mappa_prezzi_benzina/domain/repositories/repositories.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class FavoritesEvent extends Equatable {
  const FavoritesEvent();
  @override
  List<Object?> get props => [];
}

class LoadFavoritesEvent extends FavoritesEvent {
  final String userId;
  const LoadFavoritesEvent(this.userId);
  @override
  List<Object?> get props => [userId];
}

class AddFavoriteEvent extends FavoritesEvent {
  final String userId;
  final GasStation station;
  const AddFavoriteEvent({required this.userId, required this.station});
  @override
  List<Object?> get props => [userId, station.id];
}

class RemoveFavoriteEvent extends FavoritesEvent {
  final String userId;
  final String stationId;
  const RemoveFavoriteEvent({required this.userId, required this.stationId});
  @override
  List<Object?> get props => [userId, stationId];
}

class ClearFavoritesEvent extends FavoritesEvent {
  const ClearFavoritesEvent();
}

// ─── State ────────────────────────────────────────────────────────────────────

class FavoritesState extends Equatable {
  final Set<String> ids;
  final List<SavedStation> stations;
  final bool isLoading;

  const FavoritesState({
    this.ids = const {},
    this.stations = const [],
    this.isLoading = false,
  });

  bool isFavorite(String id) => ids.contains(id);

  FavoritesState copyWith({
    Set<String>? ids,
    List<SavedStation>? stations,
    bool? isLoading,
  }) =>
      FavoritesState(
        ids: ids ?? this.ids,
        stations: stations ?? this.stations,
        isLoading: isLoading ?? this.isLoading,
      );

  @override
  List<Object?> get props => [ids, stations, isLoading];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  final GasStationRepository _repo;

  FavoritesBloc(this._repo) : super(const FavoritesState()) {
    on<LoadFavoritesEvent>(_onLoad);
    on<AddFavoriteEvent>(_onAdd);
    on<RemoveFavoriteEvent>(_onRemove);
    on<ClearFavoritesEvent>(_onClear);
  }

  Future<void> _onLoad(
    LoadFavoritesEvent event,
    Emitter<FavoritesState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final saved = await _repo.getFavorites(event.userId);
      // Ordina per data aggiunta (più recenti prima) lato client
      saved.sort((a, b) {
        if (a.addedAt == null && b.addedAt == null) return 0;
        if (a.addedAt == null) return 1;
        if (b.addedAt == null) return -1;
        return b.addedAt!.compareTo(a.addedAt!);
      });
      emit(state.copyWith(
        ids: saved.map((s) => s.id).toSet(),
        stations: saved,
        isLoading: false,
      ));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onAdd(
    AddFavoriteEvent event,
    Emitter<FavoritesState> emit,
  ) async {
    // Aggiornamento ottimistico
    final newIds = Set<String>.from(state.ids)..add(event.station.id);
    final newStation = SavedStation(
      id: event.station.id,
      name: event.station.name,
      address: event.station.address,
      brand: event.station.brand,
      latitude: event.station.latitude,
      longitude: event.station.longitude,
      addedAt: DateTime.now(),
      prices: event.station.prices,
    );
    emit(state.copyWith(
      ids: newIds,
      stations: [newStation, ...state.stations],
    ));
    try {
      await _repo.addToFavorites(event.userId, event.station);
    } catch (_) {
      // Ripristina
      final revertIds = Set<String>.from(state.ids)..remove(event.station.id);
      emit(state.copyWith(
        ids: revertIds,
        stations: state.stations.where((s) => s.id != event.station.id).toList(),
      ));
    }
  }

  Future<void> _onRemove(
    RemoveFavoriteEvent event,
    Emitter<FavoritesState> emit,
  ) async {
    final prevIds = Set<String>.from(state.ids);
    final prevStations = List<SavedStation>.from(state.stations);
    final newIds = Set<String>.from(state.ids)..remove(event.stationId);
    emit(state.copyWith(
      ids: newIds,
      stations: state.stations.where((s) => s.id != event.stationId).toList(),
    ));
    try {
      await _repo.removeFromFavorites(event.userId, event.stationId);
    } catch (_) {
      // Ripristina
      emit(state.copyWith(ids: prevIds, stations: prevStations));
    }
  }

  void _onClear(ClearFavoritesEvent event, Emitter<FavoritesState> emit) {
    emit(const FavoritesState());
  }
}
