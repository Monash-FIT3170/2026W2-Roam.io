/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026
 * Description:
 *   Widget tests for ActivityFeedCard and ActivityDetailScreen — centred
 *   metrics, live comment counts, privacy engagement flags, and personal
 *   detail without engagement controls.
 */

import 'dart:async';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/activity_feed/data/activity_map_image.dart';
import 'package:roam_io/features/activity_feed/data/activity_mutation_service.dart';
import 'package:roam_io/features/activity_feed/domain/activity_route.dart';
import 'package:roam_io/features/activity_feed/models/activity_comment.dart';
import 'package:roam_io/features/activity_feed/models/activity_feed_item.dart';
import 'package:roam_io/features/activity_feed/screens/activity_detail_screen.dart';
import 'package:roam_io/features/activity_feed/widgets/activity_feed_card.dart';
import 'package:roam_io/features/activity_feed/widgets/activity_map_preview.dart';
import 'package:roam_io/features/activity_feed/widgets/activity_media_carousel.dart';
import 'package:roam_io/features/activity_feed/widgets/route_marker_icons.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';
import 'package:roam_io/features/map/data/journey_map_snapshot_service.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';
import 'package:roam_io/features/map/data/visited_region_service.dart';
import 'package:roam_io/features/map/fog/fog_decay_difficulty.dart';
import 'package:roam_io/features/map/fog/static_fog.dart';
import 'package:roam_io/features/profile/domain/visited_polygon_meta.dart';
import 'package:roam_io/features/profile/domain/visited_polygon_record.dart';

