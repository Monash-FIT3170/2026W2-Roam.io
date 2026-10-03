/*
 * Author: OpenAI Codex
 * Last Modified: 3 October 2026
 * Description:
 *   Detects when the user enters ~100m of a Google Places train station
 *   (via PlacesService) and surfaces a one-shot in-app safety notification.
 */

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../journeys/domain/nearby_place.dart';
import '../../../notifications/models/app_notification.dart';
import '../../../notifications/services/notification_service.dart';
import '../../../notifications/templates/notification_templates.dart';
import 'places_service.dart';

typedef TrainStationAlertShow =
    Future<void> Function(AppNotification notification);

/// Watches location updates and alerts once when near a train station.
class TrainStationProximityService {
  TrainStationProximityService({
    PlacesService? placesService,
    TrainStationAlertShow? showNotification,
    this.proximityRadiusMeters = 100,
    this.exitRadiusMeters = 150,
    this.queryRadiusMeters = 150,
    this.movementThresholdMeters = 5,
  }) : _placesService = placesService ?? PlacesService(),
       _showNotification =
           showNotification ?? NotificationService.instance.show;

  /// Google Place types treated as train stations for this alert.
  static const Set<String> trainStationTypes = {
    'train_station',
    'subway_station',
  };

  /// Types that mean this transit place is bus/tram, not a train station.
  static const Set<String> nonTrainTransitTypes = {
    'bus_stop',
    'bus_station',
    'tram_stop',
    'light_rail_station',
  };

  final PlacesService _placesService;
  final TrainStationAlertShow _showNotification;

  /// Radius that triggers a proximity alert.
  final double proximityRadiusMeters;

  /// Radius beyond which a station may alert again on re-entry.
  final double exitRadiusMeters;

  /// Radius used when querying Places for nearby transport candidates.
  final double queryRadiusMeters;

  /// Ignore location updates that have not moved at least this far.
  final double movementThresholdMeters;

  final Set<String> _alertedStationIds = <String>{};
  double? _lastCheckedLatitude;
  double? _lastCheckedLongitude;
  bool _isChecking = false;

  /// Station IDs that have already shown an alert while still nearby.
  Set<String> get alertedStationIds =>
      Set<String>.unmodifiable(_alertedStationIds);

  /// Whether [place] is a recognised train / subway station.
  ///
  /// Google sometimes labels major stations only as `transit_station` (no
  /// `train_station` type). Treat those as train stations when the name looks
  /// like a station and it is not also a bus/tram stop.
  static bool isTrainStation(NearbyPlace place) {
    final types = place.types.toSet();
    if (types.any(trainStationTypes.contains)) return true;

    final looksLikeStation = RegExp(
      r'\b(station|railway|train)\b',
      caseSensitive: false,
    ).hasMatch(place.name);
    if (!looksLikeStation) return false;
    if (types.any(nonTrainTransitTypes.contains)) return false;
    return types.contains('transit_station');
  }

  /// Distance in metres from [latitude]/[longitude] to [place].
  double distanceToPlace({
    required double latitude,
    required double longitude,
    required NearbyPlace place,
  }) {
    final reported = place.distanceMeters;
    if (reported != null) return reported.toDouble();

    return Geolocator.distanceBetween(
      latitude,
      longitude,
      place.latLng.latitude,
      place.latLng.longitude,
    );
  }

  /// Nearby train stations from Places, sorted nearest-first.
  Future<List<NearbyPlace>> findNearbyTrainStations({
    required double latitude,
    required double longitude,
    int? radiusMeters,
  }) async {
    final places = await _placesService.getNearbyPlaces(
      lat: latitude,
      lng: longitude,
      radiusMeters: radiusMeters ?? queryRadiusMeters.round(),
      transportOnly: true,
    );

    final stations = places.where(isTrainStation).toList()
      ..sort((a, b) {
        final aDistance = a.distanceMeters;
        final bDistance = b.distanceMeters;
        if (aDistance == null) return bDistance == null ? 0 : 1;
        if (bDistance == null) return -1;
        return aDistance.compareTo(bDistance);
      });

    return stations;
  }

  /// Nearest train station within the query radius, if any.
  Future<({NearbyPlace station, double distanceMeters})?> nearestStation({
    required double latitude,
    required double longitude,
  }) async {
    final stations = await findNearbyTrainStations(
      latitude: latitude,
      longitude: longitude,
    );
    if (stations.isEmpty) return null;

    final station = stations.first;
    return (
      station: station,
      distanceMeters: distanceToPlace(
        latitude: latitude,
        longitude: longitude,
        place: station,
      ),
    );
  }

  /// Evaluates the latest user fix and shows a proximity alert when needed.
  Future<void> onLocationUpdate({
    required double latitude,
    required double longitude,
  }) async {
    if (_isChecking) return;

    final lastLatitude = _lastCheckedLatitude;
    final lastLongitude = _lastCheckedLongitude;
    if (lastLatitude != null &&
        lastLongitude != null &&
        Geolocator.distanceBetween(
              lastLatitude,
              lastLongitude,
              latitude,
              longitude,
            ) <
            movementThresholdMeters) {
      return;
    }

    _lastCheckedLatitude = latitude;
    _lastCheckedLongitude = longitude;
    _isChecking = true;

    try {
      final stations = await findNearbyTrainStations(
        latitude: latitude,
        longitude: longitude,
      );

      if (stations.isEmpty) {
        debugPrint(
          '[TrainStationProximity] No train stations within '
          '${queryRadiusMeters.round()}m of ($latitude, $longitude)',
        );
      }

      final nearbyIds = <String>{};

      for (final station in stations) {
        final stationId = station.placeId ?? station.name;
        final distance = distanceToPlace(
          latitude: latitude,
          longitude: longitude,
          place: station,
        );

        if (distance <= proximityRadiusMeters) {
          nearbyIds.add(stationId);
          if (_alertedStationIds.contains(stationId)) continue;

          _alertedStationIds.add(stationId);
          debugPrint(
            '[TrainStationProximity] Near ${station.name} '
            '(${distance.toStringAsFixed(1)}m)',
          );
          await _showNotification(
            NotificationTemplates.trainStationProximity(station.name),
          );
          continue;
        }

        if (distance <= exitRadiusMeters) {
          nearbyIds.add(stationId);
        }
      }

      _alertedStationIds.removeWhere((id) => !nearbyIds.contains(id));
    } finally {
      _isChecking = false;
    }
  }

  /// Clears in-proximity alert state (e.g. on sign-out).
  void reset() {
    _alertedStationIds.clear();
    _lastCheckedLatitude = null;
    _lastCheckedLongitude = null;
  }
}
