import 'package:mappa_prezzi_benzina/domain/entities/price_prediction.dart';
import 'package:mappa_prezzi_benzina/domain/entities/price_snapshot.dart';

class PricePredictionService {
  static const int _minDataPoints = 3;
  static const int _windowSize = 5;

  /// Calcola la previsione del prezzo usando media mobile e regressione lineare.
  static PricePrediction predict(List<PriceSnapshot> history) {
    if (history.length < _minDataPoints) {
      return PricePrediction.insufficient();
    }

    final sorted = [...history]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final prices = sorted.map((s) => s.price).toList();
    final movingAvgs = _movingAverage(prices, _windowSize);
    final movingAvg = movingAvgs.last;

    final lastPrice = prices.last;
    final variation = movingAvg != 0
        ? ((lastPrice - movingAvg) / movingAvg) * 100.0
        : 0.0;

    final trend = _detectTrend(prices);

    final String advice;
    switch (trend) {
      case PriceTrend.falling:
        advice = 'Prezzi in calo — conviene aspettare';
        break;
      case PriceTrend.rising:
        advice = 'Prezzi in aumento — conviene fare rifornimento ora';
        break;
      case PriceTrend.stable:
        advice = 'Prezzi stabili — rifornisci quando vuoi';
        break;
    }

    return PricePrediction(
      trend: trend,
      variationPct: variation.abs(),
      movingAvg: movingAvg,
      advice: advice,
      hasEnoughData: true,
    );
  }

  static List<double> _movingAverage(List<double> prices, int window) {
    final effectiveWindow = window.clamp(1, prices.length);
    final result = <double>[];
    for (int i = effectiveWindow - 1; i < prices.length; i++) {
      final slice = prices.sublist(i - effectiveWindow + 1, i + 1);
      result.add(slice.reduce((a, b) => a + b) / effectiveWindow);
    }
    return result.isEmpty ? [prices.last] : result;
  }

  /// Regressione lineare OLS per determinare il trend del prezzo.
  static PriceTrend _detectTrend(List<double> prices) {
    final n = prices.length;
    if (n < 2) return PriceTrend.stable;

    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < n; i++) {
      final x = i.toDouble();
      sumX += x;
      sumY += prices[i];
      sumXY += x * prices[i];
      sumX2 += x * x;
    }

    final denom = n * sumX2 - sumX * sumX;
    if (denom == 0) return PriceTrend.stable;

    final slope = (n * sumXY - sumX * sumY) / denom;
    final avgPrice = sumY / n;

    // Soglia: variazione > 0.3% del prezzo per ogni periodo
    final threshold = avgPrice * 0.003 / n;
    if (slope > threshold) return PriceTrend.rising;
    if (slope < -threshold) return PriceTrend.falling;
    return PriceTrend.stable;
  }
}
