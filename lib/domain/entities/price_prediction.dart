import 'package:equatable/equatable.dart';

enum PriceTrend { rising, stable, falling }

class PricePrediction extends Equatable {
  final PriceTrend trend;
  final double variationPct; // variazione % stimata rispetto alla media mobile
  final double movingAvg;
  final String advice;
  final bool hasEnoughData;

  const PricePrediction({
    required this.trend,
    required this.variationPct,
    required this.movingAvg,
    required this.advice,
    required this.hasEnoughData,
  });

  factory PricePrediction.insufficient() => const PricePrediction(
        trend: PriceTrend.stable,
        variationPct: 0,
        movingAvg: 0,
        advice: 'Dati insufficienti — la previsione migliorerà nel tempo',
        hasEnoughData: false,
      );

  @override
  List<Object?> get props =>
      [trend, variationPct, movingAvg, advice, hasEnoughData];
}
