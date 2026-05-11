/*
 * Author: Amarprit Singh
 * Last Modified: 10/05/2026
 * Description:
 *
 *   Wraps geolocation access for the map feature so permission and device
 *   location calls are isolated from UI/controller code. This keeps map logic
 *   easier to test and change.
 *
 */

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Wraps geolocation permission checks and current-position retrieval.
class GeoLocatorService {
  static const int distanceRefreshThresholdMeters = 5;
  static const Duration currentLocationTimeout = Duration(seconds: 8);

  // Ensures location services are enabled and permissions are granted, throwing if not.
  Future<void> _ensureLocationAccess() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    var permission = await Geolocator.checkPermission();

    // Request permission if not already granted. If denied again or permanently, throw.
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      debugPrint('[GeoLocatorService] permission after request: $permission');
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }
  }

  // Gets the current location, falling back to the last known location if needed.
  Future<Position> getCurrentLocation() async {
    await _ensureLocationAccess();

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: currentLocationTimeout,
        ),
      );
    } catch (error) {
      debugPrint(
        '[GeoLocatorService] current position failed, trying last known: $error',
      );

      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        return lastKnownPosition;
      }

      throw Exception('Could not get current or last known location: $error');
    }
  }

  // Gets continuous location updates for the active map experience.
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
