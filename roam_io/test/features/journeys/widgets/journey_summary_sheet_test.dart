import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/activity_feed/domain/activity_route.dart';
import 'package:roam_io/features/activity_feed/widgets/activity_map_preview.dart';
import 'package:roam_io/features/activity_feed/widgets/route_marker_icons.dart';
import 'package:roam_io/features/journeys/domain/journey_location.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';
import 'package:roam_io/features/journeys/widgets/journey_summary_sheet.dart';
import 'package:roam_io/features/map/data/journey_map_snapshot_service.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';
import 'package:roam_io/features/map/fog/static_fog.dart';

void main() {
  testWidgets('returns edited activity title when saving', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    JourneySummaryResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await JourneySummarySheet.show(
                  context: context,
                  startLocation: _startLocation,
                  endLocation: _endLocation,
                  transportMode: TransportMode.walk,
                  distanceMeters: 3200,
                  duration: const Duration(minutes: 30),
                  routePoints: _routePoints,
                  startTime: DateTime(2026, 8, 10, 7),
                  xpEarned: 182,
                  tilesUnlocked: 3,
                  endpointMarkerIcons: _testEndpointIcons,
                  onUpdateStartName: (_) {},
                  onUpdateEndName: (_) {},
                );
              },
              child: const Text('Open summary'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open summary'));
    await tester.pumpAndSettle();

    expect(find.text('Journey Complete!'), findsOneWidget);
    expect(find.text('Journey Complete'), findsNothing);
    final heading = tester.widget<Text>(find.text('Journey Complete!'));
    expect(heading.maxLines, 1);
    expect(heading.softWrap, isFalse);
    expect(find.text('Journey title'), findsNothing);
    expect(find.text('+182 XP'), findsOneWidget);
    expect(find.textContaining('XP total'), findsNothing);
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.text('Morning Journey'), findsOneWidget);
    expect(find.text('Route'), findsOneWidget);
    expect(find.byType(ActivityMapPreview), findsOneWidget);
    expect(find.text('Route recorded'), findsNothing);
    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.polylines, hasLength(1));
    expect(map.polylines.single.points, _routePoints);
    expect(map.polylines.single.color, TransportMode.walk.routeColor);
    expect(map.markers, hasLength(2));
    expect(map.markers.map((marker) => marker.markerId.value), {
      'route-start',
      'route-finish',
    });
    final startMarker = map.markers.firstWhere(
      (marker) => marker.markerId.value == 'route-start',
    );
    final finishMarker = map.markers.firstWhere(
      (marker) => marker.markerId.value == 'route-finish',
    );
    expect(
      startMarker.icon,
      isNot(BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet)),
    );
    expect(
      finishMarker.icon,
      isNot(BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose)),
    );
    expect(startMarker.position, _routePoints.first);
    expect(finishMarker.position, _routePoints.last);
    expect(map.scrollGesturesEnabled, isFalse);
    expect(map.zoomGesturesEnabled, isFalse);
    expect(map.rotateGesturesEnabled, isFalse);
    expect(map.tiltGesturesEnabled, isFalse);
    expect(map.compassEnabled, isFalse);
    expect(map.mapToolbarEnabled, isFalse);
    expect(map.myLocationEnabled, isFalse);
    expect(map.myLocationButtonEnabled, isFalse);
    expect(map.zoomControlsEnabled, isFalse);
    expect(find.text('Media'), findsWidgets);
    expect(find.text('Photo Library'), findsOneWidget);
    expect(find.text('Add photos or videos'), findsWidgets);
    expect(find.text('0/3'), findsOneWidget);
    expect(find.text('0/3 photos or videos'), findsNothing);
    expect(find.text('Add media coming soon'), findsNothing);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.text('Locations Visited'), findsNothing);
    expect(find.text('Journey Details'), findsNothing);
    expect(find.text('From'), findsNothing);
    expect(find.text('To'), findsNothing);
    expect(find.text('Save Activity'), findsOneWidget);
    expect(find.text('Save Journey'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Creek Loop');
    await tester.scrollUntilVisible(
      find.text('Save Activity'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save Activity'));
    await tester.pumpAndSettle();

    expect(result?.action, JourneySummaryAction.save);
    expect(result?.title, 'Creek Loop');
    expect(result?.media, isEmpty);
  });

  testWidgets('returns discard action with current title', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    JourneySummaryResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await JourneySummarySheet.show(
                  context: context,
                  startLocation: _startLocation,
                  endLocation: _endLocation,
                  transportMode: TransportMode.walk,
                  distanceMeters: 3200,
                  duration: const Duration(minutes: 30),
                  routePoints: _routePoints,
                  startTime: DateTime(2026, 8, 10, 13),
                  xpEarned: 182,
                  tilesUnlocked: 3,
                  onUpdateStartName: (_) {},
                  onUpdateEndName: (_) {},
                );
              },
              child: const Text('Open summary'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open summary'));
    await tester.pumpAndSettle();

    expect(find.text('Afternoon Journey'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Discard'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(result?.action, JourneySummaryAction.discard);
    expect(result?.title, 'Afternoon Journey');
  });

  testWidgets('clears explored ground out of the fog when the snapshot loads', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final snapshotService = _FakeJourneyMapSnapshotService(
      regions: [_region(id: 'tile_visited')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JourneySummarySheet(
            startLocation: _startLocation,
            endLocation: _endLocation,
            transportMode: TransportMode.tram,
            distanceMeters: 3200,
            duration: const Duration(minutes: 30),
            routePoints: _routePoints,
            startTime: DateTime(2026, 8, 10, 7),
            xpEarned: 182,
            tilesUnlocked: 3,
            visitedRegionIds: const {'tile_visited'},
            currentRegionId: 'tile_visited',
            mapSnapshotService: snapshotService,
            endpointMarkerIcons: _testEndpointIcons,
            onUpdateStartName: (_) {},
            onUpdateEndName: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fog = tester
        .widget<StaticFogOverlay>(find.byType(StaticFogOverlay))
        .fog;
    expect(fog.clearedRegionIds, ['tile_visited']);

    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    // The fog is drawn above the map, not filled into it, so the map itself
    // carries nothing but the journey.
    expect(map.polygons, isEmpty);
    expect(map.polylines.single.points, _routePoints);
    expect(map.polylines.single.color, TransportMode.tram.routeColor);
    expect(map.polylines.single.zIndex, 20);
    expect(map.markers, hasLength(2));
    expect(map.markers.every((marker) => marker.zIndexInt == 30), isTrue);
    expect(
      map.markers.every(
        (marker) => marker.anchor == RouteMarkerIcons.flagAnchor,
      ),
      isTrue,
    );
    expect(snapshotService.loadedVisitedRegionIds, {'tile_visited'});
  });
}

const _startLocation = JourneyLocation(
  latLng: LatLng(-37.8136, 144.9631),
  displayName: 'Creek entrance',
);

const _endLocation = JourneyLocation(
  latLng: LatLng(-37.8115, 144.9631),
  displayName: 'Park lookout',
);

const _routePoints = [
  LatLng(-37.8136, 144.9631),
  LatLng(-37.8125, 144.9631),
  LatLng(-37.8115, 144.9631),
];

class _FakeJourneyMapSnapshotService extends JourneyMapSnapshotService {
  _FakeJourneyMapSnapshotService({required this.regions});

  final List<RegionPolygon> regions;
  Set<String>? loadedVisitedRegionIds;

  @override
  Future<JourneyMapSnapshotOverlay> loadRouteSnapshotOverlay({
    required ActivityRoute route,
    required Set<String> visitedRegionIds,
    String? currentRegionId,
    LatLngBounds? viewportBounds,
  }) async {
    loadedVisitedRegionIds = visitedRegionIds;
    return JourneyMapSnapshotOverlay(
      loadedBounds: route.bounds,
      clearedRegions: regions,
    );
  }
}

RegionPolygon _region({required String id}) {
  return RegionPolygon(
    id: id,
    name: id,
    areaSquareMetres: 1000,
    geometry: const <String, dynamic>{
      'type': 'Polygon',
      'coordinates': <dynamic>[
        <dynamic>[
          <double>[144.9630, -37.8140],
          <double>[144.9640, -37.8140],
          <double>[144.9640, -37.8130],
          <double>[144.9630, -37.8130],
          <double>[144.9630, -37.8140],
        ],
      ],
    },
  );
}

final _testEndpointIcons = RouteEndpointMarkerIcons(
  start: BitmapDescriptor.bytes(Uint8List.fromList([1, 2, 3])),
  finish: BitmapDescriptor.bytes(Uint8List.fromList([4, 5, 6])),
);
