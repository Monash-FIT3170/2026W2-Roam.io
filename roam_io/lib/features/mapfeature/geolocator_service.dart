// Wraps geolocation access for the map feature so permission and device
// location calls are isolated from UI/controller code. This keeps map logic
// easier to test and change.

import 'package:geolocator/geolocator.dart';

class GeoLocatorService {
  static const int distanceRefreshThresholdMeters = 5;

  Future<void> _ensureLocationAccess() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }
  }

  // function to get the current location of the user
  Future<Position> getCurrentLocation() async {
    await _ensureLocationAccess();

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  // function to get continuous location updates
  Future<Stream<Position>> getLocationUpdates() async {
    await _ensureLocationAccess();

    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceRefreshThresholdMeters,
      ),
    );
  }
}
