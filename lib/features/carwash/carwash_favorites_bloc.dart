import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mappa_prezzi_benzina/domain/entities/car_wash.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class CarWashFavoritesEvent extends Equatable {
  const CarWashFavoritesEvent();
  @override
  List<Object?> get props => [];
}

class LoadCarWashFavoritesEvent extends CarWashFavoritesEvent {
  final String userId;
  const LoadCarWashFavoritesEvent(this.userId);
  @override
  List<Object?> get props => [userId];
}

class ToggleCarWashFavoriteEvent extends CarWashFavoritesEvent {
  final String userId;
  final CarWash carWash;
  const ToggleCarWashFavoriteEvent({required this.userId, required this.carWash});
  @override
  List<Object?> get props => [userId, carWash.id];
}

class ClearCarWashFavoritesEvent extends CarWashFavoritesEvent {
  const ClearCarWashFavoritesEvent();
}

// ─── State ────────────────────────────────────────────────────────────────────

class CarWashFavoritesState extends Equatable {
  final Set<String> ids;
  const CarWashFavoritesState({this.ids = const {}});

  bool isFavorite(String id) => ids.contains(id);

  CarWashFavoritesState copyWith({Set<String>? ids}) =>
      CarWashFavoritesState(ids: ids ?? this.ids);

  @override
  List<Object?> get props => [ids];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class CarWashFavoritesBloc
    extends Bloc<CarWashFavoritesEvent, CarWashFavoritesState> {
  final FirebaseFirestore _firestore;

  CarWashFavoritesBloc(this._firestore)
      : super(const CarWashFavoritesState()) {
    on<LoadCarWashFavoritesEvent>(_onLoad);
    on<ToggleCarWashFavoriteEvent>(_onToggle);
    on<ClearCarWashFavoritesEvent>(_onClear);
  }

  CollectionReference _col(String userId) => _firestore
      .collection('users')
      .doc(userId)
      .collection('car_wash_favorites');

  Future<void> _onLoad(
    LoadCarWashFavoritesEvent event,
    Emitter<CarWashFavoritesState> emit,
  ) async {
    try {
      final snap = await _col(event.userId).get();
      emit(CarWashFavoritesState(
          ids: snap.docs.map((d) => d.id).toSet()));
    } catch (_) {}
  }

  Future<void> _onToggle(
    ToggleCarWashFavoriteEvent event,
    Emitter<CarWashFavoritesState> emit,
  ) async {
    final isFav = state.isFavorite(event.carWash.id);
    // Optimistic update
    final newIds = Set<String>.from(state.ids);
    if (isFav) {
      newIds.remove(event.carWash.id);
    } else {
      newIds.add(event.carWash.id);
    }
    emit(state.copyWith(ids: newIds));

    try {
      final ref = _col(event.userId).doc(event.carWash.id);
      if (isFav) {
        await ref.delete();
      } else {
        await ref.set({
          'name': event.carWash.name,
          if (event.carWash.address != null) 'address': event.carWash.address,
          'latitude': event.carWash.latitude,
          'longitude': event.carWash.longitude,
          'type': event.carWash.type,
          'added_at': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      // Revert on failure
      emit(state.copyWith(ids: Set<String>.from(state.ids)));
    }
  }

  void _onClear(
      ClearCarWashFavoritesEvent event, Emitter<CarWashFavoritesState> emit) {
    emit(const CarWashFavoritesState());
  }
}
