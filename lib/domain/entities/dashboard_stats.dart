import 'package:equatable/equatable.dart';

class MonthlySpend extends Equatable {
  final int year;
  final int month;
  final double amount;
  final double savedAmount;

  const MonthlySpend({
    required this.year,
    required this.month,
    required this.amount,
    required this.savedAmount,
  });

  String get label {
    const months = [
      'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
      'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic',
    ];
    return months[month - 1];
  }

  @override
  List<Object?> get props => [year, month, amount, savedAmount];
}

class DashboardStats extends Equatable {
  final double totalSpent;
  final double totalSaved;
  final double avgPriceChosen;
  final double avgPriceArea;
  final int refuelingCount;
  final List<MonthlySpend> monthlyHistory;
  final String? topSuggestion;

  const DashboardStats({
    this.totalSpent = 0,
    this.totalSaved = 0,
    this.avgPriceChosen = 0,
    this.avgPriceArea = 0,
    this.refuelingCount = 0,
    this.monthlyHistory = const [],
    this.topSuggestion,
  });

  bool get hasSavings => totalSaved > 0;
  bool get hasData => refuelingCount > 0;

  @override
  List<Object?> get props => [
        totalSpent,
        totalSaved,
        avgPriceChosen,
        avgPriceArea,
        refuelingCount,
        monthlyHistory,
      ];
}
