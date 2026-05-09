import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class GeoLocatorService {
  Future<Position> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('[GeoLocatorService] serviceEnabled: $serviceEnabled');

    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    debugPrint('[GeoLocatorService] permission before: $permission');

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

    try {
      final currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      debugPrint(
        '[GeoLocatorService] current position: '
        '${currentPosition.latitude}, ${currentPosition.longitude}',
      );

      return currentPosition;
    } catch (error) {
      debugPrint(
        '[GeoLocatorService] current position failed, trying last known: $error',
      );

      final lastKnownPosition = await Geolocator.getLastKnownPosition();

      if (lastKnownPosition != null) {
        debugPrint(
          '[GeoLocatorService] last known position: '
          '${lastKnownPosition.latitude}, ${lastKnownPosition.longitude}',
        );

        return lastKnownPosition;
      }

      throw Exception('Could not get current or last known location: $error');
    }
  }
}