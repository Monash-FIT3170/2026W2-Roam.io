/*
 * Author: Rushil Patel
 * Last Modified: 27/04/2026
 * Description:
 *   Provides device location access and permission handling for map features.
 */

import 'package:geolocator/geolocator.dart';

/// Wraps geolocation permission checks and current-position retrieval.
class GeoLocatorService {
  /// Returns the current high-accuracy device position.
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    // Request permission only after confirming it has not already been granted.
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}
