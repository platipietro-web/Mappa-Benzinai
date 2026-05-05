import 'package:equatable/equatable.dart';

class SavedStation extends Equatable {
  final String id;
  final String name;
  final String address;
  final String? brand;
  final double latitude;
  final double longitude;
  final DateTime? addedAt;
  final Map<String, double> prices;

  const SavedStation({
    required this.id,
    required this.name,
    required this.address,
    this.brand,
    required this.latitude,
    required this.longitude,
    this.addedAt,
    this.prices = const {},
  });

  @override
  List<Object?> get props => [id];
}
