import 'package:mappa_prezzi_benzina/core/utils/logger.dart';
import 'package:mappa_prezzi_benzina/data/datasources/location_service.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';
import 'package:mappa_prezzi_benzina/domain/repositories/repositories.dart';

class LocationRepositoryImpl implements LocationRepository {
  final LocationService _locationService;

  LocationRepositoryImpl(this._locationService);

  @override
  Future<UserLocation> getCurrentLocation() async {
    try {
      return await _locationService.getCurrentLocation();
    } catch (e) {
      logError('Error in getCurrentLocation repository', e);
      rethrow;
    }
  }

  @override
  Future<bool> requestLocationPermission() async {
    try {
      return await _locationService.requestLocationPermission();
    } catch (e) {
      logError('Error in requestLocationPermission repository', e);
      return false;
    }
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await _locationService.isLocationServiceEnabled();
    } catch (e) {
      logError('Error in isLocationServiceEnabled repository', e);
      return false;
    }
  }

  @override
  Stream<UserLocation> getLocationUpdates() {
    return _locationService.getLocationStream();
  }
}
