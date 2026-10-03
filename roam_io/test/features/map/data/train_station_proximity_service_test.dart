/*
 * Author: OpenAI Codex
 * Last Modified: 3 October 2026
 * Description:
 *   Unit tests for train-station proximity detection against Places results,
 *   including one-shot alert de-duplication.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/journeys/domain/nearby_place.dart';
import 'package:roam_io/features/map/data/places_service.dart';
import 'package:roam_io/features/map/data/train_station_proximity_service.dart';
import 'package:roam_io/notifications/models/app_notification.dart';
import 'package:roam_io/notifications/models/notification_type.dart';

void main() {
  const station = NearbyPlace(
    placeId: 'place-flinders',
    name: 'Flinders Street Station',
    address: 'Melbourne VIC',
    latLng: LatLng(-37.8183, 144.9671),
    distanceMeters: 5,
    types: ['train_station', 'transit_station'],
  );

  late List<AppNotification> shown;
  late _FakePlacesService placesService;
  late TrainStationProximityService service;

  setUp(() {
    shown = <AppNotification>[];
    placesService = _FakePlacesService();
    service = TrainStationProximityService(
      placesService: placesService,
      showNotification: (notification) async => shown.add(notification),
      movementThresholdMeters: 0,
    );
  });

  test('isTrainStation recognises Google Places train types', () {
    expect(TrainStationProximityService.isTrainStation(station), isTrue);
    expect(
      TrainStationProximityService.isTrainStation(
        const NearbyPlace(
          name: 'Bus Stop',
          address: '',
          latLng: LatLng(0, 0),
          types: ['bus_stop'],
        ),
      ),
      isFalse,
    );
  });

  test('findNearbyTrainStations filters transport places to train stations', () async {
    placesService.results = [
      station,
      const NearbyPlace(
        placeId: 'place-bus',
        name: 'Bus Stop',
        address: '',
        latLng: LatLng(-37.8184, 144.9672),
        distanceMeters: 8,
        types: ['bus_stop'],
      ),
    ];

    final stations = await service.findNearbyTrainStations(
      latitude: -37.8183,
      longitude: 144.9671,
    );

    expect(stations, hasLength(1));
    expect(stations.single.placeId, 'place-flinders');
    expect(placesService.lastTransportOnly, isTrue);
  });

  test('nearestStation returns distance from Places results', () async {
    placesService.results = [station];

    final nearest = await service.nearestStation(
      latitude: -37.8183,
      longitude: 144.9671,
    );

    expect(nearest, isNotNull);
    expect(nearest!.station.placeId, 'place-flinders');
    expect(nearest.distanceMeters, 5);
  });

  test('alerts when the user enters the 10m proximity area', () async {
    placesService.results = [station];

    await service.onLocationUpdate(
      latitude: -37.8183,
      longitude: 144.9671,
    );

    expect(shown, hasLength(1));
    expect(shown.single.type, NotificationType.trainStationProximity);
    expect(shown.single.title, 'Near a train station');
    expect(shown.single.body, contains('Flinders Street Station'));
  });

  test('does not duplicate alerts while remaining in proximity', () async {
    placesService.results = [station];

    await service.onLocationUpdate(
      latitude: -37.8183,
      longitude: 144.9671,
    );
    await service.onLocationUpdate(
      latitude: -37.81831,
      longitude: 144.9671,
    );
    await service.onLocationUpdate(
      latitude: -37.81829,
      longitude: 144.9671,
    );

    expect(shown, hasLength(1));
  });

  test('can alert again after the user leaves and re-enters', () async {
    placesService.results = [station];
    await service.onLocationUpdate(
      latitude: -37.8183,
      longitude: 144.9671,
    );

    placesService.results = [
      NearbyPlace(
        placeId: station.placeId,
        name: station.name,
        address: station.address,
        latLng: station.latLng,
        distanceMeters: 40,
        types: station.types,
      ),
    ];
    await service.onLocationUpdate(
      latitude: -37.8187,
      longitude: 144.9671,
    );

    placesService.results = [station];
    await service.onLocationUpdate(
      latitude: -37.8183,
      longitude: 144.9671,
    );

    expect(shown, hasLength(2));
  });

  test('does not alert when outside the proximity radius', () async {
    placesService.results = [
      NearbyPlace(
        placeId: station.placeId,
        name: station.name,
        address: station.address,
        latLng: station.latLng,
        distanceMeters: 50,
        types: station.types,
      ),
    ];

    await service.onLocationUpdate(
      latitude: -37.8188,
      longitude: 144.9671,
    );

    expect(shown, isEmpty);
  });
}

class _FakePlacesService extends PlacesService {
  List<NearbyPlace> results = const [];
  bool? lastTransportOnly;
  int? lastRadiusMeters;

  @override
  Future<List<NearbyPlace>> getNearbyPlaces({
    required double lat,
    required double lng,
    int radiusMeters = 25,
    bool transportOnly = false,
  }) async {
    lastTransportOnly = transportOnly;
    lastRadiusMeters = radiusMeters;
    return results;
  }
}
