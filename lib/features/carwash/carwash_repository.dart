import 'package:mappa_prezzi_benzina/domain/entities/car_wash.dart';

abstract class CarWashRepository {
  Future<List<CarWash>> getNearbyCarWashes(
      double lat, double lon, double radiusKm);
  Future<void> addCarWash(CarWash carWash);
  Future<void> updateCarWash(CarWash carWash);
}
