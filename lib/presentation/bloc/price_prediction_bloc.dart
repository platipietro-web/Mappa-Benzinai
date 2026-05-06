import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mappa_prezzi_benzina/core/services/price_prediction_service.dart';
import 'package:mappa_prezzi_benzina/domain/entities/price_prediction.dart';
import 'package:mappa_prezzi_benzina/domain/repositories/repositories.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class PricePredictionEvent extends Equatable {
  const PricePredictionEvent();
  @override
  List<Object?> get props => [];
}

class LoadPredictionEvent extends PricePredictionEvent {
  final String stationId;
  final String fuelType;
  final double currentPrice;

  const LoadPredictionEvent({
    required this.stationId,
    required this.fuelType,
    required this.currentPrice,
  });

  @override
  List<Object?> get props => [stationId, fuelType, currentPrice];
}

// ─── State ────────────────────────────────────────────────────────────────────

class PricePredictionState extends Equatable {
  final PricePrediction? prediction;
  final bool isLoading;
  final String? fuelType;

  const PricePredictionState({
    this.prediction,
    this.isLoading = false,
    this.fuelType,
  });

  PricePredictionState copyWith({
    PricePrediction? prediction,
    bool? isLoading,
    String? fuelType,
  }) =>
      PricePredictionState(
        prediction: prediction ?? this.prediction,
        isLoading: isLoading ?? this.isLoading,
        fuelType: fuelType ?? this.fuelType,
      );

  @override
  List<Object?> get props => [prediction, isLoading, fuelType];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class PricePredictionBloc
    extends Bloc<PricePredictionEvent, PricePredictionState> {
  final AnalyticsRepository _repo;

  PricePredictionBloc(this._repo) : super(const PricePredictionState()) {
    on<LoadPredictionEvent>(_onLoad);
  }

  Future<void> _onLoad(
    LoadPredictionEvent event,
    Emitter<PricePredictionState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, fuelType: event.fuelType));

    // Salva snapshot del prezzo corrente (max 1 al giorno, gestito dal repo)
    await _repo.savePriceSnapshot(
        event.stationId, event.fuelType, event.currentPrice);

    final snapshots =
        await _repo.getPriceSnapshots(event.stationId, event.fuelType);
    final prediction = PricePredictionService.predict(snapshots);

    emit(state.copyWith(prediction: prediction, isLoading: false));
  }
}
