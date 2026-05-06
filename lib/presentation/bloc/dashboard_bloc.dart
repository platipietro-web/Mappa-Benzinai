import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mappa_prezzi_benzina/domain/entities/dashboard_stats.dart';
import 'package:mappa_prezzi_benzina/domain/entities/refueling_log.dart';
import 'package:mappa_prezzi_benzina/domain/repositories/repositories.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();
  @override
  List<Object?> get props => [];
}

class LoadDashboardEvent extends DashboardEvent {
  final String userId;
  const LoadDashboardEvent(this.userId);
  @override
  List<Object?> get props => [userId];
}

class LogRefuelingEvent extends DashboardEvent {
  final RefuelingLog log;
  const LogRefuelingEvent(this.log);
  @override
  List<Object?> get props => [log.id];
}

class ClearDashboardEvent extends DashboardEvent {
  const ClearDashboardEvent();
}

// ─── State ────────────────────────────────────────────────────────────────────

class DashboardState extends Equatable {
  final DashboardStats stats;
  final bool isLoading;
  final bool isLogging;

  const DashboardState({
    this.stats = const DashboardStats(),
    this.isLoading = false,
    this.isLogging = false,
  });

  DashboardState copyWith({
    DashboardStats? stats,
    bool? isLoading,
    bool? isLogging,
  }) =>
      DashboardState(
        stats: stats ?? this.stats,
        isLoading: isLoading ?? this.isLoading,
        isLogging: isLogging ?? this.isLogging,
      );

  @override
  List<Object?> get props => [stats, isLoading, isLogging];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final AnalyticsRepository _repo;
  String? _currentUserId;

  DashboardBloc(this._repo) : super(const DashboardState()) {
    on<LoadDashboardEvent>(_onLoad);
    on<LogRefuelingEvent>(_onLogRefueling);
    on<ClearDashboardEvent>(_onClear);
  }

  Future<void> _onLoad(
    LoadDashboardEvent event,
    Emitter<DashboardState> emit,
  ) async {
    _currentUserId = event.userId;
    emit(state.copyWith(isLoading: true));
    final stats = await _repo.getDashboardStats(event.userId);
    emit(state.copyWith(stats: stats, isLoading: false));
  }

  Future<void> _onLogRefueling(
    LogRefuelingEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(state.copyWith(isLogging: true));
    try {
      await _repo.logRefueling(event.log);
      // Ricarica le statistiche dopo il log
      if (_currentUserId != null) {
        final stats = await _repo.getDashboardStats(_currentUserId!);
        emit(state.copyWith(stats: stats, isLogging: false));
      } else {
        emit(state.copyWith(isLogging: false));
      }
    } catch (_) {
      emit(state.copyWith(isLogging: false));
    }
  }

  void _onClear(ClearDashboardEvent event, Emitter<DashboardState> emit) {
    _currentUserId = null;
    emit(const DashboardState());
  }
}
