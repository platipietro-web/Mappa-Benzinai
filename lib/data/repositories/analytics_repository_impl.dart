import 'package:mappa_prezzi_benzina/core/utils/logger.dart';
import 'package:mappa_prezzi_benzina/data/datasources/firestore_service.dart';
import 'package:mappa_prezzi_benzina/data/models/refueling_log_model.dart';
import 'package:mappa_prezzi_benzina/domain/entities/dashboard_stats.dart';
import 'package:mappa_prezzi_benzina/domain/entities/price_snapshot.dart';
import 'package:mappa_prezzi_benzina/domain/entities/refueling_log.dart';
import 'package:mappa_prezzi_benzina/domain/repositories/repositories.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final FirestoreService _firestoreService;

  AnalyticsRepositoryImpl(this._firestoreService);

  @override
  Future<void> logRefueling(RefuelingLog log) async {
    try {
      final model = RefuelingLogModel(
        id: log.id,
        userId: log.userId,
        stationId: log.stationId,
        stationName: log.stationName,
        fuelType: log.fuelType,
        pricePerLiter: log.pricePerLiter,
        liters: log.liters,
        totalCost: log.totalCost,
        savedVsArea: log.savedVsArea,
        areaAvgPrice: log.areaAvgPrice,
        timestamp: log.timestamp,
        vehicleId: log.vehicleId,
        odometerKm: log.odometerKm,
      );
      await _firestoreService.addRefuelingLog(model);
    } catch (e) {
      logError('Error in logRefueling repository', e);
      rethrow;
    }
  }

  @override
  Future<List<RefuelingLog>> getRefuelingLogs(String userId) async {
    try {
      return await _firestoreService.getRefuelingLogs(userId);
    } catch (e) {
      logError('Error in getRefuelingLogs repository', e);
      return [];
    }
  }

  @override
  Future<void> savePriceSnapshot(
      String stationId, String fuelType, double price) async {
    try {
      await _firestoreService.savePriceSnapshot(stationId, fuelType, price);
    } catch (e) {
      logError('Error in savePriceSnapshot repository', e);
    }
  }

  @override
  Future<List<PriceSnapshot>> getPriceSnapshots(
      String stationId, String fuelType) async {
    try {
      return await _firestoreService.getPriceSnapshots(stationId, fuelType);
    } catch (e) {
      logError('Error in getPriceSnapshots repository', e);
      return [];
    }
  }

  @override
  Future<DashboardStats> getDashboardStats(String userId) async {
    try {
      final logs = await _firestoreService.getRefuelingLogs(userId);
      return _computeStats(logs);
    } catch (e) {
      logError('Error in getDashboardStats repository', e);
      return const DashboardStats();
    }
  }

  DashboardStats _computeStats(List<RefuelingLog> logs) {
    if (logs.isEmpty) return const DashboardStats();

    final totalSpent = logs.fold(0.0, (sum, l) => sum + l.totalCost);
    final totalSaved = logs.fold(0.0, (sum, l) => sum + l.savedVsArea);

    final totalLiters = logs.fold(0.0, (sum, l) => sum + l.liters);
    final avgPriceChosen = totalLiters > 0
        ? logs.fold(0.0, (sum, l) => sum + l.pricePerLiter * l.liters) /
            totalLiters
        : 0.0;

    final areaAvgPrices =
        logs.where((l) => l.areaAvgPrice > 0).map((l) => l.areaAvgPrice);
    final avgPriceArea = areaAvgPrices.isNotEmpty
        ? areaAvgPrices.reduce((a, b) => a + b) / areaAvgPrices.length
        : 0.0;

    // Aggregazione mensile ultimi 6 mesi
    final now = DateTime.now();
    final monthlyMap = <String, MonthlySpend>{};

    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final key = '${date.year}-${date.month}';
      monthlyMap[key] =
          MonthlySpend(year: date.year, month: date.month, amount: 0, savedAmount: 0);
    }

    for (final log in logs) {
      final key = '${log.timestamp.year}-${log.timestamp.month}';
      if (monthlyMap.containsKey(key)) {
        final current = monthlyMap[key]!;
        monthlyMap[key] = MonthlySpend(
          year: current.year,
          month: current.month,
          amount: current.amount + log.totalCost,
          savedAmount: current.savedAmount + log.savedVsArea,
        );
      }
    }

    final monthlyHistory = monthlyMap.values.toList();

    // Suggerimento principale
    String? suggestion;
    if (avgPriceArea > 0 && avgPriceChosen > 0) {
      final diff = avgPriceArea - avgPriceChosen;
      if (diff > 0.01) {
        final monthlySaving = diff * (totalLiters / (logs.length.clamp(1, 999)));
        suggestion =
            'Stai risparmiando ~€${monthlySaving.toStringAsFixed(1)}/rifornimento rispetto alla media zona';
      } else if (diff < -0.01) {
        suggestion =
            'Potresti risparmiare cercando distributori con prezzi più bassi nella zona';
      }
    }

    return DashboardStats(
      totalSpent: totalSpent,
      totalSaved: totalSaved,
      avgPriceChosen: avgPriceChosen,
      avgPriceArea: avgPriceArea,
      refuelingCount: logs.length,
      monthlyHistory: monthlyHistory,
      topSuggestion: suggestion,
    );
  }
}
