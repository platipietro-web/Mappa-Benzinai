import 'package:geolocator/geolocator.dart';
import 'package:mappa_prezzi_benzina/core/errors/exceptions.dart';
import 'package:mappa_prezzi_benzina/core/utils/logger.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';

abstract class LocationService {
  Future<UserLocation> getCurrentLocation();
  Future<bool> requestLocationPermission();
  Future<bool> isLocationServiceEnabled();
  Stream<UserLocation> getLocationStream();
}

class LocationServiceImpl implements LocationService {
  @override
  Future<UserLocation> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        throw LocationException(message: 'Location permission denied');
      }

      final isEnabled = await isLocationServiceEnabled();
      if (!isEnabled) {
        throw LocationException(message: 'Location services are disabled');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      logInfo('Location obtained successfully');

      return UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      logError('Error getting location', e);
      rethrow;
    }
  }

  @override
  Future<bool> requestLocationPermission() async {
    try {
      final status = await Geolocator.checkPermission();
      
      if (status == LocationPermission.denied) {
        final result = await Geolocator.requestPermission();
        return result == LocationPermission.whileInUse ||
            result == LocationPermission.always;
      }
      
      return status == LocationPermission.whileInUse ||
          status == LocationPermission.always;
    } catch (e) {
      logError('Error requesting permission', e);
      return false;
    }
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  @override
  Stream<UserLocation> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).map((position) => UserLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          timestamp: DateTime.now(),
        )).handleError((Object error) {
      logError('Error in location stream', error);
      throw LocationException(message: 'Location stream error');
    });
  }
}
