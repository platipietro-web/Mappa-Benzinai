import 'package:equatable/equatable.dart';

class PriceUpdate extends Equatable {
  final String id;
  final String stationId;
  final String userId;
  final String fuelType;
  final double price;
  final DateTime timestamp;
  final int likes;
  final bool isFlagged;

  const PriceUpdate({
    required this.id,
    required this.stationId,
    required this.userId,
    required this.fuelType,
    required this.price,
    required this.timestamp,
    this.likes = 0,
    this.isFlagged = false,
  });

  @override
  List<Object?> get props => [
    id,
    stationId,
    userId,
    fuelType,
    price,
    timestamp,
    likes,
    isFlagged,
  ];
}
