/*
 * Author: GitHub Copilot
 * Last Modified: 30/07/2026
 * Description:
 *   Core tracking service that subscribes to location updates and accumulates
 *   route points. Applies noise filtering and calculates running distance.
 */

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../map/data/geolocator_service.dart';

/// Service for tracking journey route points from GPS updates.
class JourneyTrackingService {
  JourneyTrackingService({GeoLocatorService? geoLocatorService})
    : _geoLocatorService = geoLocatorService ?? GeoLocatorService();

  final GeoLocatorService _geoLocatorService;

  /// Minimum distance (meters) between points to accept a new point.
  /// Filters GPS noise/jitter.
  static const double _noiseThresholdMeters = 5.0;

  /// Accumulated route points for the current journey.
  final List<LatLng> _routePoints = [];

  /// Total distance traveled in meters.
  double _totalDistanceMeters = 0.0;

  /// Stream subscription for location updates.
  StreamSubscription<Position>? _locationSubscription;

  /// Controller for broadcasting route updates.
  final _routeController = StreamController<List<LatLng>>.broadcast();

  /// Controller for broadcasting distance updates.
  final _distanceController = StreamController<double>.broadcast();

  /// Whether tracking is currently active.
  bool _isTracking = false;

  /// Gets the current route points (read-only copy).
  List<LatLng> get routePoints => List.unmodifiable(_routePoints);

  /// Gets the current total distance in meters.
  double get totalDistanceMeters => _totalDistanceMeters;

  /// Stream of route point updates.
  Stream<List<LatLng>> get routeStream => _routeController.stream;

  /// Stream of distance updates.
  Stream<double> get distanceStream => _distanceController.stream;

  /// Whether tracking is currently active.
  bool get isTracking => _isTracking;

  /// Starts tracking location updates.
  ///
  /// Optionally accepts an initial position to use as the first point.
  Future<void> startTracking({LatLng? initialPosition}) async {
    if (_isTracking) {
      debugPrint('[JourneyTrackingService] Already tracking, ignoring start');
      return;
    }

    _isTracking = true;
    _routePoints.clear();
    _totalDistanceMeters = 0.0;

    // Add initial position if provided
    if (initialPosition != null) {
      _routePoints.add(initialPosition);
      _routeController.add(_routePoints);
    }

    try {
      await _subscribeToLocationUpdates();
      debugPrint('[JourneyTrackingService] Started tracking');
    } catch (e) {
      _isTracking = false;
      debugPrint('[JourneyTrackingService] Failed to start tracking: $e');
      rethrow;
    }
  }

  /// Resumes a stopped session without clearing its route or distance.
  Future<void> resumeTracking() async {
    if (_isTracking) {
      debugPrint('[JourneyTrackingService] Already tracking, ignoring resume');
      return;
    }

    _isTracking = true;

    try {
      await _subscribeToLocationUpdates();
      debugPrint('[JourneyTrackingService] Resumed tracking');
    } catch (e) {
      _isTracking = false;
      debugPrint('[JourneyTrackingService] Failed to resume tracking: $e');
      rethrow;
    }
  }

  Future<void> _subscribeToLocationUpdates() async {
    final locationStream = await _geoLocatorService.getLocationUpdates();

    _locationSubscription = locationStream.listen(
      _onLocationUpdate,
      onError: (error) {
        debugPrint('[JourneyTrackingService] Location stream error: $error');
      },
    );
  }

  /// Stops tracking and returns the final route points.
  Future<List<LatLng>> stopTracking() async {
    if (!_isTracking) {
      debugPrint('[JourneyTrackingService] Not tracking, ignoring stop');
      return _routePoints;
    }

    _isTracking = false;
    await _locationSubscription?.cancel();
    _locationSubscription = null;

    debugPrint(
      '[JourneyTrackingService] Stopped tracking. '
      'Points: ${_routePoints.length}, Distance: ${_totalDistanceMeters.toStringAsFixed(1)}m',
    );

    return List.from(_routePoints);
  }

  /// Handles incoming location updates.
  void _onLocationUpdate(Position position) {
    final newPoint = LatLng(position.latitude, position.longitude);

    // Apply noise filtering if we have previous points
    if (_routePoints.isNotEmpty) {
      final lastPoint = _routePoints.last;
      final distance = _calculateDistance(lastPoint, newPoint);

      // Reject points that are too close (GPS noise)
      if (distance < _noiseThresholdMeters) {
        return;
      }

      // Add distance to total
      _totalDistanceMeters += distance;
      _distanceController.add(_totalDistanceMeters);
    }

    // Add the new point
    _routePoints.add(newPoint);
    _routeController.add(List.from(_routePoints));

    debugPrint(
      '[JourneyTrackingService] Point added: ${newPoint.latitude.toStringAsFixed(6)}, '
      '${newPoint.longitude.toStringAsFixed(6)} | Total: ${_routePoints.length} points, '
      '${_totalDistanceMeters.toStringAsFixed(1)}m',
    );
  }

  /// Calculates the distance between two points using the Haversine formula.
  double _calculateDistance(LatLng from, LatLng to) {
    const double earthRadiusMeters = 6371000;

    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final deltaLat = (to.latitude - from.latitude) * math.pi / 180;
    final deltaLng = (to.longitude - from.longitude) * math.pi / 180;

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  /// Cleans up resources.
  void dispose() {
    _locationSubscription?.cancel();
    _routeController.close();
    _distanceController.close();
  }
}
