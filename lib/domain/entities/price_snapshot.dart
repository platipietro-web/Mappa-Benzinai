import 'package:equatable/equatable.dart';

class PriceSnapshot extends Equatable {
  final String stationId;
  final String fuelType;
  final double price;
  final DateTime timestamp;

  const PriceSnapshot({
    required this.stationId,
    required this.fuelType,
    required this.price,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [stationId, fuelType, price, timestamp];
}
