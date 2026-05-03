import 'package:mappa_prezzi_benzina/domain/entities/price_update.dart';

class PriceUpdateModel extends PriceUpdate {
  const PriceUpdateModel({
    required String id,
    required String stationId,
    required String userId,
    required String fuelType,
    required double price,
    required DateTime timestamp,
    int likes = 0,
    bool isFlagged = false,
  }) : super(
    id: id,
    stationId: stationId,
    userId: userId,
    fuelType: fuelType,
    price: price,
    timestamp: timestamp,
    likes: likes,
    isFlagged: isFlagged,
  );

  factory PriceUpdateModel.fromJson(Map<String, dynamic> json) {
    return PriceUpdateModel(
      id: (json['id'] as String?) ?? '',
      stationId: (json['stationId'] as String?) ?? '',
      userId: (json['userId'] as String?) ?? '',
      fuelType: (json['fuelType'] as String?) ?? '',
      price: ((json['price'] as num?) ?? 0.0).toDouble(),
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      likes: (json['likes'] as int?) ?? 0,
      isFlagged: (json['isFlagged'] as bool?) ?? false,
    );
  }

  factory PriceUpdateModel.fromFirestore(Map<String, dynamic> json, String docId) {
    return PriceUpdateModel(
      id: docId,
      stationId: (json['stationId'] as String?) ?? '',
      userId: (json['userId'] as String?) ?? '',
      fuelType: (json['fuelType'] as String?) ?? '',
      price: ((json['price'] as num?) ?? 0.0).toDouble(),
      timestamp: json['timestamp'] != null 
          ? (json['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      likes: (json['likes'] as int?) ?? 0,
      isFlagged: (json['isFlagged'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stationId': stationId,
      'userId': userId,
      'fuelType': fuelType,
      'price': price,
      'timestamp': timestamp.toIso8601String(),
      'likes': likes,
      'isFlagged': isFlagged,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'stationId': stationId,
      'userId': userId,
      'fuelType': fuelType,
      'price': price,
      'timestamp': timestamp,
      'likes': likes,
      'isFlagged': isFlagged,
    };
  }
}

class Timestamp {
  final DateTime _date;
  
  Timestamp(this._date);
  
  DateTime toDate() => _date;
}