void main() {
  testWidgets('fogs a post with the poster\'s tiles, not the viewer\'s', (
    tester,
  ) async {
    // A post shows the journey as the traveller had it: ground they had not
    // explored stays clouded even for a viewer who has explored all of it.
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final visitedRegionService = _FakeVisitedRegionService({
      'user-1': {'tile_the_poster_explored'},
      'viewer-9': {'tile_the_poster_explored', 'tile_only_the_viewer_explored'},
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActivityFeedCard.fromItem(
              _testActivity(),
              currentUserId: 'viewer-9',
              mapSnapshotService: _FakeJourneyMapSnapshotService(),
              visitedRegionService: visitedRegionService,
              endpointMarkerIcons: _testEndpointIcons,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(visitedRegionService.loadedProfileIds, ['user-1']);
    expect(
      visitedRegionService.loadedProfileIds,
      isNot(contains('viewer-9')),
      reason: 'the viewer\'s own tiles must never clear a post\'s fog',
    );
  });

  testWidgets('persisted activity card shows metrics and map preview', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final activity = _testActivity();
    final snapshotService = _FakeJourneyMapSnapshotService();
    final visitedRegionService = _FakeVisitedRegionService({
      'user-1': {'tile_visited'},
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActivityFeedCard.fromItem(
              activity,
              showKudos: true,
              showComments: true,
              showShare: true,
              commentCountStream: Stream<int>.value(0),
              mapSnapshotService: snapshotService,
              visitedRegionService: visitedRegionService,
              endpointMarkerIcons: _testEndpointIcons,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Traveller Activity 1'), findsOneWidget);
    expect(find.text('August 3, 2026 at 10:07 AM'), findsOneWidget);
    expect(find.text('47m 51s'), findsOneWidget);
    expect(find.text('Tiles Unlocked'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('+200 XP'), findsOneWidget);
    expect(find.text('Map preview'), findsNothing);
    expect(find.byType(ActivityMapPreview), findsOneWidget);
    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.polylines, hasLength(1));
    expect(map.polylines.single.points, _decodedRoutePoints);
    expect(map.polylines.single.color, TransportMode.walk.routeColor);
    expect(map.polylines.single.zIndex, 20);
    expect(map.markers, hasLength(2));
    expect(map.markers.every((marker) => marker.zIndexInt == 30), isTrue);
    expect(
      map.markers.every(
        (marker) => marker.anchor == RouteMarkerIcons.flagAnchor,
      ),
      isTrue,
    );
    // The fog is cloud drawn over the map rather than a fill inside it, so the
    // map carries the journey alone.
    expect(map.polygons, isEmpty);
    expect(
      tester
          .widget<StaticFogOverlay>(find.byType(StaticFogOverlay))
          .fog
          .clearedRegionIds,
      ['tile_visited'],
    );
    expect(snapshotService.loadedVisitedRegionIds, {'tile_visited'});
    expect(visitedRegionService.loadedProfileIds, ['user-1']);
    expect(map.scrollGesturesEnabled, isFalse);
    expect(map.zoomGesturesEnabled, isFalse);
    expect(map.rotateGesturesEnabled, isFalse);
    expect(map.tiltGesturesEnabled, isFalse);
    expect(map.mapToolbarEnabled, isFalse);
    expect(map.myLocationEnabled, isFalse);
    expect(map.myLocationButtonEnabled, isFalse);
    expect(map.zoomControlsEnabled, isFalse);
    expect(find.text('Glaze'), findsOneWidget);
    expect(find.text('0 comments'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    // Full labels — no ellipsis clipping on the three-action row.
    expect(find.textContaining('…'), findsNothing);
    expect(find.textContaining('...'), findsNothing);
    expect(find.text('Morning Weight Training'), findsNothing);
    expect(find.byIcon(Icons.fitness_center), findsNothing);

    final label = tester.widget<Text>(find.text('Tiles Unlocked'));
    expect(label.maxLines, 1);
    expect(label.softWrap, isFalse);
    expect(label.textAlign, TextAlign.center);
  });

  testWidgets('activity card uses Journey metrics and comment counts', (
    tester,
  ) async {
    final activity = _testActivity(
      id: 'activity-2',
      title: 'Traveller Activity 2',
      metrics: const [
        ActivityFeedMetric(label: 'Time', value: '1h 12m'),
        ActivityFeedMetric(label: 'Tiles Unlocked', value: '3'),
        ActivityFeedMetric(label: 'XP Gained', value: '+150 XP'),
      ],
    );
    final counts = StreamController<int>.broadcast();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActivityFeedCard.fromItem(
              activity,
              showShare: false,
              commentCountStream: counts.stream,
            ),
          ),
        ),
      ),
    );
    counts.add(0);
    await tester.pumpAndSettle();

    expect(find.text('Sidequest Progress'), findsNothing);
    expect(find.text('Tiles Unlocked'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Glaze'), findsOneWidget);
    expect(find.text('0 comments'), findsOneWidget);

    counts.add(1);
    await tester.pumpAndSettle();
    expect(find.text('1 comment'), findsOneWidget);

    counts.add(2);
    await tester.pumpAndSettle();
    expect(find.text('2 comments'), findsOneWidget);

    await counts.close();
  });

  testWidgets('activity card carousel shows media first and route map last', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final activity = _testActivity(
      media: [
        _testMedia(id: 'video-1', order: 0, type: ActivityMediaType.video),
        _testMedia(id: 'video-2', order: 1, type: ActivityMediaType.video),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActivityFeedCard.fromItem(
              activity,
              showKudos: false,
              showComments: false,
              showShare: false,
              mapSnapshotService: _FakeJourneyMapSnapshotService(),
              visitedRegionService: _FakeVisitedRegionService({
                'user-1': {'tile_visited'},
              }),
              endpointMarkerIcons: _testEndpointIcons,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ActivityMediaCarousel), findsOneWidget);
    expect(find.byIcon(Icons.videocam_outlined), findsWidgets);

    // The carousel frames every slide, so it has to hold the shape the map
    // picture was captured in — a wider slot crops the route's ends off with
    // BoxFit.cover, a taller one leaves it in bands.
    expect(
      tester
          .widget<ActivityMediaCarousel>(find.byType(ActivityMediaCarousel))
          .aspectRatio,
      ActivityMapImage.aspectRatio,
    );

    await tester.drag(find.byType(PageView), const Offset(-360, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-360, 0));
    await tester.pumpAndSettle();

    expect(find.byType(ActivityMapPreview), findsOneWidget);
    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.polylines.single.points, _decodedRoutePoints);
  });

  testWidgets('formatCommentCount uses singular and plural forms', (
    tester,
  ) async {
    expect(formatCommentCount(0), '0 comments');
    expect(formatCommentCount(1), '1 comment');
    expect(formatCommentCount(2), '2 comments');
  });

  testWidgets(
    'detail screen shows expanded map and metrics without engagement',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final activity = _testActivity();

      await tester.pumpWidget(
        MaterialApp(home: ActivityDetailScreen(activity: activity)),
      );

      expect(find.text('Traveller Activity 1'), findsOneWidget);
      expect(find.text('August 3, 2026 at 10:07 AM'), findsOneWidget);
      expect(find.text('Journey route map'), findsNothing);
      expect(
        find.byKey(const ValueKey('activity_route_map_detail')),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('47m 51s'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('47m 51s'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('+200 XP'), findsOneWidget);
      expect(find.text('Glaze'), findsNothing);
      expect(find.text('Comment'), findsNothing);
      expect(find.text('0 comments'), findsNothing);
      expect(find.text('Share'), findsNothing);
    },
  );

  testWidgets('detail visual carousel shows route first when media exists', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityDetailScreen(
          activity: _testActivity(
            media: [
              _testMedia(
                id: 'detail-video',
                order: 0,
                type: ActivityMediaType.video,
              ),
            ],
          ),
          endpointMarkerIcons: _testEndpointIcons,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ActivityMediaCarousel), findsOneWidget);
    expect(
      find.byKey(const ValueKey('activity_route_map_detail')),
      findsOneWidget,
    );
    expect(find.byType(ActivityMapPreview), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-360, 0));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
  });

  testWidgets('legacy activity without a usable route omits the map visual', (
    tester,
  ) async {
    final activity = _testActivity(encodedRoute: null, routeBounds: null);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActivityFeedCard.fromItem(
            activity,
            commentCountStream: Stream<int>.value(0),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ActivityMapPreview), findsNothing);
    expect(find.byType(GoogleMap), findsNothing);
    expect(find.text('Map preview'), findsNothing);
  });

  testWidgets(
    'map preview keeps skeleton and ignores stale snapshot results after route switch',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _QueuedJourneyMapSnapshotService();
      final routeA = ActivityRoute.fromPoints(const [
        LatLng(38.5, -120.2),
        LatLng(38.6, -120.3),
      ])!;
      final routeB = ActivityRoute.fromPoints(const [
        LatLng(40.7, -120.95),
        LatLng(40.8, -121.05),
      ])!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityMapPreview(
              route: routeA,
              visitedRegionIds: const {'tile_a'},
              mapSnapshotService: service,
              endpointMarkerIcons: _testEndpointIcons,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(service.calls, hasLength(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityMapPreview(
              route: routeB,
              visitedRegionIds: const {'tile_b'},
              mapSnapshotService: service,
              endpointMarkerIcons: _testEndpointIcons,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(service.calls, hasLength(2));

      service.complete(
        0,
        JourneyMapSnapshotOverlay(
          loadedBounds: routeA.bounds,
          clearedRegions: [_region(id: 'tile_a')],
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(StaticFogOverlay), findsNothing);

      service.complete(
        1,
        JourneyMapSnapshotOverlay(
          loadedBounds: routeB.bounds,
          clearedRegions: [_region(id: 'tile_b')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      final fog = tester
          .widget<StaticFogOverlay>(find.byType(StaticFogOverlay))
          .fog;
      expect(fog.clearedRegionIds, ['tile_b']);

      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.onCameraIdle, isNotNull);
      // A preview is framed programmatically, and iOS does not report that
      // through onCameraMove. The fog reads the settled camera back off the map
      // at idle instead, so listening here would only ever hand it the camera
      // the map was built with.
      expect(map.onCameraMove, isNull);
    },
  );

  testWidgets('detail map opens interactive expanded route screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityDetailScreen(
          activity: _testActivity(),
          endpointMarkerIcons: _testEndpointIcons,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final detailMap = find.byKey(const ValueKey('activity_route_map_detail'));
    expect(detailMap, findsOneWidget);
    final detailSize = tester.getSize(detailMap);
    expect(detailSize.height, greaterThan(220));

    await tester.tap(find.byKey(const ValueKey('activity_route_map_open')));
    await tester.pumpAndSettle();

    final expandedMap = find.byKey(
      const ValueKey('activity_route_map_expanded'),
    );
    expect(expandedMap, findsOneWidget);
    final map = tester.widget<GoogleMap>(
      find.descendant(of: expandedMap, matching: find.byType(GoogleMap)),
    );
    expect(map.markers, hasLength(2));
    expect(map.polylines, hasLength(1));
    expect(map.scrollGesturesEnabled, isTrue);
    expect(map.zoomGesturesEnabled, isTrue);
    expect(map.rotateGesturesEnabled, isTrue);
    // Tilt is a perspective projection the fog cannot reproduce, so these maps
    // stay flat like the explore map does.
    expect(map.tiltGesturesEnabled, isFalse);
    // A map that can be dragged does have camera moves worth following.
    expect(map.onCameraMove, isNotNull);
  });

  testWidgets('owner edit media controls use native library and no arrows', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityDetailScreen(
          activity: _testActivity(),
          currentUserId: 'user-1',
          mutationService: ActivityMutationService(
            firestore: FakeFirebaseFirestore(),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Activity'), findsOneWidget);
    expect(find.text('Photo Library'), findsOneWidget);
    expect(find.byTooltip('Take photo'), findsOneWidget);
    expect(find.byTooltip('Record video'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
  });
}

ActivityFeedItem _testActivity({
  String id = 'activity-1',
  String title = 'Traveller Activity 1',
  String? encodedRoute = _encodedRoute,
  ActivityRouteBounds? routeBounds = _routeBounds,
  List<ActivityFeedMetric> metrics = const [
    ActivityFeedMetric(label: 'Time', value: '47m 51s'),
    ActivityFeedMetric(label: 'Tiles Unlocked', value: '4'),
    ActivityFeedMetric(label: 'XP Gained', value: '+200 XP'),
  ],
  String? transportMode = 'walk',
  List<ActivityMediaItem> media = const <ActivityMediaItem>[],
}) {
  return ActivityFeedItem(
    id: id,
    ownerId: 'user-1',
    displayName: 'Traveller',
    username: 'traveller',
    timestampLabel: 'August 3, 2026 at 10:07 AM',
    title: title,
    kind: ActivityFeedKind.journey,
    showMapPreview: true,
    encodedRoute: encodedRoute,
    routeBounds: routeBounds,
    transportMode: transportMode,
    media: media,
    metrics: metrics,
  );
}

ActivityMediaItem _testMedia({
  required String id,
  required int order,
  ActivityMediaType type = ActivityMediaType.photo,
}) {
  return ActivityMediaItem(
    id: id,
    type: type,
    url:
        'https://example.com/$id.${type == ActivityMediaType.video ? 'mp4' : 'jpg'}',
    storagePath: 'activity_media/user-1/activity-1/$id',
    order: order,
    createdAt: DateTime.utc(2026, 8, 22, 10, order),
  );
}

const _encodedRoute = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
const _decodedRoutePoints = [
  LatLng(38.5, -120.2),
  LatLng(40.7, -120.95),
  LatLng(43.252, -126.453),
];

const _routeBounds = ActivityRouteBounds(
  southwestLatitude: 38.5,
  southwestLongitude: -126.453,
  northeastLatitude: 43.252,
  northeastLongitude: -120.2,
);

final _testEndpointIcons = RouteEndpointMarkerIcons(
  start: BitmapDescriptor.bytes(Uint8List.fromList([1, 2, 3])),
  finish: BitmapDescriptor.bytes(Uint8List.fromList([4, 5, 6])),
);

class _QueuedSnapshotCall {
  _QueuedSnapshotCall();

  final completer = Completer<JourneyMapSnapshotOverlay>();
}

class _QueuedJourneyMapSnapshotService extends JourneyMapSnapshotService {
  final calls = <_QueuedSnapshotCall>[];

  @override
  Future<JourneyMapSnapshotOverlay> loadRouteSnapshotOverlay({
    required ActivityRoute route,
    required Set<String> visitedRegionIds,
    String? currentRegionId,
    LatLngBounds? viewportBounds,
  }) {
    final call = _QueuedSnapshotCall();
    calls.add(call);
    return call.completer.future;
  }

  void complete(int index, JourneyMapSnapshotOverlay overlay) {
    calls[index].completer.complete(overlay);
  }
}

class _FakeJourneyMapSnapshotService extends JourneyMapSnapshotService {
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
      clearedRegions: [_region(id: 'tile_visited')],
    );
  }
}

class _FakeVisitedRegionService implements VisitedRegionService {
  _FakeVisitedRegionService(this.regionIdsByProfile);

  final Map<String, Set<String>> regionIdsByProfile;
  final List<String> loadedProfileIds = [];

  @override
  Future<Set<String>> loadVisitedRegionIds() async => const <String>{};

  @override
  Stream<Set<String>> watchVisitedRegionIds() {
    return Stream<Set<String>>.value(const <String>{});
  }

  @override
  Stream<List<VisitedPolygonRecord>> watchVisitedPolygonRecords({
    String? profileId,
  }) {
    final resolvedProfileId = profileId ?? '';
    loadedProfileIds.add(resolvedProfileId);
    return Stream<List<VisitedPolygonRecord>>.value(
      (regionIdsByProfile[resolvedProfileId] ?? const <String>{})
          .map(
            (regionId) => VisitedPolygonRecord(
              profileId: resolvedProfileId,
              polygonId: regionId,
              visitedAt: DateTime(2026, 8, 21),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Stream<Map<String, VisitedPolygonMeta>> watchVisitedPolygonMeta() {
    return Stream<Map<String, VisitedPolygonMeta>>.value(
      const <String, VisitedPolygonMeta>{},
    );
  }

  @override
  Stream<Map<String, int>> watchPolygonEntryCounts() {
    return Stream<Map<String, int>>.value(const <String, int>{});
  }

  @override
  Future<bool> markVisited(
    String regionId, {
    DateTime? visitedAt,
    double? areaSquareMetres,
    String? name,
  }) async => true;

  // Fog decay plays no part in the activity feed, which reads visited polygons
  // for its route preview and nothing else. Stubbed as "nothing has decayed".

  @override
  Future<Set<String>> loadFogClearedRegionIds({
    required FogDecayDifficulty difficulty,
    DateTime? now,
  }) async => const <String>{};

  @override
  Future<void> refreshFogDecayWarnings({
    required FogDecayDifficulty difficulty,
    DateTime? now,
  }) async {}

  @override
  Future<Map<String, DateTime>> loadUnpresentedFogDecayEvents({
    required FogDecayDifficulty difficulty,
    DateTime? now,
  }) async => const <String, DateTime>{};

  @override
  Future<void> markFogDecayEventsPresented(
    Map<String, DateTime> decayAtByRegionId,
  ) async {}
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
          <double>[-120.21, 38.49],
          <double>[-120.19, 38.49],
          <double>[-120.19, 38.51],
          <double>[-120.21, 38.51],
          <double>[-120.21, 38.49],
        ],
      ],
    },
  );
}
