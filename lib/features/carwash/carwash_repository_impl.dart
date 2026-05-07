import 'package:mappa_prezzi_benzina/domain/entities/car_wash.dart';
import 'package:mappa_prezzi_benzina/features/carwash/carwash_model.dart';
import 'package:mappa_prezzi_benzina/features/carwash/carwash_repository.dart';
import 'package:mappa_prezzi_benzina/features/carwash/carwash_service.dart';

class CarWashRepositoryImpl implements CarWashRepository {
  final CarWashService _service;

  CarWashRepositoryImpl(this._service);

  @override
  Future<List<CarWash>> getNearbyCarWashes(
      double lat, double lon, double radiusKm) {
    return _service.getCarWashes(lat, lon, radiusKm);
  }

  @override
  Future<void> addCarWash(CarWash carWash) {
    final model = CarWashModel(
      id: carWash.id,
      name: carWash.name,
      address: carWash.address,
      latitude: carWash.latitude,
      longitude: carWash.longitude,
      type: carWash.type,
      hasVacuum: carWash.hasVacuum,
      paymentType: carWash.paymentType,
      createdAt: carWash.createdAt,
    );
    return _service.addCarWash(model);
  }

  @override
  Future<void> updateCarWash(CarWash carWash) {
    final model = CarWashModel(
      id: carWash.id,
      name: carWash.name,
      address: carWash.address,
      latitude: carWash.latitude,
      longitude: carWash.longitude,
      type: carWash.type,
      hasVacuum: carWash.hasVacuum,
      paymentType: carWash.paymentType,
      createdAt: carWash.createdAt,
    );
    return _service.updateCarWash(model);
  }
}
